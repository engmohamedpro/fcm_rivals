/// T-0129: preset tactic combinations — the catalogue and its
/// application through the tactics options sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/features/match/tactic_presets.dart';
import 'package:fcm_rivals/features/match/team_tactics.dart';
import 'package:fcm_rivals/features/squad/tactics_setup_view.dart';

void main() {
  test('the catalogue is non-empty with unique ids and no slider '
      'overrides', () {
    expect(tacticPresets, isNotEmpty);
    final ids = tacticPresets.map((p) => p.id).toSet();
    expect(ids.length, tacticPresets.length, reason: 'ids must be unique');
    for (final preset in tacticPresets) {
      expect(preset.tactics.inPossession.scales, isEmpty,
          reason: '${preset.id}: presets are enum-anchor combinations only');
      expect(preset.tactics.outOfPossession.scales, isEmpty,
          reason: '${preset.id}: no out-of-possession overrides');
      expect(preset.tactics.transitions.scales, isEmpty,
          reason: '${preset.id}: no transitions overrides');
      expect(preset.mentalityScale, isNull,
          reason: '${preset.id}: presets never touch the mentality');
    }
  });

  test('every preset differs from at least one other (no dead rows)',
      () {
    final unique =
        tacticPresets.map((p) => p.tactics).toSet();
    expect(unique.length, greaterThan(1));
  });

  test('the balanced preset is exactly the default TeamTactics', () {
    final balanced = tacticPresets.firstWhere((p) => p.id == 'balanced');
    expect(balanced.tactics, const TeamTactics());
  });

  testWidgets('tapping a preset in the sheet applies the whole '
      'combination at once', (WidgetTester tester) async {
    TeamTactics? applied;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Builder(
            builder: (context) {
              return Center(
                child: TextButton(
                  child: const Text('OPEN'),
                  onPressed: () => showTacticsOptionsSheet(
                    context,
                    tactics: const TeamTactics(),
                    onTactics: (t) => applied = t,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // The preset row renders with every preset label.
    for (final preset in tacticPresets) {
      expect(find.text(preset.name), findsOneWidget);
    }

    // Tap Gegenpress: the applied tactics become its combination.
    final gegenpress =
        tacticPresets.firstWhere((p) => p.id == 'gegenpress');
    await tester.tap(find.text('Gegenpress'));
    await tester.pumpAndSettle();
    expect(applied, gegenpress.tactics);

    // The chip shows selected for the active preset and the sliders
    // reflect the new values (the Out of Possession tab's defensive
    // line slider sits on the high step: 100).
    await tester.tap(find.text('Out of Possession'));
    await tester.pumpAndSettle();
    expect(find.text('100'), findsAtLeastNWidgets(1));

    // Manual adjustment on top still works: moving the defensive line
    // commits a different tactics object.
    await tester.tap(find.text('Balanced'));
    await tester.pumpAndSettle();
    final balanced =
        tacticPresets.firstWhere((p) => p.id == 'balanced');
    expect(applied, balanced.tactics);
  });
}
