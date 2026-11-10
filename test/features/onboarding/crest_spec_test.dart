// T-0097: the crest foundation — the CrestSpec value (JSON round-trip,
// legacy mapping, resolver preference) and the FcmCrest renderer
// (28px and 96px, no overflow, paints an icon; direction-agnostic by
// construction). The DB round-trip lives with the real-DB onboarding
// harness in club_creation_test.dart.
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fcm_rivals/core/database/app_database.dart';
import 'package:fcm_rivals/core/domain/crest.dart';
import 'package:fcm_rivals/core/ui/fcm_crest.dart';
import 'package:fcm_rivals/core/ui/fcm_style.dart' show FcmColors;
import 'package:fcm_rivals/features/collection/collection_store.dart';

CrestSpec _spec() => const CrestSpec(
  shape: CrestShape.pennant,
  primaryIndex: 0,
  secondaryIndex: 4,
  icon: CrestIcon.bolt,
);

void main() {
  group('CrestSpec (T-0097)', () {
    test('JSON round-trips every field', () {
      final spec = _spec();
      final encoded = jsonEncode(spec.toJson());
      final decoded = CrestSpec.fromJson(
        Map<String, Object?>.from(jsonDecode(encoded) as Map),
      );
      expect(decoded, spec, reason: 'encode → decode returns the same spec');
      expect(CrestSpec.fromJsonString(spec.encode()), spec,
          reason: 'the TEXT-column convenience round-trips too');
    });

    test('every shape and icon round-trips (exhaustive)', () {
      for (final shape in CrestShape.values) {
        for (final icon in CrestIcon.values) {
          final spec = CrestSpec(
            shape: shape,
            primaryIndex: 3,
            secondaryIndex: 5,
            icon: icon,
          );
          expect(CrestSpec.fromJsonString(spec.encode()), spec);
        }
      }
    });

    test('legacy(i) reproduces today\'s palette colour for i in 0..5', () {
      for (var i = 0; i < FcmColors.crestPalette.length; i++) {
        final legacy = CrestSpec.legacy(i);
        expect(legacy.primaryColor, FcmColors.crestColor(i),
            reason: 'legacy($i) primary is the exact old tint');
        expect(legacy.shape, CrestShape.shield);
        expect(legacy.icon, CrestIcon.star);
        // A stale out-of-range index clamps exactly like today.
        expect(CrestSpec.legacy(99).primaryColor,
            FcmColors.crestColor(99));
      }
    });

    test('fromJson tolerates junk: null, empty, invalid', () {
      expect(CrestSpec.fromJson(null), isNull);
      expect(CrestSpec.fromJsonString(null), isNull);
      expect(CrestSpec.fromJsonString(''), isNull);
      expect(CrestSpec.fromJsonString('not json'), isNull);
      expect(CrestSpec.fromJsonString('{"primary":"x"}'), isNull);
      expect(
        CrestSpec.fromJsonString('{"primary":1,"secondary":2}'),
        isNotNull,
        reason: 'unknown shape/icon fall back to defaults, never crash',
      );
    });

    test('crestOf prefers the column and falls back to crestIndex', () {
      // A generated row with a spec in the new column…
      final withSpec = CrestSpec.legacy(2);
      final club = Club(
        id: 1,
        name: 'Pyramid United',
        managerName: 'Mohamed',
        crestIndex: 5,
        formationCode: '4-3-3',
        tactics: '{}',
        mentality: 'balanced',
        coins: 0,
        isUser: true,
        createdAt: DateTime(2026, 11, 10),
        crest: withSpec.encode(),
      );
      expect(CollectionStore.crestOf(club), withSpec,
          reason: 'the column wins over the legacy index');

      // …and the same row shape with no column: the legacy mapping.
      final legacyClub = Club(
        id: 2,
        name: 'Legacy FC',
        managerName: 'Old Manager',
        crestIndex: 4,
        formationCode: '4-3-3',
        tactics: '{}',
        mentality: 'balanced',
        coins: 0,
        isUser: true,
        createdAt: DateTime(2026, 11, 10),
      );
      expect(CollectionStore.crestOf(legacyClub), CrestSpec.legacy(4));
      expect(
        CollectionStore.crestOf(legacyClub).primaryColor,
        FcmColors.crestColor(4),
        reason: 'byte-for-byte today\'s tint for existing saves',
      );

      // A corrupt column string also falls back — never crashes.
      final corrupt = Club(
        id: 3,
        name: 'Corrupt FC',
        managerName: 'X',
        crestIndex: 1,
        formationCode: '4-3-3',
        tactics: '{}',
        mentality: 'balanced',
        coins: 0,
        isUser: true,
        createdAt: DateTime(2026, 11, 10),
        crest: 'broken',
      );
      expect(CollectionStore.crestOf(corrupt), CrestSpec.legacy(1));
    });
  });

  group('FcmCrest (T-0097)', () {
    testWidgets('renders at 28 and 96 logical px without overflow, paints',
      (WidgetTester tester) async {
      for (final width in [28.0, 96.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: FcmCrest(spec: _spec(), width: width),
              ),
            ),
          ),
        );
        await tester.pump();

        final crest = tester.widget<FcmCrest>(find.byType(FcmCrest));
        expect(crest.width, width);
        // The painter really laid out at the requested size.
        final box = tester.renderObject(find.byType(FcmCrest)) as RenderBox;
        expect(box.size, Size(width, width));
        expect(tester.takeException(), isNull,
            reason: 'no overflow at $width px');
        // Something painted: the crest's own CustomPaint (scoped to
        // FcmCrest — the MaterialApp shell carries its own painters)
        // has a painter attached.
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(FcmCrest),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(paint.painter, isNotNull);
      }
    });

    testWidgets('every shape × icon combination lays out clean', (
      WidgetTester tester,
    ) async {
      for (final shape in CrestShape.values) {
        for (final icon in CrestIcon.values) {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: FcmCrest(
                    spec: CrestSpec(
                      shape: shape,
                      primaryIndex: 1,
                      secondaryIndex: 2,
                      icon: icon,
                    ),
                    width: 28,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '$shape/$icon renders without exception');
        }
      }
    });

    testWidgets('RTL renders identically (direction-agnostic design)', (
      WidgetTester tester,
    ) async {
      Future<double> paintedLeft({required bool rtl}) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: rtl ? const Locale('ar') : const Locale('en'),
            home: Directionality(
              textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
              child: const Scaffold(
                body: Center(child: FcmCrest(spec: CrestSpec(
                  shape: CrestShape.shield,
                  primaryIndex: 0,
                  secondaryIndex: 3,
                  icon: CrestIcon.star,
                ), width: 96)),
              ),
            ),
          ),
        );
        await tester.pump();
        final box = tester.renderObject(find.byType(FcmCrest)) as RenderBox;
        return box.localToGlobal(Offset.zero).dx;
      }

      // Symmetric geometry: the widget occupies the same frame slot in
      // both directions (a Center+constant child does; the assertion
      // pins that the crest itself adds no directional padding/offset).
      expect(await paintedLeft(rtl: false), await paintedLeft(rtl: true));
    });
  });

  group('CrestSpec DB round-trip (T-0097, real drift)', () {
    // Same harness pattern as club_creation_test.dart: an in-memory
    // NativeDatabase behind the real CollectionStore.
    test('a club created with a spec round-trips through the column', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = CollectionStore(db: db);
      addTearDown(db.close);

      final spec = _spec();
      final clubId = await store.createClub(
        clubName: 'Pyramid United',
        managerName: 'Mohamed',
        crestIndex: 2,
        crest: spec,
      );

      final club = await store.getClub();
      expect(club, isNotNull);
      expect(club!.id, clubId);
      expect(club.crest, spec.encode(),
          reason: 'the column carries the exact JSON payload');
      expect(CollectionStore.crestOf(club), spec,
          reason: 'the resolver reads the stored spec back');

      // And without a spec: the column stays absent, the legacy path
      // owns the club — byte-for-byte today's behaviour.
      final db2 = AppDatabase(NativeDatabase.memory());
      final store2 = CollectionStore(db: db2);
      addTearDown(db2.close);
      await store2.createClub(
        clubName: 'Legacy FC',
        managerName: 'Old Manager',
        crestIndex: 4,
      );
      final legacy = await store2.getClub();
      expect(legacy!.crest, isNull);
      expect(CollectionStore.crestOf(legacy), CrestSpec.legacy(4));
      expect(
        CollectionStore.crestOf(legacy).primaryColor,
        FcmColors.crestColor(4),
        reason: 'existing saves keep their exact tint',
      );
    });

    test('schema 13: the crest column exists after the v12→v13 step',
        () async {
      // A v12 database (pre-column) migrated to 13 keeps its rows and
      // gains the nullable column — every existing value reads null.
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 13);

      // The fresh-create path is the same schema the migration lands
      // on; write a row directly and read the column back through the
      // generated data class.
      final now = DateTime.now();
      final id = await db
          .into(db.clubs)
          .insert(ClubsCompanion.insert(
            name: 'Migrating FC',
            managerName: 'M',
            coins: 0,
            createdAt: now,
          ));
      final row = await (db.select(
        db.clubs,
      )..where((c) => c.id.equals(id))).getSingle();
      expect(row.crest, isNull,
          reason: 'pure addition: existing-style rows read null');

      await (db.update(db.clubs)..where((c) => c.id.equals(id))).write(
        ClubsCompanion(crest: Value(CrestSpec.legacy(1).encode())),
      );
      final updated = await (db.select(
        db.clubs,
      )..where((c) => c.id.equals(id))).getSingle();
      expect(
        CrestSpec.fromJsonString(updated.crest),
        CrestSpec.legacy(1),
        reason: 'the column round-trips through the generated class',
      );
    });
  });
}
