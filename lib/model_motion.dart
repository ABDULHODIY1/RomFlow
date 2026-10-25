import 'dart:math' as math;
import 'dart:ui' show Offset;

/// A short, frame-rate-independent orbit response. Pointer events set targets;
/// vsync follows them at 60/90/120 Hz without changing material/geometry LOD.
class ModelOrbit {
  double yaw, pitch, targetYaw, targetPitch;
  ModelOrbit(this.yaw, this.pitch)
      : targetYaw = yaw,
        targetPitch = pitch;
  void reset(double y, double p) {
    yaw = targetYaw = y;
    pitch = targetPitch = p;
  }

  void drag(double dx, double dy) {
    targetYaw += dx * .008;
    targetPitch = (targetPitch - dy * .008).clamp(-1.4, 1.4);
  }

  bool step(double seconds) {
    final amount = 1 - math.exp(-30 * seconds.clamp(0, .05));
    yaw += (targetYaw - yaw) * amount;
    pitch += (targetPitch - pitch) * amount;
    if ((targetYaw - yaw).abs() + (targetPitch - pitch).abs() < .00005) {
      yaw = targetYaw;
      pitch = targetPitch;
      return true;
    }
    return false;
  }
}

/// Continuous view-dependent effects: no abrupt quality switches in motion.
class ModelMotionQuality {
  static double reflectionOpacity(double fresnel, double pixels) {
    double smooth(double x) {
      final t = x.clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    return (1 - smooth((fresnel - .35) / .45)) * smooth((pixels - 6) / 24);
  }

  static int perspectiveSteps(double nearest, double farthest, double pixels) {
    if (pixels < 72 || nearest <= 0) return 1;
    final distortion = (farthest - nearest).abs() / nearest;
    if (distortion < .025) return 1;
    return distortion < .10 ? 2 : 4;
  }
}

/// A one-physical-pixel vertex-alpha fringe for mesh coverage. drawVertices
/// does not provide reliable geometric AA on every engine/backend.
class ModelEdgeCoverage {
  static List<Offset> outer(List<Offset> polygon, double width) {
    if (polygon.length < 3 || width <= 0) return polygon;
    var area = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i], b = polygon[(i + 1) % polygon.length];
      area += a.dx * b.dy - b.dx * a.dy;
    }
    final sign = area >= 0 ? 1.0 : -1.0;
    Offset normal(Offset a, Offset b) {
      final d = b - a;
      if (d.distance < 1e-8) return Offset.zero;
      return Offset(d.dy * sign, -d.dx * sign) / d.distance;
    }

    return [
      for (var i = 0; i < polygon.length; i++)
        (() {
          final n0 = normal(
            polygon[(i - 1 + polygon.length) % polygon.length],
            polygon[i],
          );
          final n1 = normal(polygon[i], polygon[(i + 1) % polygon.length]);
          final sum = n0 + n1;
          final length = sum.distance;
          if (length < 1e-8) return polygon[i] + n1 * width;
          final direction = sum / length;
          final denominator =
              (direction.dx * n1.dx + direction.dy * n1.dy).abs();
          final distance = (width / math.max(.5, denominator)).clamp(
            width,
            width * 2,
          );
          return polygon[i] + direction * distance;
        })(),
    ];
  }
}
