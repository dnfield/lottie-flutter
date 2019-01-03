import 'dart:math' as math;

import 'package:lottie_flutter/src/composition.dart';
import 'package:lottie_flutter/src/drawing/drawing_layers.dart';
import 'package:lottie_flutter/src/layers.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

class Lottie extends StatefulWidget {
  final LottieComposition _composition;
  final Size _size;
  final AnimationController _controller;
  final bool _coerceDuration;

  Lottie(
      {Key key,
      @required LottieComposition composition,
      Size size,
      AnimationController controller,
      bool coerceDuration = true})
      : assert(controller == null ||
            (controller.lowerBound >= 0.0 && controller.upperBound <= 1.0)),
        assert(coerceDuration != null),
        _composition = composition,
        _size = size ?? composition.bounds.size,
        _controller = controller,
        _coerceDuration = coerceDuration,
        super(key: key);

  @override
  _LottieState createState() => new _LottieState();
}

class _LottieState extends State<Lottie> with SingleTickerProviderStateMixin {
  CompositionLayer _compositionLayer;
  AnimationController _animation;
  bool _shouldDisposeAnimation;
  double _scale;

  @override
  void initState() {
    super.initState();

    setScaleAndCompositionLayer();

    if (widget._coerceDuration && widget._composition != null && widget._controller != null) {
      widget._controller.duration =
          new Duration(milliseconds: widget._composition.duration);
    }

    _shouldDisposeAnimation = widget._controller == null;

    _animation = widget._controller ??
        (new AnimationController(
          duration:
              new Duration(milliseconds: widget._composition?.duration ?? 1),
          lowerBound: 0.0,
          upperBound: 1.0,
          vsync: this,
        )..repeat());

    _compositionLayer?.progress = _animation.value;
    _animation.addListener(_handleChange);
  }

  static double _calcScale(Size size, LottieComposition composition) =>
      math.min(size.width / composition.bounds.size.width,
          size.height / composition.bounds.size.height);

  @override
  void didUpdateWidget(Lottie oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget._composition == widget._composition) {
      return;
    }

    setScaleAndCompositionLayer();
    if (widget._coerceDuration && widget._composition != null) {
      _animation.duration =
          new Duration(milliseconds: widget._composition.duration);
    }

    if (widget._controller == null && widget._composition != null) {
      _animation
        ..reset()
        ..repeat();
    }
  }

  void setScaleAndCompositionLayer() {
    if (widget._composition != null) {
      _scale = _calcScale(widget._size, widget._composition);

      _compositionLayer = new CompositionLayer(
          widget._composition,
          new Layer.empty(widget._size.width, widget._size.height),
          () => null,
          _scale);
    }
  }

  void _handleChange() {
    setState(() {
      _compositionLayer?.progress = _animation.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _compositionLayer != null
        ? new CustomPaint(
            painter: new LottiePainter(_compositionLayer, scale: _scale),
            size: widget._size)
        : new LimitedBox(
            maxWidth: widget._size.width,
            maxHeight: widget._size.height,
          );
  }

  @override
  void dispose() {
    _animation.removeListener(_handleChange);

    if (_shouldDisposeAnimation) {
      _animation.dispose();
    }

    super.dispose();
  }
}

class LottiePainter extends CustomPainter {
  final CompositionLayer _compositionLayer;
  final double _scale;
  final int _alpha;

  LottiePainter(this._compositionLayer, {double scale: 1.0, int alpha: 255})
      : _scale = scale,
        _alpha = alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final Matrix4 matrix = new Matrix4.identity();
    if (_scale != 1.0) {
      matrix.scale(_scale, _scale);
    }

    _compositionLayer.draw(canvas, size, matrix, _alpha);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
