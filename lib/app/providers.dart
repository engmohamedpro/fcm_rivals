/// FCM Rivals — app wiring: database, dataset bootstrap and Riverpod
/// providers shared by the feature screens.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/database/app_database.dart';
import '../features/collection/collection_store.dart';
import '../features/squad/formations.dart';
import '../features/squad/squad_engine.dart';

/// Opens the local SQLite database (SRS 21: Drift over SQLite).
Future<AppDatabase> openDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, 'fcm_rivals.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}

final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final db = await openDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Imports the bundled dataset on first launch; skips when the persisted
/// version is already current.
final datasetBootstrapProvider = FutureProvider<void>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final store = CollectionStore(db: db);
  final jsonText = await rootBundle.loadString('assets/data/players_v1.json');
  await store.importBundledDataset(jsonText);
});

final collectionStoreProvider = FutureProvider<CollectionStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  await ref.watch(datasetBootstrapProvider.future);
  return CollectionStore(db: db);
});

/// Random source for pack draws and merges; seedable in tests.
final randomProvider = Provider<math.Random>((ref) => math.Random());

/// The user club, null until created (FR-001).
final clubProvider = FutureProvider<Club?>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getClub();
});

/// Unopened packs (GDD 5.8: 36 starting position packs).
final availablePacksProvider = FutureProvider<List<Pack>>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getAvailablePacks();
});

/// Owned collection, best first.
final collectionProvider = FutureProvider<List<PlayerCard>>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getCollection();
});

/// Persisted squad assignment: slot → card.
final squadProvider = FutureProvider<Map<int, PlayerCard>>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getSquad();
});

/// Squad selection logic (GDD 6.3).
final squadEngineProvider = Provider<SquadEngine>((ref) => const SquadEngine());

/// All formation definitions (GDD 6.4).
final formationsProvider =
    Provider<List<Formation>>((ref) => formations);
