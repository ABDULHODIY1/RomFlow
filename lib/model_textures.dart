import 'dart:async';
import 'model_quality.dart';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Pixel demand chooses a mip; live views keep the same pixel demand at rest and in motion.
/// Studio devices and explicit exports use 4096² (64 MiB decoded RGBA).
class ModelTexturePolicy {
  static const budgetBytes = 72 * 1024 * 1024;
  static int resolution(
    double pixels, {
    bool moving = false,
    bool export4K = false,
    ModelQuality quality = ModelQuality.balanced,
  }) {
    if (export4K || quality == ModelQuality.studio4K) return 4096;
    const limit = 2048;
    var size = 128;
    while (size < pixels && size < limit) {
      size *= 2;
    }
    return size.clamp(128, limit);
  }

  static int bytesFor(int size) => size * size * 4;
}

/// A world-anchored, neutral brushed grain; vertex colour supplies the finish.
/// One reusable map serves aluminium, PVC, panels and fittings, avoiding a
/// separate 64 MiB image for every material or part.
TransferableTypedData makeModelGrain(int size) {
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    final gy = y * 4096 ~/ size;
    for (var x = 0; x < size; x++) {
      final gx = x * 4096 ~/ size;
      final fine = ((gx * 374761393) ^ (gy * 668265263)) & 15;
      final brush = (((gx >> 6) * 127) ^ ((gy >> 1) * 31)) & 15;
      final value = 236 + ((fine + brush) * 19 ~/ 30);
      final i = (y * size + x) * 4;
      pixels[i] = value;
      pixels[i + 1] = value;
      pixels[i + 2] = value;
      pixels[i + 3] = 255;
    }
  }
  return TransferableTypedData.fromList([pixels]);
}

/// Four finish tiles share one RGBA allocation: coating, brushed metal,
/// elastomer and laminated panel. Each is 2048² in the 4096² atlas.
TransferableTypedData makeModelAtlas(int size) {
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    final gy = y * 4096 ~/ size;
    for (var x = 0; x < size; x++) {
      final gx = x * 4096 ~/ size;
      final tile = (gx >= 2048 ? 1 : 0) + (gy >= 2048 ? 2 : 0);
      final u = gx & 2047, v = gy & 2047;
      // Integer hash avoids the visible diagonal/XOR grid of simple noise.
      var h = (u * 1597334677 + v * 3812015801) & 0xffffffff;
      h = ((h ^ (h >> 16)) * 2246822519) & 0xffffffff;
      final noise = ((h ^ (h >> 13)) & 255) / 255;
      final striation = ((u * 73 + (u >> 3) * 19) & 31) / 31;
      final broad = ((u ~/ 30 * 17 + v ~/ 42 * 23) & 15) / 15;
      final value = switch (tile) {
        1 => 241 + 10 * striation + 3 * noise, // long extrusion/brushing
        2 => 246 + 5 * noise + 2 * broad, // rubber: almost invisible grain
        3 => 246 + 4 * broad + 3 * noise, // matte laminated surface
        _ => 247 + 6 * noise, // fine powder coat; no painted scratches
      };
      final i = (y * size + x) * 4;
      pixels[i] = pixels[i + 1] = pixels[i + 2] = value.round();
      pixels[i + 3] = 255;
    }
  }
  return TransferableTypedData.fromList([pixels]);
}

TransferableTypedData _makeTexture((int, bool) request) =>
    request.$2 ? makeModelAtlas(request.$1) : makeModelGrain(request.$1);

class ModelTexture {
  final ui.Image image;
  final bool cinematic;
  final ui.ImageShader _shader;
  bool disposed = false;
  ModelTexture(this.image, {this.cinematic = false})
      : _shader = ui.ImageShader(
          image,
          ui.TileMode.repeated,
          ui.TileMode.repeated,
          Float64List.fromList(
              [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
          filterQuality: ui.FilterQuality.medium,
        );
  int get size => image.width;
  ui.Shader? get shader => disposed ? null : _shader;
  void dispose() {
    if (disposed) return;
    disposed = true;
    _shader.dispose();
    image.dispose();
  }
}

/// A bounded mip cache with one generation/upload in flight. No texture work
/// happens in paint(), and closing the view discards late isolate results.
class ModelTextures extends ChangeNotifier {
  final int budgetBytes;
  final _levels = <int, ModelTexture>{};
  Future<void>? _loading;
  int _wanted = 128, _cap = 4096;
  int revision = 0;
  bool _closed = false, _cinematic = false;
  bool get cinematic => _cinematic;

  void setCinematic(bool value) {
    if (_closed || _cinematic == value) return;
    _cinematic = value;
    for (final t in _levels.values) {
      t.dispose();
    }
    _levels.clear();
    revision++;
    notifyListeners();
  }

  ModelTextures({this.budgetBytes = ModelTexturePolicy.budgetBytes});
  int get residentBytes =>
      _levels.values.fold(0, (s, t) => s + ModelTexturePolicy.bytesFor(t.size));
  int get levelCount => _levels.length;

  ModelTexture? best(int wanted) {
    if (_closed || _levels.isEmpty) return null;
    final sizes = _levels.keys.toList()..sort();
    // Never use a larger map than the current physical pixel demand.
    final below = sizes.where((s) => s <= wanted);
    if (below.isEmpty) return null;
    final size = below.last;
    final result = _levels.remove(size)!;
    _levels[size] = result;
    return result;
  }

  Future<void> request(int requested) {
    if (_closed) return Future.value();
    final wanted = requested.clamp(128, _cap);
    if (!const {128, 256, 512, 1024, 2048, 4096}.contains(wanted)) {
      throw ArgumentError.value(requested, 'resolution');
    }
    if (ModelTexturePolicy.bytesFor(wanted) > budgetBytes) {
      return Future.value();
    }
    _wanted = wanted;
    if (_levels.containsKey(wanted)) return Future.value();
    return _loading ??= _load().whenComplete(() => _loading = null);
  }

  Future<void> _load() async {
    while (!_closed && !_levels.containsKey(_wanted)) {
      final size = _wanted, cinematic = _cinematic;
      try {
        final data = await compute(_makeTexture, (size, cinematic));
        if (_closed) return;
        final bytes = data.materialize().asUint8List();
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        ui.ImageDescriptor? descriptor;
        ui.Codec? codec;
        ui.Image? image;
        try {
          descriptor = ui.ImageDescriptor.raw(
            buffer,
            width: size,
            height: size,
            pixelFormat: ui.PixelFormat.rgba8888,
          );
          codec = await descriptor.instantiateCodec();
          image = (await codec.getNextFrame()).image;
        } finally {
          codec?.dispose();
          descriptor?.dispose();
          buffer.dispose();
        }
        if (_closed || size > _cap || cinematic != _cinematic) {
          image.dispose();
          if (_closed) return;
          continue;
        }
        while (_levels.isNotEmpty &&
            residentBytes + ModelTexturePolicy.bytesFor(size) > budgetBytes) {
          _levels.remove(_levels.keys.first)!.dispose();
        }
        _levels.remove(size)?.dispose();
        _levels[size] = ModelTexture(image, cinematic: cinematic);
        revision++;
        notifyListeners();
      } catch (_) {
        // A missing/failed texture never removes the lit geometry fallback.
        return;
      }
    }
  }

  void trim({bool memoryPressure = false, int maxResolution = 2048}) {
    if (_closed) return;
    if (memoryPressure) _cap = 1024;
    final maxSize = math.min(maxResolution, _cap);
    for (final size in _levels.keys.toList()) {
      if (size > maxSize) _levels.remove(size)!.dispose();
    }
    _wanted = math.min(_wanted, maxSize);
    revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_closed) return;
    _closed = true;
    for (final texture in _levels.values) {
      texture.dispose();
    }
    _levels.clear();
    super.dispose();
  }
}
