/// FCM Rivals — the club's composed crest identity (T-0097).
///
/// A crest is a spec, not a bare palette index: shape + primary and
/// secondary colours + icon. The spec is immutable and serializes to
/// JSON for the `clubs.crest` column; [legacy] reproduces the old
/// single-colour crests for pre-T-0097 saves so every existing club
/// renders exactly as before.
library;

import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ui/fcm_style.dart' show FcmColors;

/// The crest's silhouette (GDD 3.4 'Crest') — ten shapes;
/// rendered symmetric so the same spec reads identically LTR/RTL.
enum CrestShape {
  /// Classic football shield — flat top, pointed bottom.
  shield('shield'),

  /// Perfect circle — the roundel.
  round('round'),

  /// Pennant flag — tall, swallow-tailed base.
  pennant('pennant'),

  /// Rhombus / diamond.
  diamond('diamond'),

  /// Round-bottomed heater shield — the "U" crest.
  heater('heater'),

  /// Pointy-top hexagon — the badge.
  hexagon('hexagon'),

  /// Rounded square — the tile.
  rounded('rounded'),

  /// Round-topped doorway arch.
  arch('arch'),

  /// Eight-sided stop-sign badge.
  octagon('octagon'),

  /// Tall kite with a high shoulder.
  kite('kite');

  const CrestShape(this.json);

  /// Stable JSON identifier — the wire format never breaks when the
  /// enum's Dart name changes.
  final String json;

  /// Parses the wire value; unknown values (a future shape on an
  /// older build) fall back to [shield] instead of crashing the UI.
  static CrestShape fromJson(String? json) => CrestShape.values
      .firstWhere((s) => s.json == json, orElse: () => CrestShape.shield);
}

/// The centered glyph on the crest's field — sixteen of them.
enum CrestIcon {
  star('star'),
  ball('ball'),
  crown('crown'),
  lion('lion'),
  flame('flame'),
  bolt('bolt'),
  sun('sun'),
  tower('tower'),
  sword('sword'),
  moon('moon'),
  heart('heart'),
  gem('gem'),
  mountain('mountain'),
  trophy('trophy'),
  paw('paw'),
  sparkle('sparkle');

  const CrestIcon(this.json);

  /// Stable JSON identifier, same contract as [CrestShape.json].
  final String json;

  static CrestIcon fromJson(String? json) => CrestIcon.values
      .firstWhere((i) => i.json == json, orElse: () => CrestIcon.star);
}

/// How the crest's field is divided between the primary and secondary
/// colours. Some patterns ([diagonal], [slashes], [split]) are
/// deliberately asymmetric; they still read the same LTR and RTL because
/// the painter never flips on text direction.
enum CrestPattern {
  /// Solid primary field.
  plain('plain'),

  /// A secondary band through the middle (the original T-0097 look).
  halves('halves'),

  /// Five vertical stripes, alternating.
  stripes('stripes'),

  /// Horizontal hoops.
  hoops('hoops'),

  /// A bold diagonal sash.
  diagonal('diagonal'),

  /// A downward chevron.
  chevron('chevron'),

  /// Four quarters, opposite corners matching.
  quarters('quarters'),

  /// Left and right halves.
  split('split'),

  /// Top and bottom halves.
  splitH('splitH'),

  /// A chequerboard.
  checker('checker'),

  /// Rays fanning out from the centre.
  sunburst('sunburst'),

  /// A field of dots.
  dots('dots'),

  /// Repeated diagonal slashes.
  slashes('slashes');

  const CrestPattern(this.json);

  /// Stable JSON identifier (identical to the Dart name for every value
  /// ever persisted, so old saves keep decoding).
  final String json;

  /// Unknown values fall back to [halves] — the only pattern pre-
  /// redesign saves carry.
  static CrestPattern fromJson(String? json) => CrestPattern.values
      .firstWhere((p) => p.json == json, orElse: () => CrestPattern.halves);
}

/// One composed crest: [shape] filled [pattern]-wise with the
/// [primaryIndex] colour, outlined in [secondaryIndex], [icon]
/// centered. Colour indices resolve through [FcmColors.crestPalette]
/// (clamped — a stale index from an older save can never crash).
class CrestSpec {
  const CrestSpec({
    required this.shape,
    required this.primaryIndex,
    required this.secondaryIndex,
    required this.icon,
    this.pattern = CrestPattern.halves,
  });

  final CrestShape shape;
  final int primaryIndex;
  final int secondaryIndex;
  final CrestIcon icon;
  final CrestPattern pattern;

  /// The resolved field colour for consumers like the momentum bar's
  /// user half tint — the exact same palette + clamp as today's
  /// `FcmColors.crestColor(crestIndex)`.
  Color get primaryColor => FcmColors.crestColor(primaryIndex);

  /// The resolved outline/glyph-accent colour.
  Color get secondaryColor => FcmColors.crestColor(secondaryIndex);

  /// JSON wire format for the `clubs.crest` column: flat, lowercase
  /// keys, round-trip safe with [fromJson] (a null or invalid payload
  /// returns null so the caller falls back to `crestIndex`).
  Map<String, Object?> toJson() => {
    'shape': shape.json,
    'primary': primaryIndex,
    'secondary': secondaryIndex,
    'icon': icon.json,
    'pattern': pattern.json,
  };

  /// Parses a stored spec; `null` for null/invalid input — the
  /// resolver's legacy fallback owns that case.
  static CrestSpec? fromJson(Map<String, Object?>? json) {
    if (json == null) return null;
    final primary = json['primary'];
    final secondary = json['secondary'];
    if (primary is! int || secondary is! int) return null;
    return CrestSpec(
      shape: CrestShape.fromJson(json['shape'] as String?),
      primaryIndex: primary,
      secondaryIndex: secondary,
      icon: CrestIcon.fromJson(json['icon'] as String?),
      pattern: CrestPattern.fromJson(json['pattern'] as String?),
    );
  }

  /// Convenience overload for the stored TEXT column — `null` for
  /// null/empty/invalid encoded payloads.
  static CrestSpec? fromJsonString(String? encoded) {
    if (encoded == null || encoded.isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return null;
      return fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// The encoded TEXT for the `clubs.crest` column.
  String encode() => jsonEncode(toJson());

  /// The old single-colour crest (pre-T-0097 saves, and the default
  /// when a caller passes no spec): shield + star, the field colour
  /// the palette entry `crestIndex` resolves to — the primary reads
  /// exactly like today's flat crest colour.
  factory CrestSpec.legacy(int crestIndex) => CrestSpec(
    shape: CrestShape.shield,
    primaryIndex: crestIndex,
    secondaryIndex: _legacySecondaryFor(crestIndex),
    icon: CrestIcon.star,
  );

  /// A companion for the legacy spec's outline: the palette wraps
  /// around so the outline stays in-family (index 2, ember charcoal,
  /// is already near-black and keeps itself).
  static int _legacySecondaryFor(int crestIndex) =>
      crestIndex == 2 ? 2 : (crestIndex + 2) % _legacyPaletteSize;

  /// The palette size when the legacy rule was written — the brand
  /// metals only; later colours were appended, never reordered.
  static const int _legacyPaletteSize = 6;

  /// A crest derived from a club NAME: for opponents that have no
  /// persisted spec — synthetic friendly squads. Hashes the name into
  /// every option the builder offers, so the same opponent always wears
  /// the same badge (across sessions and seeds) while different names
  /// spread across the catalogue. The secondary colour is the primary
  /// shifted by an odd offset inside the palette, which never lands on
  /// the same index — the contrast guard by construction.
  factory CrestSpec.derived(String name) {
    var hash = 0;
    for (final code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    if (hash == 0) hash = 1;
    final n = FcmColors.crestPalette.length;
    final primary = hash % n;
    // Odd offsets only: with the even palette size, an odd shift never
    // wraps back onto the primary itself.
    final secondary = (primary + 1 + (hash >> 8) % (n ~/ 2 - 1) * 2) % n;
    return CrestSpec(
      shape: CrestShape.values[(hash >> 4) % CrestShape.values.length],
      primaryIndex: primary,
      secondaryIndex: secondary,
      icon: CrestIcon.values[(hash >> 12) % CrestIcon.values.length],
      pattern: CrestPattern.values[(hash >> 16) % CrestPattern.values.length],
    );
  }

  /// A fresh, good-looking crest drawn from EVERY option the club
  /// builder offers (shape, pattern, both colours, icon). The one source
  /// of random crests: the builder's dice button and the AI league
  /// generator both call it, so AI clubs can only ever wear crests a
  /// player could have built. Deterministic for a seeded [random].
  ///
  /// The two colours are guaranteed distinct AND visibly different
  /// (a contrast guard), so no crest is a flat blob.
  factory CrestSpec.random(math.Random random) {
    final n = FcmColors.crestPalette.length;
    final primary = random.nextInt(n);
    var secondary = random.nextInt(n);
    for (var tries = 0;
        tries < 24 && !_distinct(primary, secondary);
        tries++) {
      secondary = random.nextInt(n);
    }
    if (!_distinct(primary, secondary)) {
      // Cannot happen with the shipped palette, but stay total.
      secondary = (primary + 1) % n;
    }
    return CrestSpec(
      shape: CrestShape.values[random.nextInt(CrestShape.values.length)],
      primaryIndex: primary,
      secondaryIndex: secondary,
      icon: CrestIcon.values[random.nextInt(CrestIcon.values.length)],
      pattern: CrestPattern.values[random.nextInt(CrestPattern.values.length)],
    );
  }

  /// Whether two palette entries are different enough to pair: not the
  /// same entry, and far enough apart in luminance or hue.
  static bool _distinct(int a, int b) {
    if (a == b) return false;
    final ca = FcmColors.crestColor(a);
    final cb = FcmColors.crestColor(b);
    final dl = (ca.computeLuminance() - cb.computeLuminance()).abs();
    if (dl >= 0.18) return true;
    final ha = HSVColor.fromColor(ca);
    final hb = HSVColor.fromColor(cb);
    final dh = (ha.hue - hb.hue).abs();
    return math.min(dh, 360 - dh) >= 40 && ha.saturation > 0.35 &&
        hb.saturation > 0.35;
  }

  /// Structural equality — specs are values, not identities.
  @override
  bool operator ==(Object other) =>
      other is CrestSpec &&
      other.shape == shape &&
      other.primaryIndex == primaryIndex &&
      other.secondaryIndex == secondaryIndex &&
      other.icon == icon &&
      other.pattern == pattern;

  @override
  int get hashCode =>
      Object.hash(shape, primaryIndex, secondaryIndex, icon, pattern);

  @override
  String toString() =>
      'CrestSpec(${shape.json}, p$primaryIndex, s$secondaryIndex, '
      '${icon.json})';
}
