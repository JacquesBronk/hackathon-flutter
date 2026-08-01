// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'drift_db.dart';

// ignore_for_file: type=lint
class $LedgerRowsTable extends LedgerRows
    with TableInfo<$LedgerRowsTable, LedgerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LedgerRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LedgerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $LedgerRowsTable createAlias(String alias) {
    return $LedgerRowsTable(attachedDatabase, alias);
  }
}

class LedgerRow extends DataClass implements Insertable<LedgerRow> {
  final String key;
  final String json;
  const LedgerRow({required this.key, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['json'] = Variable<String>(json);
    return map;
  }

  LedgerRowsCompanion toCompanion(bool nullToAbsent) {
    return LedgerRowsCompanion(key: Value(key), json: Value(json));
  }

  factory LedgerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerRow(
      key: serializer.fromJson<String>(json['key']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'json': serializer.toJson<String>(json),
    };
  }

  LedgerRow copyWith({String? key, String? json}) =>
      LedgerRow(key: key ?? this.key, json: json ?? this.json);
  LedgerRow copyWithCompanion(LedgerRowsCompanion data) {
    return LedgerRow(
      key: data.key.present ? data.key.value : this.key,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerRow(')
          ..write('key: $key, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerRow && other.key == this.key && other.json == this.json);
}

class LedgerRowsCompanion extends UpdateCompanion<LedgerRow> {
  final Value<String> key;
  final Value<String> json;
  final Value<int> rowid;
  const LedgerRowsCompanion({
    this.key = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerRowsCompanion.insert({
    required String key,
    required String json,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       json = Value(json);
  static Insertable<LedgerRow> custom({
    Expression<String>? key,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerRowsCompanion copyWith({
    Value<String>? key,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return LedgerRowsCompanion(
      key: key ?? this.key,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerRowsCompanion(')
          ..write('key: $key, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeerRowsTable extends PeerRows with TableInfo<$PeerRowsTable, PeerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeerRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addrMeta = const VerificationMeta('addr');
  @override
  late final GeneratedColumn<String> addr = GeneratedColumn<String>(
    'addr',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [addr, name];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peer_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('addr')) {
      context.handle(
        _addrMeta,
        addr.isAcceptableOrUnknown(data['addr']!, _addrMeta),
      );
    } else if (isInserting) {
      context.missing(_addrMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {addr};
  @override
  PeerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerRow(
      addr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}addr'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $PeerRowsTable createAlias(String alias) {
    return $PeerRowsTable(attachedDatabase, alias);
  }
}

class PeerRow extends DataClass implements Insertable<PeerRow> {
  final String addr;
  final String name;
  const PeerRow({required this.addr, required this.name});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['addr'] = Variable<String>(addr);
    map['name'] = Variable<String>(name);
    return map;
  }

  PeerRowsCompanion toCompanion(bool nullToAbsent) {
    return PeerRowsCompanion(addr: Value(addr), name: Value(name));
  }

  factory PeerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerRow(
      addr: serializer.fromJson<String>(json['addr']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'addr': serializer.toJson<String>(addr),
      'name': serializer.toJson<String>(name),
    };
  }

  PeerRow copyWith({String? addr, String? name}) =>
      PeerRow(addr: addr ?? this.addr, name: name ?? this.name);
  PeerRow copyWithCompanion(PeerRowsCompanion data) {
    return PeerRow(
      addr: data.addr.present ? data.addr.value : this.addr,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerRow(')
          ..write('addr: $addr, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(addr, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerRow && other.addr == this.addr && other.name == this.name);
}

class PeerRowsCompanion extends UpdateCompanion<PeerRow> {
  final Value<String> addr;
  final Value<String> name;
  final Value<int> rowid;
  const PeerRowsCompanion({
    this.addr = const Value.absent(),
    this.name = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeerRowsCompanion.insert({
    required String addr,
    required String name,
    this.rowid = const Value.absent(),
  }) : addr = Value(addr),
       name = Value(name);
  static Insertable<PeerRow> custom({
    Expression<String>? addr,
    Expression<String>? name,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (addr != null) 'addr': addr,
      if (name != null) 'name': name,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeerRowsCompanion copyWith({
    Value<String>? addr,
    Value<String>? name,
    Value<int>? rowid,
  }) {
    return PeerRowsCompanion(
      addr: addr ?? this.addr,
      name: name ?? this.name,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (addr.present) {
      map['addr'] = Variable<String>(addr.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeerRowsCompanion(')
          ..write('addr: $addr, ')
          ..write('name: $name, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetaRowsTable extends MetaRows with TableInfo<$MetaRowsTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kMeta = const VerificationMeta('k');
  @override
  late final GeneratedColumn<String> k = GeneratedColumn<String>(
    'k',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vMeta = const VerificationMeta('v');
  @override
  late final GeneratedColumn<String> v = GeneratedColumn<String>(
    'v',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [k, v];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('k')) {
      context.handle(_kMeta, k.isAcceptableOrUnknown(data['k']!, _kMeta));
    } else if (isInserting) {
      context.missing(_kMeta);
    }
    if (data.containsKey('v')) {
      context.handle(_vMeta, v.isAcceptableOrUnknown(data['v']!, _vMeta));
    } else if (isInserting) {
      context.missing(_vMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {k};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      k: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}k'],
      )!,
      v: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}v'],
      )!,
    );
  }

  @override
  $MetaRowsTable createAlias(String alias) {
    return $MetaRowsTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String k;
  final String v;
  const MetaRow({required this.k, required this.v});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['k'] = Variable<String>(k);
    map['v'] = Variable<String>(v);
    return map;
  }

  MetaRowsCompanion toCompanion(bool nullToAbsent) {
    return MetaRowsCompanion(k: Value(k), v: Value(v));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      k: serializer.fromJson<String>(json['k']),
      v: serializer.fromJson<String>(json['v']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'k': serializer.toJson<String>(k),
      'v': serializer.toJson<String>(v),
    };
  }

  MetaRow copyWith({String? k, String? v}) =>
      MetaRow(k: k ?? this.k, v: v ?? this.v);
  MetaRow copyWithCompanion(MetaRowsCompanion data) {
    return MetaRow(
      k: data.k.present ? data.k.value : this.k,
      v: data.v.present ? data.v.value : this.v,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('k: $k, ')
          ..write('v: $v')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(k, v);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.k == this.k && other.v == this.v);
}

class MetaRowsCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> k;
  final Value<String> v;
  final Value<int> rowid;
  const MetaRowsCompanion({
    this.k = const Value.absent(),
    this.v = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaRowsCompanion.insert({
    required String k,
    required String v,
    this.rowid = const Value.absent(),
  }) : k = Value(k),
       v = Value(v);
  static Insertable<MetaRow> custom({
    Expression<String>? k,
    Expression<String>? v,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (k != null) 'k': k,
      if (v != null) 'v': v,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaRowsCompanion copyWith({
    Value<String>? k,
    Value<String>? v,
    Value<int>? rowid,
  }) {
    return MetaRowsCompanion(
      k: k ?? this.k,
      v: v ?? this.v,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (k.present) {
      map['k'] = Variable<String>(k.value);
    }
    if (v.present) {
      map['v'] = Variable<String>(v.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaRowsCompanion(')
          ..write('k: $k, ')
          ..write('v: $v, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxRowsTable extends OutboxRows
    with TableInfo<$OutboxRowsTable, OutboxRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _msgIdMeta = const VerificationMeta('msgId');
  @override
  late final GeneratedColumn<String> msgId = GeneratedColumn<String>(
    'msg_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _frameJsonMeta = const VerificationMeta(
    'frameJson',
  );
  @override
  late final GeneratedColumn<String> frameJson = GeneratedColumn<String>(
    'frame_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [msgId, frameJson, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('msg_id')) {
      context.handle(
        _msgIdMeta,
        msgId.isAcceptableOrUnknown(data['msg_id']!, _msgIdMeta),
      );
    } else if (isInserting) {
      context.missing(_msgIdMeta);
    }
    if (data.containsKey('frame_json')) {
      context.handle(
        _frameJsonMeta,
        frameJson.isAcceptableOrUnknown(data['frame_json']!, _frameJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_frameJsonMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {msgId};
  @override
  OutboxRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxRow(
      msgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}msg_id'],
      )!,
      frameJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}frame_json'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $OutboxRowsTable createAlias(String alias) {
    return $OutboxRowsTable(attachedDatabase, alias);
  }
}

class OutboxRow extends DataClass implements Insertable<OutboxRow> {
  final String msgId;
  final String frameJson;
  final DateTime expiresAt;
  const OutboxRow({
    required this.msgId,
    required this.frameJson,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['msg_id'] = Variable<String>(msgId);
    map['frame_json'] = Variable<String>(frameJson);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    return map;
  }

  OutboxRowsCompanion toCompanion(bool nullToAbsent) {
    return OutboxRowsCompanion(
      msgId: Value(msgId),
      frameJson: Value(frameJson),
      expiresAt: Value(expiresAt),
    );
  }

  factory OutboxRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxRow(
      msgId: serializer.fromJson<String>(json['msgId']),
      frameJson: serializer.fromJson<String>(json['frameJson']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'msgId': serializer.toJson<String>(msgId),
      'frameJson': serializer.toJson<String>(frameJson),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
    };
  }

  OutboxRow copyWith({String? msgId, String? frameJson, DateTime? expiresAt}) =>
      OutboxRow(
        msgId: msgId ?? this.msgId,
        frameJson: frameJson ?? this.frameJson,
        expiresAt: expiresAt ?? this.expiresAt,
      );
  OutboxRow copyWithCompanion(OutboxRowsCompanion data) {
    return OutboxRow(
      msgId: data.msgId.present ? data.msgId.value : this.msgId,
      frameJson: data.frameJson.present ? data.frameJson.value : this.frameJson,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRow(')
          ..write('msgId: $msgId, ')
          ..write('frameJson: $frameJson, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(msgId, frameJson, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxRow &&
          other.msgId == this.msgId &&
          other.frameJson == this.frameJson &&
          other.expiresAt == this.expiresAt);
}

class OutboxRowsCompanion extends UpdateCompanion<OutboxRow> {
  final Value<String> msgId;
  final Value<String> frameJson;
  final Value<DateTime> expiresAt;
  final Value<int> rowid;
  const OutboxRowsCompanion({
    this.msgId = const Value.absent(),
    this.frameJson = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxRowsCompanion.insert({
    required String msgId,
    required String frameJson,
    required DateTime expiresAt,
    this.rowid = const Value.absent(),
  }) : msgId = Value(msgId),
       frameJson = Value(frameJson),
       expiresAt = Value(expiresAt);
  static Insertable<OutboxRow> custom({
    Expression<String>? msgId,
    Expression<String>? frameJson,
    Expression<DateTime>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (msgId != null) 'msg_id': msgId,
      if (frameJson != null) 'frame_json': frameJson,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxRowsCompanion copyWith({
    Value<String>? msgId,
    Value<String>? frameJson,
    Value<DateTime>? expiresAt,
    Value<int>? rowid,
  }) {
    return OutboxRowsCompanion(
      msgId: msgId ?? this.msgId,
      frameJson: frameJson ?? this.frameJson,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (msgId.present) {
      map['msg_id'] = Variable<String>(msgId.value);
    }
    if (frameJson.present) {
      map['frame_json'] = Variable<String>(frameJson.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxRowsCompanion(')
          ..write('msgId: $msgId, ')
          ..write('frameJson: $frameJson, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SeenRowsTable extends SeenRows with TableInfo<$SeenRowsTable, SeenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeenRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _msgIdMeta = const VerificationMeta('msgId');
  @override
  late final GeneratedColumn<String> msgId = GeneratedColumn<String>(
    'msg_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [seq, msgId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'seen_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<SeenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    }
    if (data.containsKey('msg_id')) {
      context.handle(
        _msgIdMeta,
        msgId.isAcceptableOrUnknown(data['msg_id']!, _msgIdMeta),
      );
    } else if (isInserting) {
      context.missing(_msgIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  SeenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SeenRow(
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      msgId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}msg_id'],
      )!,
    );
  }

  @override
  $SeenRowsTable createAlias(String alias) {
    return $SeenRowsTable(attachedDatabase, alias);
  }
}

class SeenRow extends DataClass implements Insertable<SeenRow> {
  final int seq;
  final String msgId;
  const SeenRow({required this.seq, required this.msgId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['msg_id'] = Variable<String>(msgId);
    return map;
  }

  SeenRowsCompanion toCompanion(bool nullToAbsent) {
    return SeenRowsCompanion(seq: Value(seq), msgId: Value(msgId));
  }

  factory SeenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SeenRow(
      seq: serializer.fromJson<int>(json['seq']),
      msgId: serializer.fromJson<String>(json['msgId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'msgId': serializer.toJson<String>(msgId),
    };
  }

  SeenRow copyWith({int? seq, String? msgId}) =>
      SeenRow(seq: seq ?? this.seq, msgId: msgId ?? this.msgId);
  SeenRow copyWithCompanion(SeenRowsCompanion data) {
    return SeenRow(
      seq: data.seq.present ? data.seq.value : this.seq,
      msgId: data.msgId.present ? data.msgId.value : this.msgId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SeenRow(')
          ..write('seq: $seq, ')
          ..write('msgId: $msgId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(seq, msgId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SeenRow && other.seq == this.seq && other.msgId == this.msgId);
}

class SeenRowsCompanion extends UpdateCompanion<SeenRow> {
  final Value<int> seq;
  final Value<String> msgId;
  const SeenRowsCompanion({
    this.seq = const Value.absent(),
    this.msgId = const Value.absent(),
  });
  SeenRowsCompanion.insert({
    this.seq = const Value.absent(),
    required String msgId,
  }) : msgId = Value(msgId);
  static Insertable<SeenRow> custom({
    Expression<int>? seq,
    Expression<String>? msgId,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (msgId != null) 'msg_id': msgId,
    });
  }

  SeenRowsCompanion copyWith({Value<int>? seq, Value<String>? msgId}) {
    return SeenRowsCompanion(seq: seq ?? this.seq, msgId: msgId ?? this.msgId);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (msgId.present) {
      map['msg_id'] = Variable<String>(msgId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeenRowsCompanion(')
          ..write('seq: $seq, ')
          ..write('msgId: $msgId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LedgerRowsTable ledgerRows = $LedgerRowsTable(this);
  late final $PeerRowsTable peerRows = $PeerRowsTable(this);
  late final $MetaRowsTable metaRows = $MetaRowsTable(this);
  late final $OutboxRowsTable outboxRows = $OutboxRowsTable(this);
  late final $SeenRowsTable seenRows = $SeenRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    ledgerRows,
    peerRows,
    metaRows,
    outboxRows,
    seenRows,
  ];
}

typedef $$LedgerRowsTableCreateCompanionBuilder =
    LedgerRowsCompanion Function({
      required String key,
      required String json,
      Value<int> rowid,
    });
typedef $$LedgerRowsTableUpdateCompanionBuilder =
    LedgerRowsCompanion Function({
      Value<String> key,
      Value<String> json,
      Value<int> rowid,
    });

class $$LedgerRowsTableFilterComposer
    extends Composer<_$AppDatabase, $LedgerRowsTable> {
  $$LedgerRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LedgerRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $LedgerRowsTable> {
  $$LedgerRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LedgerRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LedgerRowsTable> {
  $$LedgerRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$LedgerRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LedgerRowsTable,
          LedgerRow,
          $$LedgerRowsTableFilterComposer,
          $$LedgerRowsTableOrderingComposer,
          $$LedgerRowsTableAnnotationComposer,
          $$LedgerRowsTableCreateCompanionBuilder,
          $$LedgerRowsTableUpdateCompanionBuilder,
          (
            LedgerRow,
            BaseReferences<_$AppDatabase, $LedgerRowsTable, LedgerRow>,
          ),
          LedgerRow,
          PrefetchHooks Function()
        > {
  $$LedgerRowsTableTableManager(_$AppDatabase db, $LedgerRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LedgerRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LedgerRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LedgerRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerRowsCompanion(key: key, json: json, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => LedgerRowsCompanion.insert(
                key: key,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LedgerRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LedgerRowsTable,
      LedgerRow,
      $$LedgerRowsTableFilterComposer,
      $$LedgerRowsTableOrderingComposer,
      $$LedgerRowsTableAnnotationComposer,
      $$LedgerRowsTableCreateCompanionBuilder,
      $$LedgerRowsTableUpdateCompanionBuilder,
      (LedgerRow, BaseReferences<_$AppDatabase, $LedgerRowsTable, LedgerRow>),
      LedgerRow,
      PrefetchHooks Function()
    >;
typedef $$PeerRowsTableCreateCompanionBuilder =
    PeerRowsCompanion Function({
      required String addr,
      required String name,
      Value<int> rowid,
    });
typedef $$PeerRowsTableUpdateCompanionBuilder =
    PeerRowsCompanion Function({
      Value<String> addr,
      Value<String> name,
      Value<int> rowid,
    });

class $$PeerRowsTableFilterComposer
    extends Composer<_$AppDatabase, $PeerRowsTable> {
  $$PeerRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get addr => $composableBuilder(
    column: $table.addr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeerRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $PeerRowsTable> {
  $$PeerRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get addr => $composableBuilder(
    column: $table.addr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeerRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeerRowsTable> {
  $$PeerRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get addr =>
      $composableBuilder(column: $table.addr, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);
}

class $$PeerRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeerRowsTable,
          PeerRow,
          $$PeerRowsTableFilterComposer,
          $$PeerRowsTableOrderingComposer,
          $$PeerRowsTableAnnotationComposer,
          $$PeerRowsTableCreateCompanionBuilder,
          $$PeerRowsTableUpdateCompanionBuilder,
          (PeerRow, BaseReferences<_$AppDatabase, $PeerRowsTable, PeerRow>),
          PeerRow,
          PrefetchHooks Function()
        > {
  $$PeerRowsTableTableManager(_$AppDatabase db, $PeerRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeerRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeerRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeerRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> addr = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeerRowsCompanion(addr: addr, name: name, rowid: rowid),
          createCompanionCallback:
              ({
                required String addr,
                required String name,
                Value<int> rowid = const Value.absent(),
              }) => PeerRowsCompanion.insert(
                addr: addr,
                name: name,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeerRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeerRowsTable,
      PeerRow,
      $$PeerRowsTableFilterComposer,
      $$PeerRowsTableOrderingComposer,
      $$PeerRowsTableAnnotationComposer,
      $$PeerRowsTableCreateCompanionBuilder,
      $$PeerRowsTableUpdateCompanionBuilder,
      (PeerRow, BaseReferences<_$AppDatabase, $PeerRowsTable, PeerRow>),
      PeerRow,
      PrefetchHooks Function()
    >;
typedef $$MetaRowsTableCreateCompanionBuilder =
    MetaRowsCompanion Function({
      required String k,
      required String v,
      Value<int> rowid,
    });
typedef $$MetaRowsTableUpdateCompanionBuilder =
    MetaRowsCompanion Function({
      Value<String> k,
      Value<String> v,
      Value<int> rowid,
    });

class $$MetaRowsTableFilterComposer
    extends Composer<_$AppDatabase, $MetaRowsTable> {
  $$MetaRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get k => $composableBuilder(
    column: $table.k,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get v => $composableBuilder(
    column: $table.v,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $MetaRowsTable> {
  $$MetaRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get k => $composableBuilder(
    column: $table.k,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get v => $composableBuilder(
    column: $table.v,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaRowsTable> {
  $$MetaRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get k =>
      $composableBuilder(column: $table.k, builder: (column) => column);

  GeneratedColumn<String> get v =>
      $composableBuilder(column: $table.v, builder: (column) => column);
}

class $$MetaRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaRowsTable,
          MetaRow,
          $$MetaRowsTableFilterComposer,
          $$MetaRowsTableOrderingComposer,
          $$MetaRowsTableAnnotationComposer,
          $$MetaRowsTableCreateCompanionBuilder,
          $$MetaRowsTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$AppDatabase, $MetaRowsTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaRowsTableTableManager(_$AppDatabase db, $MetaRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> k = const Value.absent(),
                Value<String> v = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaRowsCompanion(k: k, v: v, rowid: rowid),
          createCompanionCallback:
              ({
                required String k,
                required String v,
                Value<int> rowid = const Value.absent(),
              }) => MetaRowsCompanion.insert(k: k, v: v, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaRowsTable,
      MetaRow,
      $$MetaRowsTableFilterComposer,
      $$MetaRowsTableOrderingComposer,
      $$MetaRowsTableAnnotationComposer,
      $$MetaRowsTableCreateCompanionBuilder,
      $$MetaRowsTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$AppDatabase, $MetaRowsTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;
typedef $$OutboxRowsTableCreateCompanionBuilder =
    OutboxRowsCompanion Function({
      required String msgId,
      required String frameJson,
      required DateTime expiresAt,
      Value<int> rowid,
    });
typedef $$OutboxRowsTableUpdateCompanionBuilder =
    OutboxRowsCompanion Function({
      Value<String> msgId,
      Value<String> frameJson,
      Value<DateTime> expiresAt,
      Value<int> rowid,
    });

class $$OutboxRowsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxRowsTable> {
  $$OutboxRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get msgId => $composableBuilder(
    column: $table.msgId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get frameJson => $composableBuilder(
    column: $table.frameJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxRowsTable> {
  $$OutboxRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get msgId => $composableBuilder(
    column: $table.msgId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frameJson => $composableBuilder(
    column: $table.frameJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxRowsTable> {
  $$OutboxRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get msgId =>
      $composableBuilder(column: $table.msgId, builder: (column) => column);

  GeneratedColumn<String> get frameJson =>
      $composableBuilder(column: $table.frameJson, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);
}

class $$OutboxRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxRowsTable,
          OutboxRow,
          $$OutboxRowsTableFilterComposer,
          $$OutboxRowsTableOrderingComposer,
          $$OutboxRowsTableAnnotationComposer,
          $$OutboxRowsTableCreateCompanionBuilder,
          $$OutboxRowsTableUpdateCompanionBuilder,
          (
            OutboxRow,
            BaseReferences<_$AppDatabase, $OutboxRowsTable, OutboxRow>,
          ),
          OutboxRow,
          PrefetchHooks Function()
        > {
  $$OutboxRowsTableTableManager(_$AppDatabase db, $OutboxRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> msgId = const Value.absent(),
                Value<String> frameJson = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxRowsCompanion(
                msgId: msgId,
                frameJson: frameJson,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String msgId,
                required String frameJson,
                required DateTime expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxRowsCompanion.insert(
                msgId: msgId,
                frameJson: frameJson,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxRowsTable,
      OutboxRow,
      $$OutboxRowsTableFilterComposer,
      $$OutboxRowsTableOrderingComposer,
      $$OutboxRowsTableAnnotationComposer,
      $$OutboxRowsTableCreateCompanionBuilder,
      $$OutboxRowsTableUpdateCompanionBuilder,
      (OutboxRow, BaseReferences<_$AppDatabase, $OutboxRowsTable, OutboxRow>),
      OutboxRow,
      PrefetchHooks Function()
    >;
typedef $$SeenRowsTableCreateCompanionBuilder =
    SeenRowsCompanion Function({Value<int> seq, required String msgId});
typedef $$SeenRowsTableUpdateCompanionBuilder =
    SeenRowsCompanion Function({Value<int> seq, Value<String> msgId});

class $$SeenRowsTableFilterComposer
    extends Composer<_$AppDatabase, $SeenRowsTable> {
  $$SeenRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get msgId => $composableBuilder(
    column: $table.msgId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SeenRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $SeenRowsTable> {
  $$SeenRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get msgId => $composableBuilder(
    column: $table.msgId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SeenRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeenRowsTable> {
  $$SeenRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get msgId =>
      $composableBuilder(column: $table.msgId, builder: (column) => column);
}

class $$SeenRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeenRowsTable,
          SeenRow,
          $$SeenRowsTableFilterComposer,
          $$SeenRowsTableOrderingComposer,
          $$SeenRowsTableAnnotationComposer,
          $$SeenRowsTableCreateCompanionBuilder,
          $$SeenRowsTableUpdateCompanionBuilder,
          (SeenRow, BaseReferences<_$AppDatabase, $SeenRowsTable, SeenRow>),
          SeenRow,
          PrefetchHooks Function()
        > {
  $$SeenRowsTableTableManager(_$AppDatabase db, $SeenRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeenRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeenRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeenRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> msgId = const Value.absent(),
              }) => SeenRowsCompanion(seq: seq, msgId: msgId),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String msgId,
              }) => SeenRowsCompanion.insert(seq: seq, msgId: msgId),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SeenRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeenRowsTable,
      SeenRow,
      $$SeenRowsTableFilterComposer,
      $$SeenRowsTableOrderingComposer,
      $$SeenRowsTableAnnotationComposer,
      $$SeenRowsTableCreateCompanionBuilder,
      $$SeenRowsTableUpdateCompanionBuilder,
      (SeenRow, BaseReferences<_$AppDatabase, $SeenRowsTable, SeenRow>),
      SeenRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LedgerRowsTableTableManager get ledgerRows =>
      $$LedgerRowsTableTableManager(_db, _db.ledgerRows);
  $$PeerRowsTableTableManager get peerRows =>
      $$PeerRowsTableTableManager(_db, _db.peerRows);
  $$MetaRowsTableTableManager get metaRows =>
      $$MetaRowsTableTableManager(_db, _db.metaRows);
  $$OutboxRowsTableTableManager get outboxRows =>
      $$OutboxRowsTableTableManager(_db, _db.outboxRows);
  $$SeenRowsTableTableManager get seenRows =>
      $$SeenRowsTableTableManager(_db, _db.seenRows);
}
