/// FCM Rivals — squad store: persisted squad assignments and the
/// club's saved tactical setup.
///
/// Extracted from CollectionStore: slot assignments, Auto Pick,
/// formation changes (which re-run Auto Pick, GDD 6.4) and the
/// saved tactics/mentality. Same database, same engines, same
/// behaviour — just a single-purpose home.
library;

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/players.dart' show BasePlayer, BaseStats, Position;
import '../match/tactics.dart' show TeamTactics;
import '../squad/formations.dart';
import '../squad/squad_engine.dart' show PlayerCard, SquadEngine;
import 'collection_store.dart' show CollectionException;

/// CollectionStore delegates here; see the library doc.
class SquadStore {
  SquadStore({required this.db, this.squad = const SquadEngine()});

  final AppDatabase db;
  final SquadEngine squad;

  /// The user club, or null before onboarding completes (same
  /// singleOrNull semantics as CollectionStore.getClub).
  Future<Club?> getClub() => (db.select(
    db.clubs,
  )..where((c) => c.isUser.equals(true))).getSingleOrNull();

  /// best-first) — so consumers that walk the entries see the ranked
  /// squad instead of an arbitrary database row order.
  Future<Map<int, PlayerCard>> getSquad() async {
    final club = await getClub();
    if (club == null) return const {};
    final byId = await _ownedCardsById(club.id);
    final rows =
        await (db.select(db.ownedPlayers)
              ..where((o) => o.clubId.equals(club.id))
              ..orderBy([(o) => OrderingTerm.asc(o.squadSlot)]))
            .get();
    final squad = <int, PlayerCard>{};
    for (final row in rows) {
      if (row.squadSlot != null && byId.containsKey(row.id)) {
        squad[row.squadSlot!] = byId[row.id]!;
      }
    }
    return squad;
  }

  /// Persists a full squad assignment (FR-017/FR-020 storage side). Slots
  /// not present in [assignments] are cleared. Runs in one transaction.
  ///
  /// [allowInjured]: the Team tab's management pick saves the club's
  /// identity eleven on merit — an injured player CAN hold his saved
  /// slot (T-0117; the matchday layers re-field a fit XI at kick-off
  /// via the session guard). Default false keeps the T-0055 backstop
  /// for every other caller.
  Future<void> saveSquad(
    Map<int, int> assignments, {
    bool allowInjured = false,
  }) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final owned = await (db.select(
      db.ownedPlayers,
    )..where((o) => o.clubId.equals(club.id) & o.status.equals('owned'))).get();
    final byOwned = {for (final o in owned) o.id: o};
    for (final id in assignments.values) {
      if (!byOwned.containsKey(id)) {
        throw CollectionException('Owned player $id not found');
      }
      // Injured players are unselectable on MATCHDAY paths (T-0055,
      // GDD 11.7) — the store is the backstop behind the UI. The Team
      // tab's management save (T-0117) explicitly allows the identity
      // eleven to include an injured player: fitness is a matchday
      // concern, and the kick-off session guard re-fields a fit XI.
      if (!allowInjured && (byOwned[id]!.injuryMatchesRemaining ?? 0) > 0) {
        throw CollectionException(
          'Injured player $id cannot be selected '
          '(${byOwned[id]!.injuryMatchesRemaining} matches remaining)',
        );
      }
    }
    // one player per slot and one slot per player
    if (assignments.values.toSet().length != assignments.length) {
      throw const CollectionException('A player cannot take two slots');
    }

    await db.transaction(() async {
      for (final o in owned) {
        final slot = assignments.entries
            .where((e) => e.value == o.id)
            .map((e) => e.key)
            .firstOrNull;
        if (o.squadSlot != slot) {
          await (db.update(db.ownedPlayers)..where((x) => x.id.equals(o.id)))
              .write(OwnedPlayersCompanion(squadSlot: Value(slot)));
        }
      }
    });
  }

  /// Auto Pick over the current collection and formation, then persist
  /// (FR-019). Returns the applied assignment.
  ///
  /// [excludeInjured]: the Team tab's pick passes false (T-0117) — the
  /// saved XI is the club's identity eleven on MERIT; fitness is a
  /// matchday concern (pre-match projection + kick-off guard), never
  /// a reason the club's best XI changes. Defaults true so matchday
  /// and store-internal callers keep the T-0055 behaviour.
  ///
  /// [naturalOnly]: XI slots take only natural-position players and stay
  /// empty otherwise (the Team tab's Auto Pick button).
  Future<Map<int, int>> autoPickSquad({
    bool excludeInjured = true,
    bool naturalOnly = false,
  }) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final byId = await _ownedCardsById(club.id);
    final cards = byId.values.toList(growable: false);
    final formation = formationByCode(club.formationCode);
    final assignment = squad.autoPick(
      cards,
      formation,
      excludeInjured: excludeInjured,
      naturalOnly: naturalOnly,
    );
    await saveSquad(assignment, allowInjured: !excludeInjured);
    return assignment;
  }

  /// Updates the club formation (FR-018) and re-runs Auto Pick so every XI
  /// slot stays filled (GDD 6.4: changing formation updates positions).
  Future<void> changeFormation(String formationCode) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    final formation = formationByCode(formationCode);
    await (db.update(db.clubs)..where((c) => c.id.equals(club.id))).write(
      ClubsCompanion(formationCode: Value(formation.code)),
    );
    await autoPickSquad();
  }

  /// Updates the club's tactical setup for future matches (GDD 10.2/10.3).
  /// [tactics] persists as the JSON payload of [TeamTactics].
  Future<void> changeTactics({
    String? formationCode,
    TeamTactics? tactics,
    String? mentality,
  }) async {
    final club = await getClub();
    if (club == null) {
      throw const CollectionException('No club');
    }
    await (db.update(db.clubs)..where((c) => c.id.equals(club.id))).write(
      ClubsCompanion(
        formationCode: formationCode != null
            ? Value(formationByCode(formationCode).code)
            : const Value.absent(),
        tactics: tactics != null
            ? Value(jsonEncode(tactics.toJson()))
            : const Value.absent(),
        mentality: mentality != null ? Value(mentality) : const Value.absent(),
      ),
    );
    if (formationCode != null) {
      await autoPickSquad();
    }
  }

  /// The club's saved custom tactics (GDD 10.2). Any legacy payload —
  /// including the pre-v11 playing-style names and a missing column —
  /// loads as the default (identity) setup; malformed JSON falls back
  /// the same way instead of crashing the club load.
  TeamTactics tacticsOfClub(Club club) {
    final raw = club.tactics;
    if (raw.isEmpty || raw == '{}') return const TeamTactics();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return const TeamTactics();
    try {
      return TeamTactics.fromJson(decoded);
    } on FormatException {
      return const TeamTactics();
    }
  }

  /// Owned players of [clubId] joined with the dataset's base rows —
  /// the same join CollectionStore.getCollection performs, kept local
  /// so the squad reads stay single-purpose.
  Future<Map<int, PlayerCard>> _ownedCardsById(int clubId) async {
    final query = db.select(db.ownedPlayers).join([
      innerJoin(
        db.players,
        db.players.playerId.equalsExp(db.ownedPlayers.playerId),
      ),
    ]);
    query.where(
      db.ownedPlayers.clubId.equals(clubId) &
          db.ownedPlayers.status.equals('owned'),
    );
    final rows = await query.map((row) {
      final owned = row.readTable(db.ownedPlayers);
      final base = row.readTable(db.players);
      return PlayerCard(
        ownedId: owned.id,
        base: BasePlayer(
          playerId: base.playerId,
          name: base.name,
          position: Position.fromCode(base.position),
          nationality: base.nationality,
          marketValueEur: base.marketValueEur,
          baseStats: BaseStats(
            overall: base.overall,
            attack: base.attack,
            support: base.support,
            defence: base.defence,
            goalkeeping: base.goalkeeping,
          ),
        ),
        upgradeLevel: owned.upgradeLevel,
        staminaPercent: owned.staminaPercent,
        injuryMatchesRemaining: owned.injuryMatchesRemaining ?? 0,
        injuryKind: owned.injuryKind,
      );
    }).get();
    return {for (final c in rows) c.ownedId: c};
  }
}
