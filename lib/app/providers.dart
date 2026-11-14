/// FCM Rivals — app wiring: database, dataset bootstrap and Riverpod
/// providers shared by the feature screens.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/database/app_database.dart';
import '../core/domain/crest.dart' show CrestSpec;
import '../features/ads/ad_store.dart';
import '../features/collection/club_store.dart';
import '../features/collection/collection_store.dart';
import '../features/collection/squad_store.dart';
import '../features/player_database/player_database.dart';
import '../features/settings/user_settings_store.dart';
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

/// Bridges a drift watch into the provider graph (M1: live club row).
///
/// drift cancels the underlying query stream when its LAST listener
/// goes away, and that cancellation schedules a zero-duration timer
/// (StreamQueryStore.markAsClosed). In widget tests that timer fires
/// after the tree is disposed, tripping the binding's `timersPending`
/// assertion, and cancelling under db.close() races drift's shutdown
/// ("Cannot add event while adding stream"). The bridge keeps ONE
/// subscription alive for the database's whole lifetime and fans the
/// events out on a broadcast stream: Riverpod scopes may come and go
/// without ever dropping drift to zero listeners, so no cancellation
/// (and no zero-timer) ever happens. Broadcast relaying is also
/// memory-safe here — events are small, immutable row snapshots.
Stream<T> _livedb<T>(AppDatabase db, Stream<T> Function() watch) async* {
  final controller = StreamController<T>.broadcast();
  final subscription = watch().listen(
    controller.add,
    onError: controller.addError,
  );
  db.attachedDatabaseStreamController = controller.sink;
  try {
    yield* controller.stream;
  } finally {
    await subscription.cancel();
    await controller.close();
  }
}

/// Marker sink so [._livedb]'s subscription lifetime is provably tied
/// to the database (see databaseProvider's onDispose); kept as an
/// extension setter to avoid widening the AppDatabase API.
extension _DbLifetimeSink on AppDatabase {
  static final Expando<StreamSink<Object?>> _sinks = Expando();
  set attachedDatabaseStreamController(StreamSink<Object?> sink) =>
      _sinks[this] = sink;
}

/// Imports the bundled dataset on first launch; skips when the persisted
/// version is already current.
///
/// The shipped bundle is the four tm-files (owner request 2026-11-12:
/// `tm-players.json`, `tm-icons.json`, `tm-clubs.json`,
/// `tm-leagues.json` — as sent, never rewritten; see
/// `PlayerDataset.fromTmBundle`): ~12 MB of JSON decoded on a background
/// isolate (Isolate.run) so the first-launch frame budget is not spent
/// on jsonDecode — the UI thread only awaits the parsed dataset and
/// hands it to the store, which batches the inserts (see
/// CollectionStore.applyDatasetUpdate).
final datasetBootstrapProvider = FutureProvider<void>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  final store = CollectionStore(db: db);
  final playersText = await rootBundle
      .loadString('assets/data/tm-players.json');
  final iconsText = await rootBundle.loadString('assets/data/tm-icons.json');
  final clubsText = await rootBundle.loadString('assets/data/tm-clubs.json');
  final leaguesText = await rootBundle
      .loadString('assets/data/tm-leagues.json');
  final dataset = await Isolate.run(
    () => PlayerDataset.fromTmBundle(
      playersJson: playersText,
      iconsJson: iconsText,
      clubsJson: clubsText,
      leaguesJson: leaguesText,
    ),
  );
  await store.importBundledDataset(dataset);
});

/// Rewarded-ad store (GDD 19): economy ad surfaces for the collection.
final adStoreProvider = FutureProvider<AdStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return AdStore(db: db);
});

final collectionStoreProvider = FutureProvider<CollectionStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  await ref.watch(datasetBootstrapProvider.future);
  return CollectionStore(
    db: db,
    adStore: await ref.watch(adStoreProvider.future),
  );
});

/// Focused stores extracted from CollectionStore (app-structure Task 2):
/// same database instance, single-purpose APIs. Screens may watch these
/// directly; CollectionStore remains the facade for the pack/collection
/// flows and composes the same three objects internally.
final clubStoreProvider = FutureProvider<ClubStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ClubStore(db: db);
});

final squadStoreProvider = FutureProvider<SquadStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  await ref.watch(datasetBootstrapProvider.future);
  return SquadStore(db: db, squad: ref.watch(squadEngineProvider));
});

/// Random source for pack draws and merges; seedable in tests.
final randomProvider = Provider<math.Random>((ref) => math.Random());

/// App-level user settings (match playback speed): the chosen speed
/// persists across matches and app restarts (GDD 26.2).
final userSettingsProvider = FutureProvider<UserSettingsStore>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return UserSettingsStore(database: db);
});

/// The persisted UI language: 'en', 'ar', or null (follow the system).
/// The app bar's language toggle writes through [setLocaleProvider].
final localeProvider = StateProvider<String?>((ref) => null);

/// Persists a UI language choice and updates [localeProvider] so the
/// MaterialApp rebuilds with the new locale immediately. Accepts the
/// provider pair so both widget refs and plain refs can call it.
Future<void> setLocale({
  required StateController<String?> controller,
  required Future<UserSettingsStore> Function() settings,
  String? tag,
}) async {
  controller.state = tag;
  await (await settings()).setLocale(tag);
}

/// The user club, null until created (FR-001). A stream over drift's
/// table watch: every coin movement, rename or crest change re-emits
/// the row automatically, so the app-bar balance and every screen
/// reading coins are live without manual invalidation.
final clubProvider = StreamProvider<Club?>((ref) async* {
  final store = await ref.watch(collectionStoreProvider.future);
  yield* _livedb(store.db, store.watchClub);
});

/// Unopened packs (GDD 5.8: 36 starting position packs).
final availablePacksProvider = FutureProvider<List<Pack>>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getAvailablePacks();
});

/// The store's buyable pack offers with their coin prices (GDD 5.5).
final storeOffersProvider = FutureProvider<List<StorePackOffer>>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getStoreOffers();
});

/// Owned collection, best first.
final collectionProvider = FutureProvider<List<PlayerCard>>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getCollection();
});

/// Squad capacity: distinct players owned vs. the slots the club has, and
/// the price of the next block of slots. Re-derived whenever the
/// collection changes (a pack opened, a player sold); a slot purchase
/// invalidates it directly.
final squadCapacityProvider = FutureProvider<SquadCapacity>((ref) async {
  ref.watch(collectionProvider);
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getSquadCapacity();
});

/// One-shot request for the game shell to switch tab (index into the
/// bottom nav, e.g. 1 = Team). The shell consumes it and resets it to
/// null, so any screen can send the player to another tab.
final shellTabRequestProvider = StateProvider<int?>((ref) => null);

/// Persisted squad assignment: slot → card.
final squadProvider = FutureProvider<Map<int, PlayerCard>>((ref) async {
  final store = await ref.watch(collectionStoreProvider.future);
  return store.getSquad();
});

/// Squad selection logic (GDD 6.3).
final squadEngineProvider = Provider<SquadEngine>((ref) => const SquadEngine());

/// All formation definitions (GDD 6.4).
final formationsProvider = Provider<List<Formation>>((ref) => formations);

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

/// T-0130: the season's per-player statistics rows — the leaderboards'
/// raw material. Refreshes with the standings (a committed match
/// invalidates both together).
final playerSeasonStatsProvider = FutureProvider<List<PlayerSeasonStat>>((
  ref,
) async {
  final store = await ref.watch(seasonStoreProvider.future);
  return store.getPlayerSeasonStats();
});

/// Every club's crest by club id (the standings table's badge column).
/// Re-reads whenever the standings refresh, so a new season's freshly
/// generated AI crests show up with it.
final standingCrestsProvider = FutureProvider<Map<int, CrestSpec>>((ref) async {
  await ref.watch(standingsProvider.future);
  final db = await ref.watch(databaseProvider.future);
  final clubs = await db.select(db.clubs).get();
  return {for (final c in clubs) c.id: CollectionStore.crestOf(c)};
});

/// The user's next fixture, null when idle or done.
final nextFixtureProvider = FutureProvider<NextFixture?>((ref) async {
  final store = await ref.watch(seasonStoreProvider.future);
  return store.getNextFixture();
});
