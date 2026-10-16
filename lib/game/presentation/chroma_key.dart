import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Specification for chroma-key removal.
///
/// Production character sprites are rendered on a pure magenta plate
/// (#FF00FF). Pixels within [softStart] of the key color (Manhattan
/// distance in RGB) become fully transparent; pixels beyond [softEnd]
/// stay fully opaque, and the band in between fades along a smoothstep
/// curve so the silhouette edge stays soft instead of stair-stepping.
class ChromaKeySpec {
  const ChromaKeySpec({
    this.keyR = 255,
    this.keyG = 0,
    this.keyB = 255,
    this.softStart = 60,
    this.softEnd = 140,
  });

  final int keyR;
  final int keyG;
  final int keyB;
  final int softStart;
  final int softEnd;
}

/// Pure alpha function for one pixel — returns 0.0 (fully transparent)
/// to 1.0 (fully opaque) based on distance from the key color.
/// Kept free of any Flutter dependency so it is unit-testable.
double chromaKeyAlpha(
  int r,
  int g,
  int b, [
  ChromaKeySpec spec = const ChromaKeySpec(),
]) {
  final distance = (r - spec.keyR).abs() + (g - spec.keyG).abs() + (b - spec.keyB).abs();
  if (distance <= spec.softStart) {
    return 0.0;
  }
  if (distance >= spec.softEnd) {
    return 1.0;
  }
  final t = (distance - spec.softStart) / (spec.softEnd - spec.softStart);
  return t * t * (3 - 2 * t);
}

/// Loads a sprite PNG from the asset bundle, converts its magenta plate
/// to real alpha, and crops the result to the character's bounding box
/// (removing the empty plate margins baked into the generation canvas).
Future<ui.Image> loadKeyedSprite(
  String bundleAssetPath, {
  ChromaKeySpec spec = const ChromaKeySpec(),
}) async {
  final data = await rootBundle.load(bundleAssetPath);
  final decoded = await _decodeImageList(
    data.buffer.asUint8List(),
  );
  final width = decoded.width;
  final height = decoded.height;
  final raw = await decoded.toByteData(format: ui.ImageByteFormat.rawRgba);
  decoded.dispose();
  if (raw == null) {
    throw StateError('Could not read RGBA pixels for $bundleAssetPath');
  }

  final pixels = raw.buffer.asUint8List();
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;
  for (var i = 0; i < width * height; i++) {
    final o = i * 4;
    final alpha = chromaKeyAlpha(
      pixels[o],
      pixels[o + 1],
      pixels[o + 2],
      spec,
    );
    pixels[o + 3] = (alpha * 255).round();
    if (alpha > 0.6) {
      final x = i % width;
      final y = i ~/ width;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) {
    throw StateError('Keyed sprite is fully transparent: $bundleAssetPath');
  }

  // Keep a 1px margin so the smooth edge band survives the crop.
  const margin = 1;
  minX = (minX - margin).clamp(0, width - 1);
  minY = (minY - margin).clamp(0, height - 1);
  maxX = (maxX + margin).clamp(0, width - 1);
  maxY = (maxY + margin).clamp(0, height - 1);

  final cropW = maxX - minX + 1;
  final cropH = maxY - minY + 1;
  final cropped = Uint8List(cropW * cropH * 4);
  for (var y = 0; y < cropH; y++) {
    final srcStart = ((minY + y) * width + minX) * 4;
    cropped.setRange(y * cropW * 4, (y + 1) * cropW * 4, pixels, srcStart);
  }
  return _decodeRasterPixels(cropped, cropW, cropH);
}

Future<ui.Image> _decodeImageList(Uint8List bytes) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, completer.complete);
  return completer.future;
}

Future<ui.Image> _decodeRasterPixels(Uint8List pixels, int w, int h) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    w,
    h,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
