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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LedgerRowsTable ledgerRows = $LedgerRowsTable(this);
  late final $PeerRowsTable peerRows = $PeerRowsTable(this);
  late final $MetaRowsTable metaRows = $MetaRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    ledgerRows,
    peerRows,
    metaRows,
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LedgerRowsTableTableManager get ledgerRows =>
      $$LedgerRowsTableTableManager(_db, _db.ledgerRows);
  $$PeerRowsTableTableManager get peerRows =>
      $$PeerRowsTableTableManager(_db, _db.peerRows);
  $$MetaRowsTableTableManager get metaRows =>
      $$MetaRowsTableTableManager(_db, _db.metaRows);
}
