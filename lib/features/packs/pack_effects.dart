/// FCM Rivals — pack opening visual effects (CustomPainter based).
///
/// * [FoilPackPainter]  — the sealed trading-card booster: foil wrapper, card
///   fan, wordmark band, holo sheen and a light crack that grows while the
///   pack charges.
/// * [LightRaysPainter] — rotating stadium-light beams behind the reveal.
/// * [ParticleBurstPainter] — sparks thrown out when the pack bursts.
///
/// Barrel (T-0040): the families live in `pack_effect_palette.dart`,
/// `foil_pack_painter.dart` and `pack_particles.dart`; this file keeps
/// the historical `features/packs/pack_effects.dart` import path stable.
library;

export 'foil_pack_painter.dart';
export 'pack_effect_palette.dart';
export 'pack_particles.dart';
