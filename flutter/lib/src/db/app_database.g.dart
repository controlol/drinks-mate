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
        iconKey,
        iconColor,
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
    if (data.containsKey('icon_key')) {
      context.handle(_iconKeyMeta,
          iconKey.isAcceptableOrUnknown(data['icon_key']!, _iconKeyMeta));
    }
    if (data.containsKey('icon_color')) {
      context.handle(_iconColorMeta,
          iconColor.isAcceptableOrUnknown(data['icon_color']!, _iconColorMeta));
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
      iconKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_key']),
      iconColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon_color']),
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

  /// Snapshot of price in minor units at log time.
  final int? priceMinor;
  final String? currency;
  final String? iconKey;
  final String? iconColor;
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
      this.iconKey,
      this.iconColor,
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

  DrinkEntryRow copyWith(
          {String? id,
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
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      DrinkEntryRow(
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
      abvPercent:
          data.abvPercent.present ? data.abvPercent.value : this.abvPercent,
      priceMinor:
          data.priceMinor.present ? data.priceMinor.value : this.priceMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      iconKey: data.iconKey.present ? data.iconKey.value : this.iconKey,
      iconColor: data.iconColor.present ? data.iconColor.value : this.iconColor,
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

  DrinkEntriesCompanion copyWith(
      {Value<String>? id,
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
      Value<int>? rowid}) {
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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DrinkPresetsTable drinkPresets = $DrinkPresetsTable(this);
  late final $DrinkEntriesTable drinkEntries = $DrinkEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [drinkPresets, drinkEntries];
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
  Value<String?> iconKey,
  Value<String?> iconColor,
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

  ColumnFilters<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get iconColor => $composableBuilder(
      column: $table.iconColor, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get iconKey => $composableBuilder(
      column: $table.iconKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get iconColor => $composableBuilder(
      column: $table.iconColor, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<String> get iconKey =>
      $composableBuilder(column: $table.iconKey, builder: (column) => column);

  GeneratedColumn<String> get iconColor =>
      $composableBuilder(column: $table.iconColor, builder: (column) => column);

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
            Value<String?> iconKey = const Value.absent(),
            Value<String?> iconColor = const Value.absent(),
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
            iconKey: iconKey,
            iconColor: iconColor,
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
            Value<String?> iconKey = const Value.absent(),
            Value<String?> iconColor = const Value.absent(),
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DrinkPresetsTableTableManager get drinkPresets =>
      $$DrinkPresetsTableTableManager(_db, _db.drinkPresets);
  $$DrinkEntriesTableTableManager get drinkEntries =>
      $$DrinkEntriesTableTableManager(_db, _db.drinkEntries);
}
