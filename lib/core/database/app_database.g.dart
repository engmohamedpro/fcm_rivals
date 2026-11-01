// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PlayersTable extends Players with TableInfo<$PlayersTable, Player> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<int> playerId = GeneratedColumn<int>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<String> position = GeneratedColumn<String>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nationalityMeta = const VerificationMeta(
    'nationality',
  );
  @override
  late final GeneratedColumn<String> nationality = GeneratedColumn<String>(
    'nationality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clubMeta = const VerificationMeta('club');
  @override
  late final GeneratedColumn<String> club = GeneratedColumn<String>(
    'club',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leagueCodeMeta = const VerificationMeta(
    'leagueCode',
  );
  @override
  late final GeneratedColumn<String> leagueCode = GeneratedColumn<String>(
    'league_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _marketValueEurMeta = const VerificationMeta(
    'marketValueEur',
  );
  @override
  late final GeneratedColumn<int> marketValueEur = GeneratedColumn<int>(
    'market_value_eur',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overallMeta = const VerificationMeta(
    'overall',
  );
  @override
  late final GeneratedColumn<int> overall = GeneratedColumn<int>(
    'overall',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attackMeta = const VerificationMeta('attack');
  @override
  late final GeneratedColumn<int> attack = GeneratedColumn<int>(
    'attack',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supportMeta = const VerificationMeta(
    'support',
  );
  @override
  late final GeneratedColumn<int> support = GeneratedColumn<int>(
    'support',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defenceMeta = const VerificationMeta(
    'defence',
  );
  @override
  late final GeneratedColumn<int> defence = GeneratedColumn<int>(
    'defence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalkeepingMeta = const VerificationMeta(
    'goalkeeping',
  );
  @override
  late final GeneratedColumn<int> goalkeeping = GeneratedColumn<int>(
    'goalkeeping',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    playerId,
    name,
    position,
    age,
    nationality,
    club,
    leagueCode,
    marketValueEur,
    overall,
    attack,
    support,
    defence,
    goalkeeping,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'players';
  @override
  VerificationContext validateIntegrity(
    Insertable<Player> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    } else if (isInserting) {
      context.missing(_ageMeta);
    }
    if (data.containsKey('nationality')) {
      context.handle(
        _nationalityMeta,
        nationality.isAcceptableOrUnknown(
          data['nationality']!,
          _nationalityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nationalityMeta);
    }
    if (data.containsKey('club')) {
      context.handle(
        _clubMeta,
        club.isAcceptableOrUnknown(data['club']!, _clubMeta),
      );
    } else if (isInserting) {
      context.missing(_clubMeta);
    }
    if (data.containsKey('league_code')) {
      context.handle(
        _leagueCodeMeta,
        leagueCode.isAcceptableOrUnknown(data['league_code']!, _leagueCodeMeta),
      );
    }
    if (data.containsKey('market_value_eur')) {
      context.handle(
        _marketValueEurMeta,
        marketValueEur.isAcceptableOrUnknown(
          data['market_value_eur']!,
          _marketValueEurMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marketValueEurMeta);
    }
    if (data.containsKey('overall')) {
      context.handle(
        _overallMeta,
        overall.isAcceptableOrUnknown(data['overall']!, _overallMeta),
      );
    } else if (isInserting) {
      context.missing(_overallMeta);
    }
    if (data.containsKey('attack')) {
      context.handle(
        _attackMeta,
        attack.isAcceptableOrUnknown(data['attack']!, _attackMeta),
      );
    } else if (isInserting) {
      context.missing(_attackMeta);
    }
    if (data.containsKey('support')) {
      context.handle(
        _supportMeta,
        support.isAcceptableOrUnknown(data['support']!, _supportMeta),
      );
    } else if (isInserting) {
      context.missing(_supportMeta);
    }
    if (data.containsKey('defence')) {
      context.handle(
        _defenceMeta,
        defence.isAcceptableOrUnknown(data['defence']!, _defenceMeta),
      );
    } else if (isInserting) {
      context.missing(_defenceMeta);
    }
    if (data.containsKey('goalkeeping')) {
      context.handle(
        _goalkeepingMeta,
        goalkeeping.isAcceptableOrUnknown(
          data['goalkeeping']!,
          _goalkeepingMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_goalkeepingMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playerId};
  @override
  Player map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Player(
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}player_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}position'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      )!,
      nationality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nationality'],
      )!,
      club: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}club'],
      )!,
      leagueCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}league_code'],
      )!,
      marketValueEur: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}market_value_eur'],
      )!,
      overall: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}overall'],
      )!,
      attack: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attack'],
      )!,
      support: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}support'],
      )!,
      defence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}defence'],
      )!,
      goalkeeping: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goalkeeping'],
      )!,
    );
  }

  @override
  $PlayersTable createAlias(String alias) {
    return $PlayersTable(attachedDatabase, alias);
  }
}

class Player extends DataClass implements Insertable<Player> {
  final int playerId;
  final String name;
  final String position;
  final int age;
  final String nationality;
  final String club;
  final String leagueCode;
  final int marketValueEur;
  final int overall;
  final int attack;
  final int support;
  final int defence;
  final int goalkeeping;
  const Player({
    required this.playerId,
    required this.name,
    required this.position,
    required this.age,
    required this.nationality,
    required this.club,
    required this.leagueCode,
    required this.marketValueEur,
    required this.overall,
    required this.attack,
    required this.support,
    required this.defence,
    required this.goalkeeping,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['player_id'] = Variable<int>(playerId);
    map['name'] = Variable<String>(name);
    map['position'] = Variable<String>(position);
    map['age'] = Variable<int>(age);
    map['nationality'] = Variable<String>(nationality);
    map['club'] = Variable<String>(club);
    map['league_code'] = Variable<String>(leagueCode);
    map['market_value_eur'] = Variable<int>(marketValueEur);
    map['overall'] = Variable<int>(overall);
    map['attack'] = Variable<int>(attack);
    map['support'] = Variable<int>(support);
    map['defence'] = Variable<int>(defence);
    map['goalkeeping'] = Variable<int>(goalkeeping);
    return map;
  }

  PlayersCompanion toCompanion(bool nullToAbsent) {
    return PlayersCompanion(
      playerId: Value(playerId),
      name: Value(name),
      position: Value(position),
      age: Value(age),
      nationality: Value(nationality),
      club: Value(club),
      leagueCode: Value(leagueCode),
      marketValueEur: Value(marketValueEur),
      overall: Value(overall),
      attack: Value(attack),
      support: Value(support),
      defence: Value(defence),
      goalkeeping: Value(goalkeeping),
    );
  }

  factory Player.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Player(
      playerId: serializer.fromJson<int>(json['playerId']),
      name: serializer.fromJson<String>(json['name']),
      position: serializer.fromJson<String>(json['position']),
      age: serializer.fromJson<int>(json['age']),
      nationality: serializer.fromJson<String>(json['nationality']),
      club: serializer.fromJson<String>(json['club']),
      leagueCode: serializer.fromJson<String>(json['leagueCode']),
      marketValueEur: serializer.fromJson<int>(json['marketValueEur']),
      overall: serializer.fromJson<int>(json['overall']),
      attack: serializer.fromJson<int>(json['attack']),
      support: serializer.fromJson<int>(json['support']),
      defence: serializer.fromJson<int>(json['defence']),
      goalkeeping: serializer.fromJson<int>(json['goalkeeping']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playerId': serializer.toJson<int>(playerId),
      'name': serializer.toJson<String>(name),
      'position': serializer.toJson<String>(position),
      'age': serializer.toJson<int>(age),
      'nationality': serializer.toJson<String>(nationality),
      'club': serializer.toJson<String>(club),
      'leagueCode': serializer.toJson<String>(leagueCode),
      'marketValueEur': serializer.toJson<int>(marketValueEur),
      'overall': serializer.toJson<int>(overall),
      'attack': serializer.toJson<int>(attack),
      'support': serializer.toJson<int>(support),
      'defence': serializer.toJson<int>(defence),
      'goalkeeping': serializer.toJson<int>(goalkeeping),
    };
  }

  Player copyWith({
    int? playerId,
    String? name,
    String? position,
    int? age,
    String? nationality,
    String? club,
    String? leagueCode,
    int? marketValueEur,
    int? overall,
    int? attack,
    int? support,
    int? defence,
    int? goalkeeping,
  }) => Player(
    playerId: playerId ?? this.playerId,
    name: name ?? this.name,
    position: position ?? this.position,
    age: age ?? this.age,
    nationality: nationality ?? this.nationality,
    club: club ?? this.club,
    leagueCode: leagueCode ?? this.leagueCode,
    marketValueEur: marketValueEur ?? this.marketValueEur,
    overall: overall ?? this.overall,
    attack: attack ?? this.attack,
    support: support ?? this.support,
    defence: defence ?? this.defence,
    goalkeeping: goalkeeping ?? this.goalkeeping,
  );
  Player copyWithCompanion(PlayersCompanion data) {
    return Player(
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      name: data.name.present ? data.name.value : this.name,
      position: data.position.present ? data.position.value : this.position,
      age: data.age.present ? data.age.value : this.age,
      nationality: data.nationality.present
          ? data.nationality.value
          : this.nationality,
      club: data.club.present ? data.club.value : this.club,
      leagueCode: data.leagueCode.present
          ? data.leagueCode.value
          : this.leagueCode,
      marketValueEur: data.marketValueEur.present
          ? data.marketValueEur.value
          : this.marketValueEur,
      overall: data.overall.present ? data.overall.value : this.overall,
      attack: data.attack.present ? data.attack.value : this.attack,
      support: data.support.present ? data.support.value : this.support,
      defence: data.defence.present ? data.defence.value : this.defence,
      goalkeeping: data.goalkeeping.present
          ? data.goalkeeping.value
          : this.goalkeeping,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Player(')
          ..write('playerId: $playerId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('age: $age, ')
          ..write('nationality: $nationality, ')
          ..write('club: $club, ')
          ..write('leagueCode: $leagueCode, ')
          ..write('marketValueEur: $marketValueEur, ')
          ..write('overall: $overall, ')
          ..write('attack: $attack, ')
          ..write('support: $support, ')
          ..write('defence: $defence, ')
          ..write('goalkeeping: $goalkeeping')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    playerId,
    name,
    position,
    age,
    nationality,
    club,
    leagueCode,
    marketValueEur,
    overall,
    attack,
    support,
    defence,
    goalkeeping,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Player &&
          other.playerId == this.playerId &&
          other.name == this.name &&
          other.position == this.position &&
          other.age == this.age &&
          other.nationality == this.nationality &&
          other.club == this.club &&
          other.leagueCode == this.leagueCode &&
          other.marketValueEur == this.marketValueEur &&
          other.overall == this.overall &&
          other.attack == this.attack &&
          other.support == this.support &&
          other.defence == this.defence &&
          other.goalkeeping == this.goalkeeping);
}

class PlayersCompanion extends UpdateCompanion<Player> {
  final Value<int> playerId;
  final Value<String> name;
  final Value<String> position;
  final Value<int> age;
  final Value<String> nationality;
  final Value<String> club;
  final Value<String> leagueCode;
  final Value<int> marketValueEur;
  final Value<int> overall;
  final Value<int> attack;
  final Value<int> support;
  final Value<int> defence;
  final Value<int> goalkeeping;
  const PlayersCompanion({
    this.playerId = const Value.absent(),
    this.name = const Value.absent(),
    this.position = const Value.absent(),
    this.age = const Value.absent(),
    this.nationality = const Value.absent(),
    this.club = const Value.absent(),
    this.leagueCode = const Value.absent(),
    this.marketValueEur = const Value.absent(),
    this.overall = const Value.absent(),
    this.attack = const Value.absent(),
    this.support = const Value.absent(),
    this.defence = const Value.absent(),
    this.goalkeeping = const Value.absent(),
  });
  PlayersCompanion.insert({
    this.playerId = const Value.absent(),
    required String name,
    required String position,
    required int age,
    required String nationality,
    required String club,
    this.leagueCode = const Value.absent(),
    required int marketValueEur,
    required int overall,
    required int attack,
    required int support,
    required int defence,
    required int goalkeeping,
  }) : name = Value(name),
       position = Value(position),
       age = Value(age),
       nationality = Value(nationality),
       club = Value(club),
       marketValueEur = Value(marketValueEur),
       overall = Value(overall),
       attack = Value(attack),
       support = Value(support),
       defence = Value(defence),
       goalkeeping = Value(goalkeeping);
  static Insertable<Player> custom({
    Expression<int>? playerId,
    Expression<String>? name,
    Expression<String>? position,
    Expression<int>? age,
    Expression<String>? nationality,
    Expression<String>? club,
    Expression<String>? leagueCode,
    Expression<int>? marketValueEur,
    Expression<int>? overall,
    Expression<int>? attack,
    Expression<int>? support,
    Expression<int>? defence,
    Expression<int>? goalkeeping,
  }) {
    return RawValuesInsertable({
      if (playerId != null) 'player_id': playerId,
      if (name != null) 'name': name,
      if (position != null) 'position': position,
      if (age != null) 'age': age,
      if (nationality != null) 'nationality': nationality,
      if (club != null) 'club': club,
      if (leagueCode != null) 'league_code': leagueCode,
      if (marketValueEur != null) 'market_value_eur': marketValueEur,
      if (overall != null) 'overall': overall,
      if (attack != null) 'attack': attack,
      if (support != null) 'support': support,
      if (defence != null) 'defence': defence,
      if (goalkeeping != null) 'goalkeeping': goalkeeping,
    });
  }

  PlayersCompanion copyWith({
    Value<int>? playerId,
    Value<String>? name,
    Value<String>? position,
    Value<int>? age,
    Value<String>? nationality,
    Value<String>? club,
    Value<String>? leagueCode,
    Value<int>? marketValueEur,
    Value<int>? overall,
    Value<int>? attack,
    Value<int>? support,
    Value<int>? defence,
    Value<int>? goalkeeping,
  }) {
    return PlayersCompanion(
      playerId: playerId ?? this.playerId,
      name: name ?? this.name,
      position: position ?? this.position,
      age: age ?? this.age,
      nationality: nationality ?? this.nationality,
      club: club ?? this.club,
      leagueCode: leagueCode ?? this.leagueCode,
      marketValueEur: marketValueEur ?? this.marketValueEur,
      overall: overall ?? this.overall,
      attack: attack ?? this.attack,
      support: support ?? this.support,
      defence: defence ?? this.defence,
      goalkeeping: goalkeeping ?? this.goalkeeping,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playerId.present) {
      map['player_id'] = Variable<int>(playerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (position.present) {
      map['position'] = Variable<String>(position.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (nationality.present) {
      map['nationality'] = Variable<String>(nationality.value);
    }
    if (club.present) {
      map['club'] = Variable<String>(club.value);
    }
    if (leagueCode.present) {
      map['league_code'] = Variable<String>(leagueCode.value);
    }
    if (marketValueEur.present) {
      map['market_value_eur'] = Variable<int>(marketValueEur.value);
    }
    if (overall.present) {
      map['overall'] = Variable<int>(overall.value);
    }
    if (attack.present) {
      map['attack'] = Variable<int>(attack.value);
    }
    if (support.present) {
      map['support'] = Variable<int>(support.value);
    }
    if (defence.present) {
      map['defence'] = Variable<int>(defence.value);
    }
    if (goalkeeping.present) {
      map['goalkeeping'] = Variable<int>(goalkeeping.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlayersCompanion(')
          ..write('playerId: $playerId, ')
          ..write('name: $name, ')
          ..write('position: $position, ')
          ..write('age: $age, ')
          ..write('nationality: $nationality, ')
          ..write('club: $club, ')
          ..write('leagueCode: $leagueCode, ')
          ..write('marketValueEur: $marketValueEur, ')
          ..write('overall: $overall, ')
          ..write('attack: $attack, ')
          ..write('support: $support, ')
          ..write('defence: $defence, ')
          ..write('goalkeeping: $goalkeeping')
          ..write(')'))
        .toString();
  }
}

class $DatasetVersionsTable extends DatasetVersions
    with TableInfo<$DatasetVersionsTable, DatasetVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DatasetVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _asOfMeta = const VerificationMeta('asOf');
  @override
  late final GeneratedColumn<String> asOf = GeneratedColumn<String>(
    'as_of',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _digestMeta = const VerificationMeta('digest');
  @override
  late final GeneratedColumn<String> digest = GeneratedColumn<String>(
    'digest',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _importedAtMeta = const VerificationMeta(
    'importedAt',
  );
  @override
  late final GeneratedColumn<DateTime> importedAt = GeneratedColumn<DateTime>(
    'imported_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerCountMeta = const VerificationMeta(
    'playerCount',
  );
  @override
  late final GeneratedColumn<int> playerCount = GeneratedColumn<int>(
    'player_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    version,
    asOf,
    digest,
    importedAt,
    playerCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dataset_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DatasetVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('as_of')) {
      context.handle(
        _asOfMeta,
        asOf.isAcceptableOrUnknown(data['as_of']!, _asOfMeta),
      );
    } else if (isInserting) {
      context.missing(_asOfMeta);
    }
    if (data.containsKey('digest')) {
      context.handle(
        _digestMeta,
        digest.isAcceptableOrUnknown(data['digest']!, _digestMeta),
      );
    }
    if (data.containsKey('imported_at')) {
      context.handle(
        _importedAtMeta,
        importedAt.isAcceptableOrUnknown(data['imported_at']!, _importedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_importedAtMeta);
    }
    if (data.containsKey('player_count')) {
      context.handle(
        _playerCountMeta,
        playerCount.isAcceptableOrUnknown(
          data['player_count']!,
          _playerCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_playerCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {version};
  @override
  DatasetVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DatasetVersion(
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      asOf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}as_of'],
      )!,
      digest: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}digest'],
      )!,
      importedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}imported_at'],
      )!,
      playerCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}player_count'],
      )!,
    );
  }

  @override
  $DatasetVersionsTable createAlias(String alias) {
    return $DatasetVersionsTable(attachedDatabase, alias);
  }
}

class DatasetVersion extends DataClass implements Insertable<DatasetVersion> {
  final int version;
  final String asOf;
  final String digest;
  final DateTime importedAt;
  final int playerCount;
  const DatasetVersion({
    required this.version,
    required this.asOf,
    required this.digest,
    required this.importedAt,
    required this.playerCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<int>(version);
    map['as_of'] = Variable<String>(asOf);
    map['digest'] = Variable<String>(digest);
    map['imported_at'] = Variable<DateTime>(importedAt);
    map['player_count'] = Variable<int>(playerCount);
    return map;
  }

  DatasetVersionsCompanion toCompanion(bool nullToAbsent) {
    return DatasetVersionsCompanion(
      version: Value(version),
      asOf: Value(asOf),
      digest: Value(digest),
      importedAt: Value(importedAt),
      playerCount: Value(playerCount),
    );
  }

  factory DatasetVersion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DatasetVersion(
      version: serializer.fromJson<int>(json['version']),
      asOf: serializer.fromJson<String>(json['asOf']),
      digest: serializer.fromJson<String>(json['digest']),
      importedAt: serializer.fromJson<DateTime>(json['importedAt']),
      playerCount: serializer.fromJson<int>(json['playerCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<int>(version),
      'asOf': serializer.toJson<String>(asOf),
      'digest': serializer.toJson<String>(digest),
      'importedAt': serializer.toJson<DateTime>(importedAt),
      'playerCount': serializer.toJson<int>(playerCount),
    };
  }

  DatasetVersion copyWith({
    int? version,
    String? asOf,
    String? digest,
    DateTime? importedAt,
    int? playerCount,
  }) => DatasetVersion(
    version: version ?? this.version,
    asOf: asOf ?? this.asOf,
    digest: digest ?? this.digest,
    importedAt: importedAt ?? this.importedAt,
    playerCount: playerCount ?? this.playerCount,
  );
  DatasetVersion copyWithCompanion(DatasetVersionsCompanion data) {
    return DatasetVersion(
      version: data.version.present ? data.version.value : this.version,
      asOf: data.asOf.present ? data.asOf.value : this.asOf,
      digest: data.digest.present ? data.digest.value : this.digest,
      importedAt: data.importedAt.present
          ? data.importedAt.value
          : this.importedAt,
      playerCount: data.playerCount.present
          ? data.playerCount.value
          : this.playerCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DatasetVersion(')
          ..write('version: $version, ')
          ..write('asOf: $asOf, ')
          ..write('digest: $digest, ')
          ..write('importedAt: $importedAt, ')
          ..write('playerCount: $playerCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(version, asOf, digest, importedAt, playerCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DatasetVersion &&
          other.version == this.version &&
          other.asOf == this.asOf &&
          other.digest == this.digest &&
          other.importedAt == this.importedAt &&
          other.playerCount == this.playerCount);
}

class DatasetVersionsCompanion extends UpdateCompanion<DatasetVersion> {
  final Value<int> version;
  final Value<String> asOf;
  final Value<String> digest;
  final Value<DateTime> importedAt;
  final Value<int> playerCount;
  const DatasetVersionsCompanion({
    this.version = const Value.absent(),
    this.asOf = const Value.absent(),
    this.digest = const Value.absent(),
    this.importedAt = const Value.absent(),
    this.playerCount = const Value.absent(),
  });
  DatasetVersionsCompanion.insert({
    this.version = const Value.absent(),
    required String asOf,
    this.digest = const Value.absent(),
    required DateTime importedAt,
    required int playerCount,
  }) : asOf = Value(asOf),
       importedAt = Value(importedAt),
       playerCount = Value(playerCount);
  static Insertable<DatasetVersion> custom({
    Expression<int>? version,
    Expression<String>? asOf,
    Expression<String>? digest,
    Expression<DateTime>? importedAt,
    Expression<int>? playerCount,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (asOf != null) 'as_of': asOf,
      if (digest != null) 'digest': digest,
      if (importedAt != null) 'imported_at': importedAt,
      if (playerCount != null) 'player_count': playerCount,
    });
  }

  DatasetVersionsCompanion copyWith({
    Value<int>? version,
    Value<String>? asOf,
    Value<String>? digest,
    Value<DateTime>? importedAt,
    Value<int>? playerCount,
  }) {
    return DatasetVersionsCompanion(
      version: version ?? this.version,
      asOf: asOf ?? this.asOf,
      digest: digest ?? this.digest,
      importedAt: importedAt ?? this.importedAt,
      playerCount: playerCount ?? this.playerCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (asOf.present) {
      map['as_of'] = Variable<String>(asOf.value);
    }
    if (digest.present) {
      map['digest'] = Variable<String>(digest.value);
    }
    if (importedAt.present) {
      map['imported_at'] = Variable<DateTime>(importedAt.value);
    }
    if (playerCount.present) {
      map['player_count'] = Variable<int>(playerCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DatasetVersionsCompanion(')
          ..write('version: $version, ')
          ..write('asOf: $asOf, ')
          ..write('digest: $digest, ')
          ..write('importedAt: $importedAt, ')
          ..write('playerCount: $playerCount')
          ..write(')'))
        .toString();
  }
}

class $ClubsTable extends Clubs with TableInfo<$ClubsTable, Club> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClubsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _managerNameMeta = const VerificationMeta(
    'managerName',
  );
  @override
  late final GeneratedColumn<String> managerName = GeneratedColumn<String>(
    'manager_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _crestIndexMeta = const VerificationMeta(
    'crestIndex',
  );
  @override
  late final GeneratedColumn<int> crestIndex = GeneratedColumn<int>(
    'crest_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _formationCodeMeta = const VerificationMeta(
    'formationCode',
  );
  @override
  late final GeneratedColumn<String> formationCode = GeneratedColumn<String>(
    'formation_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('4-3-3'),
  );
  static const VerificationMeta _playingStyleMeta = const VerificationMeta(
    'playingStyle',
  );
  @override
  late final GeneratedColumn<String> playingStyle = GeneratedColumn<String>(
    'playing_style',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('balanced'),
  );
  static const VerificationMeta _mentalityMeta = const VerificationMeta(
    'mentality',
  );
  @override
  late final GeneratedColumn<String> mentality = GeneratedColumn<String>(
    'mentality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('balanced'),
  );
  static const VerificationMeta _coinsMeta = const VerificationMeta('coins');
  @override
  late final GeneratedColumn<int> coins = GeneratedColumn<int>(
    'coins',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isUserMeta = const VerificationMeta('isUser');
  @override
  late final GeneratedColumn<bool> isUser = GeneratedColumn<bool>(
    'is_user',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    managerName,
    crestIndex,
    formationCode,
    playingStyle,
    mentality,
    coins,
    isUser,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clubs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Club> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('manager_name')) {
      context.handle(
        _managerNameMeta,
        managerName.isAcceptableOrUnknown(
          data['manager_name']!,
          _managerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_managerNameMeta);
    }
    if (data.containsKey('crest_index')) {
      context.handle(
        _crestIndexMeta,
        crestIndex.isAcceptableOrUnknown(data['crest_index']!, _crestIndexMeta),
      );
    }
    if (data.containsKey('formation_code')) {
      context.handle(
        _formationCodeMeta,
        formationCode.isAcceptableOrUnknown(
          data['formation_code']!,
          _formationCodeMeta,
        ),
      );
    }
    if (data.containsKey('playing_style')) {
      context.handle(
        _playingStyleMeta,
        playingStyle.isAcceptableOrUnknown(
          data['playing_style']!,
          _playingStyleMeta,
        ),
      );
    }
    if (data.containsKey('mentality')) {
      context.handle(
        _mentalityMeta,
        mentality.isAcceptableOrUnknown(data['mentality']!, _mentalityMeta),
      );
    }
    if (data.containsKey('coins')) {
      context.handle(
        _coinsMeta,
        coins.isAcceptableOrUnknown(data['coins']!, _coinsMeta),
      );
    } else if (isInserting) {
      context.missing(_coinsMeta);
    }
    if (data.containsKey('is_user')) {
      context.handle(
        _isUserMeta,
        isUser.isAcceptableOrUnknown(data['is_user']!, _isUserMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Club map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Club(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      managerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manager_name'],
      )!,
      crestIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}crest_index'],
      )!,
      formationCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}formation_code'],
      )!,
      playingStyle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}playing_style'],
      )!,
      mentality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mentality'],
      )!,
      coins: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}coins'],
      )!,
      isUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ClubsTable createAlias(String alias) {
    return $ClubsTable(attachedDatabase, alias);
  }
}

class Club extends DataClass implements Insertable<Club> {
  final int id;
  final String name;
  final String managerName;
  final int crestIndex;
  final String formationCode;
  final String playingStyle;
  final String mentality;
  final int coins;
  final bool isUser;
  final DateTime createdAt;
  const Club({
    required this.id,
    required this.name,
    required this.managerName,
    required this.crestIndex,
    required this.formationCode,
    required this.playingStyle,
    required this.mentality,
    required this.coins,
    required this.isUser,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['manager_name'] = Variable<String>(managerName);
    map['crest_index'] = Variable<int>(crestIndex);
    map['formation_code'] = Variable<String>(formationCode);
    map['playing_style'] = Variable<String>(playingStyle);
    map['mentality'] = Variable<String>(mentality);
    map['coins'] = Variable<int>(coins);
    map['is_user'] = Variable<bool>(isUser);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ClubsCompanion toCompanion(bool nullToAbsent) {
    return ClubsCompanion(
      id: Value(id),
      name: Value(name),
      managerName: Value(managerName),
      crestIndex: Value(crestIndex),
      formationCode: Value(formationCode),
      playingStyle: Value(playingStyle),
      mentality: Value(mentality),
      coins: Value(coins),
      isUser: Value(isUser),
      createdAt: Value(createdAt),
    );
  }

  factory Club.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Club(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      managerName: serializer.fromJson<String>(json['managerName']),
      crestIndex: serializer.fromJson<int>(json['crestIndex']),
      formationCode: serializer.fromJson<String>(json['formationCode']),
      playingStyle: serializer.fromJson<String>(json['playingStyle']),
      mentality: serializer.fromJson<String>(json['mentality']),
      coins: serializer.fromJson<int>(json['coins']),
      isUser: serializer.fromJson<bool>(json['isUser']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'managerName': serializer.toJson<String>(managerName),
      'crestIndex': serializer.toJson<int>(crestIndex),
      'formationCode': serializer.toJson<String>(formationCode),
      'playingStyle': serializer.toJson<String>(playingStyle),
      'mentality': serializer.toJson<String>(mentality),
      'coins': serializer.toJson<int>(coins),
      'isUser': serializer.toJson<bool>(isUser),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Club copyWith({
    int? id,
    String? name,
    String? managerName,
    int? crestIndex,
    String? formationCode,
    String? playingStyle,
    String? mentality,
    int? coins,
    bool? isUser,
    DateTime? createdAt,
  }) => Club(
    id: id ?? this.id,
    name: name ?? this.name,
    managerName: managerName ?? this.managerName,
    crestIndex: crestIndex ?? this.crestIndex,
    formationCode: formationCode ?? this.formationCode,
    playingStyle: playingStyle ?? this.playingStyle,
    mentality: mentality ?? this.mentality,
    coins: coins ?? this.coins,
    isUser: isUser ?? this.isUser,
    createdAt: createdAt ?? this.createdAt,
  );
  Club copyWithCompanion(ClubsCompanion data) {
    return Club(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      managerName: data.managerName.present
          ? data.managerName.value
          : this.managerName,
      crestIndex: data.crestIndex.present
          ? data.crestIndex.value
          : this.crestIndex,
      formationCode: data.formationCode.present
          ? data.formationCode.value
          : this.formationCode,
      playingStyle: data.playingStyle.present
          ? data.playingStyle.value
          : this.playingStyle,
      mentality: data.mentality.present ? data.mentality.value : this.mentality,
      coins: data.coins.present ? data.coins.value : this.coins,
      isUser: data.isUser.present ? data.isUser.value : this.isUser,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Club(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('managerName: $managerName, ')
          ..write('crestIndex: $crestIndex, ')
          ..write('formationCode: $formationCode, ')
          ..write('playingStyle: $playingStyle, ')
          ..write('mentality: $mentality, ')
          ..write('coins: $coins, ')
          ..write('isUser: $isUser, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    managerName,
    crestIndex,
    formationCode,
    playingStyle,
    mentality,
    coins,
    isUser,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Club &&
          other.id == this.id &&
          other.name == this.name &&
          other.managerName == this.managerName &&
          other.crestIndex == this.crestIndex &&
          other.formationCode == this.formationCode &&
          other.playingStyle == this.playingStyle &&
          other.mentality == this.mentality &&
          other.coins == this.coins &&
          other.isUser == this.isUser &&
          other.createdAt == this.createdAt);
}

class ClubsCompanion extends UpdateCompanion<Club> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> managerName;
  final Value<int> crestIndex;
  final Value<String> formationCode;
  final Value<String> playingStyle;
  final Value<String> mentality;
  final Value<int> coins;
  final Value<bool> isUser;
  final Value<DateTime> createdAt;
  const ClubsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.managerName = const Value.absent(),
    this.crestIndex = const Value.absent(),
    this.formationCode = const Value.absent(),
    this.playingStyle = const Value.absent(),
    this.mentality = const Value.absent(),
    this.coins = const Value.absent(),
    this.isUser = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ClubsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String managerName,
    this.crestIndex = const Value.absent(),
    this.formationCode = const Value.absent(),
    this.playingStyle = const Value.absent(),
    this.mentality = const Value.absent(),
    required int coins,
    this.isUser = const Value.absent(),
    required DateTime createdAt,
  }) : name = Value(name),
       managerName = Value(managerName),
       coins = Value(coins),
       createdAt = Value(createdAt);
  static Insertable<Club> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? managerName,
    Expression<int>? crestIndex,
    Expression<String>? formationCode,
    Expression<String>? playingStyle,
    Expression<String>? mentality,
    Expression<int>? coins,
    Expression<bool>? isUser,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (managerName != null) 'manager_name': managerName,
      if (crestIndex != null) 'crest_index': crestIndex,
      if (formationCode != null) 'formation_code': formationCode,
      if (playingStyle != null) 'playing_style': playingStyle,
      if (mentality != null) 'mentality': mentality,
      if (coins != null) 'coins': coins,
      if (isUser != null) 'is_user': isUser,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ClubsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? managerName,
    Value<int>? crestIndex,
    Value<String>? formationCode,
    Value<String>? playingStyle,
    Value<String>? mentality,
    Value<int>? coins,
    Value<bool>? isUser,
    Value<DateTime>? createdAt,
  }) {
    return ClubsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      managerName: managerName ?? this.managerName,
      crestIndex: crestIndex ?? this.crestIndex,
      formationCode: formationCode ?? this.formationCode,
      playingStyle: playingStyle ?? this.playingStyle,
      mentality: mentality ?? this.mentality,
      coins: coins ?? this.coins,
      isUser: isUser ?? this.isUser,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (managerName.present) {
      map['manager_name'] = Variable<String>(managerName.value);
    }
    if (crestIndex.present) {
      map['crest_index'] = Variable<int>(crestIndex.value);
    }
    if (formationCode.present) {
      map['formation_code'] = Variable<String>(formationCode.value);
    }
    if (playingStyle.present) {
      map['playing_style'] = Variable<String>(playingStyle.value);
    }
    if (mentality.present) {
      map['mentality'] = Variable<String>(mentality.value);
    }
    if (coins.present) {
      map['coins'] = Variable<int>(coins.value);
    }
    if (isUser.present) {
      map['is_user'] = Variable<bool>(isUser.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClubsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('managerName: $managerName, ')
          ..write('crestIndex: $crestIndex, ')
          ..write('formationCode: $formationCode, ')
          ..write('playingStyle: $playingStyle, ')
          ..write('mentality: $mentality, ')
          ..write('coins: $coins, ')
          ..write('isUser: $isUser, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OwnedPlayersTable extends OwnedPlayers
    with TableInfo<$OwnedPlayersTable, OwnedPlayer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OwnedPlayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clubIdMeta = const VerificationMeta('clubId');
  @override
  late final GeneratedColumn<int> clubId = GeneratedColumn<int>(
    'club_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerIdMeta = const VerificationMeta(
    'playerId',
  );
  @override
  late final GeneratedColumn<int> playerId = GeneratedColumn<int>(
    'player_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _upgradeLevelMeta = const VerificationMeta(
    'upgradeLevel',
  );
  @override
  late final GeneratedColumn<int> upgradeLevel = GeneratedColumn<int>(
    'upgrade_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _upgradedAttackMeta = const VerificationMeta(
    'upgradedAttack',
  );
  @override
  late final GeneratedColumn<int> upgradedAttack = GeneratedColumn<int>(
    'upgraded_attack',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _upgradedSupportMeta = const VerificationMeta(
    'upgradedSupport',
  );
  @override
  late final GeneratedColumn<int> upgradedSupport = GeneratedColumn<int>(
    'upgraded_support',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _upgradedDefenceMeta = const VerificationMeta(
    'upgradedDefence',
  );
  @override
  late final GeneratedColumn<int> upgradedDefence = GeneratedColumn<int>(
    'upgraded_defence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _upgradedGoalkeepingMeta =
      const VerificationMeta('upgradedGoalkeeping');
  @override
  late final GeneratedColumn<int> upgradedGoalkeeping = GeneratedColumn<int>(
    'upgraded_goalkeeping',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _staminaPercentMeta = const VerificationMeta(
    'staminaPercent',
  );
  @override
  late final GeneratedColumn<int> staminaPercent = GeneratedColumn<int>(
    'stamina_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _squadSlotMeta = const VerificationMeta(
    'squadSlot',
  );
  @override
  late final GeneratedColumn<int> squadSlot = GeneratedColumn<int>(
    'squad_slot',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('owned'),
  );
  static const VerificationMeta _acquisitionSourceMeta = const VerificationMeta(
    'acquisitionSource',
  );
  @override
  late final GeneratedColumn<String> acquisitionSource =
      GeneratedColumn<String>(
        'acquisition_source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pack'),
      );
  static const VerificationMeta _acquiredAtMeta = const VerificationMeta(
    'acquiredAt',
  );
  @override
  late final GeneratedColumn<DateTime> acquiredAt = GeneratedColumn<DateTime>(
    'acquired_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clubId,
    playerId,
    upgradeLevel,
    upgradedAttack,
    upgradedSupport,
    upgradedDefence,
    upgradedGoalkeeping,
    staminaPercent,
    squadSlot,
    status,
    acquisitionSource,
    acquiredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'owned_players';
  @override
  VerificationContext validateIntegrity(
    Insertable<OwnedPlayer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('club_id')) {
      context.handle(
        _clubIdMeta,
        clubId.isAcceptableOrUnknown(data['club_id']!, _clubIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clubIdMeta);
    }
    if (data.containsKey('player_id')) {
      context.handle(
        _playerIdMeta,
        playerId.isAcceptableOrUnknown(data['player_id']!, _playerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playerIdMeta);
    }
    if (data.containsKey('upgrade_level')) {
      context.handle(
        _upgradeLevelMeta,
        upgradeLevel.isAcceptableOrUnknown(
          data['upgrade_level']!,
          _upgradeLevelMeta,
        ),
      );
    }
    if (data.containsKey('upgraded_attack')) {
      context.handle(
        _upgradedAttackMeta,
        upgradedAttack.isAcceptableOrUnknown(
          data['upgraded_attack']!,
          _upgradedAttackMeta,
        ),
      );
    }
    if (data.containsKey('upgraded_support')) {
      context.handle(
        _upgradedSupportMeta,
        upgradedSupport.isAcceptableOrUnknown(
          data['upgraded_support']!,
          _upgradedSupportMeta,
        ),
      );
    }
    if (data.containsKey('upgraded_defence')) {
      context.handle(
        _upgradedDefenceMeta,
        upgradedDefence.isAcceptableOrUnknown(
          data['upgraded_defence']!,
          _upgradedDefenceMeta,
        ),
      );
    }
    if (data.containsKey('upgraded_goalkeeping')) {
      context.handle(
        _upgradedGoalkeepingMeta,
        upgradedGoalkeeping.isAcceptableOrUnknown(
          data['upgraded_goalkeeping']!,
          _upgradedGoalkeepingMeta,
        ),
      );
    }
    if (data.containsKey('stamina_percent')) {
      context.handle(
        _staminaPercentMeta,
        staminaPercent.isAcceptableOrUnknown(
          data['stamina_percent']!,
          _staminaPercentMeta,
        ),
      );
    }
    if (data.containsKey('squad_slot')) {
      context.handle(
        _squadSlotMeta,
        squadSlot.isAcceptableOrUnknown(data['squad_slot']!, _squadSlotMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('acquisition_source')) {
      context.handle(
        _acquisitionSourceMeta,
        acquisitionSource.isAcceptableOrUnknown(
          data['acquisition_source']!,
          _acquisitionSourceMeta,
        ),
      );
    }
    if (data.containsKey('acquired_at')) {
      context.handle(
        _acquiredAtMeta,
        acquiredAt.isAcceptableOrUnknown(data['acquired_at']!, _acquiredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_acquiredAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OwnedPlayer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OwnedPlayer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clubId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}club_id'],
      )!,
      playerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}player_id'],
      )!,
      upgradeLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upgrade_level'],
      )!,
      upgradedAttack: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upgraded_attack'],
      )!,
      upgradedSupport: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upgraded_support'],
      )!,
      upgradedDefence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upgraded_defence'],
      )!,
      upgradedGoalkeeping: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}upgraded_goalkeeping'],
      )!,
      staminaPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stamina_percent'],
      )!,
      squadSlot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}squad_slot'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      acquisitionSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acquisition_source'],
      )!,
      acquiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acquired_at'],
      )!,
    );
  }

  @override
  $OwnedPlayersTable createAlias(String alias) {
    return $OwnedPlayersTable(attachedDatabase, alias);
  }
}

class OwnedPlayer extends DataClass implements Insertable<OwnedPlayer> {
  final int id;
  final int clubId;
  final int playerId;

  /// Duplicate-merge level (GDD 8.1).
  final int upgradeLevel;

  /// Attribute points added by upgrades (GDD 8.2).
  final int upgradedAttack;
  final int upgradedSupport;
  final int upgradedDefence;
  final int upgradedGoalkeeping;
  final int staminaPercent;
  final int? squadSlot;

  /// owned | sold | merged (sold/merged rows kept for history).
  final String status;
  final String acquisitionSource;
  final DateTime acquiredAt;
  const OwnedPlayer({
    required this.id,
    required this.clubId,
    required this.playerId,
    required this.upgradeLevel,
    required this.upgradedAttack,
    required this.upgradedSupport,
    required this.upgradedDefence,
    required this.upgradedGoalkeeping,
    required this.staminaPercent,
    this.squadSlot,
    required this.status,
    required this.acquisitionSource,
    required this.acquiredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['club_id'] = Variable<int>(clubId);
    map['player_id'] = Variable<int>(playerId);
    map['upgrade_level'] = Variable<int>(upgradeLevel);
    map['upgraded_attack'] = Variable<int>(upgradedAttack);
    map['upgraded_support'] = Variable<int>(upgradedSupport);
    map['upgraded_defence'] = Variable<int>(upgradedDefence);
    map['upgraded_goalkeeping'] = Variable<int>(upgradedGoalkeeping);
    map['stamina_percent'] = Variable<int>(staminaPercent);
    if (!nullToAbsent || squadSlot != null) {
      map['squad_slot'] = Variable<int>(squadSlot);
    }
    map['status'] = Variable<String>(status);
    map['acquisition_source'] = Variable<String>(acquisitionSource);
    map['acquired_at'] = Variable<DateTime>(acquiredAt);
    return map;
  }

  OwnedPlayersCompanion toCompanion(bool nullToAbsent) {
    return OwnedPlayersCompanion(
      id: Value(id),
      clubId: Value(clubId),
      playerId: Value(playerId),
      upgradeLevel: Value(upgradeLevel),
      upgradedAttack: Value(upgradedAttack),
      upgradedSupport: Value(upgradedSupport),
      upgradedDefence: Value(upgradedDefence),
      upgradedGoalkeeping: Value(upgradedGoalkeeping),
      staminaPercent: Value(staminaPercent),
      squadSlot: squadSlot == null && nullToAbsent
          ? const Value.absent()
          : Value(squadSlot),
      status: Value(status),
      acquisitionSource: Value(acquisitionSource),
      acquiredAt: Value(acquiredAt),
    );
  }

  factory OwnedPlayer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OwnedPlayer(
      id: serializer.fromJson<int>(json['id']),
      clubId: serializer.fromJson<int>(json['clubId']),
      playerId: serializer.fromJson<int>(json['playerId']),
      upgradeLevel: serializer.fromJson<int>(json['upgradeLevel']),
      upgradedAttack: serializer.fromJson<int>(json['upgradedAttack']),
      upgradedSupport: serializer.fromJson<int>(json['upgradedSupport']),
      upgradedDefence: serializer.fromJson<int>(json['upgradedDefence']),
      upgradedGoalkeeping: serializer.fromJson<int>(
        json['upgradedGoalkeeping'],
      ),
      staminaPercent: serializer.fromJson<int>(json['staminaPercent']),
      squadSlot: serializer.fromJson<int?>(json['squadSlot']),
      status: serializer.fromJson<String>(json['status']),
      acquisitionSource: serializer.fromJson<String>(json['acquisitionSource']),
      acquiredAt: serializer.fromJson<DateTime>(json['acquiredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clubId': serializer.toJson<int>(clubId),
      'playerId': serializer.toJson<int>(playerId),
      'upgradeLevel': serializer.toJson<int>(upgradeLevel),
      'upgradedAttack': serializer.toJson<int>(upgradedAttack),
      'upgradedSupport': serializer.toJson<int>(upgradedSupport),
      'upgradedDefence': serializer.toJson<int>(upgradedDefence),
      'upgradedGoalkeeping': serializer.toJson<int>(upgradedGoalkeeping),
      'staminaPercent': serializer.toJson<int>(staminaPercent),
      'squadSlot': serializer.toJson<int?>(squadSlot),
      'status': serializer.toJson<String>(status),
      'acquisitionSource': serializer.toJson<String>(acquisitionSource),
      'acquiredAt': serializer.toJson<DateTime>(acquiredAt),
    };
  }

  OwnedPlayer copyWith({
    int? id,
    int? clubId,
    int? playerId,
    int? upgradeLevel,
    int? upgradedAttack,
    int? upgradedSupport,
    int? upgradedDefence,
    int? upgradedGoalkeeping,
    int? staminaPercent,
    Value<int?> squadSlot = const Value.absent(),
    String? status,
    String? acquisitionSource,
    DateTime? acquiredAt,
  }) => OwnedPlayer(
    id: id ?? this.id,
    clubId: clubId ?? this.clubId,
    playerId: playerId ?? this.playerId,
    upgradeLevel: upgradeLevel ?? this.upgradeLevel,
    upgradedAttack: upgradedAttack ?? this.upgradedAttack,
    upgradedSupport: upgradedSupport ?? this.upgradedSupport,
    upgradedDefence: upgradedDefence ?? this.upgradedDefence,
    upgradedGoalkeeping: upgradedGoalkeeping ?? this.upgradedGoalkeeping,
    staminaPercent: staminaPercent ?? this.staminaPercent,
    squadSlot: squadSlot.present ? squadSlot.value : this.squadSlot,
    status: status ?? this.status,
    acquisitionSource: acquisitionSource ?? this.acquisitionSource,
    acquiredAt: acquiredAt ?? this.acquiredAt,
  );
  OwnedPlayer copyWithCompanion(OwnedPlayersCompanion data) {
    return OwnedPlayer(
      id: data.id.present ? data.id.value : this.id,
      clubId: data.clubId.present ? data.clubId.value : this.clubId,
      playerId: data.playerId.present ? data.playerId.value : this.playerId,
      upgradeLevel: data.upgradeLevel.present
          ? data.upgradeLevel.value
          : this.upgradeLevel,
      upgradedAttack: data.upgradedAttack.present
          ? data.upgradedAttack.value
          : this.upgradedAttack,
      upgradedSupport: data.upgradedSupport.present
          ? data.upgradedSupport.value
          : this.upgradedSupport,
      upgradedDefence: data.upgradedDefence.present
          ? data.upgradedDefence.value
          : this.upgradedDefence,
      upgradedGoalkeeping: data.upgradedGoalkeeping.present
          ? data.upgradedGoalkeeping.value
          : this.upgradedGoalkeeping,
      staminaPercent: data.staminaPercent.present
          ? data.staminaPercent.value
          : this.staminaPercent,
      squadSlot: data.squadSlot.present ? data.squadSlot.value : this.squadSlot,
      status: data.status.present ? data.status.value : this.status,
      acquisitionSource: data.acquisitionSource.present
          ? data.acquisitionSource.value
          : this.acquisitionSource,
      acquiredAt: data.acquiredAt.present
          ? data.acquiredAt.value
          : this.acquiredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OwnedPlayer(')
          ..write('id: $id, ')
          ..write('clubId: $clubId, ')
          ..write('playerId: $playerId, ')
          ..write('upgradeLevel: $upgradeLevel, ')
          ..write('upgradedAttack: $upgradedAttack, ')
          ..write('upgradedSupport: $upgradedSupport, ')
          ..write('upgradedDefence: $upgradedDefence, ')
          ..write('upgradedGoalkeeping: $upgradedGoalkeeping, ')
          ..write('staminaPercent: $staminaPercent, ')
          ..write('squadSlot: $squadSlot, ')
          ..write('status: $status, ')
          ..write('acquisitionSource: $acquisitionSource, ')
          ..write('acquiredAt: $acquiredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clubId,
    playerId,
    upgradeLevel,
    upgradedAttack,
    upgradedSupport,
    upgradedDefence,
    upgradedGoalkeeping,
    staminaPercent,
    squadSlot,
    status,
    acquisitionSource,
    acquiredAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OwnedPlayer &&
          other.id == this.id &&
          other.clubId == this.clubId &&
          other.playerId == this.playerId &&
          other.upgradeLevel == this.upgradeLevel &&
          other.upgradedAttack == this.upgradedAttack &&
          other.upgradedSupport == this.upgradedSupport &&
          other.upgradedDefence == this.upgradedDefence &&
          other.upgradedGoalkeeping == this.upgradedGoalkeeping &&
          other.staminaPercent == this.staminaPercent &&
          other.squadSlot == this.squadSlot &&
          other.status == this.status &&
          other.acquisitionSource == this.acquisitionSource &&
          other.acquiredAt == this.acquiredAt);
}

class OwnedPlayersCompanion extends UpdateCompanion<OwnedPlayer> {
  final Value<int> id;
  final Value<int> clubId;
  final Value<int> playerId;
  final Value<int> upgradeLevel;
  final Value<int> upgradedAttack;
  final Value<int> upgradedSupport;
  final Value<int> upgradedDefence;
  final Value<int> upgradedGoalkeeping;
  final Value<int> staminaPercent;
  final Value<int?> squadSlot;
  final Value<String> status;
  final Value<String> acquisitionSource;
  final Value<DateTime> acquiredAt;
  const OwnedPlayersCompanion({
    this.id = const Value.absent(),
    this.clubId = const Value.absent(),
    this.playerId = const Value.absent(),
    this.upgradeLevel = const Value.absent(),
    this.upgradedAttack = const Value.absent(),
    this.upgradedSupport = const Value.absent(),
    this.upgradedDefence = const Value.absent(),
    this.upgradedGoalkeeping = const Value.absent(),
    this.staminaPercent = const Value.absent(),
    this.squadSlot = const Value.absent(),
    this.status = const Value.absent(),
    this.acquisitionSource = const Value.absent(),
    this.acquiredAt = const Value.absent(),
  });
  OwnedPlayersCompanion.insert({
    this.id = const Value.absent(),
    required int clubId,
    required int playerId,
    this.upgradeLevel = const Value.absent(),
    this.upgradedAttack = const Value.absent(),
    this.upgradedSupport = const Value.absent(),
    this.upgradedDefence = const Value.absent(),
    this.upgradedGoalkeeping = const Value.absent(),
    this.staminaPercent = const Value.absent(),
    this.squadSlot = const Value.absent(),
    this.status = const Value.absent(),
    this.acquisitionSource = const Value.absent(),
    required DateTime acquiredAt,
  }) : clubId = Value(clubId),
       playerId = Value(playerId),
       acquiredAt = Value(acquiredAt);
  static Insertable<OwnedPlayer> custom({
    Expression<int>? id,
    Expression<int>? clubId,
    Expression<int>? playerId,
    Expression<int>? upgradeLevel,
    Expression<int>? upgradedAttack,
    Expression<int>? upgradedSupport,
    Expression<int>? upgradedDefence,
    Expression<int>? upgradedGoalkeeping,
    Expression<int>? staminaPercent,
    Expression<int>? squadSlot,
    Expression<String>? status,
    Expression<String>? acquisitionSource,
    Expression<DateTime>? acquiredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clubId != null) 'club_id': clubId,
      if (playerId != null) 'player_id': playerId,
      if (upgradeLevel != null) 'upgrade_level': upgradeLevel,
      if (upgradedAttack != null) 'upgraded_attack': upgradedAttack,
      if (upgradedSupport != null) 'upgraded_support': upgradedSupport,
      if (upgradedDefence != null) 'upgraded_defence': upgradedDefence,
      if (upgradedGoalkeeping != null)
        'upgraded_goalkeeping': upgradedGoalkeeping,
      if (staminaPercent != null) 'stamina_percent': staminaPercent,
      if (squadSlot != null) 'squad_slot': squadSlot,
      if (status != null) 'status': status,
      if (acquisitionSource != null) 'acquisition_source': acquisitionSource,
      if (acquiredAt != null) 'acquired_at': acquiredAt,
    });
  }

  OwnedPlayersCompanion copyWith({
    Value<int>? id,
    Value<int>? clubId,
    Value<int>? playerId,
    Value<int>? upgradeLevel,
    Value<int>? upgradedAttack,
    Value<int>? upgradedSupport,
    Value<int>? upgradedDefence,
    Value<int>? upgradedGoalkeeping,
    Value<int>? staminaPercent,
    Value<int?>? squadSlot,
    Value<String>? status,
    Value<String>? acquisitionSource,
    Value<DateTime>? acquiredAt,
  }) {
    return OwnedPlayersCompanion(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      playerId: playerId ?? this.playerId,
      upgradeLevel: upgradeLevel ?? this.upgradeLevel,
      upgradedAttack: upgradedAttack ?? this.upgradedAttack,
      upgradedSupport: upgradedSupport ?? this.upgradedSupport,
      upgradedDefence: upgradedDefence ?? this.upgradedDefence,
      upgradedGoalkeeping: upgradedGoalkeeping ?? this.upgradedGoalkeeping,
      staminaPercent: staminaPercent ?? this.staminaPercent,
      squadSlot: squadSlot ?? this.squadSlot,
      status: status ?? this.status,
      acquisitionSource: acquisitionSource ?? this.acquisitionSource,
      acquiredAt: acquiredAt ?? this.acquiredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clubId.present) {
      map['club_id'] = Variable<int>(clubId.value);
    }
    if (playerId.present) {
      map['player_id'] = Variable<int>(playerId.value);
    }
    if (upgradeLevel.present) {
      map['upgrade_level'] = Variable<int>(upgradeLevel.value);
    }
    if (upgradedAttack.present) {
      map['upgraded_attack'] = Variable<int>(upgradedAttack.value);
    }
    if (upgradedSupport.present) {
      map['upgraded_support'] = Variable<int>(upgradedSupport.value);
    }
    if (upgradedDefence.present) {
      map['upgraded_defence'] = Variable<int>(upgradedDefence.value);
    }
    if (upgradedGoalkeeping.present) {
      map['upgraded_goalkeeping'] = Variable<int>(upgradedGoalkeeping.value);
    }
    if (staminaPercent.present) {
      map['stamina_percent'] = Variable<int>(staminaPercent.value);
    }
    if (squadSlot.present) {
      map['squad_slot'] = Variable<int>(squadSlot.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (acquisitionSource.present) {
      map['acquisition_source'] = Variable<String>(acquisitionSource.value);
    }
    if (acquiredAt.present) {
      map['acquired_at'] = Variable<DateTime>(acquiredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OwnedPlayersCompanion(')
          ..write('id: $id, ')
          ..write('clubId: $clubId, ')
          ..write('playerId: $playerId, ')
          ..write('upgradeLevel: $upgradeLevel, ')
          ..write('upgradedAttack: $upgradedAttack, ')
          ..write('upgradedSupport: $upgradedSupport, ')
          ..write('upgradedDefence: $upgradedDefence, ')
          ..write('upgradedGoalkeeping: $upgradedGoalkeeping, ')
          ..write('staminaPercent: $staminaPercent, ')
          ..write('squadSlot: $squadSlot, ')
          ..write('status: $status, ')
          ..write('acquisitionSource: $acquisitionSource, ')
          ..write('acquiredAt: $acquiredAt')
          ..write(')'))
        .toString();
  }
}

class $PacksTable extends Packs with TableInfo<$PacksTable, Pack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PacksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clubIdMeta = const VerificationMeta('clubId');
  @override
  late final GeneratedColumn<int> clubId = GeneratedColumn<int>(
    'club_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeValueMeta = const VerificationMeta(
    'scopeValue',
  );
  @override
  late final GeneratedColumn<String> scopeValue = GeneratedColumn<String>(
    'scope_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('starting'),
  );
  static const VerificationMeta _openedMeta = const VerificationMeta('opened');
  @override
  late final GeneratedColumn<bool> opened = GeneratedColumn<bool>(
    'opened',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("opened" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clubId,
    category,
    scopeValue,
    price,
    source,
    opened,
    openedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'packs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('club_id')) {
      context.handle(
        _clubIdMeta,
        clubId.isAcceptableOrUnknown(data['club_id']!, _clubIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clubIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('scope_value')) {
      context.handle(
        _scopeValueMeta,
        scopeValue.isAcceptableOrUnknown(data['scope_value']!, _scopeValueMeta),
      );
    }
    if (data.containsKey('price')) {
      context.handle(
        _priceMeta,
        price.isAcceptableOrUnknown(data['price']!, _priceMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('opened')) {
      context.handle(
        _openedMeta,
        opened.isAcceptableOrUnknown(data['opened']!, _openedMeta),
      );
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pack(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clubId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}club_id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      scopeValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_value'],
      ),
      price: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      opened: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}opened'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opened_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PacksTable createAlias(String alias) {
    return $PacksTable(attachedDatabase, alias);
  }
}

class Pack extends DataClass implements Insertable<Pack> {
  final int id;
  final int clubId;
  final String category;
  final String? scopeValue;
  final int price;
  final String source;
  final bool opened;
  final DateTime? openedAt;
  final DateTime createdAt;
  const Pack({
    required this.id,
    required this.clubId,
    required this.category,
    this.scopeValue,
    required this.price,
    required this.source,
    required this.opened,
    this.openedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['club_id'] = Variable<int>(clubId);
    map['category'] = Variable<String>(category);
    if (!nullToAbsent || scopeValue != null) {
      map['scope_value'] = Variable<String>(scopeValue);
    }
    map['price'] = Variable<int>(price);
    map['source'] = Variable<String>(source);
    map['opened'] = Variable<bool>(opened);
    if (!nullToAbsent || openedAt != null) {
      map['opened_at'] = Variable<DateTime>(openedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PacksCompanion toCompanion(bool nullToAbsent) {
    return PacksCompanion(
      id: Value(id),
      clubId: Value(clubId),
      category: Value(category),
      scopeValue: scopeValue == null && nullToAbsent
          ? const Value.absent()
          : Value(scopeValue),
      price: Value(price),
      source: Value(source),
      opened: Value(opened),
      openedAt: openedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(openedAt),
      createdAt: Value(createdAt),
    );
  }

  factory Pack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pack(
      id: serializer.fromJson<int>(json['id']),
      clubId: serializer.fromJson<int>(json['clubId']),
      category: serializer.fromJson<String>(json['category']),
      scopeValue: serializer.fromJson<String?>(json['scopeValue']),
      price: serializer.fromJson<int>(json['price']),
      source: serializer.fromJson<String>(json['source']),
      opened: serializer.fromJson<bool>(json['opened']),
      openedAt: serializer.fromJson<DateTime?>(json['openedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clubId': serializer.toJson<int>(clubId),
      'category': serializer.toJson<String>(category),
      'scopeValue': serializer.toJson<String?>(scopeValue),
      'price': serializer.toJson<int>(price),
      'source': serializer.toJson<String>(source),
      'opened': serializer.toJson<bool>(opened),
      'openedAt': serializer.toJson<DateTime?>(openedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Pack copyWith({
    int? id,
    int? clubId,
    String? category,
    Value<String?> scopeValue = const Value.absent(),
    int? price,
    String? source,
    bool? opened,
    Value<DateTime?> openedAt = const Value.absent(),
    DateTime? createdAt,
  }) => Pack(
    id: id ?? this.id,
    clubId: clubId ?? this.clubId,
    category: category ?? this.category,
    scopeValue: scopeValue.present ? scopeValue.value : this.scopeValue,
    price: price ?? this.price,
    source: source ?? this.source,
    opened: opened ?? this.opened,
    openedAt: openedAt.present ? openedAt.value : this.openedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  Pack copyWithCompanion(PacksCompanion data) {
    return Pack(
      id: data.id.present ? data.id.value : this.id,
      clubId: data.clubId.present ? data.clubId.value : this.clubId,
      category: data.category.present ? data.category.value : this.category,
      scopeValue: data.scopeValue.present
          ? data.scopeValue.value
          : this.scopeValue,
      price: data.price.present ? data.price.value : this.price,
      source: data.source.present ? data.source.value : this.source,
      opened: data.opened.present ? data.opened.value : this.opened,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pack(')
          ..write('id: $id, ')
          ..write('clubId: $clubId, ')
          ..write('category: $category, ')
          ..write('scopeValue: $scopeValue, ')
          ..write('price: $price, ')
          ..write('source: $source, ')
          ..write('opened: $opened, ')
          ..write('openedAt: $openedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clubId,
    category,
    scopeValue,
    price,
    source,
    opened,
    openedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pack &&
          other.id == this.id &&
          other.clubId == this.clubId &&
          other.category == this.category &&
          other.scopeValue == this.scopeValue &&
          other.price == this.price &&
          other.source == this.source &&
          other.opened == this.opened &&
          other.openedAt == this.openedAt &&
          other.createdAt == this.createdAt);
}

class PacksCompanion extends UpdateCompanion<Pack> {
  final Value<int> id;
  final Value<int> clubId;
  final Value<String> category;
  final Value<String?> scopeValue;
  final Value<int> price;
  final Value<String> source;
  final Value<bool> opened;
  final Value<DateTime?> openedAt;
  final Value<DateTime> createdAt;
  const PacksCompanion({
    this.id = const Value.absent(),
    this.clubId = const Value.absent(),
    this.category = const Value.absent(),
    this.scopeValue = const Value.absent(),
    this.price = const Value.absent(),
    this.source = const Value.absent(),
    this.opened = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PacksCompanion.insert({
    this.id = const Value.absent(),
    required int clubId,
    required String category,
    this.scopeValue = const Value.absent(),
    this.price = const Value.absent(),
    this.source = const Value.absent(),
    this.opened = const Value.absent(),
    this.openedAt = const Value.absent(),
    required DateTime createdAt,
  }) : clubId = Value(clubId),
       category = Value(category),
       createdAt = Value(createdAt);
  static Insertable<Pack> custom({
    Expression<int>? id,
    Expression<int>? clubId,
    Expression<String>? category,
    Expression<String>? scopeValue,
    Expression<int>? price,
    Expression<String>? source,
    Expression<bool>? opened,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clubId != null) 'club_id': clubId,
      if (category != null) 'category': category,
      if (scopeValue != null) 'scope_value': scopeValue,
      if (price != null) 'price': price,
      if (source != null) 'source': source,
      if (opened != null) 'opened': opened,
      if (openedAt != null) 'opened_at': openedAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PacksCompanion copyWith({
    Value<int>? id,
    Value<int>? clubId,
    Value<String>? category,
    Value<String?>? scopeValue,
    Value<int>? price,
    Value<String>? source,
    Value<bool>? opened,
    Value<DateTime?>? openedAt,
    Value<DateTime>? createdAt,
  }) {
    return PacksCompanion(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      category: category ?? this.category,
      scopeValue: scopeValue ?? this.scopeValue,
      price: price ?? this.price,
      source: source ?? this.source,
      opened: opened ?? this.opened,
      openedAt: openedAt ?? this.openedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clubId.present) {
      map['club_id'] = Variable<int>(clubId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (scopeValue.present) {
      map['scope_value'] = Variable<String>(scopeValue.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (opened.present) {
      map['opened'] = Variable<bool>(opened.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PacksCompanion(')
          ..write('id: $id, ')
          ..write('clubId: $clubId, ')
          ..write('category: $category, ')
          ..write('scopeValue: $scopeValue, ')
          ..write('price: $price, ')
          ..write('source: $source, ')
          ..write('opened: $opened, ')
          ..write('openedAt: $openedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CoinTransactionsTable extends CoinTransactions
    with TableInfo<$CoinTransactionsTable, CoinTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoinTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _clubIdMeta = const VerificationMeta('clubId');
  @override
  late final GeneratedColumn<int> clubId = GeneratedColumn<int>(
    'club_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceAfterMeta = const VerificationMeta(
    'balanceAfter',
  );
  @override
  late final GeneratedColumn<int> balanceAfter = GeneratedColumn<int>(
    'balance_after',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clubId,
    amount,
    balanceAfter,
    reason,
    detail,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coin_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoinTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('club_id')) {
      context.handle(
        _clubIdMeta,
        clubId.isAcceptableOrUnknown(data['club_id']!, _clubIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clubIdMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('balance_after')) {
      context.handle(
        _balanceAfterMeta,
        balanceAfter.isAcceptableOrUnknown(
          data['balance_after']!,
          _balanceAfterMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_balanceAfterMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoinTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoinTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      clubId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}club_id'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      balanceAfter: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_after'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CoinTransactionsTable createAlias(String alias) {
    return $CoinTransactionsTable(attachedDatabase, alias);
  }
}

class CoinTransaction extends DataClass implements Insertable<CoinTransaction> {
  final int id;
  final int clubId;
  final int amount;
  final int balanceAfter;
  final String reason;
  final String? detail;
  final DateTime createdAt;
  const CoinTransaction({
    required this.id,
    required this.clubId,
    required this.amount,
    required this.balanceAfter,
    required this.reason,
    this.detail,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['club_id'] = Variable<int>(clubId);
    map['amount'] = Variable<int>(amount);
    map['balance_after'] = Variable<int>(balanceAfter);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CoinTransactionsCompanion toCompanion(bool nullToAbsent) {
    return CoinTransactionsCompanion(
      id: Value(id),
      clubId: Value(clubId),
      amount: Value(amount),
      balanceAfter: Value(balanceAfter),
      reason: Value(reason),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      createdAt: Value(createdAt),
    );
  }

  factory CoinTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoinTransaction(
      id: serializer.fromJson<int>(json['id']),
      clubId: serializer.fromJson<int>(json['clubId']),
      amount: serializer.fromJson<int>(json['amount']),
      balanceAfter: serializer.fromJson<int>(json['balanceAfter']),
      reason: serializer.fromJson<String>(json['reason']),
      detail: serializer.fromJson<String?>(json['detail']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'clubId': serializer.toJson<int>(clubId),
      'amount': serializer.toJson<int>(amount),
      'balanceAfter': serializer.toJson<int>(balanceAfter),
      'reason': serializer.toJson<String>(reason),
      'detail': serializer.toJson<String?>(detail),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CoinTransaction copyWith({
    int? id,
    int? clubId,
    int? amount,
    int? balanceAfter,
    String? reason,
    Value<String?> detail = const Value.absent(),
    DateTime? createdAt,
  }) => CoinTransaction(
    id: id ?? this.id,
    clubId: clubId ?? this.clubId,
    amount: amount ?? this.amount,
    balanceAfter: balanceAfter ?? this.balanceAfter,
    reason: reason ?? this.reason,
    detail: detail.present ? detail.value : this.detail,
    createdAt: createdAt ?? this.createdAt,
  );
  CoinTransaction copyWithCompanion(CoinTransactionsCompanion data) {
    return CoinTransaction(
      id: data.id.present ? data.id.value : this.id,
      clubId: data.clubId.present ? data.clubId.value : this.clubId,
      amount: data.amount.present ? data.amount.value : this.amount,
      balanceAfter: data.balanceAfter.present
          ? data.balanceAfter.value
          : this.balanceAfter,
      reason: data.reason.present ? data.reason.value : this.reason,
      detail: data.detail.present ? data.detail.value : this.detail,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoinTransaction(')
          ..write('id: $id, ')
          ..write('clubId: $clubId, ')
          ..write('amount: $amount, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('reason: $reason, ')
          ..write('detail: $detail, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, clubId, amount, balanceAfter, reason, detail, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoinTransaction &&
          other.id == this.id &&
          other.clubId == this.clubId &&
          other.amount == this.amount &&
          other.balanceAfter == this.balanceAfter &&
          other.reason == this.reason &&
          other.detail == this.detail &&
          other.createdAt == this.createdAt);
}

class CoinTransactionsCompanion extends UpdateCompanion<CoinTransaction> {
  final Value<int> id;
  final Value<int> clubId;
  final Value<int> amount;
  final Value<int> balanceAfter;
  final Value<String> reason;
  final Value<String?> detail;
  final Value<DateTime> createdAt;
  const CoinTransactionsCompanion({
    this.id = const Value.absent(),
    this.clubId = const Value.absent(),
    this.amount = const Value.absent(),
    this.balanceAfter = const Value.absent(),
    this.reason = const Value.absent(),
    this.detail = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CoinTransactionsCompanion.insert({
    this.id = const Value.absent(),
    required int clubId,
    required int amount,
    required int balanceAfter,
    required String reason,
    this.detail = const Value.absent(),
    required DateTime createdAt,
  }) : clubId = Value(clubId),
       amount = Value(amount),
       balanceAfter = Value(balanceAfter),
       reason = Value(reason),
       createdAt = Value(createdAt);
  static Insertable<CoinTransaction> custom({
    Expression<int>? id,
    Expression<int>? clubId,
    Expression<int>? amount,
    Expression<int>? balanceAfter,
    Expression<String>? reason,
    Expression<String>? detail,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clubId != null) 'club_id': clubId,
      if (amount != null) 'amount': amount,
      if (balanceAfter != null) 'balance_after': balanceAfter,
      if (reason != null) 'reason': reason,
      if (detail != null) 'detail': detail,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CoinTransactionsCompanion copyWith({
    Value<int>? id,
    Value<int>? clubId,
    Value<int>? amount,
    Value<int>? balanceAfter,
    Value<String>? reason,
    Value<String?>? detail,
    Value<DateTime>? createdAt,
  }) {
    return CoinTransactionsCompanion(
      id: id ?? this.id,
      clubId: clubId ?? this.clubId,
      amount: amount ?? this.amount,
      balanceAfter: balanceAfter ?? this.balanceAfter,
      reason: reason ?? this.reason,
      detail: detail ?? this.detail,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (clubId.present) {
      map['club_id'] = Variable<int>(clubId.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (balanceAfter.present) {
      map['balance_after'] = Variable<int>(balanceAfter.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoinTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('clubId: $clubId, ')
          ..write('amount: $amount, ')
          ..write('balanceAfter: $balanceAfter, ')
          ..write('reason: $reason, ')
          ..write('detail: $detail, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PlayersTable players = $PlayersTable(this);
  late final $DatasetVersionsTable datasetVersions = $DatasetVersionsTable(
    this,
  );
  late final $ClubsTable clubs = $ClubsTable(this);
  late final $OwnedPlayersTable ownedPlayers = $OwnedPlayersTable(this);
  late final $PacksTable packs = $PacksTable(this);
  late final $CoinTransactionsTable coinTransactions = $CoinTransactionsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    players,
    datasetVersions,
    clubs,
    ownedPlayers,
    packs,
    coinTransactions,
  ];
}

typedef $$PlayersTableCreateCompanionBuilder = PlayersCompanion Function({
  Value<int> playerId,
  required String name,
  required String position,
  required int age,
  required String nationality,
  required String club,
  Value<String> leagueCode,
  required int marketValueEur,
  required int overall,
  required int attack,
  required int support,
  required int defence,
  required int goalkeeping,
});
typedef $$PlayersTableUpdateCompanionBuilder = PlayersCompanion Function({
  Value<int> playerId,
  Value<String> name,
  Value<String> position,
  Value<int> age,
  Value<String> nationality,
  Value<String> club,
  Value<String> leagueCode,
  Value<int> marketValueEur,
  Value<int> overall,
  Value<int> attack,
  Value<int> support,
  Value<int> defence,
  Value<int> goalkeeping,
});

class $$PlayersTableFilterComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nationality => $composableBuilder(
    column: $table.nationality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get club => $composableBuilder(
    column: $table.club,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leagueCode => $composableBuilder(
    column: $table.leagueCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get marketValueEur => $composableBuilder(
    column: $table.marketValueEur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overall => $composableBuilder(
    column: $table.overall,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attack => $composableBuilder(
    column: $table.attack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get support => $composableBuilder(
    column: $table.support,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defence => $composableBuilder(
    column: $table.defence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalkeeping => $composableBuilder(
    column: $table.goalkeeping,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nationality => $composableBuilder(
    column: $table.nationality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get club => $composableBuilder(
    column: $table.club,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leagueCode => $composableBuilder(
    column: $table.leagueCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get marketValueEur => $composableBuilder(
    column: $table.marketValueEur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overall => $composableBuilder(
    column: $table.overall,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attack => $composableBuilder(
    column: $table.attack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get support => $composableBuilder(
    column: $table.support,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defence => $composableBuilder(
    column: $table.defence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalkeeping => $composableBuilder(
    column: $table.goalkeeping,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlayersTable> {
  $$PlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get playerId =>
      $composableBuilder(column: $table.playerId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<String> get nationality => $composableBuilder(
    column: $table.nationality,
    builder: (column) => column,
  );

  GeneratedColumn<String> get club =>
      $composableBuilder(column: $table.club, builder: (column) => column);

  GeneratedColumn<String> get leagueCode => $composableBuilder(
    column: $table.leagueCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get marketValueEur => $composableBuilder(
    column: $table.marketValueEur,
    builder: (column) => column,
  );

  GeneratedColumn<int> get overall =>
      $composableBuilder(column: $table.overall, builder: (column) => column);

  GeneratedColumn<int> get attack =>
      $composableBuilder(column: $table.attack, builder: (column) => column);

  GeneratedColumn<int> get support =>
      $composableBuilder(column: $table.support, builder: (column) => column);

  GeneratedColumn<int> get defence =>
      $composableBuilder(column: $table.defence, builder: (column) => column);

  GeneratedColumn<int> get goalkeeping => $composableBuilder(
    column: $table.goalkeeping,
    builder: (column) => column,
  );
}

class $$PlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlayersTable,
          Player,
          $$PlayersTableFilterComposer,
          $$PlayersTableOrderingComposer,
          $$PlayersTableAnnotationComposer,
          $$PlayersTableCreateCompanionBuilder,
          $$PlayersTableUpdateCompanionBuilder,
          (Player, BaseReferences<_$AppDatabase, $PlayersTable, Player>),
          Player,
          PrefetchHooks Function()
        > {
  $$PlayersTableTableManager(_$AppDatabase db, $PlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> position = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<String> nationality = const Value.absent(),
                Value<String> club = const Value.absent(),
                Value<String> leagueCode = const Value.absent(),
                Value<int> marketValueEur = const Value.absent(),
                Value<int> overall = const Value.absent(),
                Value<int> attack = const Value.absent(),
                Value<int> support = const Value.absent(),
                Value<int> defence = const Value.absent(),
                Value<int> goalkeeping = const Value.absent(),
              }) => PlayersCompanion(
                playerId: playerId,
                name: name,
                position: position,
                age: age,
                nationality: nationality,
                club: club,
                leagueCode: leagueCode,
                marketValueEur: marketValueEur,
                overall: overall,
                attack: attack,
                support: support,
                defence: defence,
                goalkeeping: goalkeeping,
              ),
          createCompanionCallback:
              ({
                Value<int> playerId = const Value.absent(),
                required String name,
                required String position,
                required int age,
                required String nationality,
                required String club,
                Value<String> leagueCode = const Value.absent(),
                required int marketValueEur,
                required int overall,
                required int attack,
                required int support,
                required int defence,
                required int goalkeeping,
              }) => PlayersCompanion.insert(
                playerId: playerId,
                name: name,
                position: position,
                age: age,
                nationality: nationality,
                club: club,
                leagueCode: leagueCode,
                marketValueEur: marketValueEur,
                overall: overall,
                attack: attack,
                support: support,
                defence: defence,
                goalkeeping: goalkeeping,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlayersTable, Player>(table),
                  BaseReferences<_$AppDatabase, $PlayersTable, Player>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlayersTable,
      Player,
      $$PlayersTableFilterComposer,
      $$PlayersTableOrderingComposer,
      $$PlayersTableAnnotationComposer,
      $$PlayersTableCreateCompanionBuilder,
      $$PlayersTableUpdateCompanionBuilder,
      (Player, BaseReferences<_$AppDatabase, $PlayersTable, Player>),
      Player,
      PrefetchHooks Function()
    >;
typedef $$DatasetVersionsTableCreateCompanionBuilder =
    DatasetVersionsCompanion Function({
      Value<int> version,
      required String asOf,
      Value<String> digest,
      required DateTime importedAt,
      required int playerCount,
    });
typedef $$DatasetVersionsTableUpdateCompanionBuilder =
    DatasetVersionsCompanion Function({
      Value<int> version,
      Value<String> asOf,
      Value<String> digest,
      Value<DateTime> importedAt,
      Value<int> playerCount,
    });

class $$DatasetVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $DatasetVersionsTable> {
  $$DatasetVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get digest => $composableBuilder(
    column: $table.digest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DatasetVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DatasetVersionsTable> {
  $$DatasetVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get digest => $composableBuilder(
    column: $table.digest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DatasetVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DatasetVersionsTable> {
  $$DatasetVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get asOf =>
      $composableBuilder(column: $table.asOf, builder: (column) => column);

  GeneratedColumn<String> get digest =>
      $composableBuilder(column: $table.digest, builder: (column) => column);

  GeneratedColumn<DateTime> get importedAt => $composableBuilder(
    column: $table.importedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playerCount => $composableBuilder(
    column: $table.playerCount,
    builder: (column) => column,
  );
}

class $$DatasetVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DatasetVersionsTable,
          DatasetVersion,
          $$DatasetVersionsTableFilterComposer,
          $$DatasetVersionsTableOrderingComposer,
          $$DatasetVersionsTableAnnotationComposer,
          $$DatasetVersionsTableCreateCompanionBuilder,
          $$DatasetVersionsTableUpdateCompanionBuilder,
          (
            DatasetVersion,
            BaseReferences<
              _$AppDatabase,
              $DatasetVersionsTable,
              DatasetVersion
            >,
          ),
          DatasetVersion,
          PrefetchHooks Function()
        > {
  $$DatasetVersionsTableTableManager(
    _$AppDatabase db,
    $DatasetVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DatasetVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DatasetVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DatasetVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                Value<String> asOf = const Value.absent(),
                Value<String> digest = const Value.absent(),
                Value<DateTime> importedAt = const Value.absent(),
                Value<int> playerCount = const Value.absent(),
              }) => DatasetVersionsCompanion(
                version: version,
                asOf: asOf,
                digest: digest,
                importedAt: importedAt,
                playerCount: playerCount,
              ),
          createCompanionCallback:
              ({
                Value<int> version = const Value.absent(),
                required String asOf,
                Value<String> digest = const Value.absent(),
                required DateTime importedAt,
                required int playerCount,
              }) => DatasetVersionsCompanion.insert(
                version: version,
                asOf: asOf,
                digest: digest,
                importedAt: importedAt,
                playerCount: playerCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DatasetVersionsTable, DatasetVersion>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $DatasetVersionsTable,
                    DatasetVersion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DatasetVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DatasetVersionsTable,
      DatasetVersion,
      $$DatasetVersionsTableFilterComposer,
      $$DatasetVersionsTableOrderingComposer,
      $$DatasetVersionsTableAnnotationComposer,
      $$DatasetVersionsTableCreateCompanionBuilder,
      $$DatasetVersionsTableUpdateCompanionBuilder,
      (
        DatasetVersion,
        BaseReferences<_$AppDatabase, $DatasetVersionsTable, DatasetVersion>,
      ),
      DatasetVersion,
      PrefetchHooks Function()
    >;
typedef $$ClubsTableCreateCompanionBuilder = ClubsCompanion Function({
  Value<int> id,
  required String name,
  required String managerName,
  Value<int> crestIndex,
  Value<String> formationCode,
  Value<String> playingStyle,
  Value<String> mentality,
  required int coins,
  Value<bool> isUser,
  required DateTime createdAt,
});
typedef $$ClubsTableUpdateCompanionBuilder = ClubsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> managerName,
  Value<int> crestIndex,
  Value<String> formationCode,
  Value<String> playingStyle,
  Value<String> mentality,
  Value<int> coins,
  Value<bool> isUser,
  Value<DateTime> createdAt,
});

class $$ClubsTableFilterComposer extends Composer<_$AppDatabase, $ClubsTable> {
  $$ClubsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get managerName => $composableBuilder(
    column: $table.managerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get crestIndex => $composableBuilder(
    column: $table.crestIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formationCode => $composableBuilder(
    column: $table.formationCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playingStyle => $composableBuilder(
    column: $table.playingStyle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mentality => $composableBuilder(
    column: $table.mentality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUser => $composableBuilder(
    column: $table.isUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClubsTableOrderingComposer
    extends Composer<_$AppDatabase, $ClubsTable> {
  $$ClubsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get managerName => $composableBuilder(
    column: $table.managerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get crestIndex => $composableBuilder(
    column: $table.crestIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formationCode => $composableBuilder(
    column: $table.formationCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playingStyle => $composableBuilder(
    column: $table.playingStyle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mentality => $composableBuilder(
    column: $table.mentality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coins => $composableBuilder(
    column: $table.coins,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUser => $composableBuilder(
    column: $table.isUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClubsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClubsTable> {
  $$ClubsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get managerName => $composableBuilder(
    column: $table.managerName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get crestIndex => $composableBuilder(
    column: $table.crestIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get formationCode => $composableBuilder(
    column: $table.formationCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get playingStyle => $composableBuilder(
    column: $table.playingStyle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mentality =>
      $composableBuilder(column: $table.mentality, builder: (column) => column);

  GeneratedColumn<int> get coins =>
      $composableBuilder(column: $table.coins, builder: (column) => column);

  GeneratedColumn<bool> get isUser =>
      $composableBuilder(column: $table.isUser, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ClubsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClubsTable,
          Club,
          $$ClubsTableFilterComposer,
          $$ClubsTableOrderingComposer,
          $$ClubsTableAnnotationComposer,
          $$ClubsTableCreateCompanionBuilder,
          $$ClubsTableUpdateCompanionBuilder,
          (Club, BaseReferences<_$AppDatabase, $ClubsTable, Club>),
          Club,
          PrefetchHooks Function()
        > {
  $$ClubsTableTableManager(_$AppDatabase db, $ClubsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClubsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClubsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClubsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> managerName = const Value.absent(),
                Value<int> crestIndex = const Value.absent(),
                Value<String> formationCode = const Value.absent(),
                Value<String> playingStyle = const Value.absent(),
                Value<String> mentality = const Value.absent(),
                Value<int> coins = const Value.absent(),
                Value<bool> isUser = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ClubsCompanion(
                id: id,
                name: name,
                managerName: managerName,
                crestIndex: crestIndex,
                formationCode: formationCode,
                playingStyle: playingStyle,
                mentality: mentality,
                coins: coins,
                isUser: isUser,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String managerName,
                Value<int> crestIndex = const Value.absent(),
                Value<String> formationCode = const Value.absent(),
                Value<String> playingStyle = const Value.absent(),
                Value<String> mentality = const Value.absent(),
                required int coins,
                Value<bool> isUser = const Value.absent(),
                required DateTime createdAt,
              }) => ClubsCompanion.insert(
                id: id,
                name: name,
                managerName: managerName,
                crestIndex: crestIndex,
                formationCode: formationCode,
                playingStyle: playingStyle,
                mentality: mentality,
                coins: coins,
                isUser: isUser,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClubsTable, Club>(table),
                  BaseReferences<_$AppDatabase, $ClubsTable, Club>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClubsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClubsTable,
      Club,
      $$ClubsTableFilterComposer,
      $$ClubsTableOrderingComposer,
      $$ClubsTableAnnotationComposer,
      $$ClubsTableCreateCompanionBuilder,
      $$ClubsTableUpdateCompanionBuilder,
      (Club, BaseReferences<_$AppDatabase, $ClubsTable, Club>),
      Club,
      PrefetchHooks Function()
    >;
typedef $$OwnedPlayersTableCreateCompanionBuilder =
    OwnedPlayersCompanion Function({
      Value<int> id,
      required int clubId,
      required int playerId,
      Value<int> upgradeLevel,
      Value<int> upgradedAttack,
      Value<int> upgradedSupport,
      Value<int> upgradedDefence,
      Value<int> upgradedGoalkeeping,
      Value<int> staminaPercent,
      Value<int?> squadSlot,
      Value<String> status,
      Value<String> acquisitionSource,
      required DateTime acquiredAt,
    });
typedef $$OwnedPlayersTableUpdateCompanionBuilder =
    OwnedPlayersCompanion Function({
      Value<int> id,
      Value<int> clubId,
      Value<int> playerId,
      Value<int> upgradeLevel,
      Value<int> upgradedAttack,
      Value<int> upgradedSupport,
      Value<int> upgradedDefence,
      Value<int> upgradedGoalkeeping,
      Value<int> staminaPercent,
      Value<int?> squadSlot,
      Value<String> status,
      Value<String> acquisitionSource,
      Value<DateTime> acquiredAt,
    });

class $$OwnedPlayersTableFilterComposer
    extends Composer<_$AppDatabase, $OwnedPlayersTable> {
  $$OwnedPlayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clubId => $composableBuilder(
    column: $table.clubId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upgradeLevel => $composableBuilder(
    column: $table.upgradeLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upgradedAttack => $composableBuilder(
    column: $table.upgradedAttack,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upgradedSupport => $composableBuilder(
    column: $table.upgradedSupport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upgradedDefence => $composableBuilder(
    column: $table.upgradedDefence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get upgradedGoalkeeping => $composableBuilder(
    column: $table.upgradedGoalkeeping,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get staminaPercent => $composableBuilder(
    column: $table.staminaPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get squadSlot => $composableBuilder(
    column: $table.squadSlot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acquisitionSource => $composableBuilder(
    column: $table.acquisitionSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OwnedPlayersTableOrderingComposer
    extends Composer<_$AppDatabase, $OwnedPlayersTable> {
  $$OwnedPlayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clubId => $composableBuilder(
    column: $table.clubId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playerId => $composableBuilder(
    column: $table.playerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upgradeLevel => $composableBuilder(
    column: $table.upgradeLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upgradedAttack => $composableBuilder(
    column: $table.upgradedAttack,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upgradedSupport => $composableBuilder(
    column: $table.upgradedSupport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upgradedDefence => $composableBuilder(
    column: $table.upgradedDefence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get upgradedGoalkeeping => $composableBuilder(
    column: $table.upgradedGoalkeeping,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get staminaPercent => $composableBuilder(
    column: $table.staminaPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get squadSlot => $composableBuilder(
    column: $table.squadSlot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acquisitionSource => $composableBuilder(
    column: $table.acquisitionSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OwnedPlayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OwnedPlayersTable> {
  $$OwnedPlayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get clubId =>
      $composableBuilder(column: $table.clubId, builder: (column) => column);

  GeneratedColumn<int> get playerId =>
      $composableBuilder(column: $table.playerId, builder: (column) => column);

  GeneratedColumn<int> get upgradeLevel => $composableBuilder(
    column: $table.upgradeLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get upgradedAttack => $composableBuilder(
    column: $table.upgradedAttack,
    builder: (column) => column,
  );

  GeneratedColumn<int> get upgradedSupport => $composableBuilder(
    column: $table.upgradedSupport,
    builder: (column) => column,
  );

  GeneratedColumn<int> get upgradedDefence => $composableBuilder(
    column: $table.upgradedDefence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get upgradedGoalkeeping => $composableBuilder(
    column: $table.upgradedGoalkeeping,
    builder: (column) => column,
  );

  GeneratedColumn<int> get staminaPercent => $composableBuilder(
    column: $table.staminaPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get squadSlot =>
      $composableBuilder(column: $table.squadSlot, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get acquisitionSource => $composableBuilder(
    column: $table.acquisitionSource,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => column,
  );
}

class $$OwnedPlayersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OwnedPlayersTable,
          OwnedPlayer,
          $$OwnedPlayersTableFilterComposer,
          $$OwnedPlayersTableOrderingComposer,
          $$OwnedPlayersTableAnnotationComposer,
          $$OwnedPlayersTableCreateCompanionBuilder,
          $$OwnedPlayersTableUpdateCompanionBuilder,
          (
            OwnedPlayer,
            BaseReferences<_$AppDatabase, $OwnedPlayersTable, OwnedPlayer>,
          ),
          OwnedPlayer,
          PrefetchHooks Function()
        > {
  $$OwnedPlayersTableTableManager(_$AppDatabase db, $OwnedPlayersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OwnedPlayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OwnedPlayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OwnedPlayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clubId = const Value.absent(),
                Value<int> playerId = const Value.absent(),
                Value<int> upgradeLevel = const Value.absent(),
                Value<int> upgradedAttack = const Value.absent(),
                Value<int> upgradedSupport = const Value.absent(),
                Value<int> upgradedDefence = const Value.absent(),
                Value<int> upgradedGoalkeeping = const Value.absent(),
                Value<int> staminaPercent = const Value.absent(),
                Value<int?> squadSlot = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> acquisitionSource = const Value.absent(),
                Value<DateTime> acquiredAt = const Value.absent(),
              }) => OwnedPlayersCompanion(
                id: id,
                clubId: clubId,
                playerId: playerId,
                upgradeLevel: upgradeLevel,
                upgradedAttack: upgradedAttack,
                upgradedSupport: upgradedSupport,
                upgradedDefence: upgradedDefence,
                upgradedGoalkeeping: upgradedGoalkeeping,
                staminaPercent: staminaPercent,
                squadSlot: squadSlot,
                status: status,
                acquisitionSource: acquisitionSource,
                acquiredAt: acquiredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clubId,
                required int playerId,
                Value<int> upgradeLevel = const Value.absent(),
                Value<int> upgradedAttack = const Value.absent(),
                Value<int> upgradedSupport = const Value.absent(),
                Value<int> upgradedDefence = const Value.absent(),
                Value<int> upgradedGoalkeeping = const Value.absent(),
                Value<int> staminaPercent = const Value.absent(),
                Value<int?> squadSlot = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> acquisitionSource = const Value.absent(),
                required DateTime acquiredAt,
              }) => OwnedPlayersCompanion.insert(
                id: id,
                clubId: clubId,
                playerId: playerId,
                upgradeLevel: upgradeLevel,
                upgradedAttack: upgradedAttack,
                upgradedSupport: upgradedSupport,
                upgradedDefence: upgradedDefence,
                upgradedGoalkeeping: upgradedGoalkeeping,
                staminaPercent: staminaPercent,
                squadSlot: squadSlot,
                status: status,
                acquisitionSource: acquisitionSource,
                acquiredAt: acquiredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OwnedPlayersTable, OwnedPlayer>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $OwnedPlayersTable,
                    OwnedPlayer
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OwnedPlayersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OwnedPlayersTable,
      OwnedPlayer,
      $$OwnedPlayersTableFilterComposer,
      $$OwnedPlayersTableOrderingComposer,
      $$OwnedPlayersTableAnnotationComposer,
      $$OwnedPlayersTableCreateCompanionBuilder,
      $$OwnedPlayersTableUpdateCompanionBuilder,
      (
        OwnedPlayer,
        BaseReferences<_$AppDatabase, $OwnedPlayersTable, OwnedPlayer>,
      ),
      OwnedPlayer,
      PrefetchHooks Function()
    >;
typedef $$PacksTableCreateCompanionBuilder = PacksCompanion Function({
  Value<int> id,
  required int clubId,
  required String category,
  Value<String?> scopeValue,
  Value<int> price,
  Value<String> source,
  Value<bool> opened,
  Value<DateTime?> openedAt,
  required DateTime createdAt,
});
typedef $$PacksTableUpdateCompanionBuilder = PacksCompanion Function({
  Value<int> id,
  Value<int> clubId,
  Value<String> category,
  Value<String?> scopeValue,
  Value<int> price,
  Value<String> source,
  Value<bool> opened,
  Value<DateTime?> openedAt,
  Value<DateTime> createdAt,
});

class $$PacksTableFilterComposer extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clubId => $composableBuilder(
    column: $table.clubId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeValue => $composableBuilder(
    column: $table.scopeValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get opened => $composableBuilder(
    column: $table.opened,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PacksTableOrderingComposer
    extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clubId => $composableBuilder(
    column: $table.clubId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeValue => $composableBuilder(
    column: $table.scopeValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get price => $composableBuilder(
    column: $table.price,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get opened => $composableBuilder(
    column: $table.opened,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PacksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PacksTable> {
  $$PacksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get clubId =>
      $composableBuilder(column: $table.clubId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get scopeValue => $composableBuilder(
    column: $table.scopeValue,
    builder: (column) => column,
  );

  GeneratedColumn<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get opened =>
      $composableBuilder(column: $table.opened, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PacksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PacksTable,
          Pack,
          $$PacksTableFilterComposer,
          $$PacksTableOrderingComposer,
          $$PacksTableAnnotationComposer,
          $$PacksTableCreateCompanionBuilder,
          $$PacksTableUpdateCompanionBuilder,
          (Pack, BaseReferences<_$AppDatabase, $PacksTable, Pack>),
          Pack,
          PrefetchHooks Function()
        > {
  $$PacksTableTableManager(_$AppDatabase db, $PacksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PacksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PacksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PacksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clubId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String?> scopeValue = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> opened = const Value.absent(),
                Value<DateTime?> openedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PacksCompanion(
                id: id,
                clubId: clubId,
                category: category,
                scopeValue: scopeValue,
                price: price,
                source: source,
                opened: opened,
                openedAt: openedAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clubId,
                required String category,
                Value<String?> scopeValue = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<bool> opened = const Value.absent(),
                Value<DateTime?> openedAt = const Value.absent(),
                required DateTime createdAt,
              }) => PacksCompanion.insert(
                id: id,
                clubId: clubId,
                category: category,
                scopeValue: scopeValue,
                price: price,
                source: source,
                opened: opened,
                openedAt: openedAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PacksTable, Pack>(table),
                  BaseReferences<_$AppDatabase, $PacksTable, Pack>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PacksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PacksTable,
      Pack,
      $$PacksTableFilterComposer,
      $$PacksTableOrderingComposer,
      $$PacksTableAnnotationComposer,
      $$PacksTableCreateCompanionBuilder,
      $$PacksTableUpdateCompanionBuilder,
      (Pack, BaseReferences<_$AppDatabase, $PacksTable, Pack>),
      Pack,
      PrefetchHooks Function()
    >;
typedef $$CoinTransactionsTableCreateCompanionBuilder =
    CoinTransactionsCompanion Function({
      Value<int> id,
      required int clubId,
      required int amount,
      required int balanceAfter,
      required String reason,
      Value<String?> detail,
      required DateTime createdAt,
    });
typedef $$CoinTransactionsTableUpdateCompanionBuilder =
    CoinTransactionsCompanion Function({
      Value<int> id,
      Value<int> clubId,
      Value<int> amount,
      Value<int> balanceAfter,
      Value<String> reason,
      Value<String?> detail,
      Value<DateTime> createdAt,
    });

class $$CoinTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $CoinTransactionsTable> {
  $$CoinTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get clubId => $composableBuilder(
    column: $table.clubId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CoinTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CoinTransactionsTable> {
  $$CoinTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get clubId => $composableBuilder(
    column: $table.clubId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoinTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoinTransactionsTable> {
  $$CoinTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get clubId =>
      $composableBuilder(column: $table.clubId, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<int> get balanceAfter => $composableBuilder(
    column: $table.balanceAfter,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$CoinTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoinTransactionsTable,
          CoinTransaction,
          $$CoinTransactionsTableFilterComposer,
          $$CoinTransactionsTableOrderingComposer,
          $$CoinTransactionsTableAnnotationComposer,
          $$CoinTransactionsTableCreateCompanionBuilder,
          $$CoinTransactionsTableUpdateCompanionBuilder,
          (
            CoinTransaction,
            BaseReferences<
              _$AppDatabase,
              $CoinTransactionsTable,
              CoinTransaction
            >,
          ),
          CoinTransaction,
          PrefetchHooks Function()
        > {
  $$CoinTransactionsTableTableManager(
    _$AppDatabase db,
    $CoinTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoinTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoinTransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoinTransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> clubId = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<int> balanceAfter = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CoinTransactionsCompanion(
                id: id,
                clubId: clubId,
                amount: amount,
                balanceAfter: balanceAfter,
                reason: reason,
                detail: detail,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int clubId,
                required int amount,
                required int balanceAfter,
                required String reason,
                Value<String?> detail = const Value.absent(),
                required DateTime createdAt,
              }) => CoinTransactionsCompanion.insert(
                id: id,
                clubId: clubId,
                amount: amount,
                balanceAfter: balanceAfter,
                reason: reason,
                detail: detail,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoinTransactionsTable, CoinTransaction>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CoinTransactionsTable,
                    CoinTransaction
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CoinTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoinTransactionsTable,
      CoinTransaction,
      $$CoinTransactionsTableFilterComposer,
      $$CoinTransactionsTableOrderingComposer,
      $$CoinTransactionsTableAnnotationComposer,
      $$CoinTransactionsTableCreateCompanionBuilder,
      $$CoinTransactionsTableUpdateCompanionBuilder,
      (
        CoinTransaction,
        BaseReferences<_$AppDatabase, $CoinTransactionsTable, CoinTransaction>,
      ),
      CoinTransaction,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PlayersTableTableManager get players =>
      $$PlayersTableTableManager(_db, _db.players);
  $$DatasetVersionsTableTableManager get datasetVersions =>
      $$DatasetVersionsTableTableManager(_db, _db.datasetVersions);
  $$ClubsTableTableManager get clubs =>
      $$ClubsTableTableManager(_db, _db.clubs);
  $$OwnedPlayersTableTableManager get ownedPlayers =>
      $$OwnedPlayersTableTableManager(_db, _db.ownedPlayers);
  $$PacksTableTableManager get packs =>
      $$PacksTableTableManager(_db, _db.packs);
  $$CoinTransactionsTableTableManager get coinTransactions =>
      $$CoinTransactionsTableTableManager(_db, _db.coinTransactions);
}
