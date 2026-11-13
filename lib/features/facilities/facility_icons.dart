/// FCM Rivals — facility presentation icons (GDD 3.5).
///
/// Presentation-only split out of `facilities.dart` (T-0060): the
/// economy/session chain that consumes `Facility` stays pure Dart and
/// runnable under plain `dart run`; the campus UI imports this file for
/// the iconography.
library;

import 'package:flutter/material.dart';

import 'facilities.dart';

/// The shelf icon for each campus facility.
extension FacilityIcons on Facility {
  IconData get icon => switch (this) {
    Facility.attack => Icons.sports_soccer_rounded,
    Facility.support => Icons.hub_rounded,
    Facility.defence => Icons.shield_rounded,
    Facility.goalkeeping => Icons.sports_handball_rounded,
    Facility.recovery => Icons.spa_rounded,
    Facility.medical => Icons.medical_services_rounded,
  };
}
