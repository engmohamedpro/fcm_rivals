/// FCM Rivals — league metadata from the imported dataset.
library;

/// Display names for Transfermarkt domestic league codes.
const Map<String, String> leagueNames = {
  'GB1': 'Premier League',
  'ES1': 'LaLiga',
  'IT1': 'Serie A',
  'L1': 'Bundesliga',
  'FR1': 'Ligue 1',
  'PO1': 'Liga Portugal',
  'NL1': 'Eredivisie',
  'BE1': 'Pro League',
  'TR1': 'Süper Lig',
  'RU1': 'Premier Liga',
  'GR1': 'Super League',
  'SC1': 'Premiership',
  'A1': 'Bundesliga AT',
  'CH1': 'Super League CH',
  'DK1': 'Superliga',
  'SE1': 'Allsvenskan',
  'NO1': 'Eliteserien',
  'UK1': 'Premier Liha',
  'RO1': 'Liga I',
  'RS1': 'SuperLiga',
  'HR1': 'HNL',
  'CZ1': 'Chance Liga',
  'PL1': 'Ekstraklasa',
  'US1': 'MLS',
  'MX1': 'Liga MX',
  'AR1': 'Primera División',
  'BR1': 'Série A',
  'JP1': 'J1 League',
  'KR1': 'K League 1',
  'AU1': 'A-League',
  'SA1': 'Saudi Pro League',
};

String leagueDisplayName(String code, {Map<String, String>? fromDataset}) =>
    (fromDataset ?? const {})[code] ?? leagueNames[code] ?? code;
