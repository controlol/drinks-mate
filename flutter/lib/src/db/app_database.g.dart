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
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _beverageTypeMeta =
      const VerificationMeta('beverageType');
  @override
  late final GeneratedColumn<String> beverageType = GeneratedColumn<String>(
      'beverage_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _volumeMlMeta =
      const VerificationMeta('volumeMl');
  @override
  late final GeneratedColumn<int> volumeMl = GeneratedColumn<int>(
      'volume_ml', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _abvPercentMeta =
      const VerificationMeta('abvPercent');
  @override
  late final GeneratedColumn<double> abvPercent = GeneratedColumn<double>(
      'abv_percent', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _regularPriceMinorMeta =
      const VerificationMeta('regularPriceMinor');
  @override
  late final GeneratedColumn<int> regularPriceMinor = GeneratedColumn<int>(
      'regular_price_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _regularCurrencyMeta =
      const VerificationMeta('regularCurrency');
  @override
  late final GeneratedColumn<String> regularCurrency = GeneratedColumn<String>(
      'regular_currency', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconKeyMeta =
      const VerificationMeta('iconKey');
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
      'icon_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconColorMeta =
      const VerificationMeta('iconColor');
  @override
  late final GeneratedColumn<String> iconColor = GeneratedColumn<String>(
      'icon_color', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isUserCreatedMeta =
      const VerificationMeta('isUserCreated');
  @override
  late final GeneratedColumn<bool> isUserCreated = GeneratedColumn<bool>(
      'is_user_created', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_user_created" IN (0, 1))'));
  static const VerificationMeta _isHiddenMeta =
      const VerificationMeta('isHidden');
  @override
  late final GeneratedColumn<bool> isHidden = GeneratedColumn<bool>(
      'is_hidden', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_hidden" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
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
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drink_presets';
  @override
  VerificationContext validateIntegrity(Insertable<DrinkPresetRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('beverage_type')) {
      context.handle(
          _beverageTypeMeta,
          beverageType.isAcceptableOrUnknown(
              data['beverage_type']!, _beverageTypeMeta));
    } else if (isInserting) {
      context.missing(_beverageTypeMeta);
    }
    if (data.containsKey('volume_ml')) {
      context.handle(_volumeMlMeta,
          volumeMl.isAcceptableOrUnknown(data['volume_ml']!, _volumeMlMeta));
    } else if (isInserting) {
      context.missing(_volumeMlMeta);
    }
    if (data.containsKey('abv_percent')) {
      context.handle(
          _abvPercentMeta,
          abvPercent.isAcceptableOrUnknown(
              data['abv_percent']!, _abvPercentMeta));
    }
    if (data.containsKey('regular_price_minor')) {
      context.handle(
          _regularPriceMinorMeta,
          regularPriceMinor.isAcceptableOrUnknown(
              data['regular_price_minor']!, _regularPriceMinorMeta));
    }
    if (data.containsKey('regular_currency')) {
      context.handle(
          _regularCurrencyMeta,
          regularCurrency.isAcceptableOrUnknown(
              data['regular_currency']!, _regularCurrencyMeta));
    }
    if (data.containsKey('icon_key')) {
      context.handle(_iconKeyMeta,
          iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta));
    } else if (isInserting) {
      context.missing(_iconKeyMeta);
    }
    if (data.containsKey('icon_color')) {
      context.handle(_iconColorMeta,
          iconColor.isAcceptableOrUnknown(data['icon_color']!, _iconColorMeta));
    } else if (isInserting) {
      context.missing(_iconColorMeta);
    }
    if (data.containsKey('is_user_created')) {
      context.handle(
          _isUserCreatedMeta,
          isUserCreated.isAcceptableOrUnknown(
              data['is_user_created']!, _isUserCreatedMeta));
    } else if (isInserting) {
      context.missing(_isUserCreatedMeta);
    }
    if (data.containsKey('is_hidden')) {
      context.handle(_isHiddenMeta,
          isHidden.isAcceptableOrUnknown(data['is_hidden']!, _isHiddenMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DrinkPresetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DrinkPresetRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      beverageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}beverage_type'])!,
      volumeMl: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}volume_ml'])!,
      abvPercent: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}abv_percent']),
      regularPriceMinor: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}regular_price_minor']),
      regularCurrency: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}regular_currency']),
      iconKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_key'])!,
      iconColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_color'])!,
      isUserCreated: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_user_created'])!,
      isHidden: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_hidden'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
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
  const DrinkPresetRow(
      {required this.id,
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
      this.deletedAt});
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

  factory DrinkPresetRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  DrinkPresetRow copyWith(
          {String? id,
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
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      DrinkPresetRow(
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
      abvPercent:
          data.abvPercent.present ? data.abvPercent.value : this.abvPercent,
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
      deletedAt);
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
  })  : id = Value(id),
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

  DrinkPresetsCompanion copyWith(
      {Value<String>? id,
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
      Value<int>? rowid}) {
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
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _beverageTypeMeta =
      const VerificationMeta('beverageType');
  @override
  late final GeneratedColumn<String> beverageType = GeneratedColumn<String>(
      'beverage_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _volumeMlMeta =
      const VerificationMeta('volumeMl');
  @override
  late final GeneratedColumn<int> volumeMl = GeneratedColumn<int>(
      'volume_ml', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _abvPercentMeta =
      const VerificationMeta('abvPercent');
  @override
  late final GeneratedColumn<double> abvPercent = GeneratedColumn<double>(
      'abv_percent', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _priceMinorMeta =
      const VerificationMeta('priceMinor');
  @override
  late final GeneratedColumn<int> priceMinor = GeneratedColumn<int>(
      'price_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priceTokensMeta =
      const VerificationMeta('priceTokens');
  @override
  late final GeneratedColumn<int> priceTokens = GeneratedColumn<int>(
      'price_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tokenValueMinorMeta =
      const VerificationMeta('tokenValueMinor');
  @override
  late final GeneratedColumn<int> tokenValueMinor = GeneratedColumn<int>(
      'token_value_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tokenValueCurrencyMeta =
      const VerificationMeta('tokenValueCurrency');
  @override
  late final GeneratedColumn<String> tokenValueCurrency =
      GeneratedColumn<String>('token_value_currency', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconKeyMeta =
      const VerificationMeta('iconKey');
  @override
  late final GeneratedColumn<String> iconKey = GeneratedColumn<String>(
      'icon_key', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _iconColorMeta =
      const VerificationMeta('iconColor');
  @override
  late final GeneratedColumn<String> iconColor = GeneratedColumn<String>(
      'icon_color', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _partySessionIdMeta =
      const VerificationMeta('partySessionId');
  @override
  late final GeneratedColumn<String> partySessionId = GeneratedColumn<String>(
      'party_session_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _consumedAtMeta =
      const VerificationMeta('consumedAt');
  @override
  late final GeneratedColumn<DateTime> consumedAt = GeneratedColumn<DateTime>(
      'consumed_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        beverageType,
        volumeMl,
        abvPercent,
        priceMinor,
        currency,
        priceTokens,
        tokenValueMinor,
        tokenValueCurrency,
        iconKey,
        iconColor,
        partySessionId,
        consumedAt,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'drink_entries';
  @override
  VerificationContext validateIntegrity(Insertable<DrinkEntryRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('beverage_type')) {
      context.handle(
          _beverageTypeMeta,
          beverageType.isAcceptableOrUnknown(
              data['beverage_type']!, _beverageTypeMeta));
    } else if (isInserting) {
      context.missing(_beverageTypeMeta);
    }
    if (data.containsKey('volume_ml')) {
      context.handle(_volumeMlMeta,
          volumeMl.isAcceptableOrUnknown(data['volume_ml']!, _volumeMlMeta));
    } else if (isInserting) {
      context.missing(_volumeMlMeta);
    }
    if (data.containsKey('abv_percent')) {
      context.handle(
          _abvPercentMeta,
          abvPercent.isAcceptableOrUnknown(
              data['abv_percent']!, _abvPercentMeta));
    }
    if (data.containsKey('price_minor')) {
      context.handle(
          _priceMinorMeta,
          priceMinor.isAcceptableOrUnknown(
              data['price_minor']!, _priceMinorMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('price_tokens')) {
      context.handle(
          _priceTokensMeta,
          priceTokens.isAcceptableOrUnknown(
              data['price_tokens']!, _priceTokensMeta));
    }
    if (data.containsKey('token_value_minor')) {
      context.handle(
          _tokenValueMinorMeta,
          tokenValueMinor.isAcceptableOrUnknown(
              data['token_value_minor']!, _tokenValueMinorMeta));
    }
    if (data.containsKey('token_value_currency')) {
      context.handle(
          _tokenValueCurrencyMeta,
          tokenValueCurrency.isAcceptableOrUnknown(
              data['token_value_currency']!, _tokenValueCurrencyMeta));
    }
    if (data.containsKey('icon_key')) {
      context.handle(_iconKeyMeta,
          iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta));
    }
    if (data.containsKey('icon_color')) {
      context.handle(_iconColorMeta,
          iconColor.isAcceptableOrUnknown(data['icon_color']!, _iconColorMeta));
    }
    if (data.containsKey('party_session_id')) {
      context.handle(
          _partySessionIdMeta,
          partySessionId.isAcceptableOrUnknown(
              data['party_session_id']!, _partySessionIdMeta));
    }
    if (data.containsKey('consumed_at')) {
      context.handle(
          _consumedAtMeta,
          consumedAt.isAcceptableOrUnknown(
              data['consumed_at']!, _consumedAtMeta));
    } else if (isInserting) {
      context.missing(_consumedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DrinkEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DrinkEntryRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name']),
      beverageType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}beverage_type'])!,
      volumeMl: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}volume_ml'])!,
      abvPercent: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}abv_percent']),
      priceMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_minor']),
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency']),
      priceTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_tokens']),
      tokenValueMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}token_value_minor']),
      tokenValueCurrency: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}token_value_currency']),
      iconKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_key']),
      iconColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_color']),
      partySessionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}party_session_id']),
      consumedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}consumed_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
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

  /// Snapshot of price in minor units at log time. Mutually exclusive with
  /// [priceTokens] (data-model.md §DrinkEntry).
  final int? priceMinor;
  final String? currency;

  /// Snapshot of the token cost at log time, when paid for in tokens during
  /// a Party Session. Mutually exclusive with [priceMinor].
  final int? priceTokens;

  /// Snapshot of the token-to-money value at log time, in the minor unit of
  /// [tokenValueCurrency]. Null when [priceTokens] is null.
  final int? tokenValueMinor;

  /// Snapshot of the currency the token value was expressed in. Null when
  /// [priceTokens] is null.
  final String? tokenValueCurrency;
  final String? iconKey;
  final String? iconColor;

  /// FK to [PartySessions.id]. Null for non-alcoholic drinks and for
  /// alcoholic "orphan" drinks logged with no active session
  /// (data-model.md §Meal → Relationship to DrinkEntry).
  final String? partySessionId;
  final DateTime consumedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const DrinkEntryRow(
      {required this.id,
      this.name,
      required this.beverageType,
      required this.volumeMl,
      this.abvPercent,
      this.priceMinor,
      this.currency,
      this.priceTokens,
      this.tokenValueMinor,
      this.tokenValueCurrency,
      this.iconKey,
      this.iconColor,
      this.partySessionId,
      required this.consumedAt,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
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
    if (!nullToAbsent || priceTokens != null) {
      map['price_tokens'] = Variable<int>(priceTokens);
    }
    if (!nullToAbsent || tokenValueMinor != null) {
      map['token_value_minor'] = Variable<int>(tokenValueMinor);
    }
    if (!nullToAbsent || tokenValueCurrency != null) {
      map['token_value_currency'] = Variable<String>(tokenValueCurrency);
    }
    if (!nullToAbsent || iconKey != null) {
      map['icon_key'] = Variable<String>(iconKey);
    }
    if (!nullToAbsent || iconColor != null) {
      map['icon_color'] = Variable<String>(iconColor);
    }
    if (!nullToAbsent || partySessionId != null) {
      map['party_session_id'] = Variable<String>(partySessionId);
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
      priceTokens: priceTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(priceTokens),
      tokenValueMinor: tokenValueMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenValueMinor),
      tokenValueCurrency: tokenValueCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenValueCurrency),
      iconKey: iconKey == null && nullToAbsent
          ? const Value.absent()
          : Value(iconKey),
      iconColor: iconColor == null && nullToAbsent
          ? const Value.absent()
          : Value(iconColor),
      partySessionId: partySessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(partySessionId),
      consumedAt: Value(consumedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory DrinkEntryRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DrinkEntryRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String?>(json['name']),
      beverageType: serializer.fromJson<String>(json['beverageType']),
      volumeMl: serializer.fromJson<int>(json['volumeMl']),
      abvPercent: serializer.fromJson<double?>(json['abvPercent']),
      priceMinor: serializer.fromJson<int?>(json['priceMinor']),
      currency: serializer.fromJson<String?>(json['currency']),
      priceTokens: serializer.fromJson<int?>(json['priceTokens']),
      tokenValueMinor: serializer.fromJson<int?>(json['tokenValueMinor']),
      tokenValueCurrency:
          serializer.fromJson<String?>(json['tokenValueCurrency']),
      iconKey: serializer.fromJson<String?>(json['iconKey']),
      iconColor: serializer.fromJson<String?>(json['iconColor']),
      partySessionId: serializer.fromJson<String?>(json['partySessionId']),
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
      'priceTokens': serializer.toJson<int?>(priceTokens),
      'tokenValueMinor': serializer.toJson<int?>(tokenValueMinor),
      'tokenValueCurrency': serializer.toJson<String?>(tokenValueCurrency),
      'iconKey': serializer.toJson<String?>(iconKey),
      'iconColor': serializer.toJson<String?>(iconColor),
      'partySessionId': serializer.toJson<String?>(partySessionId),
      'consumedAt': serializer.toJson<DateTime>(consumedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  DrinkEntryRow copyWith(
          {String? id,
          Value<String?> name = const Value.absent(),
          String? beverageType,
          int? volumeMl,
          Value<double?> abvPercent = const Value.absent(),
          Value<int?> priceMinor = const Value.absent(),
          Value<String?> currency = const Value.absent(),
          Value<int?> priceTokens = const Value.absent(),
          Value<int?> tokenValueMinor = const Value.absent(),
          Value<String?> tokenValueCurrency = const Value.absent(),
          Value<String?> iconKey = const Value.absent(),
          Value<String?> iconColor = const Value.absent(),
          Value<String?> partySessionId = const Value.absent(),
          DateTime? consumedAt,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      DrinkEntryRow(
        id: id ?? this.id,
        name: name.present ? name.value : this.name,
        beverageType: beverageType ?? this.beverageType,
        volumeMl: volumeMl ?? this.volumeMl,
        abvPercent: abvPercent.present ? abvPercent.value : this.abvPercent,
        priceMinor: priceMinor.present ? priceMinor.value : this.priceMinor,
        currency: currency.present ? currency.value : this.currency,
        priceTokens: priceTokens.present ? priceTokens.value : this.priceTokens,
        tokenValueMinor: tokenValueMinor.present
            ? tokenValueMinor.value
            : this.tokenValueMinor,
        tokenValueCurrency: tokenValueCurrency.present
            ? tokenValueCurrency.value
            : this.tokenValueCurrency,
        iconKey: iconKey.present ? iconKey.value : this.iconKey,
        iconColor: iconColor.present ? iconColor.value : this.iconColor,
        partySessionId:
            partySessionId.present ? partySessionId.value : this.partySessionId,
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
      abvPercent:
          data.abvPercent.present ? data.abvPercent.value : this.abvPercent,
      priceMinor:
          data.priceMinor.present ? data.priceMinor.value : this.priceMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      priceTokens:
          data.priceTokens.present ? data.priceTokens.value : this.priceTokens,
      tokenValueMinor: data.tokenValueMinor.present
          ? data.tokenValueMinor.value
          : this.tokenValueMinor,
      tokenValueCurrency: data.tokenValueCurrency.present
          ? data.tokenValueCurrency.value
          : this.tokenValueCurrency,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      iconColor: data.iconColor.present ? data.iconColor.value : this.iconColor,
      partySessionId: data.partySessionId.present
          ? data.partySessionId.value
          : this.partySessionId,
      consumedAt:
          data.consumedAt.present ? data.consumedAt.value : this.consumedAt,
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
          ..write('priceTokens: $priceTokens, ')
          ..write('tokenValueMinor: $tokenValueMinor, ')
          ..write('tokenValueCurrency: $tokenValueCurrency, ')
          ..write('iconKey: $iconKey, ')
          ..write('iconColor: $iconColor, ')
          ..write('partySessionId: $partySessionId, ')
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
      priceTokens,
      tokenValueMinor,
      tokenValueCurrency,
      iconKey,
      iconColor,
      partySessionId,
      consumedAt,
      createdAt,
      updatedAt,
      deletedAt);
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
          other.priceTokens == this.priceTokens &&
          other.tokenValueMinor == this.tokenValueMinor &&
          other.tokenValueCurrency == this.tokenValueCurrency &&
          other.iconKey == this.iconKey &&
          other.iconColor == this.iconColor &&
          other.partySessionId == this.partySessionId &&
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
  final Value<int?> priceTokens;
  final Value<int?> tokenValueMinor;
  final Value<String?> tokenValueCurrency;
  final Value<String?> iconKey;
  final Value<String?> iconColor;
  final Value<String?> partySessionId;
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
    this.priceTokens = const Value.absent(),
    this.tokenValueMinor = const Value.absent(),
    this.tokenValueCurrency = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.iconColor = const Value.absent(),
    this.partySessionId = const Value.absent(),
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
    this.priceTokens = const Value.absent(),
    this.tokenValueMinor = const Value.absent(),
    this.tokenValueCurrency = const Value.absent(),
    this.iconKey = const Value.absent(),
    this.iconColor = const Value.absent(),
    this.partySessionId = const Value.absent(),
    required DateTime consumedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
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
    Expression<int>? priceTokens,
    Expression<int>? tokenValueMinor,
    Expression<String>? tokenValueCurrency,
    Expression<String>? iconKey,
    Expression<String>? iconColor,
    Expression<String>? partySessionId,
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
      if (priceTokens != null) 'price_tokens': priceTokens,
      if (tokenValueMinor != null) 'token_value_minor': tokenValueMinor,
      if (tokenValueCurrency != null)
        'token_value_currency': tokenValueCurrency,
      if (iconKey != null) 'icon_key': iconKey,
      if (iconColor != null) 'icon_color': iconColor,
      if (partySessionId != null) 'party_session_id': partySessionId,
      if (consumedAt != null) 'consumed_at': consumedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DrinkEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? name,
      Value<String>? beverageType,
      Value<int>? volumeMl,
      Value<double?>? abvPercent,
      Value<int?>? priceMinor,
      Value<String?>? currency,
      Value<int?>? priceTokens,
      Value<int?>? tokenValueMinor,
      Value<String?>? tokenValueCurrency,
      Value<String?>? iconKey,
      Value<String?>? iconColor,
      Value<String?>? partySessionId,
      Value<DateTime>? consumedAt,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return DrinkEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      beverageType: beverageType ?? this.beverageType,
      volumeMl: volumeMl ?? this.volumeMl,
      abvPercent: abvPercent ?? this.abvPercent,
      priceMinor: priceMinor ?? this.priceMinor,
      currency: currency ?? this.currency,
      priceTokens: priceTokens ?? this.priceTokens,
      tokenValueMinor: tokenValueMinor ?? this.tokenValueMinor,
      tokenValueCurrency: tokenValueCurrency ?? this.tokenValueCurrency,
      iconKey: iconKey ?? this.iconKey,
      iconColor: iconColor ?? this.iconColor,
      partySessionId: partySessionId ?? this.partySessionId,
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
    if (priceTokens.present) {
      map['price_tokens'] = Variable<int>(priceTokens.value);
    }
    if (tokenValueMinor.present) {
      map['token_value_minor'] = Variable<int>(tokenValueMinor.value);
    }
    if (tokenValueCurrency.present) {
      map['token_value_currency'] = Variable<String>(tokenValueCurrency.value);
    }
    if (iconKey.present) {
      map['icon_key'] = Variable<String>(iconKey.value);
    }
    if (iconColor.present) {
      map['icon_color'] = Variable<String>(iconColor.value);
    }
    if (partySessionId.present) {
      map['party_session_id'] = Variable<String>(partySessionId.value);
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
          ..write('priceTokens: $priceTokens, ')
          ..write('tokenValueMinor: $tokenValueMinor, ')
          ..write('tokenValueCurrency: $tokenValueCurrency, ')
          ..write('iconKey: $iconKey, ')
          ..write('iconColor: $iconColor, ')
          ..write('partySessionId: $partySessionId, ')
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
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
      'gender', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _weightKgMeta =
      const VerificationMeta('weightKg');
  @override
  late final GeneratedColumn<double> weightKg = GeneratedColumn<double>(
      'weight_kg', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _heightCmMeta =
      const VerificationMeta('heightCm');
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
      'height_cm', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _birthDateMeta =
      const VerificationMeta('birthDate');
  @override
  late final GeneratedColumn<String> birthDate = GeneratedColumn<String>(
      'birth_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        gender,
        weightKg,
        heightCm,
        birthDate,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<UserProfileRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('gender')) {
      context.handle(_genderMeta,
          gender.isAcceptableOrUnknown(data['gender']!, _genderMeta));
    }
    if (data.containsKey('weight_kg')) {
      context.handle(_weightKgMeta,
          weightKg.isAcceptableOrUnknown(data['weight_kg']!, _weightKgMeta));
    }
    if (data.containsKey('height_cm')) {
      context.handle(_heightCmMeta,
          heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta));
    }
    if (data.containsKey('birth_date')) {
      context.handle(_birthDateMeta,
          birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      gender: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gender']),
      weightKg: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}weight_kg']),
      heightCm: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}height_cm']),
      birthDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}birth_date']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
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
  const UserProfileRow(
      {required this.id,
      this.gender,
      this.weightKg,
      this.heightCm,
      this.birthDate,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
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
      gender:
          gender == null && nullToAbsent ? const Value.absent() : Value(gender),
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

  factory UserProfileRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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

  UserProfileRow copyWith(
          {String? id,
          Value<String?> gender = const Value.absent(),
          Value<double?> weightKg = const Value.absent(),
          Value<double?> heightCm = const Value.absent(),
          Value<String?> birthDate = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      UserProfileRow(
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
  int get hashCode => Object.hash(id, gender, weightKg, heightCm, birthDate,
      createdAt, updatedAt, deletedAt);
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
  })  : id = Value(id),
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

  UserProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String?>? gender,
      Value<double?>? weightKg,
      Value<double?>? heightCm,
      Value<String?>? birthDate,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
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
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _usernameMeta =
      const VerificationMeta('username');
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
      'username', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _dailyGoalMlMeta =
      const VerificationMeta('dailyGoalMl');
  @override
  late final GeneratedColumn<int> dailyGoalMl = GeneratedColumn<int>(
      'daily_goal_ml', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dayBoundaryHourMeta =
      const VerificationMeta('dayBoundaryHour');
  @override
  late final GeneratedColumn<int> dayBoundaryHour = GeneratedColumn<int>(
      'day_boundary_hour', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(5));
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<String> units = GeneratedColumn<String>(
      'units', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('metric'));
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('EUR'));
  static const VerificationMeta _reminderEnabledMeta =
      const VerificationMeta('reminderEnabled');
  @override
  late final GeneratedColumn<bool> reminderEnabled = GeneratedColumn<bool>(
      'reminder_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("reminder_enabled" IN (0, 1))'));
  static const VerificationMeta _reminderStartHourMeta =
      const VerificationMeta('reminderStartHour');
  @override
  late final GeneratedColumn<int> reminderStartHour = GeneratedColumn<int>(
      'reminder_start_hour', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(8));
  static const VerificationMeta _reminderEndHourMeta =
      const VerificationMeta('reminderEndHour');
  @override
  late final GeneratedColumn<int> reminderEndHour = GeneratedColumn<int>(
      'reminder_end_hour', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(22));
  static const VerificationMeta _reminderIntervalMinMeta =
      const VerificationMeta('reminderIntervalMin');
  @override
  late final GeneratedColumn<int> reminderIntervalMin = GeneratedColumn<int>(
      'reminder_interval_min', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(90));
  static const VerificationMeta _inactivityReminderEnabledMeta =
      const VerificationMeta('inactivityReminderEnabled');
  @override
  late final GeneratedColumn<bool> inactivityReminderEnabled =
      GeneratedColumn<bool>('inactivity_reminder_enabled', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("inactivity_reminder_enabled" IN (0, 1))'));
  static const VerificationMeta _weeklySummaryEnabledMeta =
      const VerificationMeta('weeklySummaryEnabled');
  @override
  late final GeneratedColumn<bool> weeklySummaryEnabled = GeneratedColumn<bool>(
      'weekly_summary_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("weekly_summary_enabled" IN (0, 1))'));
  static const VerificationMeta _defaultDrinkPresetIdMeta =
      const VerificationMeta('defaultDrinkPresetId');
  @override
  late final GeneratedColumn<String> defaultDrinkPresetId =
      GeneratedColumn<String>('default_drink_preset_id', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bacCapGramsPerLMeta =
      const VerificationMeta('bacCapGramsPerL');
  @override
  late final GeneratedColumn<double> bacCapGramsPerL = GeneratedColumn<double>(
      'bac_cap_grams_per_l', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _bacOnLockScreenEnabledMeta =
      const VerificationMeta('bacOnLockScreenEnabled');
  @override
  late final GeneratedColumn<bool> bacOnLockScreenEnabled =
      GeneratedColumn<bool>('bac_on_lock_screen_enabled', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("bac_on_lock_screen_enabled" IN (0, 1))'));
  static const VerificationMeta _approachingCapNotifEnabledMeta =
      const VerificationMeta('approachingCapNotifEnabled');
  @override
  late final GeneratedColumn<bool> approachingCapNotifEnabled =
      GeneratedColumn<bool>('approaching_cap_notif_enabled', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("approaching_cap_notif_enabled" IN (0, 1))'));
  static const VerificationMeta _soberEstimateNotifEnabledMeta =
      const VerificationMeta('soberEstimateNotifEnabled');
  @override
  late final GeneratedColumn<bool> soberEstimateNotifEnabled =
      GeneratedColumn<bool>('sober_estimate_notif_enabled', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: true,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("sober_estimate_notif_enabled" IN (0, 1))'));
  static const VerificationMeta _installedAtMeta =
      const VerificationMeta('installedAt');
  @override
  late final GeneratedColumn<int> installedAt = GeneratedColumn<int>(
      'installed_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
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
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences';
  @override
  VerificationContext validateIntegrity(Insertable<UserPreferencesRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('username')) {
      context.handle(_usernameMeta,
          username.isAcceptableOrUnknown(data['username']!, _usernameMeta));
    }
    if (data.containsKey('daily_goal_ml')) {
      context.handle(
          _dailyGoalMlMeta,
          dailyGoalMl.isAcceptableOrUnknown(
              data['daily_goal_ml']!, _dailyGoalMlMeta));
    } else if (isInserting) {
      context.missing(_dailyGoalMlMeta);
    }
    if (data.containsKey('day_boundary_hour')) {
      context.handle(
          _dayBoundaryHourMeta,
          dayBoundaryHour.isAcceptableOrUnknown(
              data['day_boundary_hour']!, _dayBoundaryHourMeta));
    }
    if (data.containsKey('units')) {
      context.handle(
          _unitsMeta, units.isAcceptableOrUnknown(data['units']!, _unitsMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
          _reminderEnabledMeta,
          reminderEnabled.isAcceptableOrUnknown(
              data['reminder_enabled']!, _reminderEnabledMeta));
    } else if (isInserting) {
      context.missing(_reminderEnabledMeta);
    }
    if (data.containsKey('reminder_start_hour')) {
      context.handle(
          _reminderStartHourMeta,
          reminderStartHour.isAcceptableOrUnknown(
              data['reminder_start_hour']!, _reminderStartHourMeta));
    }
    if (data.containsKey('reminder_end_hour')) {
      context.handle(
          _reminderEndHourMeta,
          reminderEndHour.isAcceptableOrUnknown(
              data['reminder_end_hour']!, _reminderEndHourMeta));
    }
    if (data.containsKey('reminder_interval_min')) {
      context.handle(
          _reminderIntervalMinMeta,
          reminderIntervalMin.isAcceptableOrUnknown(
              data['reminder_interval_min']!, _reminderIntervalMinMeta));
    }
    if (data.containsKey('inactivity_reminder_enabled')) {
      context.handle(
          _inactivityReminderEnabledMeta,
          inactivityReminderEnabled.isAcceptableOrUnknown(
              data['inactivity_reminder_enabled']!,
              _inactivityReminderEnabledMeta));
    } else if (isInserting) {
      context.missing(_inactivityReminderEnabledMeta);
    }
    if (data.containsKey('weekly_summary_enabled')) {
      context.handle(
          _weeklySummaryEnabledMeta,
          weeklySummaryEnabled.isAcceptableOrUnknown(
              data['weekly_summary_enabled']!, _weeklySummaryEnabledMeta));
    } else if (isInserting) {
      context.missing(_weeklySummaryEnabledMeta);
    }
    if (data.containsKey('default_drink_preset_id')) {
      context.handle(
          _defaultDrinkPresetIdMeta,
          defaultDrinkPresetId.isAcceptableOrUnknown(
              data['default_drink_preset_id']!, _defaultDrinkPresetIdMeta));
    }
    if (data.containsKey('bac_cap_grams_per_l')) {
      context.handle(
          _bacCapGramsPerLMeta,
          bacCapGramsPerL.isAcceptableOrUnknown(
              data['bac_cap_grams_per_l']!, _bacCapGramsPerLMeta));
    }
    if (data.containsKey('bac_on_lock_screen_enabled')) {
      context.handle(
          _bacOnLockScreenEnabledMeta,
          bacOnLockScreenEnabled.isAcceptableOrUnknown(
              data['bac_on_lock_screen_enabled']!,
              _bacOnLockScreenEnabledMeta));
    } else if (isInserting) {
      context.missing(_bacOnLockScreenEnabledMeta);
    }
    if (data.containsKey('approaching_cap_notif_enabled')) {
      context.handle(
          _approachingCapNotifEnabledMeta,
          approachingCapNotifEnabled.isAcceptableOrUnknown(
              data['approaching_cap_notif_enabled']!,
              _approachingCapNotifEnabledMeta));
    } else if (isInserting) {
      context.missing(_approachingCapNotifEnabledMeta);
    }
    if (data.containsKey('sober_estimate_notif_enabled')) {
      context.handle(
          _soberEstimateNotifEnabledMeta,
          soberEstimateNotifEnabled.isAcceptableOrUnknown(
              data['sober_estimate_notif_enabled']!,
              _soberEstimateNotifEnabledMeta));
    } else if (isInserting) {
      context.missing(_soberEstimateNotifEnabledMeta);
    }
    if (data.containsKey('installed_at')) {
      context.handle(
          _installedAtMeta,
          installedAt.isAcceptableOrUnknown(
              data['installed_at']!, _installedAtMeta));
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
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
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      username: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}username']),
      dailyGoalMl: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}daily_goal_ml'])!,
      dayBoundaryHour: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_boundary_hour'])!,
      units: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}units'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      reminderEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}reminder_enabled'])!,
      reminderStartHour: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}reminder_start_hour'])!,
      reminderEndHour: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reminder_end_hour'])!,
      reminderIntervalMin: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}reminder_interval_min'])!,
      inactivityReminderEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}inactivity_reminder_enabled'])!,
      weeklySummaryEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}weekly_summary_enabled'])!,
      defaultDrinkPresetId: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}default_drink_preset_id']),
      bacCapGramsPerL: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}bac_cap_grams_per_l']),
      bacOnLockScreenEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}bac_on_lock_screen_enabled'])!,
      approachingCapNotifEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}approaching_cap_notif_enabled'])!,
      soberEstimateNotifEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}sober_estimate_notif_enabled'])!,
      installedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}installed_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
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
  const UserPreferencesRow(
      {required this.id,
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
      required this.updatedAt});
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
    map['inactivity_reminder_enabled'] =
        Variable<bool>(inactivityReminderEnabled);
    map['weekly_summary_enabled'] = Variable<bool>(weeklySummaryEnabled);
    if (!nullToAbsent || defaultDrinkPresetId != null) {
      map['default_drink_preset_id'] = Variable<String>(defaultDrinkPresetId);
    }
    if (!nullToAbsent || bacCapGramsPerL != null) {
      map['bac_cap_grams_per_l'] = Variable<double>(bacCapGramsPerL);
    }
    map['bac_on_lock_screen_enabled'] = Variable<bool>(bacOnLockScreenEnabled);
    map['approaching_cap_notif_enabled'] =
        Variable<bool>(approachingCapNotifEnabled);
    map['sober_estimate_notif_enabled'] =
        Variable<bool>(soberEstimateNotifEnabled);
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

  factory UserPreferencesRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
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
      reminderIntervalMin:
          serializer.fromJson<int>(json['reminderIntervalMin']),
      inactivityReminderEnabled:
          serializer.fromJson<bool>(json['inactivityReminderEnabled']),
      weeklySummaryEnabled:
          serializer.fromJson<bool>(json['weeklySummaryEnabled']),
      defaultDrinkPresetId:
          serializer.fromJson<String?>(json['defaultDrinkPresetId']),
      bacCapGramsPerL: serializer.fromJson<double?>(json['bacCapGramsPerL']),
      bacOnLockScreenEnabled:
          serializer.fromJson<bool>(json['bacOnLockScreenEnabled']),
      approachingCapNotifEnabled:
          serializer.fromJson<bool>(json['approachingCapNotifEnabled']),
      soberEstimateNotifEnabled:
          serializer.fromJson<bool>(json['soberEstimateNotifEnabled']),
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
      'inactivityReminderEnabled':
          serializer.toJson<bool>(inactivityReminderEnabled),
      'weeklySummaryEnabled': serializer.toJson<bool>(weeklySummaryEnabled),
      'defaultDrinkPresetId': serializer.toJson<String?>(defaultDrinkPresetId),
      'bacCapGramsPerL': serializer.toJson<double?>(bacCapGramsPerL),
      'bacOnLockScreenEnabled': serializer.toJson<bool>(bacOnLockScreenEnabled),
      'approachingCapNotifEnabled':
          serializer.toJson<bool>(approachingCapNotifEnabled),
      'soberEstimateNotifEnabled':
          serializer.toJson<bool>(soberEstimateNotifEnabled),
      'installedAt': serializer.toJson<int>(installedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPreferencesRow copyWith(
          {String? id,
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
          DateTime? updatedAt}) =>
      UserPreferencesRow(
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
      dailyGoalMl:
          data.dailyGoalMl.present ? data.dailyGoalMl.value : this.dailyGoalMl,
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
      installedAt:
          data.installedAt.present ? data.installedAt.value : this.installedAt,
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
      updatedAt);
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
  })  : id = Value(id),
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

  UserPreferencesTableCompanion copyWith(
      {Value<String>? id,
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
      Value<int>? rowid}) {
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
      map['inactivity_reminder_enabled'] =
          Variable<bool>(inactivityReminderEnabled.value);
    }
    if (weeklySummaryEnabled.present) {
      map['weekly_summary_enabled'] =
          Variable<bool>(weeklySummaryEnabled.value);
    }
    if (defaultDrinkPresetId.present) {
      map['default_drink_preset_id'] =
          Variable<String>(defaultDrinkPresetId.value);
    }
    if (bacCapGramsPerL.present) {
      map['bac_cap_grams_per_l'] = Variable<double>(bacCapGramsPerL.value);
    }
    if (bacOnLockScreenEnabled.present) {
      map['bac_on_lock_screen_enabled'] =
          Variable<bool>(bacOnLockScreenEnabled.value);
    }
    if (approachingCapNotifEnabled.present) {
      map['approaching_cap_notif_enabled'] =
          Variable<bool>(approachingCapNotifEnabled.value);
    }
    if (soberEstimateNotifEnabled.present) {
      map['sober_estimate_notif_enabled'] =
          Variable<bool>(soberEstimateNotifEnabled.value);
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

class $PartySessionsTable extends PartySessions
    with TableInfo<$PartySessionsTable, PartySessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
      'started_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _endReasonMeta =
      const VerificationMeta('endReason');
  @override
  late final GeneratedColumn<String> endReason = GeneratedColumn<String>(
      'end_reason', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _useSessionPricesMeta =
      const VerificationMeta('useSessionPrices');
  @override
  late final GeneratedColumn<bool> useSessionPrices = GeneratedColumn<bool>(
      'use_session_prices', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("use_session_prices" IN (0, 1))'));
  static const VerificationMeta _tokenNameMeta =
      const VerificationMeta('tokenName');
  @override
  late final GeneratedColumn<String> tokenName = GeneratedColumn<String>(
      'token_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tokenValueMinorMeta =
      const VerificationMeta('tokenValueMinor');
  @override
  late final GeneratedColumn<int> tokenValueMinor = GeneratedColumn<int>(
      'token_value_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tokenValueCurrencyMeta =
      const VerificationMeta('tokenValueCurrency');
  @override
  late final GeneratedColumn<String> tokenValueCurrency =
      GeneratedColumn<String>('token_value_currency', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        startedAt,
        endedAt,
        endReason,
        useSessionPrices,
        tokenName,
        tokenValueMinor,
        tokenValueCurrency,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'party_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<PartySessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('end_reason')) {
      context.handle(_endReasonMeta,
          endReason.isAcceptableOrUnknown(data['end_reason']!, _endReasonMeta));
    }
    if (data.containsKey('use_session_prices')) {
      context.handle(
          _useSessionPricesMeta,
          useSessionPrices.isAcceptableOrUnknown(
              data['use_session_prices']!, _useSessionPricesMeta));
    } else if (isInserting) {
      context.missing(_useSessionPricesMeta);
    }
    if (data.containsKey('token_name')) {
      context.handle(_tokenNameMeta,
          tokenName.isAcceptableOrUnknown(data['token_name']!, _tokenNameMeta));
    }
    if (data.containsKey('token_value_minor')) {
      context.handle(
          _tokenValueMinorMeta,
          tokenValueMinor.isAcceptableOrUnknown(
              data['token_value_minor']!, _tokenValueMinorMeta));
    }
    if (data.containsKey('token_value_currency')) {
      context.handle(
          _tokenValueCurrencyMeta,
          tokenValueCurrency.isAcceptableOrUnknown(
              data['token_value_currency']!, _tokenValueCurrencyMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PartySessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartySessionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at']),
      endReason: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_reason']),
      useSessionPrices: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}use_session_prices'])!,
      tokenName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}token_name']),
      tokenValueMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}token_value_minor']),
      tokenValueCurrency: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}token_value_currency']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PartySessionsTable createAlias(String alias) {
    return $PartySessionsTable(attachedDatabase, alias);
  }
}

class PartySessionRow extends DataClass implements Insertable<PartySessionRow> {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// 'manual' | 'auto_timeout'. Null while active.
  final String? endReason;

  /// Whether to apply this session's [PartySessionPrices] overrides when
  /// logging drinks. Toggled live during the session.
  final bool useSessionPrices;

  /// Display label for the session's tokens (e.g. "Token", "Munt"). Null
  /// when tokens are not used in this session.
  final String? tokenName;

  /// What one token is worth, in the minor unit of [tokenValueCurrency].
  final int? tokenValueMinor;

  /// 'EUR' | 'USD' | 'GBP'. Required when [tokenValueMinor] is set.
  final String? tokenValueCurrency;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const PartySessionRow(
      {required this.id,
      required this.startedAt,
      this.endedAt,
      this.endReason,
      required this.useSessionPrices,
      this.tokenName,
      this.tokenValueMinor,
      this.tokenValueCurrency,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || endReason != null) {
      map['end_reason'] = Variable<String>(endReason);
    }
    map['use_session_prices'] = Variable<bool>(useSessionPrices);
    if (!nullToAbsent || tokenName != null) {
      map['token_name'] = Variable<String>(tokenName);
    }
    if (!nullToAbsent || tokenValueMinor != null) {
      map['token_value_minor'] = Variable<int>(tokenValueMinor);
    }
    if (!nullToAbsent || tokenValueCurrency != null) {
      map['token_value_currency'] = Variable<String>(tokenValueCurrency);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PartySessionsCompanion toCompanion(bool nullToAbsent) {
    return PartySessionsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      endReason: endReason == null && nullToAbsent
          ? const Value.absent()
          : Value(endReason),
      useSessionPrices: Value(useSessionPrices),
      tokenName: tokenName == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenName),
      tokenValueMinor: tokenValueMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenValueMinor),
      tokenValueCurrency: tokenValueCurrency == null && nullToAbsent
          ? const Value.absent()
          : Value(tokenValueCurrency),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PartySessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartySessionRow(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      endReason: serializer.fromJson<String?>(json['endReason']),
      useSessionPrices: serializer.fromJson<bool>(json['useSessionPrices']),
      tokenName: serializer.fromJson<String?>(json['tokenName']),
      tokenValueMinor: serializer.fromJson<int?>(json['tokenValueMinor']),
      tokenValueCurrency:
          serializer.fromJson<String?>(json['tokenValueCurrency']),
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
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'endReason': serializer.toJson<String?>(endReason),
      'useSessionPrices': serializer.toJson<bool>(useSessionPrices),
      'tokenName': serializer.toJson<String?>(tokenName),
      'tokenValueMinor': serializer.toJson<int?>(tokenValueMinor),
      'tokenValueCurrency': serializer.toJson<String?>(tokenValueCurrency),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PartySessionRow copyWith(
          {String? id,
          DateTime? startedAt,
          Value<DateTime?> endedAt = const Value.absent(),
          Value<String?> endReason = const Value.absent(),
          bool? useSessionPrices,
          Value<String?> tokenName = const Value.absent(),
          Value<int?> tokenValueMinor = const Value.absent(),
          Value<String?> tokenValueCurrency = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      PartySessionRow(
        id: id ?? this.id,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        endReason: endReason.present ? endReason.value : this.endReason,
        useSessionPrices: useSessionPrices ?? this.useSessionPrices,
        tokenName: tokenName.present ? tokenName.value : this.tokenName,
        tokenValueMinor: tokenValueMinor.present
            ? tokenValueMinor.value
            : this.tokenValueMinor,
        tokenValueCurrency: tokenValueCurrency.present
            ? tokenValueCurrency.value
            : this.tokenValueCurrency,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  PartySessionRow copyWithCompanion(PartySessionsCompanion data) {
    return PartySessionRow(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      endReason: data.endReason.present ? data.endReason.value : this.endReason,
      useSessionPrices: data.useSessionPrices.present
          ? data.useSessionPrices.value
          : this.useSessionPrices,
      tokenName: data.tokenName.present ? data.tokenName.value : this.tokenName,
      tokenValueMinor: data.tokenValueMinor.present
          ? data.tokenValueMinor.value
          : this.tokenValueMinor,
      tokenValueCurrency: data.tokenValueCurrency.present
          ? data.tokenValueCurrency.value
          : this.tokenValueCurrency,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartySessionRow(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('endReason: $endReason, ')
          ..write('useSessionPrices: $useSessionPrices, ')
          ..write('tokenName: $tokenName, ')
          ..write('tokenValueMinor: $tokenValueMinor, ')
          ..write('tokenValueCurrency: $tokenValueCurrency, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      startedAt,
      endedAt,
      endReason,
      useSessionPrices,
      tokenName,
      tokenValueMinor,
      tokenValueCurrency,
      createdAt,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartySessionRow &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.endReason == this.endReason &&
          other.useSessionPrices == this.useSessionPrices &&
          other.tokenName == this.tokenName &&
          other.tokenValueMinor == this.tokenValueMinor &&
          other.tokenValueCurrency == this.tokenValueCurrency &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PartySessionsCompanion extends UpdateCompanion<PartySessionRow> {
  final Value<String> id;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String?> endReason;
  final Value<bool> useSessionPrices;
  final Value<String?> tokenName;
  final Value<int?> tokenValueMinor;
  final Value<String?> tokenValueCurrency;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PartySessionsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.endReason = const Value.absent(),
    this.useSessionPrices = const Value.absent(),
    this.tokenName = const Value.absent(),
    this.tokenValueMinor = const Value.absent(),
    this.tokenValueCurrency = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartySessionsCompanion.insert({
    required String id,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.endReason = const Value.absent(),
    required bool useSessionPrices,
    this.tokenName = const Value.absent(),
    this.tokenValueMinor = const Value.absent(),
    this.tokenValueCurrency = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        startedAt = Value(startedAt),
        useSessionPrices = Value(useSessionPrices),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PartySessionRow> custom({
    Expression<String>? id,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? endReason,
    Expression<bool>? useSessionPrices,
    Expression<String>? tokenName,
    Expression<int>? tokenValueMinor,
    Expression<String>? tokenValueCurrency,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (endReason != null) 'end_reason': endReason,
      if (useSessionPrices != null) 'use_session_prices': useSessionPrices,
      if (tokenName != null) 'token_name': tokenName,
      if (tokenValueMinor != null) 'token_value_minor': tokenValueMinor,
      if (tokenValueCurrency != null)
        'token_value_currency': tokenValueCurrency,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartySessionsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? startedAt,
      Value<DateTime?>? endedAt,
      Value<String?>? endReason,
      Value<bool>? useSessionPrices,
      Value<String?>? tokenName,
      Value<int?>? tokenValueMinor,
      Value<String?>? tokenValueCurrency,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return PartySessionsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      endReason: endReason ?? this.endReason,
      useSessionPrices: useSessionPrices ?? this.useSessionPrices,
      tokenName: tokenName ?? this.tokenName,
      tokenValueMinor: tokenValueMinor ?? this.tokenValueMinor,
      tokenValueCurrency: tokenValueCurrency ?? this.tokenValueCurrency,
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
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (endReason.present) {
      map['end_reason'] = Variable<String>(endReason.value);
    }
    if (useSessionPrices.present) {
      map['use_session_prices'] = Variable<bool>(useSessionPrices.value);
    }
    if (tokenName.present) {
      map['token_name'] = Variable<String>(tokenName.value);
    }
    if (tokenValueMinor.present) {
      map['token_value_minor'] = Variable<int>(tokenValueMinor.value);
    }
    if (tokenValueCurrency.present) {
      map['token_value_currency'] = Variable<String>(tokenValueCurrency.value);
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
    return (StringBuffer('PartySessionsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('endReason: $endReason, ')
          ..write('useSessionPrices: $useSessionPrices, ')
          ..write('tokenName: $tokenName, ')
          ..write('tokenValueMinor: $tokenValueMinor, ')
          ..write('tokenValueCurrency: $tokenValueCurrency, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartySessionPricesTable extends PartySessionPrices
    with TableInfo<$PartySessionPricesTable, PartySessionPriceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartySessionPricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _partySessionIdMeta =
      const VerificationMeta('partySessionId');
  @override
  late final GeneratedColumn<String> partySessionId = GeneratedColumn<String>(
      'party_session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _drinkPresetIdMeta =
      const VerificationMeta('drinkPresetId');
  @override
  late final GeneratedColumn<String> drinkPresetId = GeneratedColumn<String>(
      'drink_preset_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _priceMinorMeta =
      const VerificationMeta('priceMinor');
  @override
  late final GeneratedColumn<int> priceMinor = GeneratedColumn<int>(
      'price_minor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priceTokensMeta =
      const VerificationMeta('priceTokens');
  @override
  late final GeneratedColumn<int> priceTokens = GeneratedColumn<int>(
      'price_tokens', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        partySessionId,
        drinkPresetId,
        priceMinor,
        currency,
        priceTokens,
        createdAt,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'party_session_prices';
  @override
  VerificationContext validateIntegrity(
      Insertable<PartySessionPriceRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('party_session_id')) {
      context.handle(
          _partySessionIdMeta,
          partySessionId.isAcceptableOrUnknown(
              data['party_session_id']!, _partySessionIdMeta));
    } else if (isInserting) {
      context.missing(_partySessionIdMeta);
    }
    if (data.containsKey('drink_preset_id')) {
      context.handle(
          _drinkPresetIdMeta,
          drinkPresetId.isAcceptableOrUnknown(
              data['drink_preset_id']!, _drinkPresetIdMeta));
    } else if (isInserting) {
      context.missing(_drinkPresetIdMeta);
    }
    if (data.containsKey('price_minor')) {
      context.handle(
          _priceMinorMeta,
          priceMinor.isAcceptableOrUnknown(
              data['price_minor']!, _priceMinorMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('price_tokens')) {
      context.handle(
          _priceTokensMeta,
          priceTokens.isAcceptableOrUnknown(
              data['price_tokens']!, _priceTokensMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PartySessionPriceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartySessionPriceRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      partySessionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}party_session_id'])!,
      drinkPresetId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}drink_preset_id'])!,
      priceMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_minor']),
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency']),
      priceTokens: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}price_tokens']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $PartySessionPricesTable createAlias(String alias) {
    return $PartySessionPricesTable(attachedDatabase, alias);
  }
}

class PartySessionPriceRow extends DataClass
    implements Insertable<PartySessionPriceRow> {
  final String id;
  final String partySessionId;
  final String drinkPresetId;

  /// Money price for this drink during this session, in minor units.
  final int? priceMinor;

  /// 'EUR' | 'USD' | 'GBP'. Required when [priceMinor] is set.
  final String? currency;

  /// Token cost for this drink during this session.
  final int? priceTokens;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const PartySessionPriceRow(
      {required this.id,
      required this.partySessionId,
      required this.drinkPresetId,
      this.priceMinor,
      this.currency,
      this.priceTokens,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['party_session_id'] = Variable<String>(partySessionId);
    map['drink_preset_id'] = Variable<String>(drinkPresetId);
    if (!nullToAbsent || priceMinor != null) {
      map['price_minor'] = Variable<int>(priceMinor);
    }
    if (!nullToAbsent || currency != null) {
      map['currency'] = Variable<String>(currency);
    }
    if (!nullToAbsent || priceTokens != null) {
      map['price_tokens'] = Variable<int>(priceTokens);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  PartySessionPricesCompanion toCompanion(bool nullToAbsent) {
    return PartySessionPricesCompanion(
      id: Value(id),
      partySessionId: Value(partySessionId),
      drinkPresetId: Value(drinkPresetId),
      priceMinor: priceMinor == null && nullToAbsent
          ? const Value.absent()
          : Value(priceMinor),
      currency: currency == null && nullToAbsent
          ? const Value.absent()
          : Value(currency),
      priceTokens: priceTokens == null && nullToAbsent
          ? const Value.absent()
          : Value(priceTokens),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory PartySessionPriceRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartySessionPriceRow(
      id: serializer.fromJson<String>(json['id']),
      partySessionId: serializer.fromJson<String>(json['partySessionId']),
      drinkPresetId: serializer.fromJson<String>(json['drinkPresetId']),
      priceMinor: serializer.fromJson<int?>(json['priceMinor']),
      currency: serializer.fromJson<String?>(json['currency']),
      priceTokens: serializer.fromJson<int?>(json['priceTokens']),
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
      'partySessionId': serializer.toJson<String>(partySessionId),
      'drinkPresetId': serializer.toJson<String>(drinkPresetId),
      'priceMinor': serializer.toJson<int?>(priceMinor),
      'currency': serializer.toJson<String?>(currency),
      'priceTokens': serializer.toJson<int?>(priceTokens),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  PartySessionPriceRow copyWith(
          {String? id,
          String? partySessionId,
          String? drinkPresetId,
          Value<int?> priceMinor = const Value.absent(),
          Value<String?> currency = const Value.absent(),
          Value<int?> priceTokens = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      PartySessionPriceRow(
        id: id ?? this.id,
        partySessionId: partySessionId ?? this.partySessionId,
        drinkPresetId: drinkPresetId ?? this.drinkPresetId,
        priceMinor: priceMinor.present ? priceMinor.value : this.priceMinor,
        currency: currency.present ? currency.value : this.currency,
        priceTokens: priceTokens.present ? priceTokens.value : this.priceTokens,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  PartySessionPriceRow copyWithCompanion(PartySessionPricesCompanion data) {
    return PartySessionPriceRow(
      id: data.id.present ? data.id.value : this.id,
      partySessionId: data.partySessionId.present
          ? data.partySessionId.value
          : this.partySessionId,
      drinkPresetId: data.drinkPresetId.present
          ? data.drinkPresetId.value
          : this.drinkPresetId,
      priceMinor:
          data.priceMinor.present ? data.priceMinor.value : this.priceMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      priceTokens:
          data.priceTokens.present ? data.priceTokens.value : this.priceTokens,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartySessionPriceRow(')
          ..write('id: $id, ')
          ..write('partySessionId: $partySessionId, ')
          ..write('drinkPresetId: $drinkPresetId, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('currency: $currency, ')
          ..write('priceTokens: $priceTokens, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, partySessionId, drinkPresetId, priceMinor,
      currency, priceTokens, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartySessionPriceRow &&
          other.id == this.id &&
          other.partySessionId == this.partySessionId &&
          other.drinkPresetId == this.drinkPresetId &&
          other.priceMinor == this.priceMinor &&
          other.currency == this.currency &&
          other.priceTokens == this.priceTokens &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class PartySessionPricesCompanion
    extends UpdateCompanion<PartySessionPriceRow> {
  final Value<String> id;
  final Value<String> partySessionId;
  final Value<String> drinkPresetId;
  final Value<int?> priceMinor;
  final Value<String?> currency;
  final Value<int?> priceTokens;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const PartySessionPricesCompanion({
    this.id = const Value.absent(),
    this.partySessionId = const Value.absent(),
    this.drinkPresetId = const Value.absent(),
    this.priceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.priceTokens = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartySessionPricesCompanion.insert({
    required String id,
    required String partySessionId,
    required String drinkPresetId,
    this.priceMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.priceTokens = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        partySessionId = Value(partySessionId),
        drinkPresetId = Value(drinkPresetId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<PartySessionPriceRow> custom({
    Expression<String>? id,
    Expression<String>? partySessionId,
    Expression<String>? drinkPresetId,
    Expression<int>? priceMinor,
    Expression<String>? currency,
    Expression<int>? priceTokens,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (partySessionId != null) 'party_session_id': partySessionId,
      if (drinkPresetId != null) 'drink_preset_id': drinkPresetId,
      if (priceMinor != null) 'price_minor': priceMinor,
      if (currency != null) 'currency': currency,
      if (priceTokens != null) 'price_tokens': priceTokens,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartySessionPricesCompanion copyWith(
      {Value<String>? id,
      Value<String>? partySessionId,
      Value<String>? drinkPresetId,
      Value<int?>? priceMinor,
      Value<String?>? currency,
      Value<int?>? priceTokens,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return PartySessionPricesCompanion(
      id: id ?? this.id,
      partySessionId: partySessionId ?? this.partySessionId,
      drinkPresetId: drinkPresetId ?? this.drinkPresetId,
      priceMinor: priceMinor ?? this.priceMinor,
      currency: currency ?? this.currency,
      priceTokens: priceTokens ?? this.priceTokens,
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
    if (partySessionId.present) {
      map['party_session_id'] = Variable<String>(partySessionId.value);
    }
    if (drinkPresetId.present) {
      map['drink_preset_id'] = Variable<String>(drinkPresetId.value);
    }
    if (priceMinor.present) {
      map['price_minor'] = Variable<int>(priceMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (priceTokens.present) {
      map['price_tokens'] = Variable<int>(priceTokens.value);
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
    return (StringBuffer('PartySessionPricesCompanion(')
          ..write('id: $id, ')
          ..write('partySessionId: $partySessionId, ')
          ..write('drinkPresetId: $drinkPresetId, ')
          ..write('priceMinor: $priceMinor, ')
          ..write('currency: $currency, ')
          ..write('priceTokens: $priceTokens, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MealsTable extends Meals with TableInfo<$MealsTable, MealRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _partySessionIdMeta =
      const VerificationMeta('partySessionId');
  @override
  late final GeneratedColumn<String> partySessionId = GeneratedColumn<String>(
      'party_session_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
      'size', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _eatenAtMeta =
      const VerificationMeta('eatenAt');
  @override
  late final GeneratedColumn<DateTime> eatenAt = GeneratedColumn<DateTime>(
      'eaten_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, partySessionId, size, eatenAt, createdAt, updatedAt, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meals';
  @override
  VerificationContext validateIntegrity(Insertable<MealRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('party_session_id')) {
      context.handle(
          _partySessionIdMeta,
          partySessionId.isAcceptableOrUnknown(
              data['party_session_id']!, _partySessionIdMeta));
    } else if (isInserting) {
      context.missing(_partySessionIdMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('eaten_at')) {
      context.handle(_eatenAtMeta,
          eatenAt.isAcceptableOrUnknown(data['eaten_at']!, _eatenAtMeta));
    } else if (isInserting) {
      context.missing(_eatenAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      partySessionId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}party_session_id'])!,
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}size'])!,
      eatenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}eaten_at'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $MealsTable createAlias(String alias) {
    return $MealsTable(attachedDatabase, alias);
  }
}

class MealRow extends DataClass implements Insertable<MealRow> {
  final String id;
  final String partySessionId;

  /// 'small' | 'medium' | 'large'.
  final String size;

  /// When the meal was eaten. Defaults to "now" at logging, adjustable.
  final DateTime eatenAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const MealRow(
      {required this.id,
      required this.partySessionId,
      required this.size,
      required this.eatenAt,
      required this.createdAt,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['party_session_id'] = Variable<String>(partySessionId);
    map['size'] = Variable<String>(size);
    map['eaten_at'] = Variable<DateTime>(eatenAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  MealsCompanion toCompanion(bool nullToAbsent) {
    return MealsCompanion(
      id: Value(id),
      partySessionId: Value(partySessionId),
      size: Value(size),
      eatenAt: Value(eatenAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MealRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealRow(
      id: serializer.fromJson<String>(json['id']),
      partySessionId: serializer.fromJson<String>(json['partySessionId']),
      size: serializer.fromJson<String>(json['size']),
      eatenAt: serializer.fromJson<DateTime>(json['eatenAt']),
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
      'partySessionId': serializer.toJson<String>(partySessionId),
      'size': serializer.toJson<String>(size),
      'eatenAt': serializer.toJson<DateTime>(eatenAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  MealRow copyWith(
          {String? id,
          String? partySessionId,
          String? size,
          DateTime? eatenAt,
          DateTime? createdAt,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      MealRow(
        id: id ?? this.id,
        partySessionId: partySessionId ?? this.partySessionId,
        size: size ?? this.size,
        eatenAt: eatenAt ?? this.eatenAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  MealRow copyWithCompanion(MealsCompanion data) {
    return MealRow(
      id: data.id.present ? data.id.value : this.id,
      partySessionId: data.partySessionId.present
          ? data.partySessionId.value
          : this.partySessionId,
      size: data.size.present ? data.size.value : this.size,
      eatenAt: data.eatenAt.present ? data.eatenAt.value : this.eatenAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealRow(')
          ..write('id: $id, ')
          ..write('partySessionId: $partySessionId, ')
          ..write('size: $size, ')
          ..write('eatenAt: $eatenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, partySessionId, size, eatenAt, createdAt, updatedAt, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealRow &&
          other.id == this.id &&
          other.partySessionId == this.partySessionId &&
          other.size == this.size &&
          other.eatenAt == this.eatenAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MealsCompanion extends UpdateCompanion<MealRow> {
  final Value<String> id;
  final Value<String> partySessionId;
  final Value<String> size;
  final Value<DateTime> eatenAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const MealsCompanion({
    this.id = const Value.absent(),
    this.partySessionId = const Value.absent(),
    this.size = const Value.absent(),
    this.eatenAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealsCompanion.insert({
    required String id,
    required String partySessionId,
    required String size,
    required DateTime eatenAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        partySessionId = Value(partySessionId),
        size = Value(size),
        eatenAt = Value(eatenAt),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<MealRow> custom({
    Expression<String>? id,
    Expression<String>? partySessionId,
    Expression<String>? size,
    Expression<DateTime>? eatenAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (partySessionId != null) 'party_session_id': partySessionId,
      if (size != null) 'size': size,
      if (eatenAt != null) 'eaten_at': eatenAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealsCompanion copyWith(
      {Value<String>? id,
      Value<String>? partySessionId,
      Value<String>? size,
      Value<DateTime>? eatenAt,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt,
      Value<int>? rowid}) {
    return MealsCompanion(
      id: id ?? this.id,
      partySessionId: partySessionId ?? this.partySessionId,
      size: size ?? this.size,
      eatenAt: eatenAt ?? this.eatenAt,
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
    if (partySessionId.present) {
      map['party_session_id'] = Variable<String>(partySessionId.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (eatenAt.present) {
      map['eaten_at'] = Variable<DateTime>(eatenAt.value);
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
    return (StringBuffer('MealsCompanion(')
          ..write('id: $id, ')
          ..write('partySessionId: $partySessionId, ')
          ..write('size: $size, ')
          ..write('eatenAt: $eatenAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
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
  late final $PartySessionsTable partySessions = $PartySessionsTable(this);
  late final $PartySessionPricesTable partySessionPrices =
      $PartySessionPricesTable(this);
  late final $MealsTable meals = $MealsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        drinkPresets,
        drinkEntries,
        userProfiles,
        userPreferencesTable,
        partySessions,
        partySessionPrices,
        meals
      ];
}

typedef $$DrinkPresetsTableCreateCompanionBuilder = DrinkPresetsCompanion
    Function({
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
typedef $$DrinkPresetsTableUpdateCompanionBuilder = DrinkPresetsCompanion
    Function({
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
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get beverageType => $composableBuilder(
      column: $table.beverageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get volumeMl => $composableBuilder(
      column: $table.volumeMl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get abvPercent => $composableBuilder(
      column: $table.abvPercent, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get regularPriceMinor => $composableBuilder(
      column: $table.regularPriceMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get regularCurrency => $composableBuilder(
      column: $table.regularCurrency,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconColor => $composableBuilder(
      column: $table.iconColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isUserCreated => $composableBuilder(
      column: $table.isUserCreated, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isHidden => $composableBuilder(
      column: $table.isHidden, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
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
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get beverageType => $composableBuilder(
      column: $table.beverageType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get volumeMl => $composableBuilder(
      column: $table.volumeMl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get abvPercent => $composableBuilder(
      column: $table.abvPercent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get regularPriceMinor => $composableBuilder(
      column: $table.regularPriceMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get regularCurrency => $composableBuilder(
      column: $table.regularCurrency,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconColor => $composableBuilder(
      column: $table.iconColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isUserCreated => $composableBuilder(
      column: $table.isUserCreated,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isHidden => $composableBuilder(
      column: $table.isHidden, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
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
      column: $table.beverageType, builder: (column) => column);

  GeneratedColumn<int> get volumeMl =>
      $composableBuilder(column: $table.volumeMl, builder: (column) => column);

  GeneratedColumn<double> get abvPercent => $composableBuilder(
      column: $table.abvPercent, builder: (column) => column);

  GeneratedColumn<int> get regularPriceMinor => $composableBuilder(
      column: $table.regularPriceMinor, builder: (column) => column);

  GeneratedColumn<String> get regularCurrency => $composableBuilder(
      column: $table.regularCurrency, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get iconColor =>
      $composableBuilder(column: $table.iconColor, builder: (column) => column);

  GeneratedColumn<bool> get isUserCreated => $composableBuilder(
      column: $table.isUserCreated, builder: (column) => column);

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

class $$DrinkPresetsTableTableManager extends RootTableManager<
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
      BaseReferences<_$AppDatabase, $DrinkPresetsTable, DrinkPresetRow>
    ),
    DrinkPresetRow,
    PrefetchHooks Function()> {
  $$DrinkPresetsTableTableManager(_$AppDatabase db, $DrinkPresetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DrinkPresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DrinkPresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DrinkPresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
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
          }) =>
              DrinkPresetsCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              DrinkPresetsCompanion.insert(
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
        ));
}

typedef $$DrinkPresetsTableProcessedTableManager = ProcessedTableManager<
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
      BaseReferences<_$AppDatabase, $DrinkPresetsTable, DrinkPresetRow>
    ),
    DrinkPresetRow,
    PrefetchHooks Function()>;
typedef $$DrinkEntriesTableCreateCompanionBuilder = DrinkEntriesCompanion
    Function({
  required String id,
  Value<String?> name,
  required String beverageType,
  required int volumeMl,
  Value<double?> abvPercent,
  Value<int?> priceMinor,
  Value<String?> currency,
  Value<int?> priceTokens,
  Value<int?> tokenValueMinor,
  Value<String?> tokenValueCurrency,
  Value<String?> iconKey,
  Value<String?> iconColor,
  Value<String?> partySessionId,
  required DateTime consumedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$DrinkEntriesTableUpdateCompanionBuilder = DrinkEntriesCompanion
    Function({
  Value<String> id,
  Value<String?> name,
  Value<String> beverageType,
  Value<int> volumeMl,
  Value<double?> abvPercent,
  Value<int?> priceMinor,
  Value<String?> currency,
  Value<int?> priceTokens,
  Value<int?> tokenValueMinor,
  Value<String?> tokenValueCurrency,
  Value<String?> iconKey,
  Value<String?> iconColor,
  Value<String?> partySessionId,
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
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get beverageType => $composableBuilder(
      column: $table.beverageType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get volumeMl => $composableBuilder(
      column: $table.volumeMl, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get abvPercent => $composableBuilder(
      column: $table.abvPercent, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceTokens => $composableBuilder(
      column: $table.priceTokens, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tokenValueMinor => $composableBuilder(
      column: $table.tokenValueMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tokenValueCurrency => $composableBuilder(
      column: $table.tokenValueCurrency,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconColor => $composableBuilder(
      column: $table.iconColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get consumedAt => $composableBuilder(
      column: $table.consumedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
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
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get beverageType => $composableBuilder(
      column: $table.beverageType,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get volumeMl => $composableBuilder(
      column: $table.volumeMl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get abvPercent => $composableBuilder(
      column: $table.abvPercent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceTokens => $composableBuilder(
      column: $table.priceTokens, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tokenValueMinor => $composableBuilder(
      column: $table.tokenValueMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tokenValueCurrency => $composableBuilder(
      column: $table.tokenValueCurrency,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconColor => $composableBuilder(
      column: $table.iconColor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get consumedAt => $composableBuilder(
      column: $table.consumedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
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
      column: $table.beverageType, builder: (column) => column);

  GeneratedColumn<int> get volumeMl =>
      $composableBuilder(column: $table.volumeMl, builder: (column) => column);

  GeneratedColumn<double> get abvPercent => $composableBuilder(
      column: $table.abvPercent, builder: (column) => column);

  GeneratedColumn<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get priceTokens => $composableBuilder(
      column: $table.priceTokens, builder: (column) => column);

  GeneratedColumn<int> get tokenValueMinor => $composableBuilder(
      column: $table.tokenValueMinor, builder: (column) => column);

  GeneratedColumn<String> get tokenValueCurrency => $composableBuilder(
      column: $table.tokenValueCurrency, builder: (column) => column);

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get iconColor =>
      $composableBuilder(column: $table.iconColor, builder: (column) => column);

  GeneratedColumn<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get consumedAt => $composableBuilder(
      column: $table.consumedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DrinkEntriesTableTableManager extends RootTableManager<
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
      BaseReferences<_$AppDatabase, $DrinkEntriesTable, DrinkEntryRow>
    ),
    DrinkEntryRow,
    PrefetchHooks Function()> {
  $$DrinkEntriesTableTableManager(_$AppDatabase db, $DrinkEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DrinkEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DrinkEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DrinkEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> name = const Value.absent(),
            Value<String> beverageType = const Value.absent(),
            Value<int> volumeMl = const Value.absent(),
            Value<double?> abvPercent = const Value.absent(),
            Value<int?> priceMinor = const Value.absent(),
            Value<String?> currency = const Value.absent(),
            Value<int?> priceTokens = const Value.absent(),
            Value<int?> tokenValueMinor = const Value.absent(),
            Value<String?> tokenValueCurrency = const Value.absent(),
            Value<String?> iconKey = const Value.absent(),
            Value<String?> iconColor = const Value.absent(),
            Value<String?> partySessionId = const Value.absent(),
            Value<DateTime> consumedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DrinkEntriesCompanion(
            id: id,
            name: name,
            beverageType: beverageType,
            volumeMl: volumeMl,
            abvPercent: abvPercent,
            priceMinor: priceMinor,
            currency: currency,
            priceTokens: priceTokens,
            tokenValueMinor: tokenValueMinor,
            tokenValueCurrency: tokenValueCurrency,
            iconKey: iconKey,
            iconColor: iconColor,
            partySessionId: partySessionId,
            consumedAt: consumedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> name = const Value.absent(),
            required String beverageType,
            required int volumeMl,
            Value<double?> abvPercent = const Value.absent(),
            Value<int?> priceMinor = const Value.absent(),
            Value<String?> currency = const Value.absent(),
            Value<int?> priceTokens = const Value.absent(),
            Value<int?> tokenValueMinor = const Value.absent(),
            Value<String?> tokenValueCurrency = const Value.absent(),
            Value<String?> iconKey = const Value.absent(),
            Value<String?> iconColor = const Value.absent(),
            Value<String?> partySessionId = const Value.absent(),
            required DateTime consumedAt,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DrinkEntriesCompanion.insert(
            id: id,
            name: name,
            beverageType: beverageType,
            volumeMl: volumeMl,
            abvPercent: abvPercent,
            priceMinor: priceMinor,
            currency: currency,
            priceTokens: priceTokens,
            tokenValueMinor: tokenValueMinor,
            tokenValueCurrency: tokenValueCurrency,
            iconKey: iconKey,
            iconColor: iconColor,
            partySessionId: partySessionId,
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
        ));
}

typedef $$DrinkEntriesTableProcessedTableManager = ProcessedTableManager<
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
      BaseReferences<_$AppDatabase, $DrinkEntriesTable, DrinkEntryRow>
    ),
    DrinkEntryRow,
    PrefetchHooks Function()>;
typedef $$UserProfilesTableCreateCompanionBuilder = UserProfilesCompanion
    Function({
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
typedef $$UserProfilesTableUpdateCompanionBuilder = UserProfilesCompanion
    Function({
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
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get weightKg => $composableBuilder(
      column: $table.weightKg, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get heightCm => $composableBuilder(
      column: $table.heightCm, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get birthDate => $composableBuilder(
      column: $table.birthDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
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
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gender => $composableBuilder(
      column: $table.gender, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get weightKg => $composableBuilder(
      column: $table.weightKg, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get heightCm => $composableBuilder(
      column: $table.heightCm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get birthDate => $composableBuilder(
      column: $table.birthDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
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

class $$UserProfilesTableTableManager extends RootTableManager<
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
      BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>
    ),
    UserProfileRow,
    PrefetchHooks Function()> {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> gender = const Value.absent(),
            Value<double?> weightKg = const Value.absent(),
            Value<double?> heightCm = const Value.absent(),
            Value<String?> birthDate = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfilesCompanion(
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
          createCompanionCallback: ({
            required String id,
            Value<String?> gender = const Value.absent(),
            Value<double?> weightKg = const Value.absent(),
            Value<double?> heightCm = const Value.absent(),
            Value<String?> birthDate = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfilesCompanion.insert(
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
        ));
}

typedef $$UserProfilesTableProcessedTableManager = ProcessedTableManager<
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
      BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfileRow>
    ),
    UserProfileRow,
    PrefetchHooks Function()>;
typedef $$UserPreferencesTableTableCreateCompanionBuilder
    = UserPreferencesTableCompanion Function({
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
typedef $$UserPreferencesTableTableUpdateCompanionBuilder
    = UserPreferencesTableCompanion Function({
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
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyGoalMl => $composableBuilder(
      column: $table.dailyGoalMl, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dayBoundaryHour => $composableBuilder(
      column: $table.dayBoundaryHour,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get units => $composableBuilder(
      column: $table.units, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get reminderEnabled => $composableBuilder(
      column: $table.reminderEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reminderStartHour => $composableBuilder(
      column: $table.reminderStartHour,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reminderEndHour => $composableBuilder(
      column: $table.reminderEndHour,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reminderIntervalMin => $composableBuilder(
      column: $table.reminderIntervalMin,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get inactivityReminderEnabled => $composableBuilder(
      column: $table.inactivityReminderEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get weeklySummaryEnabled => $composableBuilder(
      column: $table.weeklySummaryEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get defaultDrinkPresetId => $composableBuilder(
      column: $table.defaultDrinkPresetId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get bacCapGramsPerL => $composableBuilder(
      column: $table.bacCapGramsPerL,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get bacOnLockScreenEnabled => $composableBuilder(
      column: $table.bacOnLockScreenEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get approachingCapNotifEnabled => $composableBuilder(
      column: $table.approachingCapNotifEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get soberEstimateNotifEnabled => $composableBuilder(
      column: $table.soberEstimateNotifEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get installedAt => $composableBuilder(
      column: $table.installedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
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
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get username => $composableBuilder(
      column: $table.username, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyGoalMl => $composableBuilder(
      column: $table.dailyGoalMl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dayBoundaryHour => $composableBuilder(
      column: $table.dayBoundaryHour,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get units => $composableBuilder(
      column: $table.units, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get reminderEnabled => $composableBuilder(
      column: $table.reminderEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reminderStartHour => $composableBuilder(
      column: $table.reminderStartHour,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reminderEndHour => $composableBuilder(
      column: $table.reminderEndHour,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reminderIntervalMin => $composableBuilder(
      column: $table.reminderIntervalMin,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get inactivityReminderEnabled => $composableBuilder(
      column: $table.inactivityReminderEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get weeklySummaryEnabled => $composableBuilder(
      column: $table.weeklySummaryEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get defaultDrinkPresetId => $composableBuilder(
      column: $table.defaultDrinkPresetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get bacCapGramsPerL => $composableBuilder(
      column: $table.bacCapGramsPerL,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get bacOnLockScreenEnabled => $composableBuilder(
      column: $table.bacOnLockScreenEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get approachingCapNotifEnabled => $composableBuilder(
      column: $table.approachingCapNotifEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get soberEstimateNotifEnabled => $composableBuilder(
      column: $table.soberEstimateNotifEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get installedAt => $composableBuilder(
      column: $table.installedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
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
      column: $table.dailyGoalMl, builder: (column) => column);

  GeneratedColumn<int> get dayBoundaryHour => $composableBuilder(
      column: $table.dayBoundaryHour, builder: (column) => column);

  GeneratedColumn<String> get units =>
      $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<bool> get reminderEnabled => $composableBuilder(
      column: $table.reminderEnabled, builder: (column) => column);

  GeneratedColumn<int> get reminderStartHour => $composableBuilder(
      column: $table.reminderStartHour, builder: (column) => column);

  GeneratedColumn<int> get reminderEndHour => $composableBuilder(
      column: $table.reminderEndHour, builder: (column) => column);

  GeneratedColumn<int> get reminderIntervalMin => $composableBuilder(
      column: $table.reminderIntervalMin, builder: (column) => column);

  GeneratedColumn<bool> get inactivityReminderEnabled => $composableBuilder(
      column: $table.inactivityReminderEnabled, builder: (column) => column);

  GeneratedColumn<bool> get weeklySummaryEnabled => $composableBuilder(
      column: $table.weeklySummaryEnabled, builder: (column) => column);

  GeneratedColumn<String> get defaultDrinkPresetId => $composableBuilder(
      column: $table.defaultDrinkPresetId, builder: (column) => column);

  GeneratedColumn<double> get bacCapGramsPerL => $composableBuilder(
      column: $table.bacCapGramsPerL, builder: (column) => column);

  GeneratedColumn<bool> get bacOnLockScreenEnabled => $composableBuilder(
      column: $table.bacOnLockScreenEnabled, builder: (column) => column);

  GeneratedColumn<bool> get approachingCapNotifEnabled => $composableBuilder(
      column: $table.approachingCapNotifEnabled, builder: (column) => column);

  GeneratedColumn<bool> get soberEstimateNotifEnabled => $composableBuilder(
      column: $table.soberEstimateNotifEnabled, builder: (column) => column);

  GeneratedColumn<int> get installedAt => $composableBuilder(
      column: $table.installedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPreferencesTableTableTableManager extends RootTableManager<
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
      BaseReferences<_$AppDatabase, $UserPreferencesTableTable,
          UserPreferencesRow>
    ),
    UserPreferencesRow,
    PrefetchHooks Function()> {
  $$UserPreferencesTableTableTableManager(
      _$AppDatabase db, $UserPreferencesTableTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
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
          }) =>
              UserPreferencesTableCompanion(
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
          createCompanionCallback: ({
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
          }) =>
              UserPreferencesTableCompanion.insert(
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
        ));
}

typedef $$UserPreferencesTableTableProcessedTableManager
    = ProcessedTableManager<
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
          BaseReferences<_$AppDatabase, $UserPreferencesTableTable,
              UserPreferencesRow>
        ),
        UserPreferencesRow,
        PrefetchHooks Function()>;
typedef $$PartySessionsTableCreateCompanionBuilder = PartySessionsCompanion
    Function({
  required String id,
  required DateTime startedAt,
  Value<DateTime?> endedAt,
  Value<String?> endReason,
  required bool useSessionPrices,
  Value<String?> tokenName,
  Value<int?> tokenValueMinor,
  Value<String?> tokenValueCurrency,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$PartySessionsTableUpdateCompanionBuilder = PartySessionsCompanion
    Function({
  Value<String> id,
  Value<DateTime> startedAt,
  Value<DateTime?> endedAt,
  Value<String?> endReason,
  Value<bool> useSessionPrices,
  Value<String?> tokenName,
  Value<int?> tokenValueMinor,
  Value<String?> tokenValueCurrency,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$PartySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PartySessionsTable> {
  $$PartySessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endReason => $composableBuilder(
      column: $table.endReason, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get useSessionPrices => $composableBuilder(
      column: $table.useSessionPrices,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tokenName => $composableBuilder(
      column: $table.tokenName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tokenValueMinor => $composableBuilder(
      column: $table.tokenValueMinor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tokenValueCurrency => $composableBuilder(
      column: $table.tokenValueCurrency,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$PartySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PartySessionsTable> {
  $$PartySessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endReason => $composableBuilder(
      column: $table.endReason, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get useSessionPrices => $composableBuilder(
      column: $table.useSessionPrices,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tokenName => $composableBuilder(
      column: $table.tokenName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tokenValueMinor => $composableBuilder(
      column: $table.tokenValueMinor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tokenValueCurrency => $composableBuilder(
      column: $table.tokenValueCurrency,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$PartySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartySessionsTable> {
  $$PartySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get endReason =>
      $composableBuilder(column: $table.endReason, builder: (column) => column);

  GeneratedColumn<bool> get useSessionPrices => $composableBuilder(
      column: $table.useSessionPrices, builder: (column) => column);

  GeneratedColumn<String> get tokenName =>
      $composableBuilder(column: $table.tokenName, builder: (column) => column);

  GeneratedColumn<int> get tokenValueMinor => $composableBuilder(
      column: $table.tokenValueMinor, builder: (column) => column);

  GeneratedColumn<String> get tokenValueCurrency => $composableBuilder(
      column: $table.tokenValueCurrency, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PartySessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PartySessionsTable,
    PartySessionRow,
    $$PartySessionsTableFilterComposer,
    $$PartySessionsTableOrderingComposer,
    $$PartySessionsTableAnnotationComposer,
    $$PartySessionsTableCreateCompanionBuilder,
    $$PartySessionsTableUpdateCompanionBuilder,
    (
      PartySessionRow,
      BaseReferences<_$AppDatabase, $PartySessionsTable, PartySessionRow>
    ),
    PartySessionRow,
    PrefetchHooks Function()> {
  $$PartySessionsTableTableManager(_$AppDatabase db, $PartySessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> startedAt = const Value.absent(),
            Value<DateTime?> endedAt = const Value.absent(),
            Value<String?> endReason = const Value.absent(),
            Value<bool> useSessionPrices = const Value.absent(),
            Value<String?> tokenName = const Value.absent(),
            Value<int?> tokenValueMinor = const Value.absent(),
            Value<String?> tokenValueCurrency = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PartySessionsCompanion(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            endReason: endReason,
            useSessionPrices: useSessionPrices,
            tokenName: tokenName,
            tokenValueMinor: tokenValueMinor,
            tokenValueCurrency: tokenValueCurrency,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime startedAt,
            Value<DateTime?> endedAt = const Value.absent(),
            Value<String?> endReason = const Value.absent(),
            required bool useSessionPrices,
            Value<String?> tokenName = const Value.absent(),
            Value<int?> tokenValueMinor = const Value.absent(),
            Value<String?> tokenValueCurrency = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PartySessionsCompanion.insert(
            id: id,
            startedAt: startedAt,
            endedAt: endedAt,
            endReason: endReason,
            useSessionPrices: useSessionPrices,
            tokenName: tokenName,
            tokenValueMinor: tokenValueMinor,
            tokenValueCurrency: tokenValueCurrency,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PartySessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PartySessionsTable,
    PartySessionRow,
    $$PartySessionsTableFilterComposer,
    $$PartySessionsTableOrderingComposer,
    $$PartySessionsTableAnnotationComposer,
    $$PartySessionsTableCreateCompanionBuilder,
    $$PartySessionsTableUpdateCompanionBuilder,
    (
      PartySessionRow,
      BaseReferences<_$AppDatabase, $PartySessionsTable, PartySessionRow>
    ),
    PartySessionRow,
    PrefetchHooks Function()>;
typedef $$PartySessionPricesTableCreateCompanionBuilder
    = PartySessionPricesCompanion Function({
  required String id,
  required String partySessionId,
  required String drinkPresetId,
  Value<int?> priceMinor,
  Value<String?> currency,
  Value<int?> priceTokens,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$PartySessionPricesTableUpdateCompanionBuilder
    = PartySessionPricesCompanion Function({
  Value<String> id,
  Value<String> partySessionId,
  Value<String> drinkPresetId,
  Value<int?> priceMinor,
  Value<String?> currency,
  Value<int?> priceTokens,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$PartySessionPricesTableFilterComposer
    extends Composer<_$AppDatabase, $PartySessionPricesTable> {
  $$PartySessionPricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get drinkPresetId => $composableBuilder(
      column: $table.drinkPresetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get priceTokens => $composableBuilder(
      column: $table.priceTokens, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$PartySessionPricesTableOrderingComposer
    extends Composer<_$AppDatabase, $PartySessionPricesTable> {
  $$PartySessionPricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get drinkPresetId => $composableBuilder(
      column: $table.drinkPresetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get priceTokens => $composableBuilder(
      column: $table.priceTokens, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$PartySessionPricesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartySessionPricesTable> {
  $$PartySessionPricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId, builder: (column) => column);

  GeneratedColumn<String> get drinkPresetId => $composableBuilder(
      column: $table.drinkPresetId, builder: (column) => column);

  GeneratedColumn<int> get priceMinor => $composableBuilder(
      column: $table.priceMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get priceTokens => $composableBuilder(
      column: $table.priceTokens, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$PartySessionPricesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PartySessionPricesTable,
    PartySessionPriceRow,
    $$PartySessionPricesTableFilterComposer,
    $$PartySessionPricesTableOrderingComposer,
    $$PartySessionPricesTableAnnotationComposer,
    $$PartySessionPricesTableCreateCompanionBuilder,
    $$PartySessionPricesTableUpdateCompanionBuilder,
    (
      PartySessionPriceRow,
      BaseReferences<_$AppDatabase, $PartySessionPricesTable,
          PartySessionPriceRow>
    ),
    PartySessionPriceRow,
    PrefetchHooks Function()> {
  $$PartySessionPricesTableTableManager(
      _$AppDatabase db, $PartySessionPricesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartySessionPricesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartySessionPricesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartySessionPricesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> partySessionId = const Value.absent(),
            Value<String> drinkPresetId = const Value.absent(),
            Value<int?> priceMinor = const Value.absent(),
            Value<String?> currency = const Value.absent(),
            Value<int?> priceTokens = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PartySessionPricesCompanion(
            id: id,
            partySessionId: partySessionId,
            drinkPresetId: drinkPresetId,
            priceMinor: priceMinor,
            currency: currency,
            priceTokens: priceTokens,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String partySessionId,
            required String drinkPresetId,
            Value<int?> priceMinor = const Value.absent(),
            Value<String?> currency = const Value.absent(),
            Value<int?> priceTokens = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PartySessionPricesCompanion.insert(
            id: id,
            partySessionId: partySessionId,
            drinkPresetId: drinkPresetId,
            priceMinor: priceMinor,
            currency: currency,
            priceTokens: priceTokens,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PartySessionPricesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PartySessionPricesTable,
    PartySessionPriceRow,
    $$PartySessionPricesTableFilterComposer,
    $$PartySessionPricesTableOrderingComposer,
    $$PartySessionPricesTableAnnotationComposer,
    $$PartySessionPricesTableCreateCompanionBuilder,
    $$PartySessionPricesTableUpdateCompanionBuilder,
    (
      PartySessionPriceRow,
      BaseReferences<_$AppDatabase, $PartySessionPricesTable,
          PartySessionPriceRow>
    ),
    PartySessionPriceRow,
    PrefetchHooks Function()>;
typedef $$MealsTableCreateCompanionBuilder = MealsCompanion Function({
  required String id,
  required String partySessionId,
  required String size,
  required DateTime eatenAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$MealsTableUpdateCompanionBuilder = MealsCompanion Function({
  Value<String> id,
  Value<String> partySessionId,
  Value<String> size,
  Value<DateTime> eatenAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$MealsTableFilterComposer extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get eatenAt => $composableBuilder(
      column: $table.eatenAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$MealsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get eatenAt => $composableBuilder(
      column: $table.eatenAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$MealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get partySessionId => $composableBuilder(
      column: $table.partySessionId, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get eatenAt =>
      $composableBuilder(column: $table.eatenAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$MealsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MealsTable,
    MealRow,
    $$MealsTableFilterComposer,
    $$MealsTableOrderingComposer,
    $$MealsTableAnnotationComposer,
    $$MealsTableCreateCompanionBuilder,
    $$MealsTableUpdateCompanionBuilder,
    (MealRow, BaseReferences<_$AppDatabase, $MealsTable, MealRow>),
    MealRow,
    PrefetchHooks Function()> {
  $$MealsTableTableManager(_$AppDatabase db, $MealsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> partySessionId = const Value.absent(),
            Value<String> size = const Value.absent(),
            Value<DateTime> eatenAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MealsCompanion(
            id: id,
            partySessionId: partySessionId,
            size: size,
            eatenAt: eatenAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String partySessionId,
            required String size,
            required DateTime eatenAt,
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MealsCompanion.insert(
            id: id,
            partySessionId: partySessionId,
            size: size,
            eatenAt: eatenAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MealsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MealsTable,
    MealRow,
    $$MealsTableFilterComposer,
    $$MealsTableOrderingComposer,
    $$MealsTableAnnotationComposer,
    $$MealsTableCreateCompanionBuilder,
    $$MealsTableUpdateCompanionBuilder,
    (MealRow, BaseReferences<_$AppDatabase, $MealsTable, MealRow>),
    MealRow,
    PrefetchHooks Function()>;

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
  $$PartySessionsTableTableManager get partySessions =>
      $$PartySessionsTableTableManager(_db, _db.partySessions);
  $$PartySessionPricesTableTableManager get partySessionPrices =>
      $$PartySessionPricesTableTableManager(_db, _db.partySessionPrices);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db, _db.meals);
}
