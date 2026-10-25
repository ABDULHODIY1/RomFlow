import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'design_engine.dart';
import 'app_theme.dart';
import 'calculator.dart' show money;
import 'in_place_page.dart';
import 'platform_files.dart';
import 'adaptive_ui.dart';

class P3 {
  final double x, y, z;
  const P3(this.x, this.y, this.z);
  P3 operator +(P3 b) => P3(x + b.x, y + b.y, z + b.z);
  P3 operator -(P3 b) => P3(x - b.x, y - b.y, z - b.z);
  P3 operator *(double s) => P3(x * s, y * s, z * s);
  P3 cross(P3 b) => P3(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  double dot(P3 b) => x * b.x + y * b.y + z * b.z;
  double get length => math.sqrt(dot(this));
}

class ModelFace {
  final List<P3> vertices;
  final Color color;
  final String? group;
  final bool glass;
  final String? partId;

  /// Faces of closed, consistently wound solids: hidden when they turn away.
  final bool closed;
  const ModelFace(this.vertices, this.color, this.group,
      {this.glass = false, this.partId, this.closed = false});
}

class ModelGroup {
  final DrawingCell cell;
  final double hingeX, hingeY, hingeZ;
  ModelGroup(this.cell, this.hingeX, this.hingeY, this.hingeZ);
  P3 transform(P3 p, double progress) {
    progress = ((progress - .22) / .78).clamp(0, 1);
    final type = cell.node['opening'] as String,
        sign = cell.node['outward'] == true ? -1.0 : 1.0;
    final b = bounds(cell.polygon),
        door = type.startsWith('door') || type == 'passive';
    if (type.startsWith('slide')) {
      return p +
          P3((type == 'slideLeft' ? -1 : 1) * (b[2] - b[0]) * .8 * progress, 0,
              12 * progress);
    }
    if (type == 'fixed' || progress == 0) return p;
    if (type == 'top' || type == 'bottom') {
      final a = progress * math.pi * .32 * sign * (type == 'bottom' ? 1 : -1),
          dy = p.y - hingeY,
          dz = p.z - hingeZ;
      return P3(p.x, hingeY + dy * math.cos(a) - dz * math.sin(a),
          hingeZ + dy * math.sin(a) + dz * math.cos(a));
    }
    final right = type == 'right' || type == 'doorRight';
    final a = progress *
            (door ? math.pi * .53 : math.pi * .42) *
            sign *
            (right ? 1 : -1),
        dx = p.x - hingeX,
        dz = p.z - hingeZ;
    return P3(hingeX + dx * math.cos(a) + dz * math.sin(a), p.y,
        hingeZ - dx * math.sin(a) + dz * math.cos(a));
  }
}

class HardwareMotion {
  final String ownerId, mode;
  final ModelGroup owner;
  final P3 pivot;

  /// For 'turn': the angle the handle turns about the axis through [pivot]
  /// that is square to the sash, before the sash starts to swing.
  final double turn;
  HardwareMotion(this.ownerId, this.owner, this.mode, this.pivot,
      {this.turn = 0});
  P3 transform(P3 p, double progress) {
    final release = (progress / .22).clamp(0.0, 1.0);
    P3 moved = p;
    if (mode == 'rod') moved = p + P3(0, 24 * release, 0);
    if (mode == 'turn') {
      final a = release * turn, dx = p.x - pivot.x, dy = p.y - pivot.y;
      moved = P3(pivot.x + dx * math.cos(a) - dy * math.sin(a),
          pivot.y + dx * math.sin(a) + dy * math.cos(a), p.z);
    }
    if (mode == 'pull') {
      final a = release * math.pi * .19, dy = p.y - pivot.y, dz = p.z - pivot.z;
      moved = P3(p.x, pivot.y + dy * math.cos(a) - dz * math.sin(a),
          pivot.z + dy * math.sin(a) + dz * math.cos(a));
    }
    return owner.transform(moved, progress);
  }
}

class ModelPart {
  final String id, materialKey, title;
  final P3 center, extent;
  final double explosionLayer;
  final String? group;
  const ModelPart(this.id, this.materialKey, this.title, this.center,
      this.extent, this.group,
      {this.explosionLayer = 0});
  static const _layers = <String, double>{
    'frame': -.12,
    'mullion': .06,
    'sash': .22,
    'sashMullion': .30,
    'glass': .62,
    'spacer': .54,
    'shpros': .62,
    'shprosJoint': .62,
    'shprosRosette': .65,
    'spacerCorner': .54,
    'butyl': .55,
    'iguSeal': .52,
    'desiccant': .54,
    'panel': .62,
    'lambris': .62,
    'bead': .82,
    'uGasket': .98,
    'sealInner': .42,
    'sealOuter': -.35,
    'corner': -.4,
    'mullionJoint': -.5,
    'cornerProfile': -.2,
    'handle': 1.08,
    'doorHandle': 1.08,
    'hinge': .68,
    'doorHinge': .68,
    'windowLock': .85,
    'doorLock': .88,
    'cylinder': 1.12,
    'passiveBolt': .85,
    'roller': -.35,
    'slideLock': .95,
    'rail': -.3,
    'mesh': -.75,
    'meshFrame': -.8,
    'meshRubber': -.9,
    'threshold': -.25,
    'closer': 1.1,
    'screw': 1.18
  };
  P3 explosionOffset(double amount, double span, double width, double height) {
    if (amount == 0) return const P3(0, 0, 0);
    final dx = center.x - width / 2, dy = center.y - height / 2;
    final len = math.sqrt(dx * dx + dy * dy);
    final radial = P3(len < 1 ? 0 : dx / len, len < 1 ? 0 : dy / len, 0);
    final layer = _layers[materialKey] ?? .5;
    final spread = materialKey == 'frame'
        ? 0.16
        : materialKey == 'sash'
            ? 0.20
            : .13;
    return (radial * (span * spread) +
            P3(0, 0, span * (layer + explosionLayer))) *
        amount;
  }
}

class WindowModel {
  final DMap drawing, recipe;
  final faces = <ModelFace>[];
  final groups = <String, ModelGroup>{};
  final motions = <String, HardwareMotion>{};
  final parts = <String, ModelPart>{};
  String materialKey = 'decoration';
  String? partLabel;
  String? sharedPart;

  /// The last scene in world space (sashes opened, parts taken apart),
  /// reused while only the camera turns.
  String? worldKey;
  List<(ModelFace, List<P3>)>? world;
  double explosionLayer = 0;
  ModelPart registerPart(
      List<V> polygon, double z, double depth, String? group) {
    final b = bounds(polygon), id = 'p${parts.length + 1}';
    final part = ModelPart(
        id,
        materialKey,
        partLabel ?? materialNames[materialKey] ?? 'Yordamchi 3D detal',
        P3((b[0] + b[2]) / 2, (b[1] + b[3]) / 2, z + depth / 2),
        P3(b[2] - b[0], b[3] - b[1], depth),
        group,
        explosionLayer: explosionLayer);
    parts[id] = part;
    return part;
  }

  void material(String key) {
    materialKey = key;
    partLabel = null;
  }

  late final DrawingLayout layout;
  WindowModel(this.drawing, this.recipe) {
    layout = layoutDrawing(drawing, recipe);
    build();
    buildWall();
  }
  void face(List<P3> p, Color color, String? group,
          {bool glass = false, bool closed = false}) =>
      faces.add(ModelFace(p, color, group,
          glass: glass, partId: sharedPart, closed: closed));
  void prism(List<V> poly, double z, double depth, Color color, String? group,
      {bool glass = false}) {
    if (poly.length < 3) return;
    // One winding for every solid, so back faces can be skipped when drawing.
    if (signedArea(poly) < 0) poly = poly.reversed.toList();
    final previous = sharedPart;
    sharedPart ??= registerPart(poly, z, depth, group).id;
    final front = [for (final v in poly) P3(v.x, v.y, z + depth)],
        back = [for (final v in poly) P3(v.x, v.y, z)];
    face(front, color, group, glass: glass, closed: true);
    face(back.reversed.toList(), color, group, glass: glass, closed: true);
    for (var j = 0; j < poly.length; j++) {
      final k = (j + 1) % poly.length;
      face([back[j], back[k], front[k], front[j]], color, group,
          glass: glass, closed: true);
    }
    sharedPart = previous;
  }

  /// Plaster wall with reveals and a window sill, drawn around rectangular
  /// constructions to show them installed. Not part of the bill.
  final wallFaces = <ModelFace>[];
  void buildWall() {
    if (drawing['shape'] != 'rect') return;
    final w = (drawing['widthMm'] as num).toDouble(),
        h = (drawing['heightMm'] as num).toDouble(),
        margin = (math.max(w, h) * .32).clamp(250.0, 650.0),
        start = faces.length,
        previous = sharedPart;
    sharedPart = null;
    const plaster = Color(0xffe8e2d8), sill = Color(0xfff4f4f1);
    final joins = cornerJoins(drawing),
        left = joins.contains('left') ? 0.0 : -margin,
        right = joins.contains('right') ? w : w + margin;
    for (final r in <List<double>>[
      [left, -margin, right - left, margin],
      [left, h, right - left, margin],
      if (!joins.contains('left')) [-margin, 0, margin, h],
      if (!joins.contains('right')) [w, 0, margin, h],
    ]) {
      prism([
        V(r[0], r[1]),
        V(r[0] + r[2], r[1]),
        V(r[0] + r[2], r[1] + r[3]),
        V(r[0], r[1] + r[3])
      ], -160, 250, plaster, null);
    }
    final outer = layout.outer;
    if (outer.length == 4) {
      final sillL = joins.contains('left') ? 0.0 : -45.0,
          sillR = joins.contains('right') ? w : w + 45;
      prism([V(sillL, h), V(sillR, h), V(sillR, h + 28), V(sillL, h + 28)], 55,
          230, sill, null);
    } else {
      // A stepped frame: the wall fills the steps…
      final xs = {for (final v in outer) v.x}.toList()..sort(),
          ys = {for (final v in outer) v.y}.toList()..sort();
      bool inside(double x, double y) {
        var hit = false;
        for (var j = 0; j < outer.length; j++) {
          final a = outer[j], b = outer[(j + 1) % outer.length];
          if ((a.y > y) != (b.y > y) &&
              x < a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y)) {
            hit = !hit;
          }
        }
        return hit;
      }

      for (var i = 0; i + 1 < xs.length; i++) {
        for (var j = 0; j + 1 < ys.length; j++) {
          if (inside((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2)) {
            continue;
          }
          prism([
            V(xs[i], ys[j]),
            V(xs[i + 1], ys[j]),
            V(xs[i + 1], ys[j + 1]),
            V(xs[i], ys[j + 1])
          ], -160, 250, plaster, null);
        }
      }
      // …and a sill runs under every window part; a door goes to the floor.
      final face = (recipe['frameFace'] as num).toDouble();
      for (var j = 0; j < outer.length; j++) {
        final a = outer[j], b = outer[(j + 1) % outer.length];
        if ((a.y - b.y).abs() > .5 || b.x >= a.x) continue;
        final door = layout.cells.any((c) =>
            isDoorOpening(c.node['opening'] as String? ?? 'fixed') &&
            c.box[0] < a.x &&
            c.box[2] > b.x &&
            (c.box[3] + face - a.y).abs() < 1);
        if (door) continue;
        final x0 = b.x < .5 && !joins.contains('left') ? -45.0 : b.x,
            x1 =
                (a.x - w).abs() < .5 && !joins.contains('right') ? w + 45 : a.x;
        prism([V(x0, a.y), V(x1, a.y), V(x1, a.y + 28), V(x0, a.y + 28)], 55,
            230, sill, null);
      }
    }
    for (final side in joins) {
      neighbourFrame(side,
          Color(finishColors[recipe['finish'] ?? 'silver'] ?? 0xffd7dee7));
    }
    sharedPart = previous;
    wallFaces.addAll(faces.sublist(start));
    faces.removeRange(start, faces.length);
  }

  /// A solid extruded along y from [y0] to [y1]; [xz] is its plan section
  /// with x across and z through the depth.
  void columnPrism(List<V> xz, double y0, double y1, Color color, String? group,
      {bool glass = false}) {
    face([for (final v in xz) P3(v.x, y0, v.y)], color, group, glass: glass);
    face([for (final v in xz.reversed) P3(v.x, y1, v.y)], color, group,
        glass: glass);
    for (var j = 0; j < xz.length; j++) {
      final a = xz[j], b = xz[(j + 1) % xz.length];
      face([
        P3(a.x, y0, a.y),
        P3(b.x, y0, b.y),
        P3(b.x, y1, b.y),
        P3(a.x, y1, a.y)
      ], color, group, glass: glass);
    }
  }

  /// Plan geometry of the 90° corner ("qayt") connector after the workshop
  /// photo: a web with a V at the outer corner and a Y towards the room.
  /// One pair of parallel legs grips this frame (running along x), the
  /// other the next frame (running along z, into the room).
  ({V apex, V e1, V e2, double web, double leg}) cornerGeometry(String side) {
    final depth = (recipe['frameDepth'] as num?)?.toDouble() ?? 60,
        t = cornerWall,
        s = side == 'left' ? 1.0 : -1.0,
        edge = side == 'left' ? 0.0 : (drawing['widthMm'] as num).toDouble();
    return (
      apex: V(edge - s * (depth + t), -t / 2),
      e1: V(s, 0),
      e2: const V(0, 1),
      web: (depth + t) * math.sqrt2,
      leg: (depth + t) * math.sqrt2 * .83
    );
  }

  double get cornerWall =>
      ((recipe['profileWallMm'] as num?)?.toDouble() ?? 1.8).clamp(1.2, 3.0);

  void cornerJoint(String side, Color color,
      {double? height, double shift = 0}) {
    final g = cornerGeometry(side),
        h = height ?? (drawing['heightMm'] as num).toDouble(),
        t = cornerWall,
        k = 1 / math.sqrt2;
    // Photo coordinates: p across, q up from the apex of the V.
    V at(double p, double q) =>
        g.apex +
        V(shift, 0) +
        (g.e2 - g.e1) * (p * k) +
        (g.e1 + g.e2) * (-q * k);
    List<V> strip(double p0, double q0, double p1, double q1, double thick) {
      final a = at(p0, q0),
          b = at(p1, q1),
          d = b - a,
          n = V(-d.y, d.x) * (thick / 2 / d.length);
      return [a - n, b - n, b + n, a + n];
    }

    material('cornerProfile');
    component('Burchak (qayt) ulash profili 90°', null, () {
      final legs = g.leg * k;
      for (final piece in [
        strip(0, 0, 0, -g.web, t),
        strip(0, 0, -legs, -legs, t),
        strip(0, 0, legs, -legs, t),
        strip(0, -g.web, -legs, -g.web - legs, t),
        strip(0, -g.web, legs, -g.web - legs, t),
        // Thickened node half way down the web.
        strip(0, -g.web * .42, 0, -g.web * .58, t * 2.4),
      ]) {
        columnPrism(piece, 0, h, color, null);
      }
    });
  }

  /// The next construction around the corner, drawn faintly for context.
  void neighbourFrame(String side, Color color) {
    final g = cornerGeometry(side),
        h = (drawing['heightMm'] as num).toDouble(),
        depth = (recipe['frameDepth'] as num?)?.toDouble() ?? 60,
        face = (recipe['frameFace'] as num?)?.toDouble() ?? 50,
        t = cornerWall,
        x0 = side == 'left' ? g.apex.x + t / 2 : g.apex.x - t / 2 - depth,
        x1 = x0 + depth,
        z0 = depth + t * 1.5,
        len = math.min(900.0, math.max(400.0, h * .6)),
        ghost = color.withValues(alpha: .38);
    List<V> rect(double a, double b, double c, double d) =>
        [V(a, c), V(b, c), V(b, d), V(a, d)];
    columnPrism(rect(x0, x1, z0, z0 + face), 0, h, ghost, null);
    columnPrism(rect(x0, x1, z0 + len - face, z0 + len), 0, h, ghost, null);
    columnPrism(rect(x0, x1, z0 + face, z0 + len - face), 0, face, ghost, null);
    columnPrism(
        rect(x0, x1, z0 + face, z0 + len - face), h - face, h, ghost, null);
    columnPrism(
        rect((x0 + x1) / 2 - 2, (x0 + x1) / 2 + 2, z0 + face, z0 + len - face),
        face,
        h - face,
        const Color(0x553abfcf),
        null,
        glass: true);
  }

  void box(double x, double y, double z, double w, double h, double depth,
      Color color, String? group) {
    prism([V(x, y), V(x + w, y), V(x + w, y + h), V(x, y + h)], z, depth, color,
        group);
  }

  // Generic workshop section. All dimensions are millimetres. Each hollow
  // extrusion is one physical profile, including its walls and chamber webs.
  // This is deliberately not labelled as a manufacturer-certified section.
  void profileBar(List<V> quad, double width, double depth, double z,
      Color color, String? group) {
    if (quad.length != 4 || width < 5 || depth < 5) {
      prism(quad, z, depth, color, group);
      return;
    }
    final previous = sharedPart;
    sharedPart ??= registerPart(quad, z, depth, group).id;
    final wall = ((recipe['profileWallMm'] as num?)?.toDouble() ?? 1.8)
        .clamp(.5, math.min(width, depth) / 5)
        .toDouble();
    final chambers =
        ((recipe['profileChambers'] as num?)?.toInt() ?? 2).clamp(1, 4);
    void strip(double from, double to, double back, double thick) {
      final a = quad[0], b = quad[1], ib = quad[2], ia = quad[3];
      prism([
        a + (ia - a) * from,
        b + (ib - b) * from,
        b + (ib - b) * to,
        a + (ia - a) * to
      ], z + back, thick, color, group);
    }

    final t = wall / width;
    if (simpleAluminium &&
        const {'frame', 'sash', 'mullion', 'sashMullion', 'bead'}
            .contains(materialKey)) {
      simpleSection(
          (u0, u1, w0, w1) => strip(u0 / width, u1 / width, w0, w1 - w0),
          width,
          depth,
          wall);
      sharedPart = previous;
      return;
    }
    if (materialKey == 'bead') {
      strip(0, 1, 0, wall);
      strip(0, t, wall, depth - wall);
      strip(t, .68, depth - wall, wall);
      strip(.68 - t, .68, depth * .42, depth * .58);
      strip(.68, .9, depth * .42, wall);
      strip(.9 - t, .9, 0, depth * .42);
      sharedPart = previous;
      return;
    }
    if (recipe['sectionStyle'] == 'plainHollow' || materialKey == 'spacer') {
      final core = materialKey == 'spacer' || recipe['profileDetail'] == 'box'
          ? 1.0
          : .76;
      strip(0, t, 0, depth);
      strip(core - t, core, 0, depth);
      strip(t, core - t, 0, wall);
      strip(t, core - t, depth - wall, wall);
      if (core < 1) {
        final ledge = materialKey == 'sash' ? depth * .7 : depth * .38;
        strip(core, 1, ledge, wall * 1.2);
        strip(1 - t, 1, ledge, depth - ledge);
      }
      sharedPart = previous;
      return;
    }
    // Outer and inner walls, chamber webs, rear skin and recessed front skin.
    strip(0, t, 0, depth);
    strip(1 - t, 1, 0, depth);
    strip(t, 1 - t, 0, wall);
    for (var j = 1; j < chambers; j++) {
      final mid = j / chambers;
      strip(mid - t / 2, mid + t / 2, wall, depth - wall * 2);
    }
    final grooveStart = .68, grooveEnd = .84;
    strip(t, grooveStart, depth - wall, wall);
    strip(grooveEnd, 1 - t, depth - wall, wall);
    strip(grooveStart, grooveEnd, depth - wall * 3, wall);
    strip(grooveStart, grooveStart + t, depth - wall * 2, wall * 2);
    strip(grooveEnd - t, grooveEnd, depth - wall * 2, wall * 2);
    sharedPart = previous;
  }

  bool get simpleAluminium => recipe['sectionStyle'] == 'plainHollow';

  /// Outer glazing lip of simple aluminium profiles, above the exterior skin.
  double lipHeight(double depth) => (depth * .2).clamp(6.0, 14.0).toDouble();

  /// Exterior face of the glass behind the lip and its gasket.
  double glassSeat(double depth) => lipHeight(depth) + 2;

  /// Strip next to each opening that the bead covers: the glass rebate
  /// between the profile box and the lip. The same on frame, sash and
  /// mullion so one bead outline fits every edge of a filling.
  double get rebateZone {
    double face(String k) => (recipe[k] as num?)?.toDouble() ?? 50;
    final bead = (recipe['beadFaceMm'] as num?)?.toDouble() ?? 18;
    return (bead - 2)
        .clamp(
            4.0,
            math.max(
                4.0,
                [
                  face('frameFace') * .4,
                  face('sashFace') * .4,
                  face('mullionFace') * .3
                ].reduce(math.min)))
        .toDouble();
  }

  // Simple (non-thermal) aluminium after workshop photos of AKFA profiles:
  // a hollow box, an exterior glazing flange that ends in a hooked lip, and
  // a clip on the box wall for the U-shaped bead. u runs across the face
  // from the outer edge of the bar, w through the depth from the exterior.
  void simpleSection(
      void Function(double u0, double u1, double w0, double w1) rect,
      double width,
      double depth,
      double t) {
    if (materialKey == 'bead') {
      // U channel opening towards the glass; the closed side faces the room.
      final hookW = math.min(2.5 * t, width * .25);
      rect(0, width, depth - t, depth);
      rect(0, t, depth * .25, depth - t);
      rect(0, hookW, depth * .25, depth * .25 + t);
      rect(width - 1.4 * t, width, 0, depth - t);
      rect(width - 3 * t, width, 0, t);
      return;
    }
    final lip = lipHeight(depth),
        zone = math.min(rebateZone, width * .45),
        bead = (recipe['beadDepthMm'] as num?)?.toDouble() ?? 16,
        clip = (glassSeat(depth) + GlazingSpec(recipe).totalMm + bead * .25)
            .clamp(lip + 2 * t, math.max(lip + 2 * t, depth - 3 * t))
            .toDouble();
    // Hooked lip at an opening edge; [inward] points back over the rebate.
    void lipAt(double edge, double inward) {
      final a = inward > 0 ? edge : edge - t, b = a + t;
      rect(a, b, t, lip);
      final hookA = inward > 0 ? edge : edge - 2.5 * t;
      rect(hookA, hookA + 2.5 * t, lip - t, lip);
    }

    // Bead clip on a box wall, sticking out into the rebate.
    void clipAt(double wall, double outward) {
      final a = outward > 0 ? wall : wall - 2.5 * t;
      rect(a, a + 2.5 * t, clip + t, clip + 2 * t);
      final tip = outward > 0 ? wall + 1.5 * t : wall - 2.5 * t;
      rect(tip, tip + t, clip, clip + 2 * t);
    }

    if (materialKey == 'mullion' || materialKey == 'sashMullion') {
      final a = zone, b = width - zone, cap = math.min(width * .06, zone * .5);
      rect(0, width, 0, t);
      lipAt(0, 1);
      lipAt(width, -1);
      rect(a, a + t, t, depth - t);
      rect(b - t, b, t, depth - t);
      rect(a - cap, b + cap, depth - t, depth);
      rect(a - cap, a - cap + t, depth - depth * .12, depth - t);
      rect(b + cap - t, b + cap, depth - depth * .12, depth - t);
      clipAt(a, -1);
      clipAt(b, 1);
      return;
    }
    final box = width - zone;
    rect(0, width, 0, t);
    rect(0, t, t, depth);
    rect(box - t, box, t, depth - t);
    rect(t, box, depth - t, depth);
    lipAt(width, -1);
    clipAt(box, 1);
    if (materialKey == 'sash') {
      // Lip on the room side that laps over the gap to the frame.
      final lap = math.min(8.0, width * .14);
      rect(-lap, 0, depth - t, depth);
      rect(-lap, -lap + t, depth - 3 * t, depth - t);
    }
  }

  bool get isProfile => const {
        'frame',
        'sash',
        'mullion',
        'sashMullion',
        'meshFrame',
        'rail',
        'threshold',
        'spacer',
        'bead'
      }.contains(materialKey);

  void beam(V a, V b, double width, double depth, double z, Color color,
      String? group) {
    final delta = b - a, len = delta.length;
    if (len < .1) return;
    final normal = V(-delta.y / len, delta.x / len) * (width / 2);
    final quad = [a - normal, b - normal, b + normal, a + normal];
    if (isProfile) {
      profileBar(quad, width, depth, z, color, group);
    } else {
      prism(quad, z, depth, color, group);
    }
  }

  void ring(List<V> outer, double width, double depth, double z, Color color,
      String? group) {
    final previous = sharedPart;
    if (outer.length > 8) {
      sharedPart ??= registerPart(outer, z, depth, group).id;
    }
    // Polygonal extrusion keeps the real outline. Mitred faces pair matching offset vertices.
    var inner = inset(outer, width);
    if (inner.length == outer.length) {
      var best = double.infinity, shift = 0;
      for (var offset = 0; offset < inner.length; offset++) {
        double score = 0;
        for (var j = 0; j < outer.length; j++) {
          score += (outer[j] - inner[(j + offset) % inner.length]).length;
        }
        if (score < best) {
          best = score;
          shift = offset;
        }
      }
      inner = [
        for (var j = 0; j < inner.length; j++) inner[(j + shift) % inner.length]
      ];
    }
    if (inner.length == outer.length) {
      for (var j = 0; j < outer.length; j++) {
        final k = (j + 1) % outer.length;
        final quad = [outer[j], outer[k], inner[k], inner[j]];
        if (isProfile) {
          profileBar(quad, width, depth, z, color, group);
        } else {
          prism(quad, z, depth, color, group);
        }
      }
    } else {
      for (var j = 0; j < outer.length; j++) {
        final a = outer[j],
            b = outer[(j + 1) % outer.length],
            e = b - a,
            n = V(-e.y, e.x) * (width / (2 * e.length));
        beam(a + n, b + n, width, depth, z, color, group);
      }
    }
    sharedPart = previous;
  }

  void cornerConnectors(List<V> outer, double faceWidth, double depth, double z,
      Color color, String? group) {
    // A curved extrusion has no connector at each tessellation vertex.
    if (outer.length > 24 ||
        (const {'circle', 'ellipse', 'arch'}.contains(drawing['shape']) &&
            outer.length > 8)) {
      return;
    }
    final inner = inset(outer, faceWidth * .38);
    if (inner.length != outer.length) return;
    for (var j = 0; j < outer.length; j++) {
      final v = outer[j],
          prev = outer[(j + outer.length - 1) % outer.length],
          next = outer[(j + 1) % outer.length];
      final sorted = [...inner]
        ..sort((a, b) => (a - v).length.compareTo((b - v).length));
      final at = sorted.first,
          da = prev - v,
          db = next - v,
          arm = math.min(faceWidth * 1.5, math.min(da.length, db.length) * .22);
      final width = faceWidth * .38,
          height = depth * .56,
          back = z + depth * .19;
      component('Archasimon burchak ulagichi • tishli alyuminiy', group, () {
        for (final direction in [da, db]) {
          final u = direction * (1 / direction.length), normal = V(-u.y, u.x);
          beam(at, at + u * arm, width, height, back, color, group);
          for (double t = 12; t < arm - 5; t += 8) {
            for (final sign in [-1.0, 1.0]) {
              final center = at + u * t + normal * (width * .5 * sign);
              prism([
                center - u * 3,
                center + normal * (2.5 * sign),
                center + u * 3
              ], back, height, color, group);
            }
          }
          beam(at + u * 5, at + u * (arm - 4), width * .28, 2, back + height,
              color, group);
        }
      });
    }
  }

  void cylinder(
      P3 center, double radius, double height, Color color, String? group) {
    final poly = [
      for (var j = 0; j < 20; j++)
        V(center.x + radius * math.cos(j * math.pi / 10),
            center.y + radius * math.sin(j * math.pi / 10))
    ];
    prism(poly, center.z, height, color, group);
  }

  // Compound solids retain one selectable BOM component. Its envelope is
  // measured from the finished mesh, including the curved lever and fittings.
  void component(String title, String? group, void Function() build) {
    final previous = sharedPart,
        label = partLabel,
        id = 'p${parts.length + 1}',
        start = faces.length;
    partLabel = title;
    sharedPart = id;
    parts[id] = ModelPart(
        id, materialKey, title, const P3(0, 0, 0), const P3(0, 0, 0), group);
    build();
    final vertices = faces.skip(start).expand((f) => f.vertices).toList();
    if (vertices.isNotEmpty) {
      double lo(double Function(P3) get) => vertices.map(get).reduce(math.min);
      double hi(double Function(P3) get) => vertices.map(get).reduce(math.max);
      final x = lo((p) => p.x),
          y = lo((p) => p.y),
          z = lo((p) => p.z),
          xx = hi((p) => p.x),
          yy = hi((p) => p.y),
          zz = hi((p) => p.z);
      parts[id] = ModelPart(
          id,
          materialKey,
          title,
          P3((x + xx) / 2, (y + yy) / 2, (z + zz) / 2),
          P3(xx - x, yy - y, zz - z),
          group,
          explosionLayer: explosionLayer);
    }
    sharedPart = previous;
    partLabel = label;
  }

  List<V> roundedOutline(
      double x, double y, double w, double h, double radius) {
    final r = math.min(radius, math.min(w, h) / 2), out = <V>[];
    for (var corner = 0; corner < 4; corner++) {
      final cx = corner == 0 || corner == 3 ? x + w - r : x + r,
          cy = corner < 2 ? y + h - r : y + r;
      final start = corner * math.pi / 2;
      for (var step = 0; step <= 5; step++) {
        final a = start + step * math.pi / 10;
        out.add(V(cx + r * math.cos(a), cy + r * math.sin(a)));
      }
    }
    return out;
  }

  void plate(double x, double y, double z, double w, double h, double d,
      double radius, Color color, String? group) {
    final outer = roundedOutline(x, y, w, h, radius),
        inner = roundedOutline(
            x + .7, y + .7, w - 1.4, h - 1.4, math.max(.5, radius - .7));
    final previous = sharedPart;
    sharedPart ??= registerPart(outer, z, d, group).id;
    face([for (final v in outer.reversed) P3(v.x, v.y, z)], color, group);
    face([for (final v in inner) P3(v.x, v.y, z + d)], color, group);
    for (var j = 0; j < outer.length; j++) {
      final k = (j + 1) % outer.length,
          a = outer[j],
          b = outer[k],
          c = inner[j],
          e = inner[k];
      face([
        P3(a.x, a.y, z),
        P3(b.x, b.y, z),
        P3(b.x, b.y, z + d - .8),
        P3(a.x, a.y, z + d - .8)
      ], color, group);
      face([
        P3(a.x, a.y, z + d - .8),
        P3(b.x, b.y, z + d - .8),
        P3(e.x, e.y, z + d),
        P3(c.x, c.y, z + d)
      ], color, group);
    }
    sharedPart = previous;
  }

  void tube(List<P3> centers, double radius, Color color, String? group,
      {P3 reference = const P3(0, 1, 0), double oval = 1}) {
    if (centers.length < 2) return;
    final previous = sharedPart;
    if (sharedPart == null) {
      final xy = [
            for (final c in centers) ...[
              V(c.x - radius, c.y - radius),
              V(c.x + radius, c.y + radius)
            ]
          ],
          zs = centers.map((c) => c.z);
      final z = zs.reduce(math.min) - radius;
      sharedPart =
          registerPart(xy, z, zs.reduce(math.max) + radius - z, group).id;
    }
    final rings = <List<P3>>[];
    for (var j = 0; j < centers.length; j++) {
      final tangent = (centers[math.min(j + 1, centers.length - 1)] -
          centers[math.max(0, j - 1)]);
      var normal = tangent.cross(reference);
      if (normal.length < .001) normal = tangent.cross(const P3(1, 0, 0));
      if (normal.length < .001) normal = tangent.cross(const P3(0, 0, 1));
      normal = normal * (1 / normal.length);
      final other = tangent.cross(normal) * (1 / tangent.length);
      rings.add([
        for (var k = 0; k < 20; k++)
          centers[j] +
              normal * (radius * math.cos(k * math.pi / 10)) +
              other * (radius * oval * math.sin(k * math.pi / 10))
      ]);
    }
    face(rings.first.reversed.toList(), color, group);
    face(rings.last, color, group);
    for (var j = 0; j < rings.length - 1; j++) {
      for (var k = 0; k < 20; k++) {
        final n = (k + 1) % 20;
        face([rings[j][k], rings[j][n], rings[j + 1][n], rings[j + 1][k]],
            color, group);
      }
    }
    sharedPart = previous;
  }

  void screwHead(double x, double y, double z, String? group) {
    cylinder(P3(x, y, z), 2.3, 1.6, const Color(0xffbac5ce), group);
    box(x - 1.4, y - .4, z + 1.65, 2.8, .8, .1, const Color(0xff27313c), group);
  }

  void leverHandle(double x, double y, double back, double front, bool door,
      bool right, String? group) {
    final color = recipe['hardwareFinish'] == 'silver'
        ? const Color(0xffb7c3ce)
        : recipe['hardwareFinish'] == 'gold'
            ? const Color(0xffbc9d50)
            : const Color(0xff343c45);
    component(
        door
            ? 'Eshik dastasi • ichki va tashqi to‘plam'
            : 'Deraza dastasi • egri tutqich',
        group, () {
      for (final side in door ? [1.0, -1.0] : [1.0]) {
        final z = side > 0 ? front : back;
        final long = door && recipe['handleStyle'] != 'rosette';
        plate(x - (door ? 15 : 12), y - (long ? 45 : 30), side > 0 ? z : z - 6,
            door ? 30 : 24, long ? 220 : 60, 6, door ? 10 : 8, color, group);
        final neck = z + side * 6;
        tube([P3(x, y, neck), P3(x, y, neck + side * 17)], 8, color, group);
        final dir = right ? 1.0 : -1.0;
        if (door) {
          tube([
            P3(x, y, neck + side * 15),
            P3(x + dir * 5, y, neck + side * 28),
            P3(x + dir * 16, y + 1, neck + side * 35),
            P3(x + dir * 38, y + 2, neck + side * 37),
            P3(x + dir * 78, y + 2, neck + side * 37),
            P3(x + dir * 111, y, neck + side * 34)
          ], 7.5, color, group, oval: .88);
        } else {
          tube([
            P3(x, y, neck + side * 15),
            P3(x, y + 6, neck + side * 27),
            P3(x, y + 17, neck + side * 33),
            P3(x, y + 42, neck + side * 35),
            P3(x, y + 68, neck + side * 35),
            P3(x, y + 87, neck + side * 31)
          ], 6.5, color, group, reference: const P3(1, 0, 0), oval: .86);
        }
        if (side > 0) {
          for (final delta in long ? [-33.0, 162.0] : [-21.5, 21.5]) {
            screwHead(x, y + delta, z + 6, group);
          }
        }
      }
      box(x - 3.5, y - 3.5, back - 3, 7, 7, front - back + 6,
          const Color(0xff79858f), group);
    });
  }

  void barrelHinge(
      double x, double y, double z, bool horizontal, bool door, String? group,
      {bool right = false}) {
    final color = recipe['hardwareFinish'] == 'silver'
            ? const Color(0xffa9b7c5)
            : const Color(0xff424c57),
        length = door ? 94.0 : 62.0,
        r = door ? 8.0 : 6.0;
    material(door ? 'doorHinge' : 'hinge');
    component('Petlya • rama tagligi', null, () {
      if (horizontal) {
        plate(x - 24, y - 19, z - 15, 48, 19, 5, 5, color, null);
        screwHead(x - 15, y - 10, z - 10, null);
        screwHead(x + 15, y - 10, z - 10, null);
      } else {
        plate(x + (right ? 0 : -19), y - 24, z - 15, 19, 48, 5, 5, color, null);
        screwHead(x + (right ? 10 : -10), y - 15, z - 10, null);
        screwHead(x + (right ? 10 : -10), y + 15, z - 10, null);
      }
    });
    component('Petlya • sharnir bo‘g‘imi', group, () {
      if (horizontal) {
        plate(x - 24, y + 2, z - 13, 48, 18, 5, 5, color, group);
      } else {
        plate(
            x + (right ? -20 : 2), y - 24, z - 13, 18, 48, 5, 5, color, group);
      }
      for (var k = 0; k < 3; k++) {
        final from = -length / 2 + k * length / 3 + 1,
            to = -length / 2 + (k + 1) * length / 3 - 1;
        tube(
            horizontal
                ? [P3(x + from, y, z), P3(x + to, y, z)]
                : [P3(x, y + from, z), P3(x, y + to, z)],
            r,
            color,
            group,
            reference: horizontal ? const P3(0, 1, 0) : const P3(1, 0, 0));
      }
      tube(
          horizontal
              ? [P3(x - length / 2 - 1, y, z), P3(x + length / 2 + 1, y, z)]
              : [P3(x, y - length / 2 - 1, z), P3(x, y + length / 2 + 1, z)],
          2,
          const Color(0xffbfcbd6),
          group,
          reference: horizontal ? const P3(0, 1, 0) : const P3(1, 0, 0));
      if (horizontal) {
        screwHead(x - 15, y + 10, z - 8, group);
        screwHead(x + 15, y + 10, z - 8, group);
      } else {
        screwHead(x + (right ? -10 : 10), y - 15, z - 8, group);
        screwHead(x + (right ? -10 : 10), y + 15, z - 8, group);
      }
    });
  }

  void pullWindowHandle(double x, double y, double z, List<double> bounds,
      String owner, bool right, int locks) {
    final handleMotion = '$owner-pull',
        rodMotion = '$owner-rod',
        group = groups[owner]!;
    motions[handleMotion] =
        HardwareMotion(owner, group, 'pull', P3(x, y - 18, z + 10));
    motions[rodMotion] = HardwareMotion(owner, group, 'rod', P3(x, y, z));
    final color = recipe['hardwareFinish'] == 'silver'
        ? const Color(0xffb8c3ce)
        : const Color(0xff38434f);
    material('handle');
    component('Deraza tutqichi • asos qutisi', owner, () {
      plate(x - 13, y - 33, z, 26, 68, 7, 7, color, owner);
      screwHead(x, y - 24, z + 7, owner);
      screwHead(x, y + 25, z + 7, owner);
    });
    component('Deraza tutqichi • tortma dasta', handleMotion, () {
      tube([P3(x - 10, y - 18, z + 10), P3(x + 10, y - 18, z + 10)], 4, color,
          handleMotion);
      tube([
        P3(x, y - 18, z + 10),
        P3(x, y - 5, z + 16),
        P3(x, y + 16, z + 21),
        P3(x, y + 45, z + 23),
        P3(x, y + 68, z + 20)
      ], 6.5, color, handleMotion, reference: const P3(1, 0, 0), oval: .8);
    });
    final barX = x + (right ? -13 : 13),
        top = bounds[1] + 80,
        bottom = bounds[3] - 80;
    material('windowLock');
    component('Deraza zapori • pastga suriluvchi temir tyaga', rodMotion, () {
      box(barX - 3, top, z - 5, 6, math.max(60, bottom - top), 3,
          const Color(0xffa0adba), rodMotion);
      for (var k = 0; k < math.max(2, locks); k++) {
        final cy = top +
            (bottom - top) *
                (.16 + .68 * k / math.max(1, math.max(2, locks) - 1));
        cylinder(
            P3(barX, cy - 7, z - 2), 4, 7, const Color(0xffb9c6d1), rodMotion);
      }
    });
    for (var k = 0; k < math.max(2, locks); k++) {
      final cy = top +
          (bottom - top) *
              (.16 + .68 * k / math.max(1, math.max(2, locks) - 1));
      component('Yelma • ramadagi qiya ushlagich', null, () {
        prism([
          V(barX - 8, cy - 3),
          V(barX + 10, cy - 9),
          V(barX + 10, cy + 10),
          V(barX - 8, cy + 10)
        ], z - 1, 9, const Color(0xff707e8d), null);
        screwHead(barX + 6, cy + 5, z + 8, null);
      });
    }
  }

  /// "Delfin" handle of simple aluminium casements: a rosette, a lever
  /// arched like a dolphin's back, and a hook behind it that catches a
  /// strike on the frame. The lever turns 90° to free the hook, then the
  /// sash swings.
  void dolphinHandle(double x, double y, double front, List<double> b,
      String owner, String type, bool right, int locks) {
    final turnMotion = '$owner-turn',
        horizontal = type == 'top' || type == 'bottom',
        along = horizontal ? const V(1, 0) : const V(0, 1),
        across = horizontal ? const V(0, 1) : const V(1, 0),
        pivot = V(x, y) - along * 16;
    // The lever turns into the sash, the hook out of the strike.
    final turn = math.pi /
        2 *
        (horizontal ? (type == 'top' ? -1 : 1) : (right ? -1 : 1));
    final hookDir =
        horizontal ? V(0, type == 'top' ? 1 : -1) : V(right ? -1 : 1, 0);
    motions[turnMotion] = HardwareMotion(
        owner, groups[owner]!, 'turn', P3(pivot.x, pivot.y, front),
        turn: turn);
    final color = recipe['hardwareFinish'] == 'silver'
        ? const Color(0xffc3ccd5)
        : recipe['hardwareFinish'] == 'gold'
            ? const Color(0xffbc9d50)
            : const Color(0xff2f363e);
    P3 at(double s, double c, double h) {
      final v = pivot + along * s + across * c;
      return P3(v.x, v.y, front + h);
    }

    V flat(double s, double c) => pivot + along * s + across * c;
    final reference = P3(across.x, across.y, 0);
    material('handle');
    component('Delfin tutqich • asos', owner, () {
      final a = flat(-14, -11), z = flat(50, 11);
      plate(math.min(a.x, z.x), math.min(a.y, z.y), front, (a.x - z.x).abs(),
          (a.y - z.y).abs(), 6, 9, color, owner);
      for (final s in [-5.0, 42.0]) {
        final v = flat(s, 0);
        screwHead(v.x, v.y, front + 6, owner);
      }
    });
    component('Delfin tutqich • egri dasta', turnMotion, () {
      cylinder(P3(pivot.x, pivot.y, front + 6), 8.5, 8, color, turnMotion);
      // Arched body from the head at the pivot to the tail.
      tube([
        at(0, 0, 10),
        at(7, 0, 16),
        at(19, 0, 21),
        at(37, 0, 23),
        at(57, 0, 21),
        at(72, 0, 16),
        at(80, 0, 13)
      ], 6.5, color, turnMotion, reference: reference, oval: .72);
      // Snout ahead of the pivot and a small dorsal fin.
      tube([at(0, 0, 10), at(-9, 0, 12), at(-15, 0, 11)], 4, color, turnMotion,
          reference: reference);
      tube(
          [at(30, 0, 26), at(36, 0, 31), at(40, 0, 29)], 2.4, color, turnMotion,
          reference: reference);
      // Tail flukes.
      for (final side in [-1.0, 1.0]) {
        prism([
          flat(77, -2 * side),
          flat(87, -11 * side),
          flat(92, -8 * side),
          flat(84, 0)
        ], front + 11, 4, color, turnMotion);
      }
      box(pivot.x - 3.5, pivot.y - 3.5, front - 22, 7, 7, 22,
          const Color(0xff79858f), turnMotion);
    });
    // Hook tongue behind the rosette; it reaches over the frame lip.
    final reach = (recipe['sashFace'] as num).toDouble() * .5 + 12,
        tip = pivot + hookDir * reach;
    material('windowLock');
    component('Delfin tutqich • ilgak tili', turnMotion, () {
      beam(pivot, tip, 9, 4, front - 6, const Color(0xff9aa6b2), turnMotion);
      box(tip.x - 4.5, tip.y - 4.5, front - 12, 9, 9, 6,
          const Color(0xff9aa6b2), turnMotion);
    });
    final frameFront = (recipe['frameDepth'] as num?)?.toDouble() ?? 60,
        strike = pivot + hookDir * (reach - 10);
    component('Ilgak tutgichi • ramadagi qarshi plastina', null, () {
      final lo = math.max(1.0, front - 12 - frameFront);
      box(strike.x - 9, strike.y - 9, frameFront, 18, 18, lo,
          const Color(0xff7d8b99), null);
      screwHead(strike.x, strike.y, frameFront + lo, null);
    });
    // Extra latches along the same edge when more locks are counted.
    const spots = [.18, .82, .32, .68, .1, .9, .42, .58, .05];
    for (var k = 0; k < locks - 1; k++) {
      final t = spots[k % spots.length],
          edge = horizontal
              ? V(b[0] + (b[2] - b[0]) * t, y)
              : V(x, b[1] + (b[3] - b[1]) * t);
      if ((edge - V(x, y)).length < 120) continue;
      component('Zashchelka • prujinali tilcha', owner, () {
        final a = edge - along * 18 - across * 6,
            z = edge + along * 18 + across * 6;
        plate(math.min(a.x, z.x), math.min(a.y, z.y), front, (a.x - z.x).abs(),
            (a.y - z.y).abs(), 5, 4, color, owner);
        final tongue = edge + hookDir * (reach - 4);
        beam(edge, tongue, 8, 4, front - 6, const Color(0xff9aa6b2), owner);
      });
    }
  }

  void euroCylinder(
      double x, double y, double back, double front, String? group) {
    material('cylinder');
    component('Qulf silindri • kalit teshigi', group, () {
      final color = const Color(0xffb4a56b);
      cylinder(P3(x, y, back - 3), 8, front - back + 8, color, group);
      box(x - 5, y, back - 3, 10, 13, front - back + 8, color, group);
      cylinder(P3(x, y + 12, back - 3), 5, front - back + 8, color, group);
      for (final z in [back - 3.2, front + 5.1]) {
        box(x - 1.1, y - 3, z, 2.2, 14, .2, const Color(0xff18222c), group);
        box(x - 3, y + 5, z, 6, 2, .2, const Color(0xff18222c), group);
      }
    });
  }

  List<V> simplify(List<V> p) {
    if (p.length <= 40) return p;
    return [for (var j = 0; j < p.length; j += 3) p[j]];
  }

  void build() {
    final finish = recipe['finish'] ?? 'silver';
    final frame = Color(finishColors[finish] ?? 0xffd7dee7);
    final sash = finish == 'silver' ? const Color(0xfff0f2f4) : frame;
    const bead = Color(0xffb8c6d3),
        rubber = Color(0xff29333d),
        metal = Color(0xff7d91a4),
        // Clear float glass: a faint blue-green; reflections come from the
        // renderer.
        glass = Color(0x4a5b93ad),
        wood = Color(0xffc5a27b);
    final frameDepth = (recipe['frameDepth'] ?? 60 as num).toDouble(),
        sashDepth = (recipe['sashDepth'] ?? 65 as num).toDouble(),
        thickness = (recipe['glassThickness'] ?? 6 as num).toDouble();
    final glazing = GlazingSpec(recipe);
    final frameFace = (recipe['frameFace'] as num).toDouble(),
        sashFace = (recipe['sashFace'] as num).toDouble();
    material('frame');
    ring(simplify(layout.outer), frameFace, frameDepth, 0, frame, null);
    material('decoration');
    // Drainage caps and fixing screws on the outer bottom frame.
    final w = (drawing['widthMm'] as num).toDouble(),
        h = (drawing['heightMm'] as num).toDouble();
    if ((drawing['shape'] == 'rect' && layout.outer.length == 4) ||
        drawing['shape'] == 'arch') {
      for (final x in [w * .25, w * .75]) {
        box(x - 15, h - frameFace * .65, frameDepth + 1, 30, 8, 3, metal, null);
      }
      material('screw');
      for (final x in [frameFace * .5, w - frameFace * .5]) {
        for (final y in [frameFace * .5, h - frameFace * .5]) {
          cylinder(P3(x, y, frameDepth + 1), 3, 2, metal, null);
        }
      }
    }
    material('mullion');
    for (final s in layout.splits) {
      beam(s.a, s.b, (recipe['mullionFace'] as num).toDouble(), frameDepth, 0,
          frame, null);
    }
    for (final side in cornerJoins(drawing)) {
      cornerJoint(side, frame);
    }
    material('corner');
    cornerConnectors(layout.outer, frameFace, frameDepth, 0, metal, null);
    material('mullionJoint');
    for (final split in layout.splits) {
      for (final v in [split.a, split.b]) {
        box(v.x - 9, v.y - 9, frameDepth * .3, 18, 18, 18, metal, null);
      }
    }
    for (final c in layout.cells) {
      final n = c.node,
          type = n['opening'] as String,
          b = bounds(c.polygon),
          active = type != 'fixed',
          door = type.startsWith('door') || type == 'passive';
      final right = type == 'right' || type == 'doorRight';
      final group = active ? n['id'] as String : null;
      final hingeX = right ? b[2] : b[0],
          hingeY = type == 'bottom' ? b[3] : b[1];
      if (group != null) {
        groups[group] =
            ModelGroup(c, hingeX, hingeY, frameDepth * .25 + sashDepth + 10);
      }
      final z = active ? frameDepth * .25 : 0.0,
          depth = active ? sashDepth : frameDepth;
      if (active) {
        material('sash');
        ring(simplify(c.polygon), sashFace, depth, z, sash, group);
        material('corner');
        cornerConnectors(c.polygon, sashFace, depth, z, metal, group);
        // Two separate sash seal lines.
        material('sealOuter');
        if ((recipe['outerLoops'] as num) > 0) {
          ring(simplify(inset(c.polygon, 3)), 3, 2, z + depth + 1, rubber,
              group);
        }
        material('sealInner');
        if ((recipe['innerLoops'] as num) > 0 &&
            inset(c.polygon, sashFace - 4).length > 2) {
          ring(simplify(inset(c.polygon, sashFace - 4)), 2, 2, z + depth + 1,
              rubber, group);
        }
      }
      final fillings = layoutInfill(c, recipe);
      material('sashMullion');
      for (final split in fillings.splits) {
        beam(split.a, split.b, (recipe['mullionFace'] as num).toDouble(), depth,
            z, sash, group);
      }
      for (final fill in fillings.cells) {
        // The pane or panel as ordered (it may reach under the profile lip)
        // and the visible opening it shows through.
        final poly = simplify(glassOutline(fill.polygon, recipe)),
            visible = simplify(
                inset(fill.polygon, (recipe['glassGap'] as num).toDouble())),
            kind = fill.node['fill'];
        if (poly.length < 3 || kind == 'empty') continue;
        final gb = bounds(visible), panel = kind != 'glass';
        material(kind as String);
        final glassZ = simpleAluminium
            ? z + glassSeat(depth)
            : z + (depth - glazing.totalMm) / 2;
        if (!panel && glazing.doubleGlazed) {
          // Two actual panes and the hollow metallic edge spacer between them.
          explosionLayer = -.24;
          partLabel = '1-shisha • tashqi';
          prism(poly, glassZ, thickness, glass.withValues(alpha: .18), group,
              glass: true);
          explosionLayer = .24;
          partLabel = '2-shisha • ichki';
          prism(poly, glassZ + thickness + glazing.gapMm, thickness,
              glass.withValues(alpha: .18), group,
              glass: true);
          explosionLayer = 0;
          final spacer = inset(poly, glazing.insetMm);
          material('spacer');
          ring(spacer, 5, glazing.gapMm, glassZ + thickness, metal, group);
          final bars = decorativeBars(poly, n, glazing),
              joints = decorativeJoints(bars);
          final middle = glassZ + thickness + glazing.gapMm / 2;
          material('shpros');
          for (final bar in bars) {
            beam(
                bar.a, bar.b, 8, 4, middle - 2, const Color(0xffc8ab59), group);
          }
          material('shprosJoint');
          for (final at in joints) {
            box(at.x - 5, at.y - 5, middle - 2, 10, 10, 4,
                const Color(0xffd8bf73), group);
          }
          if (n['rosettes'] == true) {
            material('shprosRosette');
            for (final at in joints) {
              final previous = sharedPart;
              sharedPart = registerPart(
                      [V(at.x - 24, at.y - 24), V(at.x + 24, at.y + 24)],
                      middle - 2,
                      4,
                      group)
                  .id;
              for (var petal = 0; petal < 8; petal++) {
                final angle = petal * math.pi / 4;
                cylinder(
                    P3(at.x + 16 * math.cos(angle), at.y + 16 * math.sin(angle),
                        middle - 1),
                    7,
                    2,
                    const Color(0xffc8ab59),
                    group);
              }
              cylinder(P3(at.x, at.y, middle - 2), 10, 4,
                  const Color(0xffdec784), group);
              sharedPart = previous;
            }
          }
          material('butyl');
          ring(spacer, 1.3, .6, glassZ + thickness - .3, rubber, group);
          ring(spacer, 1.3, .6, glassZ + thickness + glazing.gapMm - .3, rubber,
              group);
          material('iguSeal');
          ring(poly, glazing.insetMm, glazing.gapMm, glassZ + thickness, rubber,
              group);
        } else if (simpleAluminium) {
          // Panels sit in the same rebate as the glass, e.g. 4 mm composite.
          prism(poly, glassZ, panel ? math.max(glazing.totalMm, 4) : thickness,
              panel ? wood : glass, group,
              glass: !panel);
        } else {
          prism(poly, panel ? z + depth * .5 : glassZ, panel ? 20 : thickness,
              panel ? wood : glass, group,
              glass: !panel);
        }
        material('bead');
        final beadFace = (recipe['beadFaceMm'] as num?)?.toDouble() ?? 18,
            beadDepth = (recipe['beadDepthMm'] as num?)?.toDouble() ?? 16;
        if (simpleAluminium) {
          // U bead clipped onto the profile box wall, pressing the pane.
          partLabel = 'Shtapik • U shaklidagi qisqich profil';
          ring(
              simplify(outset(fill.polygon, rebateZone)),
              beadFace,
              beadDepth,
              glassZ + math.max(glazing.totalMm, panel ? 4 : 0) - 1,
              sash,
              group);
        } else {
          partLabel = 'Shtapik • pog‘onali profil va ilashuvchi lab';
          ring(poly, beadFace, beadDepth, glassZ + glazing.totalMm - 2, bead,
              group);
        }
        partLabel = null;
        material('uGasket');
        if ((recipe['uLoops'] as num) > 0) {
          if (simpleAluminium) {
            // Gasket on the lip, between the lip and the outer pane face.
            final wall = (recipe['profileWallMm'] as num?)?.toDouble() ?? 1.8;
            ring(simplify(outset(fill.polygon, wall + 1)), wall + 3, 2,
                glassZ - 2, rubber, group);
          } else {
            ring(simplify(inset(poly, 5)), 2, 2, z + depth * .65 + 2, rubber,
                group);
          }
        }
        if (kind == 'lambris') {
          material('lambris');
          final strip = (recipe['lambrisStripMm'] as num).toDouble();
          for (double x = gb[0] + strip; x < gb[2]; x += strip) {
            final narrow = rectClip(poly, [x - 1, gb[1], x + 1, gb[3]]);
            if (narrow.length > 2) {
              prism(
                  narrow,
                  simpleAluminium
                      ? glassZ + math.max(glazing.totalMm, 4)
                      : z + depth * .5 + 20,
                  1,
                  const Color(0xff9f7a53),
                  group);
            }
          }
        }
        if (active && n['mesh'] == true) {
          material('mesh');
          for (double x = gb[0] + 30;
              x < gb[2];
              x += math.max(45, (gb[2] - gb[0]) / 20)) {
            final stripe = rectClip(visible, [x, gb[1], x + 1.5, gb[3]]);
            if (stripe.length > 2) {
              prism(stripe, z - 5, 1, metal.withValues(alpha: .4), group);
            }
          }
          for (double y = gb[1] + 30;
              y < gb[3];
              y += math.max(45, (gb[3] - gb[1]) / 20)) {
            final stripe = rectClip(visible, [gb[0], y, gb[2], y + 1.5]);
            if (stripe.length > 2) {
              prism(stripe, z - 5, 1, metal.withValues(alpha: .4), group);
            }
          }
        }
      }
      if (active) {
        final count =
            ((door ? recipe['doorHinges'] : recipe['windowHinges']) as num)
                .toInt()
                .clamp(0, 8);
        final topHinge = type == 'top' || type == 'bottom',
            sliding = type.startsWith('slide');
        material(door ? 'doorHinge' : 'hinge');
        if (!sliding) {
          for (var j = 0; j < count; j++) {
            final y = topHinge
                ? hingeY
                : b[1] +
                    (b[3] - b[1]) * (.15 + .7 * j / math.max(1, count - 1));
            final x = topHinge
                ? b[0] + (b[2] - b[0]) * (.15 + .7 * j / math.max(1, count - 1))
                : hingeX;
            barrelHinge(x, y, z + depth + 10, topHinge, door, group,
                right: right);
          }
        }
        final hx = topHinge
            ? (b[0] + b[2]) / 2
            : right
                ? b[0] + sashFace * .5
                : b[2] - sashFace * .5;
        final hy = topHinge
            ? (type == 'top' ? b[3] - sashFace * .5 : b[1] + sashFace * .5)
            : (b[1] + b[3]) / 2;
        // Each primitive is selectable; purchase quantities come from the estimator,
        // never from the number of tessellated 3D surfaces or decorative screws.
        if (type != 'passive') {
          material(sliding
              ? 'slideLock'
              : door
                  ? 'doorHandle'
                  : 'handle');
          final hinged =
              !door && !sliding && group != null && type != 'tiltTurn';
          if (hinged && recipe['windowHandle'] == 'dolphin') {
            dolphinHandle(hx, hy, z + depth, b, group, type, right,
                (n['locks'] as num? ?? 1).toInt().clamp(0, 10));
          } else if (hinged && recipe['windowHandle'] != 'lever') {
            pullWindowHandle(hx, hy, z + depth, b, group, right,
                (n['locks'] as num? ?? 1).toInt().clamp(0, 10));
          } else {
            leverHandle(hx, hy, z, z + depth, door, right, group);
          }
          final locks = (n['locks'] as num? ?? 1).toInt().clamp(0, 10);
          for (var j = 0; j < locks; j++) {
            final ly = hy + 60 + j * 55;
            if (door) {
              euroCylinder(hx, ly, z, z + depth, group);
              material('doorLock');
              component('Qulf korpusi • til va yuz plastinasi', group, () {
                final edge = hx + (right ? -sashFace * .5 : sashFace * .5);
                box(edge + (right ? 1 : -35), ly - 55, z + 8, 34, 150,
                    depth - 16, metal, group);
                box(edge - 1, ly - 65, z + 3, 2, 180, depth - 6, metal, group);
                box(edge - 12, ly - 12, z + depth * .45, 24, 22, 12,
                    const Color(0xffb9c3cd), group);
                screwHead(edge, ly - 55, z + depth + 4, group);
                screwHead(edge, ly + 102, z + depth + 4, group);
              });
            } else if (sliding || type == 'tiltTurn') {
              material(sliding ? 'slideLock' : 'windowLock');
              component('Deraza zapori • ilgak', group, () {
                plate(hx - 7, ly - 18, z + depth * .5, 14, 36, 7, 4, metal,
                    group);
                tube([
                  P3(hx, ly, z + depth * .5 + 7),
                  P3(hx, ly, z + depth * .5 + 18)
                ], 4, metal, group);
              });
            }
          }
        } else {
          material('passiveBolt');
          for (final y in [b[1] + 30, b[3] - 70]) {
            box(hx - 4, y, z + depth, 8, 40, 8, metal, group);
          }
        }
        if (sliding) {
          material('roller');
          for (final x in [b[0] + 50, b[2] - 50]) {
            cylinder(P3(x, b[3] - 12, z + depth * .45), 12, 10, metal, group);
          }
          material('rail');
          beam(V(b[0], b[3]), V(b[2], b[3]), 12, 12, z - 10, metal, null);
        }
        if (door && n['threshold'] != false) {
          material('threshold');
          beam(V(b[0], b[3]), V(b[2], b[3]), 25, frameDepth, 0, metal, null);
        }
        if (door && n['closer'] == true) {
          material('closer');
          box(b[2] - 170, b[1] + 8, z + depth + 2, 110, 30, 25, metal, group);
          beam(V(b[2] - 120, b[1] + 24), V(b[2] - 20, b[1] + 70), 8, 8,
              z + depth + 30, metal, group);
        }
      }
    }
  }
}

/// A live 3D picture of the drawing being edited, turned with a finger.
/// The model is rebuilt only when the drawing or recipe changes.
class Live3D extends StatefulWidget {
  final DMap drawing, recipe;
  const Live3D({super.key, required this.drawing, required this.recipe});
  @override
  State<Live3D> createState() => _Live3DState();
}

class _Live3DState extends State<Live3D> {
  double yaw = -.45, pitch = .18;
  bool moving = false;
  String? key;
  WindowModel? model;

  WindowModel? current() {
    final next = '${jsonEncode(widget.drawing)}|${jsonEncode(widget.recipe)}';
    if (next != key) {
      key = next;
      try {
        model = WindowModel(widget.drawing, widget.recipe);
      } catch (_) {
        model = null;
      }
    }
    return model;
  }

  @override
  Widget build(BuildContext context) {
    final m = current();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: GestureDetector(
        onPanStart: (_) => moving = true,
        onPanEnd: (_) => setState(() => moving = false),
        onPanUpdate: (d) => setState(() {
          yaw += d.delta.dx * .01;
          pitch = (pitch - d.delta.dy * .01).clamp(-1.2, 1.2);
        }),
        child: m == null
            ? const ColoredBox(color: Color(0xff101d30))
            : CustomPaint(
                key: const ValueKey('live-3d'),
                size: Size.infinite,
                painter: ModelPainter(m, yaw, pitch, 1, 0, 'all', false,
                    moving: moving)),
      ),
    );
  }
}

class View3D extends StatefulWidget {
  final DMap drawing, recipe;
  final DMap? calculation;
  final bool returnToEditor;

  /// The workshop's Claude key, for finding the opening on a photo.
  final String aiKey;
  const View3D(
      {super.key,
      required this.drawing,
      required this.recipe,
      this.calculation,
      this.returnToEditor = false,
      this.aiKey = ''});
  @override
  State<View3D> createState() => _View3DState();
}

class _View3DState extends State<View3D> with TickerProviderStateMixin {
  late final WindowModel model;
  late final AnimationController animation, explode;
  DMap? bill;
  String? calculationError;
  double yaw = -.35, pitch = .15, zoom = 1, initialZoom = 1;
  Offset? last;
  String active = 'all';
  String? selectedPart, selectedMaterial;
  bool mechanism = false;
  bool wires = false,
      explodeMode = false,
      labels = false,
      isolate = false,
      focused = false,
      spinning = false,
      dragging = false;
  late final AnimationController camera;
  late final Ticker spin;
  Duration? lastSpin;
  double fromYaw = 0, fromPitch = 0, fromZoom = 1;
  double toYaw = 0, toPitch = 0, toZoom = 1;

  Size canvasSize = Size.zero;
  final shotKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    model = WindowModel(widget.drawing, widget.recipe);
    camera = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550))
      ..addListener(() {
        final t = Curves.easeInOut.transform(camera.value);
        setState(() {
          yaw = fromYaw + (toYaw - fromYaw) * t;
          pitch = fromPitch + (toPitch - fromPitch) * t;
          zoom = fromZoom + (toZoom - fromZoom) * t;
        });
      });
    spin = createTicker((elapsed) {
      final dt =
          lastSpin == null ? 0.0 : (elapsed - lastSpin!).inMicroseconds / 1e6;
      lastSpin = elapsed;
      setState(() => yaw += dt * .45);
    });
    animation = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..addListener(redraw);
    explode = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..addListener(redraw);
    try {
      bill = widget.calculation ??
          calculateDrawing({
            'drawing': widget.drawing,
            'recipe': widget.recipe,
            'quantity': 1
          }, {
            'name': 'Joriy chizma'
          });
    } catch (e) {
      calculationError = '$e';
    }
  }

  void redraw() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    animation.dispose();
    explode.dispose();
    camera.dispose();
    spin.dispose();
    super.dispose();
  }

  /// Smoothly moves the camera to a preset view.
  void look(double y, double p, [double z = 1]) {
    stopSpin();
    fromYaw = yaw;
    fromPitch = pitch;
    fromZoom = zoom;
    toYaw = y;
    toPitch = p;
    toZoom = z;
    setState(() => focused = false);
    camera.forward(from: 0);
  }

  void toggleSpin() => setState(() {
        spinning = !spinning;
        if (spinning) {
          lastSpin = null;
          spin.start();
        } else {
          spin.stop();
        }
      });

  void stopSpin() {
    if (!spinning) return;
    spin.stop();
    spinning = false;
  }

  /// The opening sash a 3D part moves with, if any.
  String? sashOf(String? partId) {
    final group = model.parts[partId]?.group;
    if (group == null) return null;
    if (model.groups.containsKey(group)) return group;
    return model.motions[group]?.ownerId;
  }

  void toggleSash(String group) {
    if (explodeMode) switchMode(false);
    setState(() => active = group);
    animation.animateTo(animation.value > .5 ? 0 : 1);
  }

  Future<void> shareImage() async {
    try {
      final boundary =
          shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return;
      final note = await shareFile(
          'RomFlow-3D-${DateTime.now().millisecondsSinceEpoch}.png',
          'image/png',
          data.buffer.asUint8List(),
          text: 'RomFlow • 3D ko‘rinish');
      if (note != null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(note)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rasmni ulashib bo‘lmadi: $e')));
      }
    }
  }

  DMap? get selectedLine {
    if (bill == null || selectedMaterial == null) return null;
    for (final item in bill!['parts'] as List) {
      if (item['key'] == selectedMaterial) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  void selectPart(String? id) {
    setState(() {
      focused = false;
      selectedPart = id;
      selectedMaterial = model.parts[id]?.materialKey;
    });
  }

  Future<void> componentList() async {
    final id = await showGlassSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(c).height * .75,
                child: ListView(children: [
                  const ListTile(title: Text('3D detallar • alohida ko‘rish')),
                  for (final p in model.parts.values)
                    ListTile(
                        title: Text(p.title),
                        subtitle: Text(
                            '${materialNames[p.materialKey] ?? p.materialKey} · ${p.extent.x.round()} × ${p.extent.y.round()} × ${p.extent.z.round()} mm'),
                        trailing: const Icon(Icons.zoom_in),
                        onTap: () => Navigator.pop(c, p.id))
                ]))));
    if (id == null || !mounted) return;
    setState(() {
      selectedPart = id;
      selectedMaterial = model.parts[id]?.materialKey;
      focused = true;
      mechanism = false;
      isolate = false;
      zoom = 1;
    });
  }

  void switchMode(bool value) {
    animation.stop();
    explode.stop();
    // Back on the opening view the parts are put together again; they used
    // to stay spread out while the sashes opened.
    if (!value && explode.value > 0) {
      explode.animateTo(0, duration: const Duration(milliseconds: 450));
    }
    setState(() => explodeMode = value);
  }

  void togglePlayback() {
    final controller = explodeMode ? explode : animation;
    if (controller.isAnimating) {
      controller.stop();
    } else {
      controller.repeat(reverse: true);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = explodeMode ? explode : animation,
        part = model.parts[selectedPart],
        line = selectedLine;
    final renderer = ModelPainter(model, yaw, pitch, zoom,
        Curves.easeInOut.transform(animation.value), active, wires,
        explosion: Curves.easeInOut.transform(explode.value),
        selectedPart: selectedPart,
        selectedMaterial: selectedMaterial,
        labels: labels && explodeMode,
        mechanism: mechanism,
        isolate: isolate,
        moving: dragging || spinning,
        rightInset: 50,
        focusPart: focused ? selectedPart : null);
    return Theme(
        data: romFlowTheme(Brightness.dark),
        child: Scaffold(
            backgroundColor: const Color(0xff101d30),
            appBar: GlassAppBar(
                backgroundColor: const Color(0xff101d30),
                foregroundColor: Colors.white,
                glassBrightness: Brightness.dark,
                title: Text(explodeMode ? 'Detallar' : '3D'),
                actions: [
                  IconButton(
                      tooltip: 'Detallar',
                      icon: const Icon(Icons.list_alt),
                      onPressed: componentList),
                  if (widget.returnToEditor)
                    IconButton(
                        tooltip: 'Chizmani qo‘lda o‘zgartirish',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.edit_outlined)),
                  IconButton(
                      tooltip: 'Rasmini ulashish',
                      onPressed: shareImage,
                      icon: const Icon(Icons.ios_share)),
                  IconButton(
                      tooltip: 'Materiallar tarkibi',
                      onPressed: inventory,
                      icon: const Icon(Icons.inventory_2_outlined)),
                ]),
            body: SafeArea(
                child: Column(children: [
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Row(children: [
                    tool(
                        const ValueKey('mode-open'),
                        Icons.sensor_door_outlined,
                        'Ochilish',
                        !explodeMode,
                        () => switchMode(false)),
                    tool(
                        const ValueKey('mode-explode'),
                        Icons.dashboard_customize_outlined,
                        'Sochish / yig‘ish',
                        explodeMode, () {
                      switchMode(true);
                      if (explode.value == 0) explode.forward();
                    }),
                    tool(
                        const ValueKey('mode-mechanism'),
                        Icons.settings_suggest_outlined,
                        'Mexanizm',
                        mechanism,
                        () => setState(() {
                              mechanism = !mechanism;
                              focused = false;
                              selectedPart = null;
                              selectedMaterial = null;
                              zoom = 1;
                            })),
                    tool(
                        const ValueKey('profile-sections'),
                        Icons.view_column_outlined,
                        'Kesimlar',
                        false,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ProfileSections(
                                    drawing: widget.drawing,
                                    recipe: widget.recipe)))),
                    // On a photo or the live camera of the real opening, in
                    // place of a drawn wall.
                    tool(
                        const ValueKey('in-place'),
                        Icons.add_a_photo_outlined,
                        'Joyida',
                        false,
                        () => openInPlace(context,
                            drawing: widget.drawing,
                            recipe: widget.recipe,
                            aiKey: widget.aiKey)),
                    tool(const ValueKey('mode-spin'), Icons.threesixty,
                        'Aylanish', spinning, toggleSpin),
                    tool(
                        const ValueKey('mode-wires'),
                        Icons.polyline_outlined,
                        'Qirralar',
                        wires,
                        () => setState(() => wires = !wires)),
                  ])),
              Expanded(
                  child: Stack(children: [
                Positioned.fill(
                    child: RepaintBoundary(
                        key: shotKey,
                        child: LayoutBuilder(builder: (context, cs) {
                          canvasSize = Size(cs.maxWidth, cs.maxHeight);
                          return GestureDetector(
                            onTapUp: (d) => selectPart(
                                renderer.pick(d.localPosition, canvasSize)),
                            onScaleStart: (d) {
                              stopSpin();
                              camera.stop();
                              last = d.focalPoint;
                              initialZoom = zoom;
                              dragging = true;
                            },
                            onScaleEnd: (_) => setState(() => dragging = false),
                            onScaleUpdate: (d) {
                              setState(() {
                                if (d.pointerCount > 1) {
                                  zoom = (initialZoom * d.scale).clamp(.45, 12);
                                } else {
                                  final delta =
                                      d.focalPoint - (last ?? d.focalPoint);
                                  yaw += delta.dx * .008;
                                  pitch -= delta.dy * .008;
                                }
                                last = d.focalPoint;
                              });
                            },
                            child: CustomPaint(
                                size: Size.infinite, painter: renderer),
                          );
                        }))),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Column(children: [
                    for (final (key, icon, tip, y, p) in const [
                      ('view-front', Icons.crop_portrait, 'Old', 0.0, 0.0),
                      ('view-left', Icons.rotate_left, 'Chap', -1.05, .08),
                      ('view-right', Icons.rotate_right, 'O‘ng', 1.05, .08),
                      ('view-top', Icons.vertical_align_top, 'Tepa', -.2, -.95),
                      ('view-iso', Icons.view_in_ar, '3D', -.35, .15),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: usesIOSGlass
                            ? GlassIconButton(
                                key: ValueKey(key),
                                icon: icon,
                                tooltip: tip,
                                onPressed: () => look(y, p),
                                size: 40,
                                brightness: Brightness.dark)
                            : IconButton(
                                key: ValueKey(key),
                                tooltip: tip,
                                onPressed: () => look(y, p),
                                style: IconButton.styleFrom(
                                    backgroundColor: Colors.black26,
                                    minimumSize: const Size(38, 38),
                                    padding: EdgeInsets.zero),
                                icon: Icon(icon,
                                    size: 19, color: Colors.white70)),
                      ),
                  ]),
                ),
              ])),
              if (selectedMaterial != null)
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                    color: const Color(0xff203951),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(
                                    part?.title ??
                                        materialNames[selectedMaterial] ??
                                        'Yordamchi 3D detal',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                if (part != null)
                                  Text(
                                      '3D gabarit: ${part.extent.x.toStringAsFixed(0)} × ${part.extent.y.toStringAsFixed(0)} × ${part.extent.z.toStringAsFixed(0)} mm',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11)),
                                if (line != null) ...[
                                  Text(
                                      '${bill!['quantity']} ta konstruksiya: sof ${(line['net'] as num).toStringAsFixed(3)} ${line['unit']} · xarid ${(line['quantity'] as num).toStringAsFixed(3)} ${line['unit']}',
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12)),
                                  Text(
                                      (line['price'] as num? ?? 0) <= 0
                                          ? 'Narx kiritilmagan — katalogda belgilang'
                                          : 'Xarid summasi: ${money(line['cost'])}',
                                      style: const TextStyle(
                                          color: Colors.lightBlueAccent,
                                          fontSize: 12)),
                                ] else
                                  const Text(
                                      'Ko‘rgazmali detal; alohida sarf qatori yo‘q.',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 11)),
                              ])),
                          if (sashOf(selectedPart) != null)
                            IconButton(
                                tooltip: 'Shu qanotni ochish / yopish',
                                onPressed: () =>
                                    toggleSash(sashOf(selectedPart)!),
                                icon: const Icon(Icons.door_sliding_outlined,
                                    color: Colors.white70)),
                          if (part != null)
                            IconButton(
                                tooltip: 'Detalni alohida ko‘rish',
                                onPressed: () => setState(() {
                                      focused = !focused;
                                      zoom = 1;
                                    }),
                                icon: Icon(Icons.center_focus_strong,
                                    color: focused
                                        ? Colors.lightBlueAccent
                                        : Colors.white70)),
                          IconButton(
                              tooltip: 'Tanlovni olish',
                              onPressed: () => setState(() {
                                    selectedPart = null;
                                    focused = false;
                                    selectedMaterial = null;
                                    isolate = false;
                                  }),
                              icon: const Icon(Icons.close,
                                  color: Colors.white70))
                        ])),
              glassPanel(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  IconButton(
                      tooltip: controller.isAnimating
                          ? 'To‘xtatish'
                          : explodeMode
                              ? 'Sochish / yig‘ish animatsiyasi'
                              : 'Ochish / yopish',
                      onPressed: !explodeMode && model.groups.isEmpty
                          ? null
                          : togglePlayback,
                      icon: Icon(
                          controller.isAnimating
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.lightBlueAccent,
                          size: 38)),
                  Expanded(
                      child: Slider(
                          key: ValueKey(explodeMode
                              ? 'explode-slider'
                              : 'opening-slider'),
                          value: controller.value,
                          onChanged: !explodeMode && model.groups.isEmpty
                              ? null
                              : (v) {
                                  controller.stop();
                                  controller.value = v;
                                })),
                  if (explodeMode) ...[
                    tool(
                        const ValueKey('explode-labels'),
                        Icons.tag,
                        'Raqamlar',
                        labels,
                        () => setState(() => labels = !labels)),
                    tool(
                        const ValueKey('explode-isolate'),
                        Icons.filter_center_focus,
                        'Faqat tanlangan',
                        isolate,
                        selectedMaterial == null
                            ? null
                            : () => setState(() => isolate = !isolate)),
                  ],
                ]),
                if (calculationError != null)
                  Text('Hisob uchun me’yorni tekshiring: $calculationError',
                      maxLines: 2,
                      style: const TextStyle(
                          color: Colors.orangeAccent, fontSize: 11)),
              ])),
            ]))));
  }

  /// A round icon with its name as a tooltip, lit when [on].
  /// The play bar under the model: dark glass, or the plain dark panel.
  Widget glassPanel({required Widget child}) {
    const radius = BorderRadius.vertical(top: Radius.circular(18));
    const padding = EdgeInsets.fromLTRB(8, 4, 12, 8);
    return usesIOSGlass
        ? GlassSurface(
            radius: radius,
            brightness: Brightness.dark,
            shadow: false,
            child: Padding(padding: padding, child: child))
        : Container(
            padding: padding,
            decoration: const BoxDecoration(
                color: Color(0xff16263a), borderRadius: radius),
            child: child);
  }

  Widget tool(
          Key key, IconData icon, String name, bool on, VoidCallback? onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: usesIOSGlass
            ? GlassIconButton(
                key: key,
                icon: icon,
                tooltip: name,
                selected: on,
                onPressed: onTap,
                size: 42,
                brightness: Brightness.dark)
            : IconButton(
                key: key,
                tooltip: name,
                isSelected: on,
                onPressed: onTap,
                style: IconButton.styleFrom(
                    backgroundColor: on
                        ? const Color(0xff2f7fd8)
                        : Colors.white.withValues(alpha: .08),
                    minimumSize: const Size(42, 42)),
                icon: Icon(icon,
                    size: 21, color: on ? Colors.white : Colors.white70),
              ),
      );

  Future<void> inventory() async {
    await showGlassSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        builder: (context) => SafeArea(
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .78,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                          'Ichida nima bor? • ${bill?['quantity'] ?? 1} ta konstruksiya',
                          style: const TextStyle(
                              fontSize: 19, fontWeight: FontWeight.bold))),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                          'Sof sarf → butun tayoq/list bilan xarid. Materialni tanlab 3D’da ajrating.')),
                  if (bill == null)
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(calculationError ?? 'Hisob yo‘q'))
                  else
                    Expanded(
                        child: ListView(children: [
                      for (final raw in bill!['parts'] as List)
                        Builder(builder: (context) {
                          final p = Map<String, dynamic>.from(raw),
                              key = p['key'] as String;
                          final visible = model.parts.values
                              .any((part) => part.materialKey == key);
                          return ListTile(
                              leading: Icon(
                                  visible
                                      ? Icons.view_in_ar
                                      : Icons.receipt_long,
                                  color: const Color(0xff206bc4)),
                              title: Text(p['name']),
                              subtitle: Text(
                                  '${(p['net'] as num).toStringAsFixed(3)} → ${(p['quantity'] as num).toStringAsFixed(3)} ${p['unit']}\n${visible ? '3D’da ko‘rsatish' : 'Hisobda bor; 3D shakli modellashtirilmagan'}'),
                              trailing: Text(money(p['cost'])),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  selectedMaterial = key;
                                  selectedPart = null;
                                  focused = false;
                                  isolate = false;
                                });
                              });
                        })
                    ])),
                ]))));
  }
}

/// Short pieces of each profile, cut square, so their sections can be
/// compared with the real bars.
class ProfileSections extends StatefulWidget {
  final DMap drawing, recipe;
  const ProfileSections(
      {super.key, required this.drawing, required this.recipe});
  @override
  State<ProfileSections> createState() => _ProfileSectionsState();
}

class _ProfileSectionsState extends State<ProfileSections> {
  static const _view = (yaw: .35, pitch: 1.05);
  // The connector is seen from above, its V up as in the workshop photo.
  static const _cornerView = (yaw: 2.2, pitch: 1.3);
  double yaw = _view.yaw, pitch = _view.pitch;
  int index = 0;

  void show(int i) => setState(() {
        index = i;
        final view = pieces[i].$1.startsWith('Qayt') ? _cornerView : _view;
        yaw = view.yaw;
        pitch = view.pitch;
      });

  /// One short square-cut piece per profile: name, size and its model.
  late final List<(String, String, WindowModel)> pieces = () {
    final r = widget.recipe, out = <(String, String, WindowModel)>[];
    double v(String k, double fallback) =>
        (r[k] as num?)?.toDouble() ?? fallback;
    String mm(double v) =>
        v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    // A sawn end shows bare aluminium whatever the coating, as in the
    // workshop photos; light metal also keeps dark finishes readable.
    const color = Color(0xffc5ccd4);
    WindowModel empty() => WindowModel(widget.drawing, r)
      ..faces.clear()
      ..parts.clear()
      ..wallFaces.clear()
      ..groups.clear()
      ..motions.clear();
    for (final (key, name, face, depth) in [
      ('frame', 'Kosa', v('frameFace', 50), v('frameDepth', 60)),
      ('sash', 'Qanot', v('sashFace', 50), v('sashDepth', 65)),
      ('mullion', 'Orta', v('mullionFace', 50), v('frameDepth', 60)),
      ('bead', 'Shtapik', v('beadFaceMm', 18), v('beadDepthMm', 16)),
    ]) {
      final m = empty()..material(key);
      m.profileBar([V(0, 0), V(0, 90), V(face, 90), V(face, 0)], face, depth, 0,
          color, null);
      out.add((name, '${mm(face)} × ${mm(depth)} mm', m));
    }
    final m = empty();
    if (m.simpleAluminium) {
      m.cornerJoint('left', color, height: 36);
      out.add(('Qayt 90°', 'burchak ulash', m));
    }
    return out;
  }();

  @override
  Widget build(BuildContext context) {
    final (_, size, model) = pieces[index];
    return Scaffold(
      backgroundColor: const Color(0xff101d30),
      appBar: GlassAppBar(
          backgroundColor: const Color(0xff101d30),
          foregroundColor: Colors.white,
          glassBrightness: Brightness.dark,
          title: const Text('Profil kesimlari')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < pieces.length; i++)
                ChoiceChip(
                    label: Text(pieces[i].$1),
                    selected: index == i,
                    onSelected: (_) => show(i)),
            ]),
          ),
          Expanded(
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                yaw += d.delta.dx * .01;
                pitch = (pitch - d.delta.dy * .01).clamp(-1.5, 1.5);
              }),
              child: CustomPaint(
                  key: const ValueKey('profile-sections-canvas'),
                  size: Size.infinite,
                  painter: ModelPainter(model, yaw, pitch, .8, 0, 'all', true)),
            ),
          ),
          Text(size,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Text(
                'Yuz eni × chuqurlik. Barmoq bilan aylantiring. O‘lchamlar “Materiallar va narxlar”da o‘zgaradi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ),
        ]),
      ),
    );
  }
}

class _ProjectedFace {
  final List<Offset> p;

  /// [light] scales the colour; [spec] is the highlight towards white;
  /// [fresnel] how much a glass face reflects (more at a slant).
  final double depth, light, spec, fresnel;
  final ModelFace face;
  _ProjectedFace(this.p, this.depth, this.light, this.face,
      {this.spec = 0, this.fresnel = 0});
  Path get path {
    final result = Path()..moveTo(p.first.dx, p.first.dy);
    for (final v in p.skip(1)) {
      result.lineTo(v.dx, v.dy);
    }
    return result..close();
  }
}

class ModelPainter extends CustomPainter {
  final WindowModel model;
  final double yaw, pitch, zoom, progress, explosion;
  final String active;
  final bool wires, labels, isolate, mechanism, wall;

  /// While a finger turns the model: tiny details are left out so every
  /// frame stays quick.
  final bool moving;

  /// Room kept free on the right for buttons over the picture.
  final double rightInset;
  final String? selectedPart, selectedMaterial, focusPart;
  ModelPainter(this.model, this.yaw, this.pitch, this.zoom, this.progress,
      this.active, this.wires,
      {this.explosion = 0,
      this.selectedPart,
      this.selectedMaterial,
      this.focusPart,
      this.labels = false,
      this.isolate = false,
      this.mechanism = false,
      this.wall = false,
      this.moving = false,
      this.rightInset = 0});
  P3 rotate(P3 p) {
    final x = p.x * _cy + p.z * _sy, z = -p.x * _sy + p.z * _cy;
    return P3(x, p.y * _cp - z * _sp, p.y * _sp + z * _cp);
  }

  P3 world(P3 p, String? groupId, ModelPart? part) {
    final group = model.groups[groupId], w = _w, h = _h;
    final motion = model.motions[groupId];
    final moved = motion != null
        ? motion.transform(
            p, active == 'all' || active == motion.ownerId ? progress : 0)
        : group == null
            ? p
            : group.transform(
                p, active == 'all' || active == groupId ? progress : 0);
    return moved +
        (part?.explosionOffset(explosion, math.max(w, h), w, h) ??
            const P3(0, 0, 0));
  }

  late final P3 _center = () {
    final focus = model.parts[focusPart];
    return focus == null
        ? P3((model.drawing['widthMm'] as num).toDouble() / 2,
            (model.drawing['heightMm'] as num).toDouble() / 2, 30)
        : world(focus.center, focus.group, focus);
  }();
  late final double _cy = math.cos(yaw),
      _sy = math.sin(yaw),
      _cp = math.cos(pitch),
      _sp = math.sin(pitch);
  late final double _w = (model.drawing['widthMm'] as num).toDouble(),
      _h = (model.drawing['heightMm'] as num).toDouble();

  P3 positioned(P3 p, String? groupId, ModelPart? part) =>
      rotate(world(p, groupId, part) - _center);

  late final List<(ModelFace, List<P3>)> transformed = () {
    final key = '$progress|$explosion|$active|$mechanism|$focusPart|'
        '$isolate|$selectedMaterial|$wall|$moving';
    var placed = model.world;
    if (model.worldKey != key || placed == null) {
      placed = [
        if (wall && !mechanism && focusPart == null && explosion < .05)
          for (final face in model.wallFaces) (face, face.vertices),
        for (final face in model.faces)
          if (_shown(face))
            (
              face,
              [
                for (final p in face.vertices)
                  world(p, face.group, model.parts[face.partId])
              ]
            )
      ];
      model
        ..world = placed
        ..worldKey = key;
    }
    final c = _center;
    return [
      for (final (face, points) in placed)
        (face, [for (final p in points) rotate(p - c)])
    ];
  }();

  bool _shown(ModelFace face) {
    final key = model.parts[face.partId]?.materialKey;
    if (mechanism && !_mechanismKeys.contains(key)) return false;
    if (focusPart != null && face.partId != focusPart) return false;
    if (_hiddenInside(key)) return false;
    if (isolate && selectedMaterial != null && key != selectedMaterial) {
      return false;
    }
    // Screws and caps are a few pixels across; they come back at rest.
    if (moving &&
        focusPart == null &&
        (key == 'screw' || key == 'decoration')) {
      return false;
    }
    return true;
  }

  static const _mechanismKeys = {
    'handle',
    'doorHandle',
    'windowLock',
    'doorLock',
    'cylinder',
    'hinge',
    'doorHinge',
    'passiveBolt',
    'roller',
    'slideLock',
    'closer',
    'screw'
  };

  /// How strongly and how tightly each material shines: polished metal
  /// fittings most, aluminium and PVC profiles a soft sheen, rubber none.
  static const _shine = <String, (double, double)>{
    'handle': (.6, 30),
    'doorHandle': (.6, 30),
    'cylinder': (.6, 30),
    'hinge': (.45, 22),
    'doorHinge': (.45, 22),
    'windowLock': (.42, 20),
    'doorLock': (.42, 20),
    'passiveBolt': (.42, 20),
    'roller': (.4, 20),
    'slideLock': (.4, 20),
    'closer': (.35, 16),
    'screw': (.5, 24),
    'threshold': (.38, 16),
    'frame': (.26, 14),
    'sash': (.26, 14),
    'mullion': (.26, 14),
    'sashMullion': (.26, 14),
    'cornerProfile': (.26, 14),
    'bead': (.2, 12),
    'corner': (.3, 16),
    'mullionJoint': (.3, 16),
    'panel': (.12, 10),
    'lambris': (.08, 8),
    'uGasket': (.03, 6),
    'sealInner': (.03, 6),
    'sealOuter': (.03, 6),
  };

  Size? projectionSize;
  double fitScale = 1, fitX = 0, fitY = 0;
  void fit(Size size) {
    if (projectionSize == size) return;
    projectionSize = size;
    final w = (model.drawing['widthMm'] as num).toDouble(),
        h = (model.drawing['heightMm'] as num).toDouble(),
        camera = math.max(w, h) * 3.3;
    var minX = double.infinity,
        minY = double.infinity,
        maxX = double.negativeInfinity,
        maxY = double.negativeInfinity;
    for (final entry in transformed) {
      for (final p in entry.$2) {
        if (camera - p.z <= math.max(w, h) * .15) continue;
        final x = p.x * camera / (camera - p.z),
            y = p.y * camera / (camera - p.z);
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
    if (!minX.isFinite) {
      minX = -w / 2;
      maxX = w / 2;
      minY = -h / 2;
      maxY = h / 2;
    }
    fitX = (minX + maxX) / 2;
    fitY = (minY + maxY) / 2;
    fitScale = math.min(
            (size.width - 50 - rightInset) / math.max(1, maxX - minX),
            (size.height - 50) / math.max(1, maxY - minY)) *
        zoom;
  }

  late final double _camera = math.max(_w, _h) * 3.3;
  Offset project(P3 p, Size size) {
    fit(size);
    final camera = _camera;
    return Offset(
        (size.width - rightInset) / 2 +
            (p.x * camera / (camera - p.z) - fitX) * fitScale,
        size.height / 2 + (p.y * camera / (camera - p.z) - fitY) * fitScale);
  }

  static P3 _unit(P3 p) => p * (1 / p.length);

  /// A key light from the upper left, a weaker fill from the right, and the
  /// half-way vector for the highlight seen from the camera.
  static final _key = _unit(const P3(-.38, -.55, .74)),
      _fill = _unit(const P3(.62, -.18, .5)),
      _half = _unit(_key + const P3(0, 0, 1));

  /// Corner and impost connectors sit inside the profile chambers: show them
  /// only when the model is taken apart or the part is asked for.
  bool _hiddenInside(String? key) =>
      (key == 'corner' || key == 'mullionJoint') &&
      explosion < .05 &&
      focusPart == null &&
      selectedMaterial != key;

  List<_ProjectedFace> _scene(Size size) {
    final result = <_ProjectedFace>[],
        span = math.max((model.drawing['widthMm'] as num).toDouble(),
            (model.drawing['heightMm'] as num).toDouble());
    for (final entry in transformed) {
      final face = entry.$1, points = entry.$2;
      if (points.any((p) => span * 3.3 - p.z <= span * .15)) continue;
      final screen = [for (final p in points) project(p, size)];
      if (face.closed) {
        // Closed solids are wound consistently: a face turned away from
        // the camera is hidden behind the solid's own front faces.
        double area = 0;
        for (var j = 0; j < screen.length; j++) {
          final a = screen[j], b = screen[(j + 1) % screen.length];
          area += a.dx * b.dy - a.dy * b.dx;
        }
        if (area <= 0) continue;
      }
      if (moving && screen.length > 2) {
        // Faces smaller than a pixel are not worth a triangle mid-turn.
        double area = 0;
        for (var j = 0; j < screen.length; j++) {
          final a = screen[j], b = screen[(j + 1) % screen.length];
          area += a.dx * b.dy - a.dy * b.dx;
        }
        if (area.abs() < 1.2) continue;
      }
      final normal = (points[1] - points[0]).cross(points[2] - points[0]),
          length = normal.length;
      var light = .78, spec = 0.0, fresnel = .3;
      if (length > .001) {
        final n = normal * (1 / length);
        light = .3 + .62 * n.dot(_key).abs() + .2 * n.dot(_fill).abs();
        final (strength, power) =
            _shine[model.parts[face.partId]?.materialKey] ?? (.14, 10.0);
        spec = face.glass
            ? .5 * math.pow(n.dot(_half).abs(), 40).toDouble()
            : strength * math.pow(n.dot(_half).abs(), power).toDouble();
        final facing = 1 - n.z.abs();
        fresnel = facing * facing;
      }
      result.add(_ProjectedFace(
          screen,
          points.fold<double>(0, (s, p) => s + p.z) / points.length,
          light,
          face,
          spec: spec,
          fresnel: fresnel));
    }
    result.sort((a, b) => a.depth.compareTo(b.depth));
    return result;
  }

  String? pick(Offset tap, Size size) {
    for (final face in _scene(size).reversed) {
      if (face.path.contains(tap)) return face.face.partId;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true,
        background = Rect.fromLTWH(0, 0, size.width, size.height);
    // A studio backdrop: lit from above, falling off to the corners.
    canvas.drawRect(
        background,
        paint
          ..shader = const RadialGradient(colors: [
            Color(0xff3a6286),
            Color(0xff1a2d44),
            Color(0xff0b1420)
          ], stops: [
            0,
            .55,
            1
          ], radius: 1.05, center: Alignment(0, -.4))
              .createShader(background));
    paint.shader = null;
    final projected = _scene(size);
    if (projected.isNotEmpty && focusPart == null) {
      // A soft contact shadow right under the construction.
      var minX = double.infinity, maxX = -double.infinity, maxY = 0.0;
      for (final f in projected) {
        for (final v in f.p) {
          if (v.dx < minX) minX = v.dx;
          if (v.dx > maxX) maxX = v.dx;
          if (v.dy > maxY) maxY = v.dy;
        }
      }
      final width = (maxX - minX).clamp(40.0, size.width);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(
                  (minX + maxX) / 2, math.min(maxY + 10, size.height - 8)),
              width: width * .92,
              height: math.max(12, width * .07)),
          paint
            ..color = Colors.black.withValues(alpha: .42)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11));
      paint.maskFilter = null;
    }
    // Faces are drawn back to front as batched triangles; one draw call per
    // batch instead of one path per face keeps phones responsive.
    final positions = <Offset>[], colors = <Color>[], indices = <int>[];
    final triangles = Paint();
    void flush() {
      if (positions.isEmpty) return;
      canvas.drawVertices(
          ui.Vertices(ui.VertexMode.triangles, positions,
              colors: colors, indices: indices),
          BlendMode.dst,
          triangles);
      positions.clear();
      colors.clear();
      indices.clear();
    }

    // Lit colour, then the highlight mixed in towards white.
    Color shade(Color color, double light, double spec, double scale) {
      int channel(double c) {
        final lit = c * light * scale;
        return (255 * (lit + (1 - lit).clamp(0.0, 1.0) * spec))
            .round()
            .clamp(0, 255);
      }

      return Color.fromARGB((color.a * 255).round(), channel(color.r),
          channel(color.g), channel(color.b));
    }

    const sky = Color(0xffe3f0fb);
    // Two soft diagonal reflections across a big pane facing the camera;
    // they slide over the glass as the model turns, like real ones.
    final streak = Paint()..isAntiAlias = true;
    void streaks(_ProjectedFace f) {
      if (f.fresnel > .5) return;
      final box = f.path.getBounds();
      if (box.width < 26 || box.height < 26) return;
      flush();
      canvas.save();
      canvas.clipPath(f.path);
      final d = box.shortestSide;
      for (final (at, wide, alpha) in const [
        (.32, .16, .13),
        (.5, .06, .1),
      ]) {
        final x = box.left + box.width * at;
        canvas.drawPath(
            Path()
              ..moveTo(x - d * .55, box.bottom)
              ..lineTo(x - d * .55 + d * wide, box.bottom)
              ..lineTo(x + d * .55 + d * wide, box.top)
              ..lineTo(x + d * .55, box.top)
              ..close(),
            streak
              ..shader = LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: alpha),
                    Colors.white.withValues(alpha: alpha * .4),
                  ]).createShader(box));
      }
      canvas.restore();
    }

    for (final f in projected) {
      final part = model.parts[f.face.partId];
      final selected = selectedPart != null
          ? f.face.partId == selectedPart
          : selectedMaterial != null && part?.materialKey == selectedMaterial;
      final color = selected && focusPart == null
          ? Color.lerp(f.face.color, Colors.lightBlueAccent, .25)!
          : f.face.color;
      if (positions.length + f.p.length > 60000) flush();
      final base = positions.length;
      positions.addAll(f.p);
      for (final v in f.p) {
        // Studio light: brightest at the upper left, falling off softly
        // towards the floor and the right.
        final up = (1 - v.dy / size.height).clamp(0.0, 1.0),
            left = (1 - v.dx / size.width).clamp(0.0, 1.0);
        if (f.face.glass) {
          // Glass mirrors the sky: more at a slant and higher up.
          final base = shade(color, f.light, f.spec, 1),
              mirror =
                  ((.16 + .62 * f.fresnel) * (.5 + .5 * up)).clamp(0.0, .85);
          final mixed = Color.lerp(base, sky, mirror)!;
          colors.add(mixed.withValues(
              alpha: (base.a + mirror * .55 + f.spec * .4).clamp(0.0, .92)));
        } else {
          colors
              .add(shade(color, f.light, f.spec, .86 + .16 * up + .08 * left));
        }
      }
      for (var j = 1; j < f.p.length - 1; j++) {
        indices
          ..add(base)
          ..add(base + j)
          ..add(base + j + 1);
      }
      if (f.face.glass && !moving) streaks(f);
      if (wires || selected) {
        flush();
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1 : .7
          ..color = selected
              ? Colors.lightBlueAccent
              : Colors.black.withValues(alpha: .3);
        canvas.drawPath(f.path, paint);
      }
    }
    flush();
    var count = 0;
    final visibleIds = transformed.map((f) => f.$1.partId).toSet();
    for (final part in model.parts.values) {
      if (!visibleIds.contains(part.id)) continue;
      final selected = selectedPart == part.id;
      if (!selected &&
          (!labels ||
              explosion < .1 ||
              count >= 28 ||
              part.materialKey == 'decoration' ||
              part.materialKey == 'screw' ||
              (selectedMaterial != null &&
                  part.materialKey != selectedMaterial))) {
        continue;
      }
      if (isolate &&
          selectedMaterial != null &&
          part.materialKey != selectedMaterial) {
        continue;
      }
      final at = project(positioned(part.center, part.group, part), size);
      if (at.dx < 10 ||
          at.dx > size.width - 10 ||
          at.dy < 10 ||
          at.dy > size.height - 10) {
        continue;
      }
      count++;
      final caption = selected ? '${part.id} · ${part.title}' : part.id;
      final text = TextPainter(
          text: TextSpan(
              text: caption,
              style: TextStyle(
                  fontSize: selected ? 11 : 9,
                  color: Colors.white,
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: size.width * .75);
      final box = Rect.fromLTWH(
          (at.dx + 9).clamp(2, size.width - text.width - 10),
          at.dy - 11,
          text.width + 10,
          text.height + 7);
      if (selected) {
        final original =
            project(positioned(part.center, part.group, null), size);
        canvas.drawLine(
            original,
            at,
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = Colors.lightBlueAccent.withValues(alpha: .6));
      }
      canvas.drawLine(
          at,
          Offset(box.left, box.center.dy),
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7
            ..color = Colors.white54);
      canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(5)),
          paint
            ..style = PaintingStyle.fill
            ..color =
                selected ? const Color(0xff1567ad) : const Color(0xdd172b43));
      text.paint(canvas, box.topLeft + const Offset(5, 3));
    }
  }

  @override
  bool shouldRepaint(covariant ModelPainter old) => true;
}
