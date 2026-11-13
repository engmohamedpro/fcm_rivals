/// Shared tm-bundle loader for the test suite (owner request 2026-11-12:
/// the four tm-*.json assets as sent, never rewritten). Loads the shipped
/// bundle through the REAL parser exactly as the app bootstrap does.
library;

import 'dart:io';

import 'package:fcm_rivals/core/domain/players.dart' show BasePlayer;
import 'package:fcm_rivals/features/player_database/player_database.dart';

const String tmPlayersPath = 'assets/data/tm-players.json';
const String tmIconsPath = 'assets/data/tm-icons.json';
const String tmClubsPath = 'assets/data/tm-clubs.json';
const String tmLeaguesPath = 'assets/data/tm-leagues.json';

PlayerDataset loadTmDataset() => PlayerDataset.fromTmBundle(
  playersJson: File(tmPlayersPath).readAsStringSync(),
  iconsJson: File(tmIconsPath).readAsStringSync(),
  clubsJson: File(tmClubsPath).readAsStringSync(),
  leaguesJson: File(tmLeaguesPath).readAsStringSync(),
);

List<BasePlayer> loadTmPool() {
  final db = PlayerDatabase();
  db.importDataset(loadTmDataset());
  return db.all.toList(growable: false);
}
