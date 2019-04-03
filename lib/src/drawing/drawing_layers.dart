import 'dart:math';
import 'dart:ui';
import 'package:lottie_flutter/src/animations.dart';
import 'package:lottie_flutter/src/composition.dart';
import 'package:lottie_flutter/src/drawing/drawing.dart';
import 'package:lottie_flutter/src/drawing/elements/groups.dart';
import 'package:lottie_flutter/src/elements/groups.dart';
import 'package:lottie_flutter/src/layers.dart';
import 'package:lottie_flutter/src/painting.dart';
import 'package:lottie_flutter/src/elements/transforms.dart';
import 'package:lottie_flutter/src/utils.dart';
import 'package:flutter/painting.dart';

import 'package:vector_math/vector_math_64.dart';

import 'package:meta/meta.dart';

BaseLayer layerForModel(
    Layer layer, LottieComposition composition, double scale, Repaint repaint) {
  switch (layer.type) {
    case LayerType.Shape:
      return new ShapeLayer(layer, repaint);
    case LayerType.PreComp:
      return new CompositionLayer(composition, layer, repaint, scale);
    case LayerType.Solid:
      return new SolidLayer(layer, repaint);
    case LayerType.Image:
      return new ImageLayer(layer, repaint, scale);
    case LayerType.Null:
      return new NullLayer(layer, repaint);
    case LayerType.Text:
    case LayerType.Unknown:
    default: // Do nothing
      print('Unknown layer type ${layer.type}');
      return null;
  }
}

abstract class BaseLayer implements Drawable {
  bool _visibility = true;
  BaseLayer _parent;
  List<BaseLayer> _parents;
  BaseLayer _matteLayer;
  Path _path = new Path();

  final Repaint _repaint;
  final Layer _layerModel;
  final Paint _contentPaint = new Paint();
  final Paint _maskPaint = new Paint();
  final Paint _mattePaint = new Paint();
  final Paint _clearPaint = new Paint();
  final MaskKeyframeAnimation _mask;
  final TransformKeyframeAnimation _transform;
  final List<BaseKeyframeAnimation<dynamic, dynamic>> _animations =
      <BaseKeyframeAnimation<dynamic, dynamic>>[];

  BaseLayer(this._layerModel, this._repaint)
      : _transform = _layerModel.transform.createAnimation(),
        _mask = new MaskKeyframeAnimation(
            _layerModel.masks == null ? const <Mask>[] : _layerModel.masks) {
    _clearPaint.blendMode = BlendMode.clear;
    _maskPaint.blendMode = BlendMode.dstIn;
    _mattePaint.blendMode = _layerModel.matteType == MatteType.Invert
        ? BlendMode.dstOut
        : BlendMode.dstIn;

    _transform.addAnimationsToLayer(this);
    _transform.addListener(onAnimationChanged);

    for (BaseKeyframeAnimation<dynamic, Path> animation in _mask.animations) {
      addAnimation(animation);
      animation.addListener(onAnimationChanged);
    }

    setupInOutAnimations();
  }

  Layer get layerModel => _layerModel;

  bool get hasMatteOnThisLayer => _matteLayer != null;

  bool get hasMasksOnThisLayer => _mask.animations.isNotEmpty;

  @override
  String get name => _layerModel.name;

  set matteLayer(BaseLayer layer) => _matteLayer = layer;

  set parent(BaseLayer layer) => _parent = layer;

  set visibility(bool value) {
    if (value != _visibility) {
      _visibility = value;
      invalidateSelf();
    }
  }

  /// Set animation progress, from 0 to 1
  set progress(double val) {
    _transform?.progress = val;
    if (_layerModel.timeStretch != null && _layerModel.timeStretch != 0) {
      val /= _layerModel.timeStretch;
    }

    // TODO - mattelayer timestretch?
    _matteLayer?.progress = val;
    for (BaseKeyframeAnimation<dynamic, dynamic> animation in _animations) {
      animation.progress = val;
    }
  }

  void addAnimation(BaseKeyframeAnimation<dynamic, dynamic> newAnimation) {
    if (newAnimation != null && newAnimation is! StaticKeyframeAnimation) {
      _animations.add(newAnimation);
    }
  }

  void onAnimationChanged(double progress) {
    invalidateSelf();
  }

  void setupInOutAnimations() {
    if (_layerModel.inOutKeyframes.isEmpty) {
      visibility = true;
      return;
    }

    final DoubleKeyframeAnimation inOutAnimation =
        new DoubleKeyframeAnimation(_layerModel.inOutKeyframes);

    inOutAnimation.isDiscrete = true;
    inOutAnimation.addListener((double progress) {
      _visibility = inOutAnimation.value == 1.0;
    });

    _visibility = inOutAnimation.value == 1.0;
    addAnimation(inOutAnimation);
  }

  void invalidateSelf() {
    _repaint();
  }

  @mustCallSuper
  @override
  Rect getBounds(Matrix4 parentMatrix) {
    final Matrix4 matrix = parentMatrix.clone();
    matrix.multiply(_transform.matrix);
    return calculateBounds(matrix);
  }

  @override
  void setContents(List<Content> contentsBefore, List<Content> contentsAfter) {
    // Do nothing
  }

  @override
  void draw(Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    if (!_visibility) {
      return;
    }
    final Matrix4 matrix = parentMatrix.clone();

    buildParentLayerListIfNeeded();

    for (int i = _parents.length - 1; i >= 0; i--) {
      matrix.multiply(_parents[i]._transform.matrix);
    }

    final int alpha = calculateAlpha(parentAlpha, _transform.opacity);

    if (!hasMatteOnThisLayer && !hasMasksOnThisLayer) {
      matrix.multiply(_transform.matrix);
      drawLayer(canvas, size, matrix, alpha);
      return;
    }

    Rect rect = getBounds(matrix);
    rect = intersectBoundsWithMatte(rect, matrix);

    matrix.multiply(_transform.matrix);
    rect = intersectBoundsWithMask(rect, matrix);

    final Rect canvasBounds =
        new Rect.fromLTRB(0.0, 0.0, size.width, size.height);
    canvas.saveLayer(canvasBounds, _contentPaint);
    clearCanvas(canvas, canvasBounds);
    drawLayer(canvas, size, matrix, alpha);

    if (hasMasksOnThisLayer) {
      applyMasks(canvas, canvasBounds, matrix);
    }

    if (hasMatteOnThisLayer) {
      canvas.saveLayer(canvasBounds, _mattePaint);
      clearCanvas(canvas, canvasBounds);
      _matteLayer.draw(canvas, size, parentMatrix, parentAlpha);
      canvas.restore();
    }

    canvas.restore();
  }

  void clearCanvas(Canvas canvas, Rect bounds) {
    // TODO: Does this happen in Flutter too?
    // IF we don't pad the clear draw, some phones leave a 1px border of the
    // graphics buffer.
    canvas.drawRect(
        new Rect.fromLTRB(bounds.left - 1, bounds.top - 1, bounds.right + 1,
            bounds.bottom + 1),
        _clearPaint);
  }

  void buildParentLayerListIfNeeded() {
    if (_parents != null) {
      return;
    }

    if (_parent == null) {
      _parents = const <BaseLayer>[];
      return;
    }

    _parents = <BaseLayer>[];
    BaseLayer layer = _parent;
    while (layer != null) {
      _parents.add(layer);
      layer = layer._parent;
    }
  }

  Rect intersectBoundsWithMatte(Rect rect, Matrix4 matrix) {
    if (!hasMatteOnThisLayer || layerModel.matteType == MatteType.Invert) {
      // We can't trim the bounds if the mask is inverted since it extends all
      // the way to the composition bounds
      return rect;
    }

    final Rect bounds = _matteLayer.getBounds(matrix);
    return _maxLeftTopMinRightBottom(rect, bounds);
  }

  Rect intersectBoundsWithMask(Rect rect, Matrix4 matrix) {
    if (!hasMasksOnThisLayer) {
      return rect;
    }

    final int length = _mask.masks.length;
    Rect maskBoundRect = Rect.zero;

    for (int i = 0; i < length; i++) {
      final Mask mask = _mask.masks[i];
      final BaseKeyframeAnimation<dynamic, Path> animation =
          _mask.animations[i];

      _path = animation.value;
      _path = _path.transform(matrix.storage);

      switch (mask.mode) {
        case MaskMode.Subtract:
          // If there is a subtract mask, the mask could potentially be the size
          // of the entire canvas so we can't use the mask bounds
          return rect;
        case MaskMode.Intersect:
          // TODO
          return rect;
        case MaskMode.Add:
        default:
          final Rect tempMaskBoundRect = _path.getBounds();

          // As we iterate through the masks, we want to calculate the union region
          // of the masks. We initialize the rect with the first mask.
          maskBoundRect = i == 0
              ? maskBoundRect
              : _minTopLeftMaxRightBottom(maskBoundRect, tempMaskBoundRect);
      }
    }
    return _maxLeftTopMinRightBottom(rect, maskBoundRect);
  }

  void applyMasks(Canvas canvas, Rect bounds, Matrix4 matrix) {
    canvas.saveLayer(bounds, _maskPaint);
    clearCanvas(canvas, bounds);

    final int length = _mask.masks.length;
    for (int i = 0; i < length; i++) {
      final Mask mask = _mask.masks[i];
      final BaseKeyframeAnimation<dynamic, Path> animation =
          _mask.animations[i];

      _path = animation.value;
      _path = _path.transform(matrix.storage);

      switch (mask.mode) {
        case MaskMode.Subtract:
          // PathFillType.inverseWinding is deprecated https://github.com/flutter/flutter/issues/5912
          //_path.fillType = PathFillType.inverseWinding;
          print(
              'MaskMode.Subtract is not supported because PathFillType.inverseWinding is deprecated');
          break;
        case MaskMode.Add:
        default:
          _path.fillType = PathFillType.nonZero;
          break;
      }

      canvas.drawPath(_path, _contentPaint);
    }

    canvas.restore();
  }

  Rect _maxLeftTopMinRightBottom(Rect first, Rect second) => new Rect.fromLTRB(
      max(first.left, second.left),
      max(first.top, second.top),
      min(first.right, second.right),
      min(first.bottom, second.bottom));

  Rect _minTopLeftMaxRightBottom(Rect first, Rect second) => new Rect.fromLTRB(
      min(first.left, second.left),
      min(first.top, second.top),
      max(first.right, second.right),
      max(first.bottom, second.bottom));

  Rect calculateBounds(Matrix4 parentMatrix);

  void drawLayer(
      Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha);
}

class SolidLayer extends BaseLayer {
  final Paint _paint = new Paint();

  SolidLayer(Layer layerModel, Repaint repaint) : super(layerModel, repaint) {
    _paint.color = layerModel.solidColor;
    _paint.style = PaintingStyle.fill;
  }

  @override
  void drawLayer(
      Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    if (layerModel.solidColor.alpha == 0) {
      return;
    }

    final int alpha =
        calculateAlpha(layerModel.solidColor.alpha, _transform.opacity);
    if (alpha > 0) {
      _paint.color = _paint.color.withAlpha(alpha);
      final Rect transformRect = calculateTransform(parentMatrix);
      canvas.drawRect(transformRect, _paint);
    }
  }

  Rect calculateTransform(Matrix4 parentMatrix) {
    final Rect canvasBounds = new Rect.fromLTRB(0.0, 0.0,
        _layerModel.solidWidth.toDouble(), _layerModel.solidHeight.toDouble());
    final Rect transformRect =
        MatrixUtils.transformRect(parentMatrix, canvasBounds);
    return transformRect;
  }

  @override
  Rect calculateBounds(Matrix4 parentMatrix) {    
    final Rect canvasBounds = new Rect.fromLTRB(0.0, 0.0,
        _layerModel.solidWidth.toDouble(), _layerModel.solidHeight.toDouble());
    final Rect transformRect =
        MatrixUtils.transformRect(parentMatrix, canvasBounds);
    return transformRect;
  }

  @override
  void addColorFilter(
      String layerName, String contentName, ColorFilter colorFilter) {
    _paint.colorFilter = colorFilter;
  }
}

class ShapeLayer extends BaseLayer {
  DrawableGroup _contentGroup;

  ShapeLayer(Layer layerModel, Repaint repaint) : super(layerModel, repaint) {
    _contentGroup = new DrawableGroup(
        layerModel.name,
        repaint,
        shapesToAnimationDrawable(repaint, layerModel.shapes, this),
        obtainTransformAnimation(layerModel.shapes),
        this);
    _contentGroup.setContents(const <Content>[], const <Content>[]);
  }

  @override
  void drawLayer(
      Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    _contentGroup.draw(canvas, size, parentMatrix, parentAlpha);
  }

  @override
  Rect calculateBounds(Matrix4 parentMatrix) {
    return _contentGroup.getBounds(parentMatrix);
  }

  @override
  void addColorFilter(
      String layerName, String contentName, ColorFilter colorFilter) {
    _contentGroup.addColorFilter(layerName, contentName, colorFilter);
  }
}

class ImageLayer extends BaseLayer {
  final Paint _paint = new Paint();
  final double _density;

  ImageLayer(Layer layerModel, Repaint repaint, this._density)
      : super(layerModel, repaint) {
    _paint
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.low; // bilinear interpolation
  }

  @override
  void drawLayer(
      Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    //TODO: fetch image from refId
    final Image image = _getImage();

    if (image == null) {
      return;
    }

    _paint.color = _paint.color.withAlpha(parentAlpha);
    canvas.save();
    canvas.transform(parentMatrix.storage);
    final Rect imageBounds = new Rect.fromLTRB(
        0.0, 0.0, image.width.toDouble(), image.height.toDouble());
    final Rect destiny = new Rect.fromLTRB(
        0.0, 0.0, image.width * _density, image.height * _density);
    canvas.drawImageRect(image, imageBounds, destiny, _paint);
    canvas.restore();
  }

  @override
  Rect calculateBounds(Matrix4 parentMatrix) {
    final Image image = _getImage();
    if (image != null) {
      final Rect bounds = new Rect.fromLTRB(
          0.0, 0.0, image.width.toDouble(), image.height.toDouble());
      return MatrixUtils.transformRect(parentMatrix, bounds);
    }

    return Rect.zero;
  }

  @override
  void addColorFilter(
      String layerName, String contentName, ColorFilter colorFilter) {
    _paint.colorFilter = colorFilter;
  }

  bool _getImageWarned = false;
  Image _getImage() {
    if (!_getImageWarned) {
      print('Get Image not implemented - TODO');
      _getImageWarned = true;
    }
    //TODO: fetch image from refId
    return null;
  }
}

class NullLayer extends BaseLayer {
  NullLayer(Layer layerModel, Repaint repaint) : super(layerModel, repaint);

  @override
  void addColorFilter(
      String layerName, String contentName, ColorFilter colorFilter) {
    // Do nothing
  }

  @override
  Rect calculateBounds(Matrix4 parentMatrix) {
    return Rect.zero;
  }

  @override
  void drawLayer(
      Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    // Do nothing
  }
}

class CompositionLayer extends BaseLayer {
  final List<BaseLayer> _layers = <BaseLayer>[];
  bool _hasMatte;
  bool _hasMasks;

  CompositionLayer(LottieComposition composition, Layer layerModel,
      Repaint repaint, double scale)
      : assert(composition != null),
        super(layerModel, repaint) {
    final List<Layer> layerModels =
        composition?.preComps[layerModel.refId] ?? composition?.layers;
    final Map<int, BaseLayer> layerMap = <int, BaseLayer>{};

    for (int i = layerModels.length - 1; i >= 0; i--) {
      final Layer currentLayerModel = layerModels[i];
      final BaseLayer layer =
          layerForModel(currentLayerModel, composition, scale, repaint);

      if (layer == null) {
        continue;
      }

      layerMap[layer.layerModel.id] = layer;

      if (_matteLayer != null) {
        _matteLayer._matteLayer = layer;
        _matteLayer = null;
      } else {
        _layers.insert(0, layer);
        switch (currentLayerModel.matteType) {
          case MatteType.Add:
          case MatteType.Invert:
            _matteLayer = layer;
            break;
          default:
            break;
        }
      }
    }

    layerMap.forEach((int key, BaseLayer currentLayer) {
      final BaseLayer parent = layerMap[currentLayer.layerModel.parentId];
      if (parent != null) {
        currentLayer.parent = parent;
      }
    });
  }

  @override
  void drawLayer(
      Canvas canvas, Size size, Matrix4 parentMatrix, int parentAlpha) {
    // TODO: Open issue about SkCanvas::getClipBounds
    // Rect canvasClipBounds = canvas.getClipBounds();
    canvas.save();
    final Rect newClipRect = new Rect.fromLTRB(
        0.0, 0.0, layerModel.preCompWidth, layerModel.preCompHeight);
    // TODO this is causing problems - why?
    // Rect transformedRect = MatrixUtils.transformRect(parentMatrix, newClipRect);

    for (int i = _layers.length - 1; i >= 0; i--) {
      if (!newClipRect.isEmpty) {
        canvas.clipRect(newClipRect);
      }
      _layers[i].draw(canvas, size, parentMatrix, parentAlpha);
    }

    canvas.restore();

    //if (!originalClipRect.isEmpty()) {
    // TODO: Open issue about Replace option
    //canvas.clipRect(canvasClipBounds, Region.Op.REPLACE);
    //}
  }

  @override
  Rect calculateBounds(Matrix4 parentMatrix) {
    Rect layerBounds = Rect.zero;
    for (int i = _layers.length - 1; i >= 0; i--) {
      final BaseLayer content = _layers[i];
      final Rect contentBounds = content.getBounds(parentMatrix);

      layerBounds = layerBounds.isEmpty
          ? contentBounds
          : _minTopLeftMaxRightBottom(layerBounds, contentBounds);
    }

    return layerBounds;
  }

  @override
  void addColorFilter(
      String layerName, String contentName, ColorFilter colorFilter) {
    for (BaseLayer layer in _layers) {
      final String name = layer.layerModel.name;
      if (layerName == null) {
        layer.addColorFilter(null, null, colorFilter);
      } else if (name == layerName) {
        layer.addColorFilter(layerName, contentName, colorFilter);
      }
    }
  }

  @override
  set progress(double val) {
    super.progress = val;

    if (layerModel.timeStretch != null && layerModel.timeStretch != 0) {
      val /= layerModel.timeStretch;
    }
    val -= _layerModel.startProgress;
    for (int i = _layers.length - 1; i >= 0; i--) {
      _layers[i].progress = val;
    }
  }

  bool get hasMasks {
    if (_hasMasks == null) {
      for (int i = _layers.length - 1; i >= 0; i--) {
        final BaseLayer layer = _layers[i];
        if (layer is ShapeLayer && layer.hasMasksOnThisLayer) {
          _hasMasks = true;
          return true;
        }
      }
      _hasMasks = false;
    }

    return _hasMasks;
  }

  bool get hasMatte {
    if (_hasMatte == null) {
      if (hasMatteOnThisLayer) {
        _hasMatte = true;
        return true;
      }

      for (int i = _layers.length - 1; i >= 0; i--) {
        final BaseLayer layer = _layers[i];
        if (layer.hasMatteOnThisLayer) {
          _hasMatte = true;
          return true;
        }
      }

      _hasMatte = false;
    }

    return _hasMatte;
  }
}
