import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:lottie_flutter/src/animations.dart';
import 'package:lottie_flutter/src/values.dart';
import 'package:vector_math/vector_math_64.dart';

const List<int> _skMatrixIdx = const <int>[
  0, 4, 12, // 1st row
  1, 5, 13, // 2nd row
  3, 7, 15 // 3rd row
];

/// Prints out the [Matrix4] in the SkMatrix format
String toShortString(Matrix4 matrix4) {
  final Float64List stor = matrix4.storage;
  matrix4.row3;
  return '['
      '${stor[_skMatrixIdx[0]]},'
      '${stor[_skMatrixIdx[1]]},'
      '${stor[_skMatrixIdx[2]]}'
      ']['
      '${stor[_skMatrixIdx[3]]},'
      '${stor[_skMatrixIdx[4]]},'
      '${stor[_skMatrixIdx[5]]}'
      ']['
      '${stor[_skMatrixIdx[6]]},'
      '${stor[_skMatrixIdx[7]]},'
      '${stor[_skMatrixIdx[8]]}'
      ']';
}

/// Parse the color string and return the corresponding Color.
/// Supported formatS are:
/// #RRGGBB and #AARRGGBB
Color parseColor(String colorString) {
  if (colorString[0] == '#') {
    int color = int.tryParse(colorString.substring(1), radix: 16);
    if (colorString.length == 7) {
      return new Color(color |= 0x00000000ff000000);
    }

    if (colorString.length == 9) {
      return new Color(color);
    }
  }

  throw new ArgumentError.value(
      colorString, 'colorString', 'Unknown color $colorString');
}

// Use this instead of [Color.lerp] because it interpolates through the gamma color
// space which looks better to us humans.
//
// Writted by Romain Guy and Francois Blavoet.
// https://androidstudygroup.slack.com/archives/animation/p1476461064000335
class GammaEvaluator {
  GammaEvaluator._();

  static Color evaluate(double fraction, Color start, Color end) {
    final double startA = start.alpha / 255.0;
    double startR = start.red / 255.0;
    double startG = start.green / 255.0;
    double startB = start.blue / 255.0;

    final double endA = end.alpha / 255.0;
    double endR = end.red / 255.0;
    double endG = end.green / 255.0;
    double endB = end.blue / 255.0;

    // convert from sRGB to linear
    startR = _eocfSrgb(startR);
    startG = _eocfSrgb(startG);
    startB = _eocfSrgb(startB);

    endR = _eocfSrgb(endR);
    endG = _eocfSrgb(endG);
    endB = _eocfSrgb(endB);

    // compute the interpolated color in linear space
    double a = startA + fraction * (endA - startA);
    double r = startR + fraction * (endR - startR);
    double g = startG + fraction * (endG - startG);
    double b = startB + fraction * (endB - startB);

    // convert back to sRGB in the [0..255] range
    a = a * 255.0;
    r = _oecfSrgb(r) * 255.0;
    g = _oecfSrgb(g) * 255.0;
    b = _oecfSrgb(b) * 255.0;

    return new Color.fromARGB(a.round(), r.round(), g.round(), b.round());
    // return new Color(
    //     a.round() << 24 | r.round() << 16 | g.round() << 8 | b.round());
  }

  // Opto-electronic conversion function for the sRGB color space
  // Takes a gamma-encoded sRGB value and converts it to a linear sRGB value
  static double _oecfSrgb(double linear) {
    // IEC 61966-2-1:1999
    return linear <= 0.0031308
        ? linear * 12.92
        : (pow(linear, 1.0 / 2.4) * 1.055) - 0.055;
  }

  // Electro-optical conversion function for the sRGB color space
  // Takes a linear sRGB value and converts it to a gamma-encoded sRGB value
  static double _eocfSrgb(double srgb) {
    // IEC 61966-2-1:1999
    return srgb <= 0.04045 ? srgb / 12.92 : pow((srgb + 0.055) / 1.055, 2.4);
  }
}

int calculateAlpha(int from, BaseKeyframeAnimation<dynamic, int> opacity) =>
    ((from / 255.0 * opacity.value / 100.0) * 255.0).toInt();

//TODO: Review this :?
// Android version: path.add(path, parentMatrix)
void addPathToPath(Path path, Path other, Matrix4 transform) =>
    //path.addPath(other.transform(transform.storage), const Offset(0.0, 0.0));
    path.addPath(other, Offset.zero, matrix4: transform.storage);

Path applyScaledTrimPathIfNeeded(
    Path path, double start, double end, double offset) {
  return applyTrimPathIfNeeded(
      path, start / 100.0, end / 100.0, offset / 100.0);
}

Path applyTrimPathIfNeeded(Path path, double start, double end, double offset) {
  if (start == 1.0 && end == 0) {
    return path;
  }

  final ui.PathMetric measure = path.computeMetrics().first;
  final double length = measure.length;
  if (length < 1.0 || (end - start - 1).abs() < .01) {
    return path;
  }

  start *= length;
  end *= length;
  double newStart = min(start, end);
  double newEnd = max(start, end);

  offset *= length;
  newStart += offset;
  newEnd += offset;
  if (newStart >= length && newEnd >= length) {
    newStart = _floorMod(newStart.toInt(), length.toInt()).toDouble();
    newEnd = _floorMod(newEnd.toInt(), length.toInt()).toDouble();
  }

  if (newStart < 0) {
    newStart = _floorMod(newStart.toInt(), length.toInt()).toDouble();
  }

  if (newEnd < 0) {
    newEnd = _floorMod(newEnd.toInt(), length.toInt()).toDouble();
  }

  if (newStart == newEnd) {
    path.reset();
    return path;
  }

  if (newStart >= newEnd) {
    newStart -= length;
  }

  final Path tempPath = measure.extractPath(newStart, newEnd);

  if (newEnd > length) {
    final Path tempPath2 = measure.extractPath(0.0, newEnd % length);
    tempPath.addPath(tempPath2, Offset.zero);
  } else if (newStart < 0) {
    final Path tempPath2 = measure.extractPath(length + newStart, length);
    tempPath.addPath(tempPath2, Offset.zero);
  }
  return tempPath;
}

int _floorMod(int x, int y) {
  return x - _floorDiv(x, y) * y;
}

int _floorDiv(int x, int y) {
  int r = x ~/ y;
  // if the signs are different and modulo not zero, round down
  if ((x ^ y) < 0 && (r * y != x)) {
    r--;
  }
  return r;
}

Shader createGradientShader(GradientColor gradient, GradientType type,
    Offset startPoint, Offset endPoint) {
  final double x0 = startPoint.dx;
  final double y0 = startPoint.dy;
  final double x1 = endPoint.dx;
  final double y1 = endPoint.dy;

  return type == GradientType.Linear
      ? _createLinearGradientShader(gradient, x0, y0, x1, y1)
      : _createRadialGradientShader(gradient, x0, y0, x1, y1);
}

Shader _createLinearGradientShader(GradientColor gradient, double x0, double y0,
    double x1, double y1) {
  print('x0: $x0, y0: $y0, x1: $x1, y1: $y1');

  return new ui.Gradient.linear(
    Offset(x0, y0),
    Offset(x1, y1),
    gradient.colors,
    gradient.positions,
  );
}

Shader _createRadialGradientShader(GradientColor gradient, double x0, double y0,
    double x1, double y1) {
  final double radius = sqrt(pow(x1 - x0, 2) + pow(y1 - y0, 2));

  // print('x0: $x0, y0: $y0, x1: $x1, y1: $y1, radius: $radius');

  return new ui.Gradient.radial(
    Offset(x0, y0),
    radius,
    gradient.colors,
    gradient.positions,
  );
}

Offset applyMatrixToOffset(Matrix4 matrix, Offset offset) {
  final Vector3 vector = new Vector3(offset.dx, offset.dy, 0.0);
  vector.applyMatrix4(matrix);

  return new Offset(vector.x, vector.y);
}
