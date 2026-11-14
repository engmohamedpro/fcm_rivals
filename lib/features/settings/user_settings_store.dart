/// FCM Rivals — user settings store (GDD 26.2).
///
/// The single `user_settings` row (id = 1): app-level preferences that
/// must survive app restarts and carry across matches. The live match
/// screen writes the playback speed the moment the user taps a new
/// multiplier and reads it back at the next kick-off, so the chosen
/// match speed sticks forever instead of resetting to 1x every match.
library;

import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart' as db;

class UserSettingsStore {
  UserSettingsStore({required this.database});

  final db.AppDatabase database;

  static const int _rowId = 1;

  /// Highest supported playback speed (1x–2x: 1x reads the match,
  /// 2x plays it — owner request 2026-11-14: 3x is removed). A
  /// persisted 3 from the old build reads back as the 1x fallback.
  static const int maxMatchSpeed = 2;

  /// The persisted match playback speed (1–2). Returns [fallback] when
  /// no row exists yet (first launch) — the caller treats that as the
  /// default speed, and the row is created on the first write.
  Future<int> matchSpeed({int fallback = 1}) async {
    final row = await _row();
    if (row == null) return fallback;
    final speed = row.matchSpeed;
    return speed >= 1 && speed <= maxMatchSpeed ? speed : fallback;
  }

  /// Persists the chosen playback speed (1–2, anything else is ignored).
  Future<void> setMatchSpeed(int speed) async {
    if (speed < 1 || speed > maxMatchSpeed) return;
    final row = await _row();
    if (row == null) {
      await database
          .into(database.userSettings)
          .insert(
            db.UserSettingsCompanion.insert(
              id: _rowId,
              matchSpeed: Value(speed),
            ),
          );
      return;
    }
    await (database.update(database.userSettings)
          ..where((t) => t.id.equals(_rowId)))
        .write(db.UserSettingsCompanion(matchSpeed: Value(speed)));
  }

  /// The persisted UI language tag ('en' | 'ar'), or null when the app
  /// should follow the system locale.
  Future<String?> locale() async {
    final row = await _row();
    return row?.locale;
  }

  /// Persists the UI language tag; a null clears it back to
  /// system-follow.
  Future<void> setLocale(String? tag) async {
    if (tag != null && tag != 'en' && tag != 'ar') return;
    final row = await _row();
    if (row == null) {
      await database
          .into(database.userSettings)
          .insert(
            db.UserSettingsCompanion.insert(
              id: _rowId,
              locale: tag == null ? const Value.absent() : Value(tag),
            ),
          );
      return;
    }
    await (database.update(database.userSettings)
          ..where((t) => t.id.equals(_rowId)))
        .write(db.UserSettingsCompanion(locale: Value(tag)));
  }

  Future<db.UserSetting?> _row() async {
    final query = database.select(database.userSettings)
      ..where((t) => t.id.equals(_rowId));
    final rows = await query.get();
    return rows.isEmpty ? null : rows.first;
  }
}
