// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DrinkPresetsTable extends DrinkPresets
    with TableInfo<$DrinkPresetsTable, DrinkPresetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DrinkPresetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _beverageTypeMeta = const VerificationMeta(
    'beverageType',
  );
  @override
  late final GeneratedColumn<String> beverageType = GeneratedColumn<String>(
    'beverage_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volumeMlMeta = const VerificationMeta(
    'volumeMl',
  );
  @override
  late final GeneratedColumn<int> volumeMl = GeneratedColumn<int>(
    'volume_ml',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _abvPercentMeta = const VerificationMeta(
    'abvPercent',
  );
  @override
  late final GeneratedColumn<double> abvPercent = GeneratedColumn<double>(
    'abv_percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regularPriceMinorMeta = const VerificationMeta(
    'regularPriceMinor',
  );
  @override
  late final GeneratedColumn<int> regularPriceMinor = GeneratedColumn<int>(
    'regular_price_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _regularCurrencyMeta = const VerificationMeta(
    'regularCurrency',
  );
  @override
  late final GeneratedColumn<String> regularCurrency = GeneratedColumn<String>(
    'regular_currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconColorMeta = const VerificationMeta(
    'iconColor',
  );
  @override
  late final GeneratedColumn<String> iconColor = GeneratedColumn<String>(
    'icon_color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isUserCreatedMeta = const VerificationMeta(
    'isUserCreated',
  );
  @override
  late final GeneratedColumn<bool> isUserCreated = GeneratedColumn<bool>(
    'is_user_created',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_user_created" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isHiddenMeta = const VerificationMeta(
    'isHidden',
  );
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
    'is_hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_hidden" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    beverageType,
    volumeMl,
    abvPercent,
    regularPriceMinor,
    regularCurrency,
    iconKey,
    iconColor,
    isUserCreated,
    isHidden,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drink_presets';
  @override
  VerificationContext validateIntegrity(
    Insertable<DrinkPresetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('beverage_type')) {
      context.handle(
        _beverageTypeMeta,
        beverageType.isAcceptableOrUnknown(
          data['beverage_type']!,
          _beverageTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beverageTypeMeta);
    }
    if (data.containsKey('volume_ml')) {
      context.handle(
        _volumeMlMeta,
        volumeMl.isAcceptableOrUnknown(data['volume_ml']!, _volumeMlMeta),
      );
    } else if (isInserting) {
      context.missing(_volumeMlMeta);
    }
    if (data.containsKey('abv_percent')) {
      context.handle(
        _abvPercentMeta,
        abvPercent.isAcceptableOrUnknown(data['abv_percent']!, _abvPercentMeta),
      );
    }
    if (data.containsKey('regular_price_minor')) {
      context.handle(
        _regularPriceMinorMeta,
        regularPriceMinor.isAcceptableOrUnknown(
          data['regular_price_minor']!,
          _regularPriceMinorMeta,
        ),
      );
    }
    if (data.containsKey('regular_currency')) {
      context.handle(
        _regularCurrencyMeta,
        regularCurrency.isAcceptableOrUnknown(
          data['regular_currency']!,
          _regularCurrencyMeta,
        ),
      );
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_iconKeyMeta);
    }
    if (data.containsKey('icon_color')) {
      context.handle(
        _iconColorMeta,
        iconColor.isAcceptableOrUnknown(data['icon_color']!, _iconColorMeta),
      );
    } else if (isInserting) {
      context.missing(_iconColorMeta);
    }
    if (data.containsKey('is_user_created')) {
      context.handle(
        _isUserCreatedMeta,
        isUserCreated.isAcceptableOrUnknown(
          data['is_user_created']!,
          _isUserCreatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isUserCreatedMeta);
    }
    if (data.containsKey('is_hidden')) {
      context.handle(
        _isHiddenMeta,
        isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DrinkPresetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DrinkPresetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      beverageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}beverage_type'],
      )!,
      volumeMl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume_ml'],
      )!,
      abvPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}abv_percent'],
      ),
      regularPriceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}regular_price_minor'],
      ),
      regularCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}regular_currency'],
      ),
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      )!,
      iconColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_color'],
      )!,
      isUserCreated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_user_created'],
      )!,
      isHidden: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_hidden'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DrinkPresetsTable createAlias(String alias) {
    return $DrinkPresetsTable(attachedDatabase, alias);
  }
}

class DrinkPresetRow extends DataClass implements Insertable<DrinkPresetRow> {
  final String id;
  final String name;

  /// Stored as the canonical string from [BeverageType.stored].
  final String beverageType;
  final int volumeMl;
  final double? abvPercent;
  final int? regularPriceMinor;
  final String? regularCurrency;
  final String iconKey;
  final String iconColor;
  final bool isUserCreated;
  final bool isHidden;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const DrinkPresetRow({
    required this.id,
    required this.name,
    required this.beverageType,
    required this.volumeMl,
    this.abvPercent,
    this.regularPriceMinor,
    this.regularCurrency,
    required this.iconKey,
    required this.iconColor,
    required this.isUserCreated,
    required this.isHidden,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['beverage_type'] = Variable<String>(beverageType);
    map['volume_ml'] = Variable<int>(volumeMl);
    if (!nullToAbsent || abvPercent != null) {
      map['abv_percent'] = Variable<double>(abvPercent);
    }
    if (!nullToAbsent || regularPriceMinor != null) {
      map['regular_price_minor'] = Variable<int>(regularPriceMinor);
    }
    if (!nullToAbsent || regularCurrency != null) {
      map['regular_currency'] = Variable<String>(regularCurrency);
    }
    map['icon_key'] = Variable<String>(iconKey);
    map['icon_color'] = Variable<String>(iconColor);
    map['is_user_created'] = Variable<bool>(isUserCreated);
    map['is_hidden'] = Variable<bool>(isHidden);
    map['sort_order'] = Variable<int>(sortOrder);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DrinkPresetsCompanion toCompanion(bool nullToAbsent) {
    return DrinkPresetsCompanion(
      id: Value(id),
      name: Value(name),
      beverageType: Value(beverageType),
      volumeMl: Value(volumeMl),
      abvPercent: abvPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(abvPercent),
      regularPriceMinor: regularPriceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(regularPriceMinor),
      regularCurrency: regularCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(regularCurrency),
      iconKey: Value(iconKey),
      iconColor: Value(iconColor),
      isUserCreated: Value(isUserCreated),
      isHidden: Value(isHidden),
      sortOrder: Value(sortOrder),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DrinkPresetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DrinkPresetRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      beverageType: serializer.fromJson<String>(json['beverageType']),
      volumeMl: serializer.fromJson<int>(json['volumeMl']),
      abvPercent: serializer.fromJson<double?>(json['abvPercent']),
      regularPriceMinor: serializer.fromJson<int?>(json['regularPriceMinor']),
      regularCurrency: serializer.fromJson<String?>(json['regularCurrency']),
      iconKey: serializer.fromJson<String>(json['iconKey']),
      iconColor: serializer.fromJson<String>(json['iconColor']),
      isUserCreated: serializer.fromJson<bool>(json['isUserCreated']),
      isHidden: serializer.fromJson<bool>(json['isHidden']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'beverageType': serializer.toJson<String>(beverageType),
      'volumeMl': serializer.toJson<int>(volumeMl),
      'abvPercent': serializer.toJson<double?>(abvPercent),
      'regularPriceMinor': serializer.toJson<int?>(regularPriceMinor),
      'regularCurrency': serializer.toJson<String?>(regularCurrency),
      'iconKey': serializer.toJson<String>(iconKey),
      'iconColor': serializer.toJson<String>(iconColor),
      'isUserCreated': serializer.toJson<bool>(isUserCreated),
      'isHidden': serializer.toJson<bool>(isHidden),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  DrinkPresetRow copyWith({
    String? id,
    String? name,
    String? beverageType,
    int? volumeMl,
    Value<double?> abvPercent = const Value.absent(),
    Value<int?> regularPriceMinor = const Value.absent(),
    Value<String?> regularCurrency = const Value.absent(),
    String? iconKey,
    String? iconColor,
    bool? isUserCreated,
    bool? isHidden,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => DrinkPresetRow(
    id: id ?? this.id,
    name: name ?? this.name,
    beverageType: beverageType ?? this.beverageType,
    volumeMl: volumeMl ?? this.volumeMl,
    abvPercent: abvPercent.present ? abvPercent.value : this.abvPercent,
    regularPriceMinor: regularPriceMinor.present
        ? regularPriceMinor.value
        : this.regularPriceMinor,
    regularCurrency: regularCurrency.present
        ? regularCurrency.value
        : this.regularCurrency,
    iconKey: iconKey ?? this.iconKey,
    iconColor: iconColor ?? this.iconColor,
    isUserCreated: isUserCreated ?? this.isUserCreated,
    isHidden: isHidden ?? this.isHidden,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DrinkPresetRow copyWithCompanion(DrinkPresetsCompanion data) {
    return DrinkPresetRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      beverageType: data.beverageType.present
          ? data.beverageType.value
          : this.beverageType,
      volumeMl: data.volumeMl.present ? data.volumeMl.value : this.volumeMl,
      abvPercent: data.abvPercent.present
          ? data.abvPercent.value
          : this.abvPercent,
      regularPriceMinor: data.regularPriceMinor.present
          ? data.regularPriceMinor.value
          : this.regularPriceMinor,
      regularCurrency: data.regularCurrency.present
          ? data.regularCurrency.value
          : this.regularCurrency,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      iconColor: data.iconColor.present ? data.iconColor.value : this.iconColor,
      isUserCreated: data.isUserCreated.present
          ? data.isUserCreated.value
          : this.isUserCreated,
      isHidden: data.isHidden.present ? data.isHidden.value : this.isHidden,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DrinkPresetRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('beverageType: $beverageType, ')
          ..write('volumeMl: $volumeMl, ')
          ..write('abvPercent: $abvPercent, ')
          ..write('regularPriceMinor: $regularPriceMinor, ')
          ..write('regularCurrency: $regularCurrency, ')
          ..write('iconKey: $iconKey, ')
          ..write('iconColor: $iconColor, ')
          ..write('isUserCreated: $isUserCreated, ')
          ..write('isHidden: $isHidden, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    beverageType,
    volumeMl,
    abvPercent,
    regularPriceMinor,
    regularCurrency,
    iconKey,
    iconColor,
    isUserCreated,
    isHidden,
    sortOrder,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DrinkPresetRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.beverageType == this.beverageType &&
          other.volumeMl == this.volumeMl &&
          other.abvPercent == this.abvPercent &&
          other.regularPriceMinor == this.regularPriceMinor &&
          other.regularCurrency == this.regularCurrency &&
          other.iconKey == this.iconKey &&
          other.iconColor == this.iconColor &&
          other.isUserCreated == this.isUserCreated &&
          other.isHidden == this.isHidden &&
          other.sortOrder == this.sortOrder &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class DrinkPresetsCompanion extends UpdateCompanion<DrinkPresetRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> beverageType;
  final Value<int> volumeMl;
  final Value<double?> abvPercent;
  final Value<int?> regularPriceMinor;
  final Value<String?> regularCurrency;
  final Value<String> iconKey;
  final Value<String> iconColor;
  final Value<bool> isUserCreated;
  final Value<bool> isHidden;
  final Value<int> sortOrder;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const DrinkPresetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.beverageType = const Value.absent(),
    this.volumeMl = const Value.absent(),
    this.abvPercent = const Value.absent(),
    this.regularPriceMinor = const Value.absent(),
    this.regularCurrency = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.iconColor = const Value.absent(),
    this.isUserCreated = const Value.absent(),
    this.isHidden = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DrinkPresetsCompanion.insert({
    required String id,
    required String name,
    required String beverageType,
    required int volumeMl,
    this.abvPercent = const Value.absent(),
    this.regularPriceMinor = const Value.absent(),
    this.regularCurrency = const Value.absent(),
    required String iconKey,
    required String iconColor,
    required bool isUserCreated,
    this.isHidden = const Value.absent(),
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       beverageType = Value(beverageType),
       volumeMl = Value(volumeMl),
       iconKey = Value(iconKey),
       iconColor = Value(iconColor),
       isUserCreated = Value(isUserCreated),
       sortOrder = Value(sortOrder),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DrinkPresetRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? beverageType,
    Expression<int>? volumeMl,
    Expression<double>? abvPercent,
    Expression<int>? regularPriceMinor,
    Expression<String>? regularCurrency,
    Expression<String>? iconKey,
    Expression<String>? iconColor,
    Expression<bool>? isUserCreated,
    Expression<bool>? isHidden,
    Expression<int>? sortOrder,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (beverageType != null) 'beverage_type': beverageType,
      if (volumeMl != null) 'volume_ml': volumeMl,
      if (abvPercent != null) 'abv_percent': abvPercent,
      if (regularPriceMinor != null) 'regular_price_minor': regularPriceMinor,
      if (regularCurrency != null) 'regular_currency': regularCurrency,
      if (iconKey != null) 'icon_key': iconKey,
      if (iconColor != null) 'icon_color': iconColor,
      if (isUserCreated != null) 'is_user_created': isUserCreated,
      if (isHidden != null) 'is_hidden': isHidden,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DrinkPresetsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? beverageType,
    Value<int>? volumeMl,
    Value<double?>? abvPercent,
    Value<int?>? regularPriceMinor,
    Value<String?>? regularCurrency,
    Value<String>? iconKey,
    Value<String>? iconColor,
    Value<bool>? isUserCreated,
    Value<bool>? isHidden,
    Value<int>? sortOrder,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DrinkPresetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      beverageType: beverageType ?? this.beverageType,
      volumeMl: volumeMl ?? this.volumeMl,
      abvPercent: abvPercent ?? this.abvPercent,
      regularPriceMinor: regularPriceMinor ?? this.regularPriceMinor,
      regularCurrency: regularCurrency ?? this.regularCurrency,
      iconKey: iconKey ?? this.iconKey,
      iconColor: iconColor ?? this.iconColor,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      isHidden: isHidden ?? this.isHidden,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (beverageType.present) {
      map['beverage_type'] = Variable<String>(beverageType.value);
    }
    if (volumeMl.present) {
      map['volume_ml'] = Variable<int>(volumeMl.value);
    }
    if (abvPercent.present) {
      map['abv_percent'] = Variable<double>(abvPercent.value);
    }
    if (regularPriceMinor.present) {
      map['regular_price_minor'] = Variable<int>(regularPriceMinor.value);
    }
    if (regularCurrency.present) {
      map['regular_currency'] = Variable<String>(regularCurrency.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (iconColor.present) {
      map['icon_color'] = Variable<String>(iconColor.value);
    }
    if (isUserCreated.present) {
      map['is_user_created'] = Variable<bool>(isUserCreated.value);
    }
    if (isHidden.present) {
      map['is_hidden'] = Variable<bool>(isHidden.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DrinkPresetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('beverageType: $beverageType, ')
          ..write('volumeMl: $volumeMl, ')
          ..write('abvPercent: $abvPercent, ')
          ..write('regularPriceMinor: $regularPriceMinor, ')
          ..write('regularCurrency: $regularCurrency, ')
          ..write('iconKey: $iconKey, ')
          ..write('iconColor: $iconColor, ')
          ..write('isUserCreated: $isUserCreated, ')
          ..write('isHidden: $isHidden, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DrinkEntriesTable extends DrinkEntries
    with TableInfo<$DrinkEntriesTable, DrinkEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DrinkEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _beverageTypeMeta = const VerificationMeta(
    'beverageType',
  );
  @override
  late final GeneratedColumn<String> beverageType = GeneratedColumn<String>(
    'beverage_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _volumeMlMeta = const VerificationMeta(
    'volumeMl',
  );
  @override
  late final GeneratedColumn<int> volumeMl = GeneratedColumn<int>(
    'volume_ml',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _abvPercentMeta = const VerificationMeta(
    'abvPercent',
  );
  @override
  late final GeneratedColumn<double> abvPercent = GeneratedColumn<double>(
    'abv_percent',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priceMinorMeta = const VerificationMeta(
    'priceMinor',
  );
  @override
  late final GeneratedColumn<int> priceMinor = GeneratedColumn<int>(
    'price_minor',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconKeyMeta = const VerificationMeta(
    'iconKey',
  );
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
    'icon_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconColorMeta = const VerificationMeta(
    'iconColor',
  );
  @override
  late final GeneratedColumn<String> iconColor = GeneratedColumn<String>(
    'icon_color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _consumedAtMeta = const VerificationMeta(
    'consumedAt',
  );
  @override
  late final GeneratedColumn<DateTime> consumedAt = GeneratedColumn<DateTime>(
    'consumed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    beverageType,
    volumeMl,
    abvPercent,
    priceMinor,
    currency,
    iconKey,
    iconColor,
    consumedAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drink_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DrinkEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('beverage_type')) {
      context.handle(
        _beverageTypeMeta,
        beverageType.isAcceptableOrUnknown(
          data['beverage_type']!,
          _beverageTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_beverageTypeMeta);
    }
    if (data.containsKey('volume_ml')) {
      context.handle(
        _volumeMlMeta,
        volumeMl.isAcceptableOrUnknown(data['volume_ml']!, _volumeMlMeta),
      );
    } else if (isInserting) {
      context.missing(_volumeMlMeta);
    }
    if (data.containsKey('abv_percent')) {
      context.handle(
        _abvPercentMeta,
        abvPercent.isAcceptableOrUnknown(data['abv_percent']!, _abvPercentMeta),
      );
    }
    if (data.containsKey('price_minor')) {
      context.handle(
        _priceMinorMeta,
        priceMinor.isAcceptableOrUnknown(data['price_minor']!, _priceMinorMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('icon_key')) {
      context.handle(
        _iconKeyMeta,
        iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta),
      );
    }
    if (data.containsKey('icon_color')) {
      context.handle(
        _iconColorMeta,
        iconColor.isAcceptableOrUnknown(data['icon_color']!, _iconColorMeta),
      );
    }
    if (data.containsKey('consumed_at')) {
      context.handle(
        _consumedAtMeta,
        consumedAt.isAcceptableOrUnknown(data['consumed_at']!, _consumedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_consumedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DrinkEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DrinkEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      beverageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}beverage_type'],
      )!,
      volumeMl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume_ml'],
      )!,
      abvPercent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}abv_percent'],
      ),
      priceMinor: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_minor'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      ),
      iconKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_key'],
      ),
      iconColor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_color'],
      ),
      consumedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}consumed_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $DrinkEntriesTable createAlias(String alias) {
    return $DrinkEntriesTable(attachedDatabase, alias);
  }
}

class DrinkEntryRow extends DataClass implements Insertable<DrinkEntryRow> {
  final String id;

  /// Snapshot of preset name at log time. Null when logged without a preset.
  final String? name;

  /// Stored as canonical string — see [BeverageType.stored].
  final String beverageType;
  final int volumeMl;
  final double? abvPercent;

  /// Snapshot of price in minor units at log time.
  final int? priceMinor;
  final String? currency;
  final String? iconKey;
  final String? iconColor;
  final DateTime consumedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const DrinkEntryRow({
    required this.id,
    this.name,
    required this.beverageType,
    required this.volumeMl,
    this.abvPercent,
    this.priceMinor,
    this.currency,
    this.iconKey,
    this.iconColor,
    required this.consumedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    map['beverage_type'] = Variable<String>(beverageType);
    map['volume_ml'] = Variable<int>(volumeMl);
    if (!nullToAbsent || abvPercent != null) {
      map['abv_percent'] = Variable<double>(abvPercent);
    }
    if (!nullToAbsent || priceMinor != null) {
      map['price_minor'] = Variable<int>(priceMinor);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    if (!nullToAbsent || iconColor != null) {
      map['icon_color'] = Variable<String>(iconColor);
    }
    map['consumed_at'] = Variable<DateTime>(consumedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  DrinkEntriesCompanion toCompanion(bool nullToAbsent) {
    return DrinkEntriesCompanion(
      id: Value(id),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      beverageType: Value(beverageType),
      volumeMl: Value(volumeMl),
      abvPercent: abvPercent == null && nullToAbsent
          ? const Value.absent()
          : Value(abvPercent),
      priceMinor: priceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(priceMinor),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      iconKey: iconKey == null && nullToAbsent
          ? const Value.absent()
          : Value(iconKey),
      iconColor: iconColor == null && nullToAbsent
          ? const Value.absent()
          : Value(iconColor),
      consumedAt: Value(consumedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DrinkEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DrinkEntryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      beverageType: serializer.fromJson<String>(json['beverageType']),
      volumeMl: serializer.fromJson<int>(json['volumeMl']),
      abvPercent: serializer.fromJson<double?>(json['abvPercent']),
      priceMinor: serializer.fromJson<int?>(json['priceMinor']),
      currency: serializer.fromJson<String?>(json['currency']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      iconColor: serializer.fromJson<String?>(json['iconColor']),
      consumedAt: serializer.fromJson<DateTime>(json['consumedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String?>(name),
      'beverageType': serializer.toJson<String>(beverageType),
      'volumeMl': serializer.toJson<int>(volumeMl),
      'abvPercent': serializer.toJson<double?>(abvPercent),
      'priceMinor': serializer.toJson<int?>(priceMinor),
      'currency': serializer.toJson<String?>(currency),
      'iconKey': serializer.toJson<String?>(iconKey),
      'iconColor': serializer.toJson<String?>(iconColor),
      'consumedAt': serializer.toJson<DateTime>(consumedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  DrinkEntryRow copyWith({
    String? id,
    Value<String?> name = const Value.absent(),
    String? beverageType,
    int? volumeMl,
    Value<double?> abvPercent = const Value.absent(),
    Value<int?> priceMinor = const Value.absent(),
    Value<String?> currency = const Value.absent(),
    Value<String?> iconKey = const Value.absent(),
    Value<String?> iconColor = const Value.absent(),
    DateTime? consumedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => DrinkEntryRow(
    id: id ?? this.id,
    name: name.present ? name.value : this.name,
    beverageType: beverageType ?? this.beverageType,
    volumeMl: volumeMl ?? this.volumeMl,
    abvPercent: abvPercent.present ? abvPercent.value : this.abvPercent,
    priceMinor: priceMinor.present ? priceMinor.value : this.priceMinor,
    currency: currency.present ? currency.value : this.currency,
    iconKey: iconKey.present ? iconKey.value : this.iconKey,
    iconColor: iconColor.present ? iconColor.value : this.iconColor,
    consumedAt: consumedAt ?? this.consumedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  DrinkEntryRow copyWithCompanion(DrinkEntriesCompanion data) {
    return DrinkEntryRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      beverageType: data.beverageType.present
          ? data.beverageType.value
          : this.beverageType,
      volumeMl: data.volumeMl.present ? data.volumeMl.value : this.volumeMl,
      abvPercent: data.abvPercent.present
          ? data.abvPercent.value
          : this.abvPercent,
      priceMinor: data.priceMinor.present
          ? data.priceMinor.value
          : this.priceMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      iconColor: data.iconColor.present ? data.iconColor.value : this.iconColor,
      consumedAt: data.consumedAt.present
          ? data.consumedAt.value
          : this.consumedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DrinkEntryRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('beverageType: $beverageType, ')
          ..write('volumeMl: $volumeMl, ')
          ..write('abvPercent: $abvPercent, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('currency: $currency, ')
          ..write('iconKey: $iconKey, ')
          ..write('iconColor: $iconColor, ')
          ..write('consumedAt: $consumedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    beverageType,
    volumeMl,
    abvPercent,
    priceMinor,
    currency,
    iconKey,
    iconColor,
    consumedAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DrinkEntryRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.beverageType == this.beverageType &&
          other.volumeMl == this.volumeMl &&
          other.abvPercent == this.abvPercent &&
          other.priceMinor == this.priceMinor &&
          other.currency == this.currency &&
          other.iconKey == this.iconKey &&
          other.iconColor == this.iconColor &&
          other.consumedAt == this.consumedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class DrinkEntriesCompanion extends UpdateCompanion<DrinkEntryRow> {
  final Value<String> id;
  final Value<String?> name;
  final Value<String> beverageType;
  final Value<int> volumeMl;
  final Value<double?> abvPercent;
  final Value<int?> priceMinor;
  final Value<String?> currency;
  final Value<String?> iconKey;
  final Value<String?> iconColor;
  final Value<DateTime> consumedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const DrinkEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.beverageType = const Value.absent(),
    this.volumeMl = const Value.absent(),
    this.abvPercent = const Value.absent(),
    this.priceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.iconColor = const Value.absent(),
    this.consumedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DrinkEntriesCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    required String beverageType,
    required int volumeMl,
    this.abvPercent = const Value.absent(),
    this.priceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.iconColor = const Value.absent(),
    required DateTime consumedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       beverageType = Value(beverageType),
       volumeMl = Value(volumeMl),
       consumedAt = Value(consumedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DrinkEntryRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? beverageType,
    Expression<int>? volumeMl,
    Expression<double>? abvPercent,
    Expression<int>? priceMinor,
    Expression<String>? currency,
    Expression<String>? iconKey,
    Expression<String>? iconColor,
    Expression<DateTime>? consumedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (beverageType != null) 'beverage_type': beverageType,
      if (volumeMl != null) 'volume_ml': volumeMl,
      if (abvPercent != null) 'abv_percent': abvPercent,
      if (priceMinor != null) 'price_minor': priceMinor,
      if (currency != null) 'currency': currency,
      if (iconKey != null) 'icon_key': iconKey,
      if (iconColor != null) 'icon_color': iconColor,
      if (consumedAt != null) 'consumed_at': consumedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DrinkEntriesCompanion copyWith({
    Value<String>? id,
    Value<String?>? name,
    Value<String>? beverageType,
    Value<int>? volumeMl,
    Value<double?>? abvPercent,
    Value<int?>? priceMinor,
    Value<String?>? currency,
    Value<String?>? iconKey,
    Value<String?>? iconColor,
    Value<DateTime>? consumedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return DrinkEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      beverageType: beverageType ?? this.beverageType,
      volumeMl: volumeMl ?? this.volumeMl,
      abvPercent: abvPercent ?? this.abvPercent,
      priceMinor: priceMinor ?? this.priceMinor,
      currency: currency ?? this.currency,
      iconKey: iconKey ?? this.iconKey,
      iconColor: iconColor ?? this.iconColor,
      consumedAt: consumedAt ?? this.consumedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (beverageType.present) {
      map['beverage_type'] = Variable<String>(beverageType.value);
    }
    if (volumeMl.present) {
      map['volume_ml'] = Variable<int>(volumeMl.value);
    }
    if (abvPercent.present) {
      map['abv_percent'] = Variable<double>(abvPercent.value);
    }
    if (priceMinor.present) {
      map['price_minor'] = Variable<int>(priceMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (iconColor.present) {
      map['icon_color'] = Variable<String>(iconColor.value);
    }
    if (consumedAt.present) {
      map['consumed_at'] = Variable<DateTime>(consumedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DrinkEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('beverageType: $beverageType, ')
          ..write('volumeMl: $volumeMl, ')
          ..write('abvPercent: $abvPercent, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('currency: $currency, ')
          ..write('iconKey: $iconKey, ')
          ..write('iconColor: $iconColor, ')
          ..write('consumedAt: $consumedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightKgMeta = const VerificationMeta(
    'weightKg',
  );
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
    'weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<String> birthDate = GeneratedColumn<String>(
    'birth_date',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    gender,
    weightKg,
    heightCm,
    birthDate,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('weight_kg')) {
      context.handle(
        _weightKgMeta,
        weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta),
      );
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      weightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_kg'],
      ),
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}birth_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfileRow extends DataClass implements Insertable<UserProfileRow> {
  final String id;
  final String? gender;

  /// Stored in kilograms (metric canonical — C1).
  final double? weightKg;

  /// Stored in centimetres (metric canonical — C1).
  final double? heightCm;

  /// ISO-8601 date string, e.g. "1990-06-15". Nullable — optional during
  /// onboarding but required for Party Mode BAC + under-18 gate.
  final String? birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const UserProfileRow({
    required this.id,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    if (!nullToAbsent || weightKg != null) {
      map['weight_kg'] = Variable<double>(weightKg);
    }
    if (!nullToAbsent || heightCm != null) {
      map['height_cm'] = Variable<double>(heightCm);
    }
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<String>(birthDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
      weightKg: weightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(weightKg),
      heightCm: heightCm == null && nullToAbsent
          ? const Value.absent()
          : Value(heightCm),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory UserProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileRow(
      id: serializer.fromJson<String>(json['id']),
      gender: serializer.fromJson<String?>(json['gender']),
      weightKg: serializer.fromJson<double?>(json['weightKg']),
      heightCm: serializer.fromJson<double?>(json['heightCm']),
      birthDate: serializer.fromJson<String?>(json['birthDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'gender': serializer.toJson<String?>(gender),
      'weightKg': serializer.toJson<double?>(weightKg),
      'heightCm': serializer.toJson<double?>(heightCm),
      'birthDate': serializer.toJson<String?>(birthDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  UserProfileRow copyWith({
    String? id,
    Value<String?> gender = const Value.absent(),
    Value<double?> weightKg = const Value.absent(),
    Value<double?> heightCm = const Value.absent(),
    Value<String?> birthDate = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => UserProfileRow(
    id: id ?? this.id,
    gender: gender.present ? gender.value : this.gender,
    weightKg: weightKg.present ? weightKg.value : this.weightKg,
    heightCm: heightCm.present ? heightCm.value : this.heightCm,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  UserProfileRow copyWithCompanion(UserProfilesCompanion data) {
    return UserProfileRow(
      id: data.id.present ? data.id.value : this.id,
      gender: data.gender.present ? data.gender.value : this.gender,
      weightKg: data.weightKg.present ? data.weightKg.value : this.weightKg,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileRow(')
          ..write('id: $id, ')
          ..write('gender: $gender, ')
          ..write('weightKg: $weightKg, ')
          ..write('heightCm: $heightCm, ')
          ..write('birthDate: $birthDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    gender,
    weightKg,
    heightCm,
    birthDate,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileRow &&
          other.id == this.id &&
          other.gender == this.gender &&
          other.weightKg == this.weightKg &&
          other.heightCm == this.heightCm &&
          other.birthDate == this.birthDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfileRow> {
  final Value<String> id;
  final Value<String?> gender;
  final Value<double?> weightKg;
  final Value<double?> heightCm;
  final Value<String?> birthDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.gender = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    required String id,
    this.gender = const Value.absent(),
    this.weightKg = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.birthDate = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserProfileRow> custom({
    Expression<String>? id,
    Expression<String>? gender,
    Expression<double>? weightKg,
    Expression<double>? heightCm,
    Expression<String>? birthDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (gender != null) 'gender': gender,
      if (weightKg != null) 'weight_kg': weightKg,
      if (heightCm != null) 'height_cm': heightCm,
      if (birthDate != null) 'birth_date': birthDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesCompanion copyWith({
    Value<String>? id,
    Value<String?>? gender,
    Value<double?>? weightKg,
    Value<double?>? heightCm,
    Value<String?>? birthDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      gender: gender ?? this.gender,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (weightKg.present) {
      map['weight_kg'] = Variable<double>(weightKg.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<String>(birthDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('gender: $gender, ')
          ..write('weightKg: $weightKg, ')
          ..write('heightCm: $heightCm, ')
          ..write('birthDate: $birthDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTableTable extends UserPreferencesTable
    with TableInfo<$UserPreferencesTableTable, UserPreferencesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dailyGoalMlMeta = const VerificationMeta(
    'dailyGoalMl',
  );
  @override
  late final GeneratedColumn<int> dailyGoalMl = GeneratedColumn<int>(
    'daily_goal_ml',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayBoundaryHourMeta = const VerificationMeta(
    'dayBoundaryHour',
  );
  @override
  late final GeneratedColumn<int> dayBoundaryHour = GeneratedColumn<int>(
    'day_boundary_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<String> units = GeneratedColumn<String>(
    'units',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('metric'),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('EUR'),
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _reminderStartHourMeta = const VerificationMeta(
    'reminderStartHour',
  );
  @override
  late final GeneratedColumn<int> reminderStartHour = GeneratedColumn<int>(
    'reminder_start_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8),
  );
  static const VerificationMeta _reminderEndHourMeta = const VerificationMeta(
    'reminderEndHour',
  );
  @override
  late final GeneratedColumn<int> reminderEndHour = GeneratedColumn<int>(
    'reminder_end_hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(22),
  );
  static const VerificationMeta _reminderIntervalMinMeta =
      const VerificationMeta('reminderIntervalMin');
  @override
  late final GeneratedColumn<int> reminderIntervalMin = GeneratedColumn<int>(
    'reminder_interval_min',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(90),
  );
  static const VerificationMeta _inactivityReminderEnabledMeta =
      const VerificationMeta('inactivityReminderEnabled');
  @override
  late final GeneratedColumn<bool> inactivityReminderEnabled =
      GeneratedColumn<bool>(
        'inactivity_reminder_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("inactivity_reminder_enabled" IN (0, 1))',
        ),
      );
  static const VerificationMeta _weeklySummaryEnabledMeta =
      const VerificationMeta('weeklySummaryEnabled');
  @override
  late final GeneratedColumn<bool> weeklySummaryEnabled = GeneratedColumn<bool>(
    'weekly_summary_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("weekly_summary_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _defaultDrinkPresetIdMeta =
      const VerificationMeta('defaultDrinkPresetId');
  @override
  late final GeneratedColumn<String> defaultDrinkPresetId =
      GeneratedColumn<String>(
        'default_drink_preset_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _bacCapGramsPerLMeta = const VerificationMeta(
    'bacCapGramsPerL',
  );
  @override
  late final GeneratedColumn<double> bacCapGramsPerL = GeneratedColumn<double>(
    'bac_cap_grams_per_l',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bacOnLockScreenEnabledMeta =
      const VerificationMeta('bacOnLockScreenEnabled');
  @override
  late final GeneratedColumn<bool> bacOnLockScreenEnabled =
      GeneratedColumn<bool>(
        'bac_on_lock_screen_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("bac_on_lock_screen_enabled" IN (0, 1))',
        ),
      );
  static const VerificationMeta _approachingCapNotifEnabledMeta =
      const VerificationMeta('approachingCapNotifEnabled');
  @override
  late final GeneratedColumn<bool> approachingCapNotifEnabled =
      GeneratedColumn<bool>(
        'approaching_cap_notif_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("approaching_cap_notif_enabled" IN (0, 1))',
        ),
      );
  static const VerificationMeta _soberEstimateNotifEnabledMeta =
      const VerificationMeta('soberEstimateNotifEnabled');
  @override
  late final GeneratedColumn<bool> soberEstimateNotifEnabled =
      GeneratedColumn<bool>(
        'sober_estimate_notif_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("sober_estimate_notif_enabled" IN (0, 1))',
        ),
      );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<int> installedAt = GeneratedColumn<int>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    username,
    dailyGoalMl,
    dayBoundaryHour,
    units,
    currency,
    reminderEnabled,
    reminderStartHour,
    reminderEndHour,
    reminderIntervalMin,
    inactivityReminderEnabled,
    weeklySummaryEnabled,
    defaultDrinkPresetId,
    bacCapGramsPerL,
    bacOnLockScreenEnabled,
    approachingCapNotifEnabled,
    soberEstimateNotifEnabled,
    installedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreferencesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    }
    if (data.containsKey('daily_goal_ml')) {
      context.handle(
        _dailyGoalMlMeta,
        dailyGoalMl.isAcceptableOrUnknown(
          data['daily_goal_ml']!,
          _dailyGoalMlMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dailyGoalMlMeta);
    }
    if (data.containsKey('day_boundary_hour')) {
      context.handle(
        _dayBoundaryHourMeta,
        dayBoundaryHour.isAcceptableOrUnknown(
          data['day_boundary_hour']!,
          _dayBoundaryHourMeta,
        ),
      );
    }
    if (data.containsKey('units')) {
      context.handle(
        _unitsMeta,
        units.isAcceptableOrUnknown(data['units']!, _unitsMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reminderEnabledMeta);
    }
    if (data.containsKey('reminder_start_hour')) {
      context.handle(
        _reminderStartHourMeta,
        reminderStartHour.isAcceptableOrUnknown(
          data['reminder_start_hour']!,
          _reminderStartHourMeta,
        ),
      );
    }
    if (data.containsKey('reminder_end_hour')) {
      context.handle(
        _reminderEndHourMeta,
        reminderEndHour.isAcceptableOrUnknown(
          data['reminder_end_hour']!,
          _reminderEndHourMeta,
        ),
      );
    }
    if (data.containsKey('reminder_interval_min')) {
      context.handle(
        _reminderIntervalMinMeta,
        reminderIntervalMin.isAcceptableOrUnknown(
          data['reminder_interval_min']!,
          _reminderIntervalMinMeta,
        ),
      );
    }
    if (data.containsKey('inactivity_reminder_enabled')) {
      context.handle(
        _inactivityReminderEnabledMeta,
        inactivityReminderEnabled.isAcceptableOrUnknown(
          data['inactivity_reminder_enabled']!,
          _inactivityReminderEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_inactivityReminderEnabledMeta);
    }
    if (data.containsKey('weekly_summary_enabled')) {
      context.handle(
        _weeklySummaryEnabledMeta,
        weeklySummaryEnabled.isAcceptableOrUnknown(
          data['weekly_summary_enabled']!,
          _weeklySummaryEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weeklySummaryEnabledMeta);
    }
    if (data.containsKey('default_drink_preset_id')) {
      context.handle(
        _defaultDrinkPresetIdMeta,
        defaultDrinkPresetId.isAcceptableOrUnknown(
          data['default_drink_preset_id']!,
          _defaultDrinkPresetIdMeta,
        ),
      );
    }
    if (data.containsKey('bac_cap_grams_per_l')) {
      context.handle(
        _bacCapGramsPerLMeta,
        bacCapGramsPerL.isAcceptableOrUnknown(
          data['bac_cap_grams_per_l']!,
          _bacCapGramsPerLMeta,
        ),
      );
    }
    if (data.containsKey('bac_on_lock_screen_enabled')) {
      context.handle(
        _bacOnLockScreenEnabledMeta,
        bacOnLockScreenEnabled.isAcceptableOrUnknown(
          data['bac_on_lock_screen_enabled']!,
          _bacOnLockScreenEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_bacOnLockScreenEnabledMeta);
    }
    if (data.containsKey('approaching_cap_notif_enabled')) {
      context.handle(
        _approachingCapNotifEnabledMeta,
        approachingCapNotifEnabled.isAcceptableOrUnknown(
          data['approaching_cap_notif_enabled']!,
          _approachingCapNotifEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_approachingCapNotifEnabledMeta);
    }
    if (data.containsKey('sober_estimate_notif_enabled')) {
      context.handle(
        _soberEstimateNotifEnabledMeta,
        soberEstimateNotifEnabled.isAcceptableOrUnknown(
          data['sober_estimate_notif_enabled']!,
          _soberEstimateNotifEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_soberEstimateNotifEnabledMeta);
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPreferencesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreferencesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      ),
      dailyGoalMl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}daily_goal_ml'],
      )!,
      dayBoundaryHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_boundary_hour'],
      )!,
      units: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}units'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderStartHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_start_hour'],
      )!,
      reminderEndHour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_end_hour'],
      )!,
      reminderIntervalMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_interval_min'],
      )!,
      inactivityReminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}inactivity_reminder_enabled'],
      )!,
      weeklySummaryEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}weekly_summary_enabled'],
      )!,
      defaultDrinkPresetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_drink_preset_id'],
      ),
      bacCapGramsPerL: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bac_cap_grams_per_l'],
      ),
      bacOnLockScreenEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}bac_on_lock_screen_enabled'],
      )!,
      approachingCapNotifEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}approaching_cap_notif_enabled'],
      )!,
      soberEstimateNotifEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sober_estimate_notif_enabled'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}installed_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserPreferencesTableTable createAlias(String alias) {
    return $UserPreferencesTableTable(attachedDatabase, alias);
  }
}

class UserPreferencesRow extends DataClass
    implements Insertable<UserPreferencesRow> {
  final String id;

  /// Display username — NFC-normalised before storing (Parity Rulebook §Username).
  /// Null until the user completes onboarding.
  final String? username;

  /// Daily hydration goal in millilitres (metric canonical — C1).
  /// Updated during onboarding. Seeded to 2000 ml as a placeholder.
  final int dailyGoalMl;

  /// Hour-of-day when the new "day" begins for goal tracking (0–23).
  final int dayBoundaryHour;

  /// Display unit preference: 'metric' | 'imperial'. Storage is always metric.
  final String units;

  /// Preferred currency: 'EUR' | 'USD' | 'GBP'.
  final String currency;
  final bool reminderEnabled;

  /// Hour-of-day when the reminder active window starts (default 8 = 08:00).
  final int reminderStartHour;

  /// Hour-of-day when the reminder active window ends (default 22 = 22:00).
  final int reminderEndHour;

  /// How often to remind, in minutes.
  final int reminderIntervalMin;
  final bool inactivityReminderEnabled;
  final bool weeklySummaryEnabled;

  /// FK to DrinkPresets.id. Nullable — falls back to seeded "Glass of water".
  final String? defaultDrinkPresetId;

  /// Optional personal BAC cap, g/L canonical. Null = no cap.
  final double? bacCapGramsPerL;
  final bool bacOnLockScreenEnabled;

  /// Party Mode notification toggles — default OFF per notifications.md §4.
  final bool approachingCapNotifEnabled;
  final bool soberEstimateNotifEnabled;

  /// Epoch-milliseconds of when the local database was first created.
  /// Set once in beforeOpen; never changes.
  final int installedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserPreferencesRow({
    required this.id,
    this.username,
    required this.dailyGoalMl,
    required this.dayBoundaryHour,
    required this.units,
    required this.currency,
    required this.reminderEnabled,
    required this.reminderStartHour,
    required this.reminderEndHour,
    required this.reminderIntervalMin,
    required this.inactivityReminderEnabled,
    required this.weeklySummaryEnabled,
    this.defaultDrinkPresetId,
    this.bacCapGramsPerL,
    required this.bacOnLockScreenEnabled,
    required this.approachingCapNotifEnabled,
    required this.soberEstimateNotifEnabled,
    required this.installedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || username != null) {
      map['username'] = Variable<String>(username);
    }
    map['daily_goal_ml'] = Variable<int>(dailyGoalMl);
    map['day_boundary_hour'] = Variable<int>(dayBoundaryHour);
    map['units'] = Variable<String>(units);
    map['currency'] = Variable<String>(currency);
    map['reminder_enabled'] = Variable<bool>(reminderEnabled);
    map['reminder_start_hour'] = Variable<int>(reminderStartHour);
    map['reminder_end_hour'] = Variable<int>(reminderEndHour);
    map['reminder_interval_min'] = Variable<int>(reminderIntervalMin);
    map['inactivity_reminder_enabled'] = Variable<bool>(
      inactivityReminderEnabled,
    );
    map['weekly_summary_enabled'] = Variable<bool>(weeklySummaryEnabled);
    if (!nullToAbsent || defaultDrinkPresetId != null) {
      map['default_drink_preset_id'] = Variable<String>(defaultDrinkPresetId);
    }
    if (!nullToAbsent || bacCapGramsPerL != null) {
      map['bac_cap_grams_per_l'] = Variable<double>(bacCapGramsPerL);
    }
    map['bac_on_lock_screen_enabled'] = Variable<bool>(bacOnLockScreenEnabled);
    map['approaching_cap_notif_enabled'] = Variable<bool>(
      approachingCapNotifEnabled,
    );
    map['sober_estimate_notif_enabled'] = Variable<bool>(
      soberEstimateNotifEnabled,
    );
    map['installed_at'] = Variable<int>(installedAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesTableCompanion(
      id: Value(id),
      username: username == null && nullToAbsent
          ? const Value.absent()
          : Value(username),
      dailyGoalMl: Value(dailyGoalMl),
      dayBoundaryHour: Value(dayBoundaryHour),
      units: Value(units),
      currency: Value(currency),
      reminderEnabled: Value(reminderEnabled),
      reminderStartHour: Value(reminderStartHour),
      reminderEndHour: Value(reminderEndHour),
      reminderIntervalMin: Value(reminderIntervalMin),
      inactivityReminderEnabled: Value(inactivityReminderEnabled),
      weeklySummaryEnabled: Value(weeklySummaryEnabled),
      defaultDrinkPresetId: defaultDrinkPresetId == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultDrinkPresetId),
      bacCapGramsPerL: bacCapGramsPerL == null && nullToAbsent
          ? const Value.absent()
          : Value(bacCapGramsPerL),
      bacOnLockScreenEnabled: Value(bacOnLockScreenEnabled),
      approachingCapNotifEnabled: Value(approachingCapNotifEnabled),
      soberEstimateNotifEnabled: Value(soberEstimateNotifEnabled),
      installedAt: Value(installedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserPreferencesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreferencesRow(
      id: serializer.fromJson<String>(json['id']),
      username: serializer.fromJson<String?>(json['username']),
      dailyGoalMl: serializer.fromJson<int>(json['dailyGoalMl']),
      dayBoundaryHour: serializer.fromJson<int>(json['dayBoundaryHour']),
      units: serializer.fromJson<String>(json['units']),
      currency: serializer.fromJson<String>(json['currency']),
      reminderEnabled: serializer.fromJson<bool>(json['reminderEnabled']),
      reminderStartHour: serializer.fromJson<int>(json['reminderStartHour']),
      reminderEndHour: serializer.fromJson<int>(json['reminderEndHour']),
      reminderIntervalMin: serializer.fromJson<int>(
        json['reminderIntervalMin'],
      ),
      inactivityReminderEnabled: serializer.fromJson<bool>(
        json['inactivityReminderEnabled'],
      ),
      weeklySummaryEnabled: serializer.fromJson<bool>(
        json['weeklySummaryEnabled'],
      ),
      defaultDrinkPresetId: serializer.fromJson<String?>(
        json['defaultDrinkPresetId'],
      ),
      bacCapGramsPerL: serializer.fromJson<double?>(json['bacCapGramsPerL']),
      bacOnLockScreenEnabled: serializer.fromJson<bool>(
        json['bacOnLockScreenEnabled'],
      ),
      approachingCapNotifEnabled: serializer.fromJson<bool>(
        json['approachingCapNotifEnabled'],
      ),
      soberEstimateNotifEnabled: serializer.fromJson<bool>(
        json['soberEstimateNotifEnabled'],
      ),
      installedAt: serializer.fromJson<int>(json['installedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'username': serializer.toJson<String?>(username),
      'dailyGoalMl': serializer.toJson<int>(dailyGoalMl),
      'dayBoundaryHour': serializer.toJson<int>(dayBoundaryHour),
      'units': serializer.toJson<String>(units),
      'currency': serializer.toJson<String>(currency),
      'reminderEnabled': serializer.toJson<bool>(reminderEnabled),
      'reminderStartHour': serializer.toJson<int>(reminderStartHour),
      'reminderEndHour': serializer.toJson<int>(reminderEndHour),
      'reminderIntervalMin': serializer.toJson<int>(reminderIntervalMin),
      'inactivityReminderEnabled': serializer.toJson<bool>(
        inactivityReminderEnabled,
      ),
      'weeklySummaryEnabled': serializer.toJson<bool>(weeklySummaryEnabled),
      'defaultDrinkPresetId': serializer.toJson<String?>(defaultDrinkPresetId),
      'bacCapGramsPerL': serializer.toJson<double?>(bacCapGramsPerL),
      'bacOnLockScreenEnabled': serializer.toJson<bool>(bacOnLockScreenEnabled),
      'approachingCapNotifEnabled': serializer.toJson<bool>(
        approachingCapNotifEnabled,
      ),
      'soberEstimateNotifEnabled': serializer.toJson<bool>(
        soberEstimateNotifEnabled,
      ),
      'installedAt': serializer.toJson<int>(installedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPreferencesRow copyWith({
    String? id,
    Value<String?> username = const Value.absent(),
    int? dailyGoalMl,
    int? dayBoundaryHour,
    String? units,
    String? currency,
    bool? reminderEnabled,
    int? reminderStartHour,
    int? reminderEndHour,
    int? reminderIntervalMin,
    bool? inactivityReminderEnabled,
    bool? weeklySummaryEnabled,
    Value<String?> defaultDrinkPresetId = const Value.absent(),
    Value<double?> bacCapGramsPerL = const Value.absent(),
    bool? bacOnLockScreenEnabled,
    bool? approachingCapNotifEnabled,
    bool? soberEstimateNotifEnabled,
    int? installedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserPreferencesRow(
    id: id ?? this.id,
    username: username.present ? username.value : this.username,
    dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
    dayBoundaryHour: dayBoundaryHour ?? this.dayBoundaryHour,
    units: units ?? this.units,
    currency: currency ?? this.currency,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderStartHour: reminderStartHour ?? this.reminderStartHour,
    reminderEndHour: reminderEndHour ?? this.reminderEndHour,
    reminderIntervalMin: reminderIntervalMin ?? this.reminderIntervalMin,
    inactivityReminderEnabled:
        inactivityReminderEnabled ?? this.inactivityReminderEnabled,
    weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
    defaultDrinkPresetId: defaultDrinkPresetId.present
        ? defaultDrinkPresetId.value
        : this.defaultDrinkPresetId,
    bacCapGramsPerL: bacCapGramsPerL.present
        ? bacCapGramsPerL.value
        : this.bacCapGramsPerL,
    bacOnLockScreenEnabled:
        bacOnLockScreenEnabled ?? this.bacOnLockScreenEnabled,
    approachingCapNotifEnabled:
        approachingCapNotifEnabled ?? this.approachingCapNotifEnabled,
    soberEstimateNotifEnabled:
        soberEstimateNotifEnabled ?? this.soberEstimateNotifEnabled,
    installedAt: installedAt ?? this.installedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserPreferencesRow copyWithCompanion(UserPreferencesTableCompanion data) {
    return UserPreferencesRow(
      id: data.id.present ? data.id.value : this.id,
      username: data.username.present ? data.username.value : this.username,
      dailyGoalMl: data.dailyGoalMl.present
          ? data.dailyGoalMl.value
          : this.dailyGoalMl,
      dayBoundaryHour: data.dayBoundaryHour.present
          ? data.dayBoundaryHour.value
          : this.dayBoundaryHour,
      units: data.units.present ? data.units.value : this.units,
      currency: data.currency.present ? data.currency.value : this.currency,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderStartHour: data.reminderStartHour.present
          ? data.reminderStartHour.value
          : this.reminderStartHour,
      reminderEndHour: data.reminderEndHour.present
          ? data.reminderEndHour.value
          : this.reminderEndHour,
      reminderIntervalMin: data.reminderIntervalMin.present
          ? data.reminderIntervalMin.value
          : this.reminderIntervalMin,
      inactivityReminderEnabled: data.inactivityReminderEnabled.present
          ? data.inactivityReminderEnabled.value
          : this.inactivityReminderEnabled,
      weeklySummaryEnabled: data.weeklySummaryEnabled.present
          ? data.weeklySummaryEnabled.value
          : this.weeklySummaryEnabled,
      defaultDrinkPresetId: data.defaultDrinkPresetId.present
          ? data.defaultDrinkPresetId.value
          : this.defaultDrinkPresetId,
      bacCapGramsPerL: data.bacCapGramsPerL.present
          ? data.bacCapGramsPerL.value
          : this.bacCapGramsPerL,
      bacOnLockScreenEnabled: data.bacOnLockScreenEnabled.present
          ? data.bacOnLockScreenEnabled.value
          : this.bacOnLockScreenEnabled,
      approachingCapNotifEnabled: data.approachingCapNotifEnabled.present
          ? data.approachingCapNotifEnabled.value
          : this.approachingCapNotifEnabled,
      soberEstimateNotifEnabled: data.soberEstimateNotifEnabled.present
          ? data.soberEstimateNotifEnabled.value
          : this.soberEstimateNotifEnabled,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesRow(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('dailyGoalMl: $dailyGoalMl, ')
          ..write('dayBoundaryHour: $dayBoundaryHour, ')
          ..write('units: $units, ')
          ..write('currency: $currency, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderStartHour: $reminderStartHour, ')
          ..write('reminderEndHour: $reminderEndHour, ')
          ..write('reminderIntervalMin: $reminderIntervalMin, ')
          ..write('inactivityReminderEnabled: $inactivityReminderEnabled, ')
          ..write('weeklySummaryEnabled: $weeklySummaryEnabled, ')
          ..write('defaultDrinkPresetId: $defaultDrinkPresetId, ')
          ..write('bacCapGramsPerL: $bacCapGramsPerL, ')
          ..write('bacOnLockScreenEnabled: $bacOnLockScreenEnabled, ')
          ..write('approachingCapNotifEnabled: $approachingCapNotifEnabled, ')
          ..write('soberEstimateNotifEnabled: $soberEstimateNotifEnabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    username,
    dailyGoalMl,
    dayBoundaryHour,
    units,
    currency,
    reminderEnabled,
    reminderStartHour,
    reminderEndHour,
    reminderIntervalMin,
    inactivityReminderEnabled,
    weeklySummaryEnabled,
    defaultDrinkPresetId,
    bacCapGramsPerL,
    bacOnLockScreenEnabled,
    approachingCapNotifEnabled,
    soberEstimateNotifEnabled,
    installedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreferencesRow &&
          other.id == this.id &&
          other.username == this.username &&
          other.dailyGoalMl == this.dailyGoalMl &&
          other.dayBoundaryHour == this.dayBoundaryHour &&
          other.units == this.units &&
          other.currency == this.currency &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderStartHour == this.reminderStartHour &&
          other.reminderEndHour == this.reminderEndHour &&
          other.reminderIntervalMin == this.reminderIntervalMin &&
          other.inactivityReminderEnabled == this.inactivityReminderEnabled &&
          other.weeklySummaryEnabled == this.weeklySummaryEnabled &&
          other.defaultDrinkPresetId == this.defaultDrinkPresetId &&
          other.bacCapGramsPerL == this.bacCapGramsPerL &&
          other.bacOnLockScreenEnabled == this.bacOnLockScreenEnabled &&
          other.approachingCapNotifEnabled == this.approachingCapNotifEnabled &&
          other.soberEstimateNotifEnabled == this.soberEstimateNotifEnabled &&
          other.installedAt == this.installedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserPreferencesTableCompanion
    extends UpdateCompanion<UserPreferencesRow> {
  final Value<String> id;
  final Value<String?> username;
  final Value<int> dailyGoalMl;
  final Value<int> dayBoundaryHour;
  final Value<String> units;
  final Value<String> currency;
  final Value<bool> reminderEnabled;
  final Value<int> reminderStartHour;
  final Value<int> reminderEndHour;
  final Value<int> reminderIntervalMin;
  final Value<bool> inactivityReminderEnabled;
  final Value<bool> weeklySummaryEnabled;
  final Value<String?> defaultDrinkPresetId;
  final Value<double?> bacCapGramsPerL;
  final Value<bool> bacOnLockScreenEnabled;
  final Value<bool> approachingCapNotifEnabled;
  final Value<bool> soberEstimateNotifEnabled;
  final Value<int> installedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserPreferencesTableCompanion({
    this.id = const Value.absent(),
    this.username = const Value.absent(),
    this.dailyGoalMl = const Value.absent(),
    this.dayBoundaryHour = const Value.absent(),
    this.units = const Value.absent(),
    this.currency = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderStartHour = const Value.absent(),
    this.reminderEndHour = const Value.absent(),
    this.reminderIntervalMin = const Value.absent(),
    this.inactivityReminderEnabled = const Value.absent(),
    this.weeklySummaryEnabled = const Value.absent(),
    this.defaultDrinkPresetId = const Value.absent(),
    this.bacCapGramsPerL = const Value.absent(),
    this.bacOnLockScreenEnabled = const Value.absent(),
    this.approachingCapNotifEnabled = const Value.absent(),
    this.soberEstimateNotifEnabled = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferencesTableCompanion.insert({
    required String id,
    this.username = const Value.absent(),
    required int dailyGoalMl,
    this.dayBoundaryHour = const Value.absent(),
    this.units = const Value.absent(),
    this.currency = const Value.absent(),
    required bool reminderEnabled,
    this.reminderStartHour = const Value.absent(),
    this.reminderEndHour = const Value.absent(),
    this.reminderIntervalMin = const Value.absent(),
    required bool inactivityReminderEnabled,
    required bool weeklySummaryEnabled,
    this.defaultDrinkPresetId = const Value.absent(),
    this.bacCapGramsPerL = const Value.absent(),
    required bool bacOnLockScreenEnabled,
    required bool approachingCapNotifEnabled,
    required bool soberEstimateNotifEnabled,
    required int installedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       dailyGoalMl = Value(dailyGoalMl),
       reminderEnabled = Value(reminderEnabled),
       inactivityReminderEnabled = Value(inactivityReminderEnabled),
       weeklySummaryEnabled = Value(weeklySummaryEnabled),
       bacOnLockScreenEnabled = Value(bacOnLockScreenEnabled),
       approachingCapNotifEnabled = Value(approachingCapNotifEnabled),
       soberEstimateNotifEnabled = Value(soberEstimateNotifEnabled),
       installedAt = Value(installedAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserPreferencesRow> custom({
    Expression<String>? id,
    Expression<String>? username,
    Expression<int>? dailyGoalMl,
    Expression<int>? dayBoundaryHour,
    Expression<String>? units,
    Expression<String>? currency,
    Expression<bool>? reminderEnabled,
    Expression<int>? reminderStartHour,
    Expression<int>? reminderEndHour,
    Expression<int>? reminderIntervalMin,
    Expression<bool>? inactivityReminderEnabled,
    Expression<bool>? weeklySummaryEnabled,
    Expression<String>? defaultDrinkPresetId,
    Expression<double>? bacCapGramsPerL,
    Expression<bool>? bacOnLockScreenEnabled,
    Expression<bool>? approachingCapNotifEnabled,
    Expression<bool>? soberEstimateNotifEnabled,
    Expression<int>? installedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (username != null) 'username': username,
      if (dailyGoalMl != null) 'daily_goal_ml': dailyGoalMl,
      if (dayBoundaryHour != null) 'day_boundary_hour': dayBoundaryHour,
      if (units != null) 'units': units,
      if (currency != null) 'currency': currency,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderStartHour != null) 'reminder_start_hour': reminderStartHour,
      if (reminderEndHour != null) 'reminder_end_hour': reminderEndHour,
      if (reminderIntervalMin != null)
        'reminder_interval_min': reminderIntervalMin,
      if (inactivityReminderEnabled != null)
        'inactivity_reminder_enabled': inactivityReminderEnabled,
      if (weeklySummaryEnabled != null)
        'weekly_summary_enabled': weeklySummaryEnabled,
      if (defaultDrinkPresetId != null)
        'default_drink_preset_id': defaultDrinkPresetId,
      if (bacCapGramsPerL != null) 'bac_cap_grams_per_l': bacCapGramsPerL,
      if (bacOnLockScreenEnabled != null)
        'bac_on_lock_screen_enabled': bacOnLockScreenEnabled,
      if (approachingCapNotifEnabled != null)
        'approaching_cap_notif_enabled': approachingCapNotifEnabled,
      if (soberEstimateNotifEnabled != null)
        'sober_estimate_notif_enabled': soberEstimateNotifEnabled,
      if (installedAt != null) 'installed_at': installedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferencesTableCompanion copyWith({
    Value<String>? id,
    Value<String?>? username,
    Value<int>? dailyGoalMl,
    Value<int>? dayBoundaryHour,
    Value<String>? units,
    Value<String>? currency,
    Value<bool>? reminderEnabled,
    Value<int>? reminderStartHour,
    Value<int>? reminderEndHour,
    Value<int>? reminderIntervalMin,
    Value<bool>? inactivityReminderEnabled,
    Value<bool>? weeklySummaryEnabled,
    Value<String?>? defaultDrinkPresetId,
    Value<double?>? bacCapGramsPerL,
    Value<bool>? bacOnLockScreenEnabled,
    Value<bool>? approachingCapNotifEnabled,
    Value<bool>? soberEstimateNotifEnabled,
    Value<int>? installedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserPreferencesTableCompanion(
      id: id ?? this.id,
      username: username ?? this.username,
      dailyGoalMl: dailyGoalMl ?? this.dailyGoalMl,
      dayBoundaryHour: dayBoundaryHour ?? this.dayBoundaryHour,
      units: units ?? this.units,
      currency: currency ?? this.currency,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderStartHour: reminderStartHour ?? this.reminderStartHour,
      reminderEndHour: reminderEndHour ?? this.reminderEndHour,
      reminderIntervalMin: reminderIntervalMin ?? this.reminderIntervalMin,
      inactivityReminderEnabled:
          inactivityReminderEnabled ?? this.inactivityReminderEnabled,
      weeklySummaryEnabled: weeklySummaryEnabled ?? this.weeklySummaryEnabled,
      defaultDrinkPresetId: defaultDrinkPresetId ?? this.defaultDrinkPresetId,
      bacCapGramsPerL: bacCapGramsPerL ?? this.bacCapGramsPerL,
      bacOnLockScreenEnabled:
          bacOnLockScreenEnabled ?? this.bacOnLockScreenEnabled,
      approachingCapNotifEnabled:
          approachingCapNotifEnabled ?? this.approachingCapNotifEnabled,
      soberEstimateNotifEnabled:
          soberEstimateNotifEnabled ?? this.soberEstimateNotifEnabled,
      installedAt: installedAt ?? this.installedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (dailyGoalMl.present) {
      map['daily_goal_ml'] = Variable<int>(dailyGoalMl.value);
    }
    if (dayBoundaryHour.present) {
      map['day_boundary_hour'] = Variable<int>(dayBoundaryHour.value);
    }
    if (units.present) {
      map['units'] = Variable<String>(units.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<bool>(reminderEnabled.value);
    }
    if (reminderStartHour.present) {
      map['reminder_start_hour'] = Variable<int>(reminderStartHour.value);
    }
    if (reminderEndHour.present) {
      map['reminder_end_hour'] = Variable<int>(reminderEndHour.value);
    }
    if (reminderIntervalMin.present) {
      map['reminder_interval_min'] = Variable<int>(reminderIntervalMin.value);
    }
    if (inactivityReminderEnabled.present) {
      map['inactivity_reminder_enabled'] = Variable<bool>(
        inactivityReminderEnabled.value,
      );
    }
    if (weeklySummaryEnabled.present) {
      map['weekly_summary_enabled'] = Variable<bool>(
        weeklySummaryEnabled.value,
      );
    }
    if (defaultDrinkPresetId.present) {
      map['default_drink_preset_id'] = Variable<String>(
        defaultDrinkPresetId.value,
      );
    }
    if (bacCapGramsPerL.present) {
      map['bac_cap_grams_per_l'] = Variable<double>(bacCapGramsPerL.value);
    }
    if (bacOnLockScreenEnabled.present) {
      map['bac_on_lock_screen_enabled'] = Variable<bool>(
        bacOnLockScreenEnabled.value,
      );
    }
    if (approachingCapNotifEnabled.present) {
      map['approaching_cap_notif_enabled'] = Variable<bool>(
        approachingCapNotifEnabled.value,
      );
    }
    if (soberEstimateNotifEnabled.present) {
      map['sober_estimate_notif_enabled'] = Variable<bool>(
        soberEstimateNotifEnabled.value,
      );
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<int>(installedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesTableCompanion(')
          ..write('id: $id, ')
          ..write('username: $username, ')
          ..write('dailyGoalMl: $dailyGoalMl, ')
          ..write('dayBoundaryHour: $dayBoundaryHour, ')
          ..write('units: $units, ')
          ..write('currency: $currency, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderStartHour: $reminderStartHour, ')
          ..write('reminderEndHour: $reminderEndHour, ')
          ..write('reminderIntervalMin: $reminderIntervalMin, ')
          ..write('inactivityReminderEnabled: $inactivityReminderEnabled, ')
          ..write('weeklySummaryEnabled: $weeklySummaryEnabled, ')
          ..write('defaultDrinkPresetId: $defaultDrinkPresetId, ')
          ..write('bacCapGramsPerL: $bacCapGramsPerL, ')
          ..write('bacOnLockScreenEnabled: $bacOnLockScreenEnabled, ')
          ..write('approachingCapNotifEnabled: $approachingCapNotifEnabled, ')
          ..write('soberEstimateNotifEnabled: $soberEstimateNotifEnabled, ')
          ..write('installedAt: $installedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DrinkPresetsTable drinkPresets = $DrinkPresetsTable(this);
  late final $DrinkEntriesTable drinkEntries = $DrinkEntriesTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $UserPreferencesTableTable userPreferencesTable =
      $UserPreferencesTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    drinkPresets,
    drinkEntries,
    userProfiles,
    userPreferencesTable,
  ];
}

typedef $$DrinkPresetsTableCreateCompanionBuilder =
    DrinkPresetsCompanion Function({
      required String id,
      required String name,
      required String beverageType,
      required int volumeMl,
      Value<double?> abvPercent,
      Value<int?> regularPriceMinor,
      Value<String?> regularCurrency,
      required String iconKey,
      required String iconColor,
      required bool isUserCreated,
      Value<bool> isHidden,
      required int sortOrder,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$DrinkPresetsTableUpdateCompanionBuilder =
    DrinkPresetsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> beverageType,
      Value<int> volumeMl,
      Value<double?> abvPercent,
      Value<int?> regularPriceMinor,
      Value<String?> regularCurrency,
      Value<String> iconKey,
      Value<String> iconColor,
      Value<bool> isUserCreated,
      Value<bool> isHidden,
      Value<int> sortOrder,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$DrinkPresetsTableFilterComposer
    extends Composer<_$AppDatabase, $DrinkPresetsTable> {
  $$DrinkPresetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beverageType => $composableBuilder(
    column: $table.beverageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volumeMl => $composableBuilder(
    column: $table.volumeMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get abvPercent => $composableBuilder(
    column: $table.abvPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get regularPriceMinor => $composableBuilder(
    column: $table.regularPriceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regularCurrency => $composableBuilder(
    column: $table.regularCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconColor => $composableBuilder(
    column: $table.iconColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUserCreated => $composableBuilder(
    column: $table.isUserCreated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DrinkPresetsTableOrderingComposer
    extends Composer<_$AppDatabase, $DrinkPresetsTable> {
  $$DrinkPresetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beverageType => $composableBuilder(
    column: $table.beverageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volumeMl => $composableBuilder(
    column: $table.volumeMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get abvPercent => $composableBuilder(
    column: $table.abvPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get regularPriceMinor => $composableBuilder(
    column: $table.regularPriceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regularCurrency => $composableBuilder(
    column: $table.regularCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconColor => $composableBuilder(
    column: $table.iconColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUserCreated => $composableBuilder(
    column: $table.isUserCreated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isHidden => $composableBuilder(
    column: $table.isHidden,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DrinkPresetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DrinkPresetsTable> {
  $$DrinkPresetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get beverageType => $composableBuilder(
    column: $table.beverageType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get volumeMl =>
      $composableBuilder(column: $table.volumeMl, builder: (column) => column);

  GeneratedColumn<double> get abvPercent => $composableBuilder(
    column: $table.abvPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get regularPriceMinor => $composableBuilder(
    column: $table.regularPriceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get regularCurrency => $composableBuilder(
    column: $table.regularCurrency,
    builder: (column) => column,
  );

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get iconColor =>
      $composableBuilder(column: $table.iconColor, builder: (column) => column);

  GeneratedColumn<bool> get isUserCreated => $composableBuilder(
    column: $table.isUserCreated,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isHidden =>
      $composableBuilder(column: $table.isHidden, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DrinkPresetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DrinkPresetsTable,
          DrinkPresetRow,
          $$DrinkPresetsTableFilterComposer,
          $$DrinkPresetsTableOrderingComposer,
          $$DrinkPresetsTableAnnotationComposer,
          $$DrinkPresetsTableCreateCompanionBuilder,
          $$DrinkPresetsTableUpdateCompanionBuilder,
          (
            DrinkPresetRow,
            BaseReferences<_$AppDatabase, $DrinkPresetsTable, DrinkPresetRow>,
          ),
          DrinkPresetRow,
          PrefetchHooks Function()
        > {
  $$DrinkPresetsTableTableManager(_$AppDatabase db, $DrinkPresetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DrinkPresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DrinkPresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DrinkPresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> beverageType = const Value.absent(),
                Value<int> volumeMl = const Value.absent(),
                Value<double?> abvPercent = const Value.absent(),
                Value<int?> regularPriceMinor = const Value.absent(),
                Value<String?> regularCurrency = const Value.absent(),
                Value<String> iconKey = const Value.absent(),
                Value<String> iconColor = const Value.absent(),
                Value<bool> isUserCreated = const Value.absent(),
                Value<bool> isHidden = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DrinkPresetsCompanion(
                id: id,
                name: name,
                beverageType: beverageType,
                volumeMl: volumeMl,
                abvPercent: abvPercent,
                regularPriceMinor: regularPriceMinor,
                regularCurrency: regularCurrency,
                iconKey: iconKey,
                iconColor: iconColor,
                isUserCreated: isUserCreated,
                isHidden: isHidden,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String beverageType,
                required int volumeMl,
                Value<double?> abvPercent = const Value.absent(),
                Value<int?> regularPriceMinor = const Value.absent(),
                Value<String?> regularCurrency = const Value.absent(),
                required String iconKey,
                required String iconColor,
                required bool isUserCreated,
                Value<bool> isHidden = const Value.absent(),
                required int sortOrder,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DrinkPresetsCompanion.insert(
                id: id,
                name: name,
                beverageType: beverageType,
                volumeMl: volumeMl,
                abvPercent: abvPercent,
                regularPriceMinor: regularPriceMinor,
                regularCurrency: regularCurrency,
                iconKey: iconKey,
                iconColor: iconColor,
                isUserCreated: isUserCreated,
                isHidden: isHidden,
                sortOrder: sortOrder,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DrinkPresetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DrinkPresetsTable,
      DrinkPresetRow,
      $$DrinkPresetsTableFilterComposer,
      $$DrinkPresetsTableOrderingComposer,
      $$DrinkPresetsTableAnnotationComposer,
      $$DrinkPresetsTableCreateCompanionBuilder,
      $$DrinkPresetsTableUpdateCompanionBuilder,
      (
        DrinkPresetRow,
        BaseReferences<_$AppDatabase, $DrinkPresetsTable, DrinkPresetRow>,
      ),
      DrinkPresetRow,
      PrefetchHooks Function()
    >;
typedef $$DrinkEntriesTableCreateCompanionBuilder =
    DrinkEntriesCompanion Function({
      required String id,
      Value<String?> name,
      required String beverageType,
      required int volumeMl,
      Value<double?> abvPercent,
      Value<int?> priceMinor,
      Value<String?> currency,
      Value<String?> iconKey,
      Value<String?> iconColor,
      required DateTime consumedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$DrinkEntriesTableUpdateCompanionBuilder =
    DrinkEntriesCompanion Function({
      Value<String> id,
      Value<String?> name,
      Value<String> beverageType,
      Value<int> volumeMl,
      Value<double?> abvPercent,
      Value<int?> priceMinor,
      Value<String?> currency,
      Value<String?> iconKey,
      Value<String?> iconColor,
      Value<DateTime> consumedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$DrinkEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DrinkEntriesTable> {
  $$DrinkEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get beverageType => $composableBuilder(
    column: $table.beverageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volumeMl => $composableBuilder(
    column: $table.volumeMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get abvPercent => $composableBuilder(
    column: $table.abvPercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceMinor => $composableBuilder(
    column: $table.priceMinor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconColor => $composableBuilder(
    column: $table.iconColor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DrinkEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DrinkEntriesTable> {
  $$DrinkEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get beverageType => $composableBuilder(
    column: $table.beverageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volumeMl => $composableBuilder(
    column: $table.volumeMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get abvPercent => $composableBuilder(
    column: $table.abvPercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceMinor => $composableBuilder(
    column: $table.priceMinor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconKey => $composableBuilder(
    column: $table.iconKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconColor => $composableBuilder(
    column: $table.iconColor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DrinkEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DrinkEntriesTable> {
  $$DrinkEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get beverageType => $composableBuilder(
    column: $table.beverageType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get volumeMl =>
      $composableBuilder(column: $table.volumeMl, builder: (column) => column);

  GeneratedColumn<double> get abvPercent => $composableBuilder(
    column: $table.abvPercent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priceMinor => $composableBuilder(
    column: $table.priceMinor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get iconColor =>
      $composableBuilder(column: $table.iconColor, builder: (column) => column);

  GeneratedColumn<DateTime> get consumedAt => $composableBuilder(
    column: $table.consumedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DrinkEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DrinkEntriesTable,
          DrinkEntryRow,
          $$DrinkEntriesTableFilterComposer,
          $$DrinkEntriesTableOrderingComposer,
          $$DrinkEntriesTableAnnotationComposer,
          $$DrinkEntriesTableCreateCompanionBuilder,
          $$DrinkEntriesTableUpdateCompanionBuilder,
          (
            DrinkEntryRow,
            BaseReferences<_$AppDatabase, $DrinkEntriesTable, DrinkEntryRow>,
          ),
          DrinkEntryRow,
          PrefetchHooks Function()
        > {
  $$DrinkEntriesTableTableManager(_$AppDatabase db, $DrinkEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DrinkEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DrinkEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DrinkEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String> beverageType = const Value.absent(),
                Value<int> volumeMl = const Value.absent(),
                Value<double?> abvPercent = const Value.absent(),
                Value<int?> priceMinor = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<String?> iconColor = const Value.absent(),
                Value<DateTime> consumedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DrinkEntriesCompanion(
                id: id,
                name: name,
                beverageType: beverageType,
                volumeMl: volumeMl,
                abvPercent: abvPercent,
                priceMinor: priceMinor,
                currency: currency,
                iconKey: iconKey,
                iconColor: iconColor,
                consumedAt: consumedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> name = const Value.absent(),
                required String beverageType,
                required int volumeMl,
                Value<double?> abvPercent = const Value.absent(),
                Value<int?> priceMinor = const Value.absent(),
                Value<String?> currency = const Value.absent(),
                Value<String?> iconKey = const Value.absent(),
                Value<String?> iconColor = const Value.absent(),
                required DateTime consumedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DrinkEntriesCompanion.insert(
                id: id,
                name: name,
                beverageType: beverageType,
                volumeMl: volumeMl,
                abvPercent: abvPercent,
                priceMinor: priceMinor,
                currency: currency,
                iconKey: iconKey,
                iconColor: iconColor,
                consumedAt: consumedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DrinkEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DrinkEntriesTable,
      DrinkEntryRow,
      $$DrinkEntriesTableFilterComposer,
      $$DrinkEntriesTableOrderingComposer,
      $$DrinkEntriesTableAnnotationComposer,
      $$DrinkEntriesTableCreateCompanionBuilder,
      $$DrinkEntriesTableUpdateCompanionBuilder,
      (
        DrinkEntryRow,
        BaseReferences<_$AppDatabase, $DrinkEntriesTable, DrinkEntryRow>,
      ),
      DrinkEntryRow,
      PrefetchHooks Function()
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      required String id,
      Value<String?> gender,
      Value<double?> weightKg,
      Value<double?> heightCm,
      Value<String?> birthDate,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<String> id,
      Value<String?> gender,
      Value<double?> weightKg,
      Value<double?> heightCm,
      Value<String?> birthDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightKg => $composableBuilder(
    column: $table.weightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<double> get weightKg =>
      $composableBuilder(column: $table.weightKg, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<String> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfileRow,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfileRow,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>,
          ),
          UserProfileRow,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<String?> birthDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                gender: gender,
                weightKg: weightKg,
                heightCm: heightCm,
                birthDate: birthDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> gender = const Value.absent(),
                Value<double?> weightKg = const Value.absent(),
                Value<double?> heightCm = const Value.absent(),
                Value<String?> birthDate = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                gender: gender,
                weightKg: weightKg,
                heightCm: heightCm,
                birthDate: birthDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfileRow,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfileRow,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>,
      ),
      UserProfileRow,
      PrefetchHooks Function()
    >;
typedef $$UserPreferencesTableTableCreateCompanionBuilder =
    UserPreferencesTableCompanion Function({
      required String id,
      Value<String?> username,
      required int dailyGoalMl,
      Value<int> dayBoundaryHour,
      Value<String> units,
      Value<String> currency,
      required bool reminderEnabled,
      Value<int> reminderStartHour,
      Value<int> reminderEndHour,
      Value<int> reminderIntervalMin,
      required bool inactivityReminderEnabled,
      required bool weeklySummaryEnabled,
      Value<String?> defaultDrinkPresetId,
      Value<double?> bacCapGramsPerL,
      required bool bacOnLockScreenEnabled,
      required bool approachingCapNotifEnabled,
      required bool soberEstimateNotifEnabled,
      required int installedAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UserPreferencesTableTableUpdateCompanionBuilder =
    UserPreferencesTableCompanion Function({
      Value<String> id,
      Value<String?> username,
      Value<int> dailyGoalMl,
      Value<int> dayBoundaryHour,
      Value<String> units,
      Value<String> currency,
      Value<bool> reminderEnabled,
      Value<int> reminderStartHour,
      Value<int> reminderEndHour,
      Value<int> reminderIntervalMin,
      Value<bool> inactivityReminderEnabled,
      Value<bool> weeklySummaryEnabled,
      Value<String?> defaultDrinkPresetId,
      Value<double?> bacCapGramsPerL,
      Value<bool> bacOnLockScreenEnabled,
      Value<bool> approachingCapNotifEnabled,
      Value<bool> soberEstimateNotifEnabled,
      Value<int> installedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserPreferencesTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyGoalMl => $composableBuilder(
    column: $table.dailyGoalMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dayBoundaryHour => $composableBuilder(
    column: $table.dayBoundaryHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderStartHour => $composableBuilder(
    column: $table.reminderStartHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderEndHour => $composableBuilder(
    column: $table.reminderEndHour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderIntervalMin => $composableBuilder(
    column: $table.reminderIntervalMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get inactivityReminderEnabled => $composableBuilder(
    column: $table.inactivityReminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get weeklySummaryEnabled => $composableBuilder(
    column: $table.weeklySummaryEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultDrinkPresetId => $composableBuilder(
    column: $table.defaultDrinkPresetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get bacCapGramsPerL => $composableBuilder(
    column: $table.bacCapGramsPerL,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get bacOnLockScreenEnabled => $composableBuilder(
    column: $table.bacOnLockScreenEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get approachingCapNotifEnabled => $composableBuilder(
    column: $table.approachingCapNotifEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get soberEstimateNotifEnabled => $composableBuilder(
    column: $table.soberEstimateNotifEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyGoalMl => $composableBuilder(
    column: $table.dailyGoalMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dayBoundaryHour => $composableBuilder(
    column: $table.dayBoundaryHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get units => $composableBuilder(
    column: $table.units,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderStartHour => $composableBuilder(
    column: $table.reminderStartHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderEndHour => $composableBuilder(
    column: $table.reminderEndHour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderIntervalMin => $composableBuilder(
    column: $table.reminderIntervalMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get inactivityReminderEnabled => $composableBuilder(
    column: $table.inactivityReminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get weeklySummaryEnabled => $composableBuilder(
    column: $table.weeklySummaryEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultDrinkPresetId => $composableBuilder(
    column: $table.defaultDrinkPresetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get bacCapGramsPerL => $composableBuilder(
    column: $table.bacCapGramsPerL,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get bacOnLockScreenEnabled => $composableBuilder(
    column: $table.bacOnLockScreenEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get approachingCapNotifEnabled => $composableBuilder(
    column: $table.approachingCapNotifEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get soberEstimateNotifEnabled => $composableBuilder(
    column: $table.soberEstimateNotifEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<int> get dailyGoalMl => $composableBuilder(
    column: $table.dailyGoalMl,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dayBoundaryHour => $composableBuilder(
    column: $table.dayBoundaryHour,
    builder: (column) => column,
  );

  GeneratedColumn<String> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderStartHour => $composableBuilder(
    column: $table.reminderStartHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderEndHour => $composableBuilder(
    column: $table.reminderEndHour,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderIntervalMin => $composableBuilder(
    column: $table.reminderIntervalMin,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get inactivityReminderEnabled => $composableBuilder(
    column: $table.inactivityReminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get weeklySummaryEnabled => $composableBuilder(
    column: $table.weeklySummaryEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get defaultDrinkPresetId => $composableBuilder(
    column: $table.defaultDrinkPresetId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get bacCapGramsPerL => $composableBuilder(
    column: $table.bacCapGramsPerL,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get bacOnLockScreenEnabled => $composableBuilder(
    column: $table.bacOnLockScreenEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get approachingCapNotifEnabled => $composableBuilder(
    column: $table.approachingCapNotifEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get soberEstimateNotifEnabled => $composableBuilder(
    column: $table.soberEstimateNotifEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPreferencesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPreferencesTableTable,
          UserPreferencesRow,
          $$UserPreferencesTableTableFilterComposer,
          $$UserPreferencesTableTableOrderingComposer,
          $$UserPreferencesTableTableAnnotationComposer,
          $$UserPreferencesTableTableCreateCompanionBuilder,
          $$UserPreferencesTableTableUpdateCompanionBuilder,
          (
            UserPreferencesRow,
            BaseReferences<
              _$AppDatabase,
              $UserPreferencesTableTable,
              UserPreferencesRow
            >,
          ),
          UserPreferencesRow,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableTableManager(
    _$AppDatabase db,
    $UserPreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> username = const Value.absent(),
                Value<int> dailyGoalMl = const Value.absent(),
                Value<int> dayBoundaryHour = const Value.absent(),
                Value<String> units = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<bool> reminderEnabled = const Value.absent(),
                Value<int> reminderStartHour = const Value.absent(),
                Value<int> reminderEndHour = const Value.absent(),
                Value<int> reminderIntervalMin = const Value.absent(),
                Value<bool> inactivityReminderEnabled = const Value.absent(),
                Value<bool> weeklySummaryEnabled = const Value.absent(),
                Value<String?> defaultDrinkPresetId = const Value.absent(),
                Value<double?> bacCapGramsPerL = const Value.absent(),
                Value<bool> bacOnLockScreenEnabled = const Value.absent(),
                Value<bool> approachingCapNotifEnabled = const Value.absent(),
                Value<bool> soberEstimateNotifEnabled = const Value.absent(),
                Value<int> installedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesTableCompanion(
                id: id,
                username: username,
                dailyGoalMl: dailyGoalMl,
                dayBoundaryHour: dayBoundaryHour,
                units: units,
                currency: currency,
                reminderEnabled: reminderEnabled,
                reminderStartHour: reminderStartHour,
                reminderEndHour: reminderEndHour,
                reminderIntervalMin: reminderIntervalMin,
                inactivityReminderEnabled: inactivityReminderEnabled,
                weeklySummaryEnabled: weeklySummaryEnabled,
                defaultDrinkPresetId: defaultDrinkPresetId,
                bacCapGramsPerL: bacCapGramsPerL,
                bacOnLockScreenEnabled: bacOnLockScreenEnabled,
                approachingCapNotifEnabled: approachingCapNotifEnabled,
                soberEstimateNotifEnabled: soberEstimateNotifEnabled,
                installedAt: installedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> username = const Value.absent(),
                required int dailyGoalMl,
                Value<int> dayBoundaryHour = const Value.absent(),
                Value<String> units = const Value.absent(),
                Value<String> currency = const Value.absent(),
                required bool reminderEnabled,
                Value<int> reminderStartHour = const Value.absent(),
                Value<int> reminderEndHour = const Value.absent(),
                Value<int> reminderIntervalMin = const Value.absent(),
                required bool inactivityReminderEnabled,
                required bool weeklySummaryEnabled,
                Value<String?> defaultDrinkPresetId = const Value.absent(),
                Value<double?> bacCapGramsPerL = const Value.absent(),
                required bool bacOnLockScreenEnabled,
                required bool approachingCapNotifEnabled,
                required bool soberEstimateNotifEnabled,
                required int installedAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesTableCompanion.insert(
                id: id,
                username: username,
                dailyGoalMl: dailyGoalMl,
                dayBoundaryHour: dayBoundaryHour,
                units: units,
                currency: currency,
                reminderEnabled: reminderEnabled,
                reminderStartHour: reminderStartHour,
                reminderEndHour: reminderEndHour,
                reminderIntervalMin: reminderIntervalMin,
                inactivityReminderEnabled: inactivityReminderEnabled,
                weeklySummaryEnabled: weeklySummaryEnabled,
                defaultDrinkPresetId: defaultDrinkPresetId,
                bacCapGramsPerL: bacCapGramsPerL,
                bacOnLockScreenEnabled: bacOnLockScreenEnabled,
                approachingCapNotifEnabled: approachingCapNotifEnabled,
                soberEstimateNotifEnabled: soberEstimateNotifEnabled,
                installedAt: installedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPreferencesTableTable,
      UserPreferencesRow,
      $$UserPreferencesTableTableFilterComposer,
      $$UserPreferencesTableTableOrderingComposer,
      $$UserPreferencesTableTableAnnotationComposer,
      $$UserPreferencesTableTableCreateCompanionBuilder,
      $$UserPreferencesTableTableUpdateCompanionBuilder,
      (
        UserPreferencesRow,
        BaseReferences<
          _$AppDatabase,
          $UserPreferencesTableTable,
          UserPreferencesRow
        >,
      ),
      UserPreferencesRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DrinkPresetsTableTableManager get drinkPresets =>
      $$DrinkPresetsTableTableManager(_db, _db.drinkPresets);
  $$DrinkEntriesTableTableManager get drinkEntries =>
      $$DrinkEntriesTableTableManager(_db, _db.drinkEntries);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$UserPreferencesTableTableTableManager get userPreferencesTable =>
      $$UserPreferencesTableTableTableManager(_db, _db.userPreferencesTable);
}
