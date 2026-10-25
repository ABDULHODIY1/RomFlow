import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Unknown devices stay on the established, bounded renderer.
enum ModelQuality { balanced, studio4K }

class ModelDeviceQuality {
  static const channel = MethodChannel('romflow/render-device');
  static ModelQuality select(Map<Object?, Object?> data) {
    final match = RegExp(
      r'^iPhone(\d+),(\d+)$',
    ).firstMatch(data['machine'] as String? ?? '');
    if (match == null) return ModelQuality.balanced;
    final major = int.parse(match[1]!), minor = int.parse(match[2]!);
    // iPhone14,6 is the SE (3rd generation), not the iPhone 13 family.
    final supported = major >= 15 ||
        (major == 14 && const {2, 3, 4, 5, 7, 8}.contains(minor));
    final thermal = (data['thermal'] as num?)?.toInt() ?? 0;
    return supported && thermal < 2
        ? ModelQuality.studio4K
        : ModelQuality.balanced;
  }

  static Future<ModelQuality> read() async {
    try {
      final data = await channel.invokeMapMethod<Object?, Object?>('status');
      return select(data ?? {});
    } on PlatformException {
      return ModelQuality.balanced;
    } on MissingPluginException {
      return ModelQuality.balanced;
    }
  }
}

/// A compact image-based-lighting approximation, not a ray tracer.
/// Roughness and metal response distinguish rubber, coated profiles and metal.
class ModelFinish {
  final double roughness, metalness;
  const ModelFinish(this.roughness, this.metalness);
  static ModelFinish forMaterial(String? key) => switch (key) {
        'glass' => const ModelFinish(.08, 0),
        'handle' ||
        'doorHandle' ||
        'hinge' ||
        'doorHinge' ||
        'cylinder' ||
        'screw' ||
        'rail' ||
        'spacer' =>
          const ModelFinish(.24, .85),
        'uGasket' ||
        'sealInner' ||
        'sealOuter' ||
        'meshRubber' ||
        'butyl' ||
        'iguSeal' =>
          const ModelFinish(.92, 0),
        'panel' || 'lambris' => const ModelFinish(.62, 0),
        _ => const ModelFinish(.38, .12),
      };

  double highlight(double nDotH, double nDotV) {
    final exponent = (2 / (roughness * roughness) - 2).clamp(2.0, 256.0);
    final fresnel = .04 + .96 * math.pow(1 - nDotV.clamp(0, 1), 5);
    return ((.12 + .55 * metalness) * math.pow(nDotH.clamp(0, 1), exponent) +
            fresnel * (1 - roughness) * .18)
        .clamp(0.0, .85);
  }

  int get atlasTile => metalness > .5
      ? 1
      : roughness > .8
          ? 2
          : roughness > .5
              ? 3
              : 0;

  /// Narkowicz ACES fitted shoulder (CC0/MIT):
  /// https://knarkowicz.wordpress.com/2016/01/06/aces-filmic-tone-mapping-curve/
  /// This is a per-material approximation, not a full HDR/ACES pipeline.
  static double filmic(double linear) {
    final x = math.max(0.0, linear);
    return ((x * (2.51 * x + .03)) / (x * (2.43 * x + .59) + .14)).clamp(
      0.0,
      1.0,
    );
  }

  static double filmicChannel(
    double srgb,
    double illumination,
    double spec, {
    double metalness = 0,
  }) {
    final linear = srgb <= .04045
        ? srgb / 12.92
        : math.pow((srgb + .055) / 1.055, 2.4).toDouble();
    final lit = linear * illumination * (1 - spec) +
        (linear * metalness + 1 - metalness) * spec * 1.8;
    final value = filmic(lit * 1.12);
    return value <= .0031308
        ? value * 12.92
        : 1.055 * math.pow(value, 1 / 2.4) - .055;
  }

  /// Beer-Lambert absorption over a bounded optical path in millimetres.
  static double glassTransmission(double thicknessMm, double viewCos) {
    final path = thicknessMm.clamp(1, 40) / viewCos.abs().clamp(.12, 1);
    return math.exp(-.004 * path);
  }

  /// Shade in linear light, then encode for display; avoids chalky highlights.
  static double channel(
    double srgb,
    double illumination,
    double spec, {
    double metalness = 0,
  }) {
    final linear = srgb <= .04045
        ? srgb / 12.92
        : math.pow((srgb + .055) / 1.055, 2.4).toDouble();
    final reflected = linear * metalness + 1 - metalness;
    final lit = (linear * illumination * (1 - spec) + reflected * spec).clamp(
      0.0,
      1.0,
    );
    return lit <= .0031308
        ? lit * 12.92
        : 1.055 * math.pow(lit, 1 / 2.4) - .055;
  }
}
