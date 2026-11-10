/// FCM Rivals — the club's composed crest identity (T-0097).
///
/// A crest is a spec, not a bare palette index: shape + primary and
/// secondary colours + icon. The spec is immutable and serializes to
/// JSON for the `clubs.crest` column; [legacy] reproduces the old
/// single-colour crests for pre-T-0097 saves so every existing club
/// renders exactly as before.
library;

import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/material.dart';

import '../ui/fcm_style.dart' show FcmColors;

/// The crest's silhouette (GDD 3.4 'Crest') — at least four shapes;
/// rendered symmetric so the same spec reads identically LTR/RTL.
enum CrestShape {
  /// Classic football shield — flat top, pointed bottom.
  shield('shield'),

  /// Perfect circle — the roundel.
  round('round'),

  /// Pennant flag — tall, swallow-tailed base.
  pennant('pennant'),

  /// Rhombus / diamond.
  diamond('diamond');

  const CrestShape(this.json);

  /// Stable JSON identifier — the wire format never breaks when the
  /// enum's Dart name changes.
  final String json;

  /// Parses the wire value; unknown values (a future shape on an
  /// older build) fall back to [shield] instead of crashing the UI.
  static CrestShape fromJson(String? json) => CrestShape.values
      .firstWhere((s) => s.json == json, orElse: () => CrestShape.shield);
}

/// The centered glyph on the crest's field — at least six icons.
enum CrestIcon {
  star('star'),
  ball('ball'),
  crown('crown'),
  lion('lion'),
  flame('flame'),
  bolt('bolt');

  const CrestIcon(this.json);

  /// Stable JSON identifier, same contract as [CrestShape.json].
  final String json;

  static CrestIcon fromJson(String? json) => CrestIcon.values
      .firstWhere((i) => i.json == json, orElse: () => CrestIcon.star);
}

/// The one pattern every crest's field carries (T-0097 Requirement 2:
/// one pattern, applied consistently): vertical halves — the primary
/// colour on the outer halves, a secondary vertical band through the
/// middle.
enum CrestPattern { halves }

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
    'pattern': pattern.name,
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
      pattern: CrestPattern.halves,
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
      crestIndex == 2 ? 2 : (crestIndex + 2) % FcmColors.crestPalette.length;

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
