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
import '../features/ads/ad_store.dart';
import '../features/collection/collection_store.dart';
import '../features/facilities/facilities.dart';
import '../features/season/season_engine.dart' show StandingEntry;
import '../features/season/season_store.dart';
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

/// Rewarded-ad store (GDD 19): economy ad surfaces for the collection.
final adStoreProvider = FutureProvider<AdStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return AdStore(db: db);
});

final collectionStoreProvider = FutureProvider<CollectionStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  await ref.watch(datasetBootstrapProvider.future);
  return CollectionStore(db: db, adStore: await ref.watch(adStoreProvider.future));
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

/// The store's buyable pack offers with their coin prices (GDD 5.5).
final storeOffersProvider =
    FutureProvider<List<StorePackOffer>>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getStoreOffers();
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

/// Season store (GDD 9): divisions, fixtures and standings.
final seasonStoreProvider = FutureProvider<SeasonStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  await ref.watch(datasetBootstrapProvider.future);
  return SeasonStore(db: db, random: ref.watch(randomProvider));
});

/// Active or latest season summary (FR-035/FR-036).
final seasonSummaryProvider = FutureProvider<SeasonSummary?>((ref) async {
  final store = await ref.watch(seasonStoreProvider.future);
  return store.getSeasonSummary();
});

/// Current standings (GDD 9.3).
final standingsProvider = FutureProvider<List<StandingEntry>>((ref) async {
  final store = await ref.watch(seasonStoreProvider.future);
  return store.getStandings();
});

/// The user's next fixture, null when idle or done.
final nextFixtureProvider = FutureProvider<NextFixture?>((ref) async {
  final store = await ref.watch(seasonStoreProvider.future);
  return store.getNextFixture();
});

/// Club campus facility levels (GDD 3.5).
final campusProvider = FutureProvider<CampusLevels>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getCampus();
});
