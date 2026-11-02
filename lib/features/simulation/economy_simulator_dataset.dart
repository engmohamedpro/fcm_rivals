/// FCM Rivals — simulation dataset builder (GDD 30).
///
/// Builds a synthetic Player Database with the market-value bands the
/// economy scenarios need (low / medium / high), across all positions,
/// in the exact import format the CollectionStore accepts.
library;

import 'dart:convert';
import 'dart:math' as math;



/// The dataset shapes the GDD 30 scenarios require: value bands.
enum SimValueBand { low, medium, high }

/// Generates a synthetic player dataset for economy simulations.
class SimDataset {
  const SimDataset._(this._rows, this._band);

  final List<List<dynamic>> _rows;
  final SimValueBand _band;

  static const _positions = [
    'GK', 'CB', 'LB', 'RB', 'CDM', 'CM', 'LM', 'RM', 'CAM', 'LW', 'RW', 'ST',
  ];

  /// Dataset shape per band (market values in EUR):
  /// - low: €200k–€2M squad-building game
  /// - medium: €500k–€30M
  /// - high: €2M–€120M superstars
  static const _ranges = <SimValueBand, (int, int)>{
    SimValueBand.low: (200_000, 2_000_000),
    SimValueBand.medium: (500_000, 30_000_000),
    SimValueBand.high: (2_000_000, 120_000_000),
  };

  static SimDataset generate({
    required SimValueBand band,
    required int size,
    required math.Random random,
  }) {
    final (min, max) = _ranges[band]!;
    // Log-uniform values so the distribution is realistic across decades.
    final logMin = math.log(min.toDouble());
    final logMax = math.log(max.toDouble());
    final rows = <List<dynamic>>[
      for (var i = 0; i < size; i++)
        () {
          final value =
              math.exp(logMin + random.nextDouble() * (logMax - logMin)).round();
          final position = _positions[i % _positions.length];
          final league = i % 2 == 0 ? 'EG1' : 'SA1';
          return <dynamic>[
            900_000 + i,
            'Sim $league ${i + 1}',
            position,
            18 + random.nextInt(18),
            random.nextBool() ? 'Egypt' : 'Saudi Arabia',
            i % 2 == 0 ? 'Cairo Union' : 'Riyadh Stars',
            league,
            value,
          ];
        }(),
    ];
    return SimDataset._(rows, band);
  }

  String get bandName => switch (_band) {
        SimValueBand.low => 'low',
        SimValueBand.medium => 'medium',
        SimValueBand.high => 'high',
      };

  /// The import JSON the CollectionStore's applyDatasetUpdate accepts.
  String toJson() => json.encode({
        'format': 'fcm-rivals-players',
        'version': 1,
        'asOf': '2026-11-01',
        'leagues': const {'EG1': 'Egyptian Premier League', 'SA1': 'Saudi Pro League'},
        'digest': 'sim-$_band',
        'players': _rows,
      });
}
