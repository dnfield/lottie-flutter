import 'dart:math';
import 'dart:ui';
import 'package:lottie_flutter/src/animatables.dart';
import 'package:lottie_flutter/src/animations.dart';
import 'package:lottie_flutter/src/drawing/drawing.dart';
import 'package:lottie_flutter/src/drawing/elements/paths.dart';
import 'package:lottie_flutter/src/utils.dart';
import 'package:lottie_flutter/src/values.dart';
import 'package:vector_math/vector_math_64.dart';

import 'package:lottie_flutter/src/drawing/drawing_layers.dart';

import 'package:path_drawing/path_drawing.dart';

class PathGroup {
  final List<PathContent> _paths = <PathContent>[];
  final TrimPathDrawable _trimPath;

  PathGroup(this._trimPath);
}

class StrokeDrawable extends AnimationDrawable {
  final List<PathGroup> _pathGroups = <PathGroup>[];
  final Paint _paint = new Paint();
  final Repaint _repaint;
  final BaseKeyframeAnimation<dynamic, int> _opacityAnimation;
  final BaseKeyframeAnimation<dynamic, double> _widthAnimation;
  final BaseKeyframeAnimation<dynamic, double> _dashPatternOffsetAnimation;
  final List<BaseKeyframeAnimation<double, double>> _dashPatternAnimations;

  StrokeDrawable(
    String name,
    StrokeCap strokeCap,
    StrokeJoin strokeJoin,
    List<AnimatableDoubleValue> dashPatternValues,
    this._repaint,
    this._opacityAnimation,
    this._widthAnimation,
    this._dashPatternOffsetAnimation,
    BaseLayer layer,
  )   : _dashPatternAnimations = dashPatternValues
            ?.map((AnimatableDoubleValue x) => x.createAnimation())
            ?.toList(),
        super(name, _repaint, layer) {
    _paint
      ..style = PaintingStyle.stroke
      ..strokeCap = strokeCap
      ..strokeJoin = strokeJoin;

    addAnimation(_opacityAnimation);
    addAnimation(_widthAnimation);

    for (AnimatableDoubleValue dashPattern in dashPatternValues) {
      addAnimation(dashPattern.createAnimation());
    }
    addAnimation(_dashPatternOffsetAnimation);
  }

  @override
  void setContents(List<Content> contentsBefore, List<Content> contentsAfter) {
    TrimPathDrawable trimPathDrawableBefore;
    for (int i = contentsBefore.length - 1; i >= 0; i--) {
      final Content content = contentsBefore[i];
      if (content is TrimPathDrawable &&
          content.type == ShapeTrimPathType.Individually) {
        trimPathDrawableBefore = content;
      }
    }

    if (trimPathDrawableBefore != null) {
      trimPathDrawableBefore.addListener(onValueChanged);
    }

    PathGroup currentPathGroup;

    for (int i = contentsAfter.length - 1; i >= 0; i--) {
      final Content content = contentsAfter[i];
      if (content is TrimPathDrawable &&
          content.type == ShapeTrimPathType.Individually) {
        if (currentPathGroup != null) {
          _pathGroups.add(currentPathGroup);
        }

        currentPathGroup = new PathGroup(content);
        content.addListener(onValueChanged);
      } else if (content is PathContent) {
        currentPathGroup =
            currentPathGroup ?? new PathGroup(trimPathDrawableBefore);
        currentPathGroup._paths.add(content);
      }
    }

    if (currentPathGroup != null) {
      _pathGroups.add(currentPathGroup);
    }
  }

  @override
  void onValueChanged(double progress) {
    _repaint();
  }

  @override
  void draw(Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    // scaling is handled differently, for better or worse
    final double strokeWidth =
        _widthAnimation.value * parentMatrix.getMaxScaleOnAxis();
    if (strokeWidth <= 0) {
      return;
    }
    _paint
      ..strokeWidth = strokeWidth // calculateScale(parentMatrix)
      ..color = _paint.color
          .withAlpha(calculateAlpha(parentAlpha, _opacityAnimation));

    for (PathGroup pathGroup in _pathGroups) {
      if (pathGroup._trimPath != null) {
        _applyTrimPath(canvas, pathGroup, parentMatrix);
      } else {
        Path path = new Path();
        for (int i = pathGroup._paths.length - 1; i >= 0; i--) {
          addPathToPath(path, pathGroup._paths[i].path, parentMatrix);
        }
        path = _applyDashPatternIfNeeded(path, parentMatrix);
        canvas.drawPath(path, _paint);
      }
    }
  }

  void _applyTrimPath(
      Canvas canvas, PathGroup pathGroup, Matrix4 parentMatrix) {
    if (pathGroup._trimPath == null) {
      return;
    }

    final Path path = new Path();
    for (int i = pathGroup._paths.length - 1; i >= 0; i--) {
      addPathToPath(path, pathGroup._paths[i].path, parentMatrix);
    }

    PathMetrics pm = path.computeMetrics();
    final double totalLength =
        pm.fold(0.0, (double len, PathMetric metric) => len + metric.length);

    final TrimPathDrawable trimPath = pathGroup._trimPath;
    final double offsetLength = totalLength * trimPath.offset / 360.0;
    final double startLength =
        totalLength * trimPath.start / 100.0 + offsetLength;
    final double endLength = totalLength * trimPath.end / 100.0 + offsetLength;

    double currentLength = 0.0;
    for (int j = pathGroup._paths.length - 1; j >= 0; j--) {
      final Path trimPath = pathGroup._paths[j].path;
      trimPath.transform(parentMatrix.storage);

      pm = trimPath.computeMetrics();
      final double length = pm.first.length;

      if (endLength > totalLength &&
          endLength - totalLength < currentLength + length &&
          currentLength < endLength - totalLength) {
        _drawSegment(
            canvas, trimPath, length, startLength, endLength, totalLength);
        continue;
      }

      if (currentLength + length < startLength || currentLength > endLength) {
        currentLength += length;
        continue;
      }

      if (currentLength + length <= endLength && startLength < currentLength) {
        canvas.drawPath(trimPath, _paint);
        currentLength += length;
        continue;
      }

      final double start = startLength < currentLength
          ? 0.0
          : (startLength - currentLength) / length;
      final double end = endLength > currentLength + length
          ? 1.0
          : (endLength - currentLength) / length;

      final Path path = applyTrimPathIfNeeded(trimPath, start, end, 0.0);
      canvas.drawPath(path, _paint);
      currentLength += length;
    }
  }

  /// Draw the segment when the end is greater than the length which wraps
  /// around to the beginning.
  void _drawSegment(Canvas canvas, Path path, double length, double startLength,
      double endLength, double totalLength) {
    final double start =
        startLength > totalLength ? (startLength - totalLength) / length : 0.0;
    final double end = min((endLength - totalLength) / length, 1.0);
    final Path trimPath = applyTrimPathIfNeeded(path, start, end, 0.0);
    canvas.drawPath(trimPath, _paint);
  }

  @override
  Rect getBounds(Matrix4 parentMatrix) {
    final Path path = new Path();
    for (PathGroup pathGroup in _pathGroups) {
      for (PathContent pathContent in pathGroup._paths) {
        addPathToPath(path, pathContent.path, parentMatrix);
      }
    }

    final Rect outBounds = path.getBounds();

    final double width = _widthAnimation.value;
    return new Rect.fromLTRB(
        outBounds.left - width / 2.0 - 1,
        outBounds.top - width / 2.0 - 1,
        outBounds.right + width / 2.0 + 1,
        outBounds.bottom + width / 2.0 + 1);
  }

  Path _applyDashPatternIfNeeded(Path path, Matrix4 parentMatrix) {
    if (_dashPatternAnimations.isEmpty) {
      return path;
    }

    const double scale = 1.0; // calculateScale(parentMatrix);
    final List<double> dashPatternValues =
        new List<double>(_dashPatternAnimations.length);
    for (int i = 0; i < _dashPatternAnimations.length; i++) {
      dashPatternValues[i] = _dashPatternAnimations[i]?.value ?? 0.0;
      // If the value of the dash pattern or gap is too small, the number of individual sections
      // approaches infinity as the value approaches 0.
      // To mitigate this, we essentially put a minimum value on the dash pattern size of 1px
      // and a minimum gap size of 0.01.
      if (i % 2 == 0) {
        if (dashPatternValues[i] < 1.0) {
          dashPatternValues[i] = 1.0;
        }
      } else {
        if (dashPatternValues[i] < 0.1) {
          dashPatternValues[i] = 0.1;
        }
      }
      dashPatternValues[i] *= scale;
    }
    final double offset = _dashPatternOffsetAnimation == null
        ? 0.0
        : _dashPatternOffsetAnimation.value;

    return dashPath(path,
        dashArray: new CircularIntervalList<double>(dashPatternValues),
        dashOffset: new DashOffset.absolute(offset));
  }
}

class ShapeStrokeDrawable extends StrokeDrawable {
  final KeyframeAnimation<Color> _colorAnimation;

  ShapeStrokeDrawable(
      String name,
      StrokeCap strokeCap,
      StrokeJoin strokeJoin,
      List<AnimatableDoubleValue> dashPatternValues,
      Repaint repaint,
      BaseKeyframeAnimation<dynamic, int> opacityAnimation,
      BaseKeyframeAnimation<dynamic, double> widthAnimation,
      BaseKeyframeAnimation<dynamic, double> dashPatternOffsetAnimation,
      this._colorAnimation,
      BaseLayer layer)
      : super(
            name,
            strokeCap,
            strokeJoin,
            dashPatternValues,
            repaint,
            opacityAnimation,
            widthAnimation,
            dashPatternOffsetAnimation,
            layer) {
    addAnimation(_colorAnimation);
  }

  @override
  void addColorFilter(
      String layerName, String contentName, ColorFilter colorFilter) {
    _paint.colorFilter = colorFilter;
  }

  @override
  void draw(Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    _paint.color = _colorAnimation.value;
    super.draw(canvas, size, parentMatrix, parentAlpha);
  }
}

class GradientStrokeDrawable extends StrokeDrawable {
  final GradientType _type;
  final KeyframeAnimation<GradientColor> _colorAnimation;
  final KeyframeAnimation<Offset> _startPointAnimation;
  final KeyframeAnimation<Offset> _endPointAnimation;

  GradientStrokeDrawable(
    String name,
    StrokeCap strokeCap,
    StrokeJoin strokeJoin,
    List<AnimatableDoubleValue> dashPatternValues,
    Repaint repaint,
    BaseKeyframeAnimation<dynamic, int> opacityAnimation,
    BaseKeyframeAnimation<dynamic, double> widthAnimation,
    BaseKeyframeAnimation<dynamic, double> dashPatternOffsetAnimation,
    this._type,
    this._colorAnimation,
    this._startPointAnimation,
    this._endPointAnimation,
    BaseLayer layer,
  ) : super(
            name,
            strokeCap,
            strokeJoin,
            dashPatternValues,
            repaint,
            opacityAnimation,
            widthAnimation,
            dashPatternOffsetAnimation,
            layer) {
    addAnimation(_colorAnimation);
  }

  @override
  void draw(Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    _paint.shader = createGradientShader(
        _colorAnimation.value,
        _type,
        applyMatrixToOffset(parentMatrix, _startPointAnimation.value),
        applyMatrixToOffset(parentMatrix, _endPointAnimation.value),
    );

    super.draw(canvas, size, parentMatrix, parentAlpha);
  }
}
