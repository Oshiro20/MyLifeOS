// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $MealLogsTable extends MealLogs
    with TableInfo<$MealLogsTable, MealLogEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _photoPathMeta =
      const VerificationMeta('photoPath');
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
      'photo_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _classificationIndexMeta =
      const VerificationMeta('classificationIndex');
  @override
  late final GeneratedColumn<int> classificationIndex = GeneratedColumn<int>(
      'classification_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _feedbackMeta =
      const VerificationMeta('feedback');
  @override
  late final GeneratedColumn<String> feedback = GeneratedColumn<String>(
      'feedback', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _detectedIngredientsCsvMeta =
      const VerificationMeta('detectedIngredientsCsv');
  @override
  late final GeneratedColumn<String> detectedIngredientsCsv =
      GeneratedColumn<String>('detected_ingredients_csv', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        timestamp,
        photoPath,
        classificationIndex,
        feedback,
        detectedIngredientsCsv
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_logs';
  @override
  VerificationContext validateIntegrity(Insertable<MealLogEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('photo_path')) {
      context.handle(_photoPathMeta,
          photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta));
    } else if (isInserting) {
      context.missing(_photoPathMeta);
    }
    if (data.containsKey('classification_index')) {
      context.handle(
          _classificationIndexMeta,
          classificationIndex.isAcceptableOrUnknown(
              data['classification_index']!, _classificationIndexMeta));
    } else if (isInserting) {
      context.missing(_classificationIndexMeta);
    }
    if (data.containsKey('feedback')) {
      context.handle(_feedbackMeta,
          feedback.isAcceptableOrUnknown(data['feedback']!, _feedbackMeta));
    } else if (isInserting) {
      context.missing(_feedbackMeta);
    }
    if (data.containsKey('detected_ingredients_csv')) {
      context.handle(
          _detectedIngredientsCsvMeta,
          detectedIngredientsCsv.isAcceptableOrUnknown(
              data['detected_ingredients_csv']!, _detectedIngredientsCsvMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealLogEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealLogEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      photoPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}photo_path'])!,
      classificationIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}classification_index'])!,
      feedback: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}feedback'])!,
      detectedIngredientsCsv: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}detected_ingredients_csv'])!,
    );
  }

  @override
  $MealLogsTable createAlias(String alias) {
    return $MealLogsTable(attachedDatabase, alias);
  }
}

class MealLogEntry extends DataClass implements Insertable<MealLogEntry> {
  final String id;
  final DateTime timestamp;
  final String photoPath;
  final int classificationIndex;
  final String feedback;
  final String detectedIngredientsCsv;
  const MealLogEntry(
      {required this.id,
      required this.timestamp,
      required this.photoPath,
      required this.classificationIndex,
      required this.feedback,
      required this.detectedIngredientsCsv});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['photo_path'] = Variable<String>(photoPath);
    map['classification_index'] = Variable<int>(classificationIndex);
    map['feedback'] = Variable<String>(feedback);
    map['detected_ingredients_csv'] = Variable<String>(detectedIngredientsCsv);
    return map;
  }

  MealLogsCompanion toCompanion(bool nullToAbsent) {
    return MealLogsCompanion(
      id: Value(id),
      timestamp: Value(timestamp),
      photoPath: Value(photoPath),
      classificationIndex: Value(classificationIndex),
      feedback: Value(feedback),
      detectedIngredientsCsv: Value(detectedIngredientsCsv),
    );
  }

  factory MealLogEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealLogEntry(
      id: serializer.fromJson<String>(json['id']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      photoPath: serializer.fromJson<String>(json['photoPath']),
      classificationIndex:
          serializer.fromJson<int>(json['classificationIndex']),
      feedback: serializer.fromJson<String>(json['feedback']),
      detectedIngredientsCsv:
          serializer.fromJson<String>(json['detectedIngredientsCsv']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'photoPath': serializer.toJson<String>(photoPath),
      'classificationIndex': serializer.toJson<int>(classificationIndex),
      'feedback': serializer.toJson<String>(feedback),
      'detectedIngredientsCsv':
          serializer.toJson<String>(detectedIngredientsCsv),
    };
  }

  MealLogEntry copyWith(
          {String? id,
          DateTime? timestamp,
          String? photoPath,
          int? classificationIndex,
          String? feedback,
          String? detectedIngredientsCsv}) =>
      MealLogEntry(
        id: id ?? this.id,
        timestamp: timestamp ?? this.timestamp,
        photoPath: photoPath ?? this.photoPath,
        classificationIndex: classificationIndex ?? this.classificationIndex,
        feedback: feedback ?? this.feedback,
        detectedIngredientsCsv:
            detectedIngredientsCsv ?? this.detectedIngredientsCsv,
      );
  MealLogEntry copyWithCompanion(MealLogsCompanion data) {
    return MealLogEntry(
      id: data.id.present ? data.id.value : this.id,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      classificationIndex: data.classificationIndex.present
          ? data.classificationIndex.value
          : this.classificationIndex,
      feedback: data.feedback.present ? data.feedback.value : this.feedback,
      detectedIngredientsCsv: data.detectedIngredientsCsv.present
          ? data.detectedIngredientsCsv.value
          : this.detectedIngredientsCsv,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealLogEntry(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('photoPath: $photoPath, ')
          ..write('classificationIndex: $classificationIndex, ')
          ..write('feedback: $feedback, ')
          ..write('detectedIngredientsCsv: $detectedIngredientsCsv')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, timestamp, photoPath, classificationIndex,
      feedback, detectedIngredientsCsv);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealLogEntry &&
          other.id == this.id &&
          other.timestamp == this.timestamp &&
          other.photoPath == this.photoPath &&
          other.classificationIndex == this.classificationIndex &&
          other.feedback == this.feedback &&
          other.detectedIngredientsCsv == this.detectedIngredientsCsv);
}

class MealLogsCompanion extends UpdateCompanion<MealLogEntry> {
  final Value<String> id;
  final Value<DateTime> timestamp;
  final Value<String> photoPath;
  final Value<int> classificationIndex;
  final Value<String> feedback;
  final Value<String> detectedIngredientsCsv;
  final Value<int> rowid;
  const MealLogsCompanion({
    this.id = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.classificationIndex = const Value.absent(),
    this.feedback = const Value.absent(),
    this.detectedIngredientsCsv = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MealLogsCompanion.insert({
    required String id,
    required DateTime timestamp,
    required String photoPath,
    required int classificationIndex,
    required String feedback,
    this.detectedIngredientsCsv = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        timestamp = Value(timestamp),
        photoPath = Value(photoPath),
        classificationIndex = Value(classificationIndex),
        feedback = Value(feedback);
  static Insertable<MealLogEntry> custom({
    Expression<String>? id,
    Expression<DateTime>? timestamp,
    Expression<String>? photoPath,
    Expression<int>? classificationIndex,
    Expression<String>? feedback,
    Expression<String>? detectedIngredientsCsv,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timestamp != null) 'timestamp': timestamp,
      if (photoPath != null) 'photo_path': photoPath,
      if (classificationIndex != null)
        'classification_index': classificationIndex,
      if (feedback != null) 'feedback': feedback,
      if (detectedIngredientsCsv != null)
        'detected_ingredients_csv': detectedIngredientsCsv,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MealLogsCompanion copyWith(
      {Value<String>? id,
      Value<DateTime>? timestamp,
      Value<String>? photoPath,
      Value<int>? classificationIndex,
      Value<String>? feedback,
      Value<String>? detectedIngredientsCsv,
      Value<int>? rowid}) {
    return MealLogsCompanion(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      photoPath: photoPath ?? this.photoPath,
      classificationIndex: classificationIndex ?? this.classificationIndex,
      feedback: feedback ?? this.feedback,
      detectedIngredientsCsv:
          detectedIngredientsCsv ?? this.detectedIngredientsCsv,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (classificationIndex.present) {
      map['classification_index'] = Variable<int>(classificationIndex.value);
    }
    if (feedback.present) {
      map['feedback'] = Variable<String>(feedback.value);
    }
    if (detectedIngredientsCsv.present) {
      map['detected_ingredients_csv'] =
          Variable<String>(detectedIngredientsCsv.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealLogsCompanion(')
          ..write('id: $id, ')
          ..write('timestamp: $timestamp, ')
          ..write('photoPath: $photoPath, ')
          ..write('classificationIndex: $classificationIndex, ')
          ..write('feedback: $feedback, ')
          ..write('detectedIngredientsCsv: $detectedIngredientsCsv, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InventoryIngredientsTable extends InventoryIngredients
    with TableInfo<$InventoryIngredientsTable, InventoryIngredientEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InventoryIngredientsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _primaryCategoryMeta =
      const VerificationMeta('primaryCategory');
  @override
  late final GeneratedColumn<String> primaryCategory = GeneratedColumn<String>(
      'primary_category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Otros'));
  static const VerificationMeta _subCategoryMeta =
      const VerificationMeta('subCategory');
  @override
  late final GeneratedColumn<String> subCategory = GeneratedColumn<String>(
      'sub_category', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _preparationMeta =
      const VerificationMeta('preparation');
  @override
  late final GeneratedColumn<String> preparation = GeneratedColumn<String>(
      'preparation', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _expirationDateMeta =
      const VerificationMeta('expirationDate');
  @override
  late final GeneratedColumn<DateTime> expirationDate =
      GeneratedColumn<DateTime>('expiration_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _imageAssetIdMeta =
      const VerificationMeta('imageAssetId');
  @override
  late final GeneratedColumn<String> imageAssetId = GeneratedColumn<String>(
      'image_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _storageAreaMeta =
      const VerificationMeta('storageArea');
  @override
  late final GeneratedColumn<String> storageArea = GeneratedColumn<String>(
      'storage_area', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        primaryCategory,
        subCategory,
        preparation,
        quantity,
        unit,
        expirationDate,
        imageAssetId,
        storageArea
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inventory_ingredients';
  @override
  VerificationContext validateIntegrity(
      Insertable<InventoryIngredientEntry> instance,
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
    if (data.containsKey('primary_category')) {
      context.handle(
          _primaryCategoryMeta,
          primaryCategory.isAcceptableOrUnknown(
              data['primary_category']!, _primaryCategoryMeta));
    }
    if (data.containsKey('sub_category')) {
      context.handle(
          _subCategoryMeta,
          subCategory.isAcceptableOrUnknown(
              data['sub_category']!, _subCategoryMeta));
    }
    if (data.containsKey('preparation')) {
      context.handle(
          _preparationMeta,
          preparation.isAcceptableOrUnknown(
              data['preparation']!, _preparationMeta));
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('expiration_date')) {
      context.handle(
          _expirationDateMeta,
          expirationDate.isAcceptableOrUnknown(
              data['expiration_date']!, _expirationDateMeta));
    }
    if (data.containsKey('image_asset_id')) {
      context.handle(
          _imageAssetIdMeta,
          imageAssetId.isAcceptableOrUnknown(
              data['image_asset_id']!, _imageAssetIdMeta));
    }
    if (data.containsKey('storage_area')) {
      context.handle(
          _storageAreaMeta,
          storageArea.isAcceptableOrUnknown(
              data['storage_area']!, _storageAreaMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InventoryIngredientEntry map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InventoryIngredientEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      primaryCategory: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}primary_category'])!,
      subCategory: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sub_category']),
      preparation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}preparation'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      expirationDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}expiration_date']),
      imageAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_asset_id']),
      storageArea: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}storage_area']),
    );
  }

  @override
  $InventoryIngredientsTable createAlias(String alias) {
    return $InventoryIngredientsTable(attachedDatabase, alias);
  }
}

class InventoryIngredientEntry extends DataClass
    implements Insertable<InventoryIngredientEntry> {
  final String id;
  final String name;
  final String primaryCategory;
  final String? subCategory;
  final String preparation;
  final double quantity;
  final String unit;
  final DateTime? expirationDate;
  final String? imageAssetId;
  final String? storageArea;
  const InventoryIngredientEntry(
      {required this.id,
      required this.name,
      required this.primaryCategory,
      this.subCategory,
      required this.preparation,
      required this.quantity,
      required this.unit,
      this.expirationDate,
      this.imageAssetId,
      this.storageArea});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['primary_category'] = Variable<String>(primaryCategory);
    if (!nullToAbsent || subCategory != null) {
      map['sub_category'] = Variable<String>(subCategory);
    }
    map['preparation'] = Variable<String>(preparation);
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    if (!nullToAbsent || expirationDate != null) {
      map['expiration_date'] = Variable<DateTime>(expirationDate);
    }
    if (!nullToAbsent || imageAssetId != null) {
      map['image_asset_id'] = Variable<String>(imageAssetId);
    }
    if (!nullToAbsent || storageArea != null) {
      map['storage_area'] = Variable<String>(storageArea);
    }
    return map;
  }

  InventoryIngredientsCompanion toCompanion(bool nullToAbsent) {
    return InventoryIngredientsCompanion(
      id: Value(id),
      name: Value(name),
      primaryCategory: Value(primaryCategory),
      subCategory: subCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(subCategory),
      preparation: Value(preparation),
      quantity: Value(quantity),
      unit: Value(unit),
      expirationDate: expirationDate == null && nullToAbsent
          ? const Value.absent()
          : Value(expirationDate),
      imageAssetId: imageAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAssetId),
      storageArea: storageArea == null && nullToAbsent
          ? const Value.absent()
          : Value(storageArea),
    );
  }

  factory InventoryIngredientEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InventoryIngredientEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      primaryCategory: serializer.fromJson<String>(json['primaryCategory']),
      subCategory: serializer.fromJson<String?>(json['subCategory']),
      preparation: serializer.fromJson<String>(json['preparation']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      expirationDate: serializer.fromJson<DateTime?>(json['expirationDate']),
      imageAssetId: serializer.fromJson<String?>(json['imageAssetId']),
      storageArea: serializer.fromJson<String?>(json['storageArea']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'primaryCategory': serializer.toJson<String>(primaryCategory),
      'subCategory': serializer.toJson<String?>(subCategory),
      'preparation': serializer.toJson<String>(preparation),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
      'expirationDate': serializer.toJson<DateTime?>(expirationDate),
      'imageAssetId': serializer.toJson<String?>(imageAssetId),
      'storageArea': serializer.toJson<String?>(storageArea),
    };
  }

  InventoryIngredientEntry copyWith(
          {String? id,
          String? name,
          String? primaryCategory,
          Value<String?> subCategory = const Value.absent(),
          String? preparation,
          double? quantity,
          String? unit,
          Value<DateTime?> expirationDate = const Value.absent(),
          Value<String?> imageAssetId = const Value.absent(),
          Value<String?> storageArea = const Value.absent()}) =>
      InventoryIngredientEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        primaryCategory: primaryCategory ?? this.primaryCategory,
        subCategory: subCategory.present ? subCategory.value : this.subCategory,
        preparation: preparation ?? this.preparation,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        expirationDate:
            expirationDate.present ? expirationDate.value : this.expirationDate,
        imageAssetId:
            imageAssetId.present ? imageAssetId.value : this.imageAssetId,
        storageArea: storageArea.present ? storageArea.value : this.storageArea,
      );
  InventoryIngredientEntry copyWithCompanion(
      InventoryIngredientsCompanion data) {
    return InventoryIngredientEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      primaryCategory: data.primaryCategory.present
          ? data.primaryCategory.value
          : this.primaryCategory,
      subCategory:
          data.subCategory.present ? data.subCategory.value : this.subCategory,
      preparation:
          data.preparation.present ? data.preparation.value : this.preparation,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      expirationDate: data.expirationDate.present
          ? data.expirationDate.value
          : this.expirationDate,
      imageAssetId: data.imageAssetId.present
          ? data.imageAssetId.value
          : this.imageAssetId,
      storageArea:
          data.storageArea.present ? data.storageArea.value : this.storageArea,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InventoryIngredientEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('primaryCategory: $primaryCategory, ')
          ..write('subCategory: $subCategory, ')
          ..write('preparation: $preparation, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('expirationDate: $expirationDate, ')
          ..write('imageAssetId: $imageAssetId, ')
          ..write('storageArea: $storageArea')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, primaryCategory, subCategory,
      preparation, quantity, unit, expirationDate, imageAssetId, storageArea);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InventoryIngredientEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.primaryCategory == this.primaryCategory &&
          other.subCategory == this.subCategory &&
          other.preparation == this.preparation &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.expirationDate == this.expirationDate &&
          other.imageAssetId == this.imageAssetId &&
          other.storageArea == this.storageArea);
}

class InventoryIngredientsCompanion
    extends UpdateCompanion<InventoryIngredientEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> primaryCategory;
  final Value<String?> subCategory;
  final Value<String> preparation;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<DateTime?> expirationDate;
  final Value<String?> imageAssetId;
  final Value<String?> storageArea;
  final Value<int> rowid;
  const InventoryIngredientsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.primaryCategory = const Value.absent(),
    this.subCategory = const Value.absent(),
    this.preparation = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.expirationDate = const Value.absent(),
    this.imageAssetId = const Value.absent(),
    this.storageArea = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InventoryIngredientsCompanion.insert({
    required String id,
    required String name,
    this.primaryCategory = const Value.absent(),
    this.subCategory = const Value.absent(),
    this.preparation = const Value.absent(),
    required double quantity,
    required String unit,
    this.expirationDate = const Value.absent(),
    this.imageAssetId = const Value.absent(),
    this.storageArea = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        quantity = Value(quantity),
        unit = Value(unit);
  static Insertable<InventoryIngredientEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? primaryCategory,
    Expression<String>? subCategory,
    Expression<String>? preparation,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<DateTime>? expirationDate,
    Expression<String>? imageAssetId,
    Expression<String>? storageArea,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (primaryCategory != null) 'primary_category': primaryCategory,
      if (subCategory != null) 'sub_category': subCategory,
      if (preparation != null) 'preparation': preparation,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (expirationDate != null) 'expiration_date': expirationDate,
      if (imageAssetId != null) 'image_asset_id': imageAssetId,
      if (storageArea != null) 'storage_area': storageArea,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InventoryIngredientsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? primaryCategory,
      Value<String?>? subCategory,
      Value<String>? preparation,
      Value<double>? quantity,
      Value<String>? unit,
      Value<DateTime?>? expirationDate,
      Value<String?>? imageAssetId,
      Value<String?>? storageArea,
      Value<int>? rowid}) {
    return InventoryIngredientsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      subCategory: subCategory ?? this.subCategory,
      preparation: preparation ?? this.preparation,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      expirationDate: expirationDate ?? this.expirationDate,
      imageAssetId: imageAssetId ?? this.imageAssetId,
      storageArea: storageArea ?? this.storageArea,
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
    if (primaryCategory.present) {
      map['primary_category'] = Variable<String>(primaryCategory.value);
    }
    if (subCategory.present) {
      map['sub_category'] = Variable<String>(subCategory.value);
    }
    if (preparation.present) {
      map['preparation'] = Variable<String>(preparation.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (expirationDate.present) {
      map['expiration_date'] = Variable<DateTime>(expirationDate.value);
    }
    if (imageAssetId.present) {
      map['image_asset_id'] = Variable<String>(imageAssetId.value);
    }
    if (storageArea.present) {
      map['storage_area'] = Variable<String>(storageArea.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InventoryIngredientsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('primaryCategory: $primaryCategory, ')
          ..write('subCategory: $subCategory, ')
          ..write('preparation: $preparation, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('expirationDate: $expirationDate, ')
          ..write('imageAssetId: $imageAssetId, ')
          ..write('storageArea: $storageArea, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipesTable extends Recipes with TableInfo<$RecipesTable, RecipeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _durationMinutesMeta =
      const VerificationMeta('durationMinutes');
  @override
  late final GeneratedColumn<int> durationMinutes = GeneratedColumn<int>(
      'duration_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(30));
  static const VerificationMeta _servingsMeta =
      const VerificationMeta('servings');
  @override
  late final GeneratedColumn<int> servings = GeneratedColumn<int>(
      'servings', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(2));
  static const VerificationMeta _instructionsJsonMeta =
      const VerificationMeta('instructionsJson');
  @override
  late final GeneratedColumn<String> instructionsJson = GeneratedColumn<String>(
      'instructions_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _tagsCsvMeta =
      const VerificationMeta('tagsCsv');
  @override
  late final GeneratedColumn<String> tagsCsv = GeneratedColumn<String>(
      'tags_csv', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _imageAssetIdMeta =
      const VerificationMeta('imageAssetId');
  @override
  late final GeneratedColumn<String> imageAssetId = GeneratedColumn<String>(
      'image_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _goalIndexMeta =
      const VerificationMeta('goalIndex');
  @override
  late final GeneratedColumn<int> goalIndex = GeneratedColumn<int>(
      'goal_index', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        durationMinutes,
        servings,
        instructionsJson,
        tagsCsv,
        imageAssetId,
        goalIndex,
        isFavorite,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes';
  @override
  VerificationContext validateIntegrity(Insertable<RecipeEntry> instance,
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
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('duration_minutes')) {
      context.handle(
          _durationMinutesMeta,
          durationMinutes.isAcceptableOrUnknown(
              data['duration_minutes']!, _durationMinutesMeta));
    }
    if (data.containsKey('servings')) {
      context.handle(_servingsMeta,
          servings.isAcceptableOrUnknown(data['servings']!, _servingsMeta));
    }
    if (data.containsKey('instructions_json')) {
      context.handle(
          _instructionsJsonMeta,
          instructionsJson.isAcceptableOrUnknown(
              data['instructions_json']!, _instructionsJsonMeta));
    }
    if (data.containsKey('tags_csv')) {
      context.handle(_tagsCsvMeta,
          tagsCsv.isAcceptableOrUnknown(data['tags_csv']!, _tagsCsvMeta));
    }
    if (data.containsKey('image_asset_id')) {
      context.handle(
          _imageAssetIdMeta,
          imageAssetId.isAcceptableOrUnknown(
              data['image_asset_id']!, _imageAssetIdMeta));
    }
    if (data.containsKey('goal_index')) {
      context.handle(_goalIndexMeta,
          goalIndex.isAcceptableOrUnknown(data['goal_index']!, _goalIndexMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description'])!,
      durationMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_minutes'])!,
      servings: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}servings'])!,
      instructionsJson: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}instructions_json'])!,
      tagsCsv: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags_csv'])!,
      imageAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_asset_id']),
      goalIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}goal_index'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $RecipesTable createAlias(String alias) {
    return $RecipesTable(attachedDatabase, alias);
  }
}

class RecipeEntry extends DataClass implements Insertable<RecipeEntry> {
  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final int servings;
  final String instructionsJson;
  final String tagsCsv;
  final String? imageAssetId;
  final int goalIndex;
  final bool isFavorite;
  final DateTime createdAt;
  const RecipeEntry(
      {required this.id,
      required this.name,
      required this.description,
      required this.durationMinutes,
      required this.servings,
      required this.instructionsJson,
      required this.tagsCsv,
      this.imageAssetId,
      required this.goalIndex,
      required this.isFavorite,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['duration_minutes'] = Variable<int>(durationMinutes);
    map['servings'] = Variable<int>(servings);
    map['instructions_json'] = Variable<String>(instructionsJson);
    map['tags_csv'] = Variable<String>(tagsCsv);
    if (!nullToAbsent || imageAssetId != null) {
      map['image_asset_id'] = Variable<String>(imageAssetId);
    }
    map['goal_index'] = Variable<int>(goalIndex);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      durationMinutes: Value(durationMinutes),
      servings: Value(servings),
      instructionsJson: Value(instructionsJson),
      tagsCsv: Value(tagsCsv),
      imageAssetId: imageAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAssetId),
      goalIndex: Value(goalIndex),
      isFavorite: Value(isFavorite),
      createdAt: Value(createdAt),
    );
  }

  factory RecipeEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      durationMinutes: serializer.fromJson<int>(json['durationMinutes']),
      servings: serializer.fromJson<int>(json['servings']),
      instructionsJson: serializer.fromJson<String>(json['instructionsJson']),
      tagsCsv: serializer.fromJson<String>(json['tagsCsv']),
      imageAssetId: serializer.fromJson<String?>(json['imageAssetId']),
      goalIndex: serializer.fromJson<int>(json['goalIndex']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'durationMinutes': serializer.toJson<int>(durationMinutes),
      'servings': serializer.toJson<int>(servings),
      'instructionsJson': serializer.toJson<String>(instructionsJson),
      'tagsCsv': serializer.toJson<String>(tagsCsv),
      'imageAssetId': serializer.toJson<String?>(imageAssetId),
      'goalIndex': serializer.toJson<int>(goalIndex),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RecipeEntry copyWith(
          {String? id,
          String? name,
          String? description,
          int? durationMinutes,
          int? servings,
          String? instructionsJson,
          String? tagsCsv,
          Value<String?> imageAssetId = const Value.absent(),
          int? goalIndex,
          bool? isFavorite,
          DateTime? createdAt}) =>
      RecipeEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        servings: servings ?? this.servings,
        instructionsJson: instructionsJson ?? this.instructionsJson,
        tagsCsv: tagsCsv ?? this.tagsCsv,
        imageAssetId:
            imageAssetId.present ? imageAssetId.value : this.imageAssetId,
        goalIndex: goalIndex ?? this.goalIndex,
        isFavorite: isFavorite ?? this.isFavorite,
        createdAt: createdAt ?? this.createdAt,
      );
  RecipeEntry copyWithCompanion(RecipesCompanion data) {
    return RecipeEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      durationMinutes: data.durationMinutes.present
          ? data.durationMinutes.value
          : this.durationMinutes,
      servings: data.servings.present ? data.servings.value : this.servings,
      instructionsJson: data.instructionsJson.present
          ? data.instructionsJson.value
          : this.instructionsJson,
      tagsCsv: data.tagsCsv.present ? data.tagsCsv.value : this.tagsCsv,
      imageAssetId: data.imageAssetId.present
          ? data.imageAssetId.value
          : this.imageAssetId,
      goalIndex: data.goalIndex.present ? data.goalIndex.value : this.goalIndex,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('servings: $servings, ')
          ..write('instructionsJson: $instructionsJson, ')
          ..write('tagsCsv: $tagsCsv, ')
          ..write('imageAssetId: $imageAssetId, ')
          ..write('goalIndex: $goalIndex, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      description,
      durationMinutes,
      servings,
      instructionsJson,
      tagsCsv,
      imageAssetId,
      goalIndex,
      isFavorite,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.durationMinutes == this.durationMinutes &&
          other.servings == this.servings &&
          other.instructionsJson == this.instructionsJson &&
          other.tagsCsv == this.tagsCsv &&
          other.imageAssetId == this.imageAssetId &&
          other.goalIndex == this.goalIndex &&
          other.isFavorite == this.isFavorite &&
          other.createdAt == this.createdAt);
}

class RecipesCompanion extends UpdateCompanion<RecipeEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<int> durationMinutes;
  final Value<int> servings;
  final Value<String> instructionsJson;
  final Value<String> tagsCsv;
  final Value<String?> imageAssetId;
  final Value<int> goalIndex;
  final Value<bool> isFavorite;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RecipesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.servings = const Value.absent(),
    this.instructionsJson = const Value.absent(),
    this.tagsCsv = const Value.absent(),
    this.imageAssetId = const Value.absent(),
    this.goalIndex = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipesCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.durationMinutes = const Value.absent(),
    this.servings = const Value.absent(),
    this.instructionsJson = const Value.absent(),
    this.tagsCsv = const Value.absent(),
    this.imageAssetId = const Value.absent(),
    this.goalIndex = const Value.absent(),
    this.isFavorite = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<RecipeEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? durationMinutes,
    Expression<int>? servings,
    Expression<String>? instructionsJson,
    Expression<String>? tagsCsv,
    Expression<String>? imageAssetId,
    Expression<int>? goalIndex,
    Expression<bool>? isFavorite,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (servings != null) 'servings': servings,
      if (instructionsJson != null) 'instructions_json': instructionsJson,
      if (tagsCsv != null) 'tags_csv': tagsCsv,
      if (imageAssetId != null) 'image_asset_id': imageAssetId,
      if (goalIndex != null) 'goal_index': goalIndex,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? description,
      Value<int>? durationMinutes,
      Value<int>? servings,
      Value<String>? instructionsJson,
      Value<String>? tagsCsv,
      Value<String?>? imageAssetId,
      Value<int>? goalIndex,
      Value<bool>? isFavorite,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return RecipesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      servings: servings ?? this.servings,
      instructionsJson: instructionsJson ?? this.instructionsJson,
      tagsCsv: tagsCsv ?? this.tagsCsv,
      imageAssetId: imageAssetId ?? this.imageAssetId,
      goalIndex: goalIndex ?? this.goalIndex,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (durationMinutes.present) {
      map['duration_minutes'] = Variable<int>(durationMinutes.value);
    }
    if (servings.present) {
      map['servings'] = Variable<int>(servings.value);
    }
    if (instructionsJson.present) {
      map['instructions_json'] = Variable<String>(instructionsJson.value);
    }
    if (tagsCsv.present) {
      map['tags_csv'] = Variable<String>(tagsCsv.value);
    }
    if (imageAssetId.present) {
      map['image_asset_id'] = Variable<String>(imageAssetId.value);
    }
    if (goalIndex.present) {
      map['goal_index'] = Variable<int>(goalIndex.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('durationMinutes: $durationMinutes, ')
          ..write('servings: $servings, ')
          ..write('instructionsJson: $instructionsJson, ')
          ..write('tagsCsv: $tagsCsv, ')
          ..write('imageAssetId: $imageAssetId, ')
          ..write('goalIndex: $goalIndex, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipeIngredientsTable extends RecipeIngredients
    with TableInfo<$RecipeIngredientsTable, RecipeIngredientEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeIngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipeIdMeta =
      const VerificationMeta('recipeId');
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
      'recipe_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES recipes (id)'));
  static const VerificationMeta _ingredientNameMeta =
      const VerificationMeta('ingredientName');
  @override
  late final GeneratedColumn<String> ingredientName = GeneratedColumn<String>(
      'ingredient_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, recipeId, ingredientName, quantity, unit];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_ingredients';
  @override
  VerificationContext validateIntegrity(
      Insertable<RecipeIngredientEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recipe_id')) {
      context.handle(_recipeIdMeta,
          recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta));
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('ingredient_name')) {
      context.handle(
          _ingredientNameMeta,
          ingredientName.isAcceptableOrUnknown(
              data['ingredient_name']!, _ingredientNameMeta));
    } else if (isInserting) {
      context.missing(_ingredientNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecipeIngredientEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeIngredientEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      recipeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_id'])!,
      ingredientName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}ingredient_name'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
    );
  }

  @override
  $RecipeIngredientsTable createAlias(String alias) {
    return $RecipeIngredientsTable(attachedDatabase, alias);
  }
}

class RecipeIngredientEntry extends DataClass
    implements Insertable<RecipeIngredientEntry> {
  final String id;
  final String recipeId;
  final String ingredientName;
  final double quantity;
  final String unit;
  const RecipeIngredientEntry(
      {required this.id,
      required this.recipeId,
      required this.ingredientName,
      required this.quantity,
      required this.unit});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recipe_id'] = Variable<String>(recipeId);
    map['ingredient_name'] = Variable<String>(ingredientName);
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    return map;
  }

  RecipeIngredientsCompanion toCompanion(bool nullToAbsent) {
    return RecipeIngredientsCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      ingredientName: Value(ingredientName),
      quantity: Value(quantity),
      unit: Value(unit),
    );
  }

  factory RecipeIngredientEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeIngredientEntry(
      id: serializer.fromJson<String>(json['id']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      ingredientName: serializer.fromJson<String>(json['ingredientName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recipeId': serializer.toJson<String>(recipeId),
      'ingredientName': serializer.toJson<String>(ingredientName),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
    };
  }

  RecipeIngredientEntry copyWith(
          {String? id,
          String? recipeId,
          String? ingredientName,
          double? quantity,
          String? unit}) =>
      RecipeIngredientEntry(
        id: id ?? this.id,
        recipeId: recipeId ?? this.recipeId,
        ingredientName: ingredientName ?? this.ingredientName,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
      );
  RecipeIngredientEntry copyWithCompanion(RecipeIngredientsCompanion data) {
    return RecipeIngredientEntry(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      ingredientName: data.ingredientName.present
          ? data.ingredientName.value
          : this.ingredientName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeIngredientEntry(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('ingredientName: $ingredientName, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recipeId, ingredientName, quantity, unit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeIngredientEntry &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.ingredientName == this.ingredientName &&
          other.quantity == this.quantity &&
          other.unit == this.unit);
}

class RecipeIngredientsCompanion
    extends UpdateCompanion<RecipeIngredientEntry> {
  final Value<String> id;
  final Value<String> recipeId;
  final Value<String> ingredientName;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<int> rowid;
  const RecipeIngredientsCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.ingredientName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipeIngredientsCompanion.insert({
    required String id,
    required String recipeId,
    required String ingredientName,
    required double quantity,
    required String unit,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        recipeId = Value(recipeId),
        ingredientName = Value(ingredientName),
        quantity = Value(quantity),
        unit = Value(unit);
  static Insertable<RecipeIngredientEntry> custom({
    Expression<String>? id,
    Expression<String>? recipeId,
    Expression<String>? ingredientName,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (ingredientName != null) 'ingredient_name': ingredientName,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipeIngredientsCompanion copyWith(
      {Value<String>? id,
      Value<String>? recipeId,
      Value<String>? ingredientName,
      Value<double>? quantity,
      Value<String>? unit,
      Value<int>? rowid}) {
    return RecipeIngredientsCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      ingredientName: ingredientName ?? this.ingredientName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (ingredientName.present) {
      map['ingredient_name'] = Variable<String>(ingredientName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeIngredientsCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('ingredientName: $ingredientName, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppliancesTable extends Appliances
    with TableInfo<$AppliancesTable, ApplianceEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppliancesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imageAssetIdMeta =
      const VerificationMeta('imageAssetId');
  @override
  late final GeneratedColumn<String> imageAssetId = GeneratedColumn<String>(
      'image_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [id, name, type, imageAssetId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'appliances';
  @override
  VerificationContext validateIntegrity(Insertable<ApplianceEntry> instance,
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
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('image_asset_id')) {
      context.handle(
          _imageAssetIdMeta,
          imageAssetId.isAcceptableOrUnknown(
              data['image_asset_id']!, _imageAssetIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApplianceEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApplianceEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      imageAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_asset_id']),
    );
  }

  @override
  $AppliancesTable createAlias(String alias) {
    return $AppliancesTable(attachedDatabase, alias);
  }
}

class ApplianceEntry extends DataClass implements Insertable<ApplianceEntry> {
  final String id;
  final String name;
  final String type;
  final String? imageAssetId;
  const ApplianceEntry(
      {required this.id,
      required this.name,
      required this.type,
      this.imageAssetId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || imageAssetId != null) {
      map['image_asset_id'] = Variable<String>(imageAssetId);
    }
    return map;
  }

  AppliancesCompanion toCompanion(bool nullToAbsent) {
    return AppliancesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      imageAssetId: imageAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAssetId),
    );
  }

  factory ApplianceEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApplianceEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      imageAssetId: serializer.fromJson<String?>(json['imageAssetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'imageAssetId': serializer.toJson<String?>(imageAssetId),
    };
  }

  ApplianceEntry copyWith(
          {String? id,
          String? name,
          String? type,
          Value<String?> imageAssetId = const Value.absent()}) =>
      ApplianceEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        imageAssetId:
            imageAssetId.present ? imageAssetId.value : this.imageAssetId,
      );
  ApplianceEntry copyWithCompanion(AppliancesCompanion data) {
    return ApplianceEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      imageAssetId: data.imageAssetId.present
          ? data.imageAssetId.value
          : this.imageAssetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApplianceEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('imageAssetId: $imageAssetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, imageAssetId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApplianceEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.imageAssetId == this.imageAssetId);
}

class AppliancesCompanion extends UpdateCompanion<ApplianceEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> imageAssetId;
  final Value<int> rowid;
  const AppliancesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.imageAssetId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppliancesCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.imageAssetId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        type = Value(type);
  static Insertable<ApplianceEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? imageAssetId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (imageAssetId != null) 'image_asset_id': imageAssetId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppliancesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? type,
      Value<String?>? imageAssetId,
      Value<int>? rowid}) {
    return AppliancesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      imageAssetId: imageAssetId ?? this.imageAssetId,
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
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (imageAssetId.present) {
      map['image_asset_id'] = Variable<String>(imageAssetId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppliancesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('imageAssetId: $imageAssetId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ShoppingItemsTable extends ShoppingItems
    with TableInfo<$ShoppingItemsTable, ShoppingItemEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ShoppingItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _quantityMeta =
      const VerificationMeta('quantity');
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
      'quantity', aliasedName, false,
      type: DriftSqlType.double, requiredDuringInsert: true);
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
      'unit', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _boughtMeta = const VerificationMeta('bought');
  @override
  late final GeneratedColumn<bool> bought = GeneratedColumn<bool>(
      'bought', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("bought" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, quantity, unit, bought, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shopping_items';
  @override
  VerificationContext validateIntegrity(Insertable<ShoppingItemEntry> instance,
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
    if (data.containsKey('quantity')) {
      context.handle(_quantityMeta,
          quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta));
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
          _unitMeta, unit.isAcceptableOrUnknown(data['unit']!, _unitMeta));
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('bought')) {
      context.handle(_boughtMeta,
          bought.isAcceptableOrUnknown(data['bought']!, _boughtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShoppingItemEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShoppingItemEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      quantity: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}quantity'])!,
      unit: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}unit'])!,
      bought: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}bought'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ShoppingItemsTable createAlias(String alias) {
    return $ShoppingItemsTable(attachedDatabase, alias);
  }
}

class ShoppingItemEntry extends DataClass
    implements Insertable<ShoppingItemEntry> {
  final String id;
  final String name;
  final double quantity;
  final String unit;
  final bool bought;
  final DateTime createdAt;
  const ShoppingItemEntry(
      {required this.id,
      required this.name,
      required this.quantity,
      required this.unit,
      required this.bought,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    map['bought'] = Variable<bool>(bought);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ShoppingItemsCompanion toCompanion(bool nullToAbsent) {
    return ShoppingItemsCompanion(
      id: Value(id),
      name: Value(name),
      quantity: Value(quantity),
      unit: Value(unit),
      bought: Value(bought),
      createdAt: Value(createdAt),
    );
  }

  factory ShoppingItemEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShoppingItemEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
      bought: serializer.fromJson<bool>(json['bought']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
      'bought': serializer.toJson<bool>(bought),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ShoppingItemEntry copyWith(
          {String? id,
          String? name,
          double? quantity,
          String? unit,
          bool? bought,
          DateTime? createdAt}) =>
      ShoppingItemEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        bought: bought ?? this.bought,
        createdAt: createdAt ?? this.createdAt,
      );
  ShoppingItemEntry copyWithCompanion(ShoppingItemsCompanion data) {
    return ShoppingItemEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
      bought: data.bought.present ? data.bought.value : this.bought,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('bought: $bought, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, quantity, unit, bought, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShoppingItemEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit &&
          other.bought == this.bought &&
          other.createdAt == this.createdAt);
}

class ShoppingItemsCompanion extends UpdateCompanion<ShoppingItemEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<bool> bought;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ShoppingItemsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.bought = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ShoppingItemsCompanion.insert({
    required String id,
    required String name,
    required double quantity,
    required String unit,
    this.bought = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        quantity = Value(quantity),
        unit = Value(unit),
        createdAt = Value(createdAt);
  static Insertable<ShoppingItemEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<bool>? bought,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (bought != null) 'bought': bought,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ShoppingItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<double>? quantity,
      Value<String>? unit,
      Value<bool>? bought,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ShoppingItemsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      bought: bought ?? this.bought,
      createdAt: createdAt ?? this.createdAt,
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
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (bought.present) {
      map['bought'] = Variable<bool>(bought.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ShoppingItemsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('bought: $bought, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WardrobeGarmentsTable extends WardrobeGarments
    with TableInfo<$WardrobeGarmentsTable, WardrobeGarmentEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WardrobeGarmentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _typeIndexMeta =
      const VerificationMeta('typeIndex');
  @override
  late final GeneratedColumn<int> typeIndex = GeneratedColumn<int>(
      'type_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _primaryColorMeta =
      const VerificationMeta('primaryColor');
  @override
  late final GeneratedColumn<String> primaryColor = GeneratedColumn<String>(
      'primary_color', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _secondaryColorMeta =
      const VerificationMeta('secondaryColor');
  @override
  late final GeneratedColumn<String> secondaryColor = GeneratedColumn<String>(
      'secondary_color', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _styleIndexMeta =
      const VerificationMeta('styleIndex');
  @override
  late final GeneratedColumn<int> styleIndex = GeneratedColumn<int>(
      'style_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _materialMeta =
      const VerificationMeta('material');
  @override
  late final GeneratedColumn<String> material = GeneratedColumn<String>(
      'material', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<String> season = GeneratedColumn<String>(
      'season', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('all'));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isCleanMeta =
      const VerificationMeta('isClean');
  @override
  late final GeneratedColumn<bool> isClean = GeneratedColumn<bool>(
      'is_clean', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_clean" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _hasRemovableHoodMeta =
      const VerificationMeta('hasRemovableHood');
  @override
  late final GeneratedColumn<bool> hasRemovableHood = GeneratedColumn<bool>(
      'has_removable_hood', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("has_removable_hood" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
      'rating', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<String> size = GeneratedColumn<String>(
      'size', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
      'brand', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<double> price = GeneratedColumn<double>(
      'price', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _imageAssetIdMeta =
      const VerificationMeta('imageAssetId');
  @override
  late final GeneratedColumn<String> imageAssetId = GeneratedColumn<String>(
      'image_asset_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imageDetailsPathMeta =
      const VerificationMeta('imageDetailsPath');
  @override
  late final GeneratedColumn<String> imageDetailsPath = GeneratedColumn<String>(
      'image_details_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        typeIndex,
        primaryColor,
        secondaryColor,
        styleIndex,
        material,
        season,
        isFavorite,
        isClean,
        hasRemovableHood,
        rating,
        size,
        brand,
        price,
        imageAssetId,
        imageDetailsPath,
        addedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wardrobe_garments';
  @override
  VerificationContext validateIntegrity(
      Insertable<WardrobeGarmentEntry> instance,
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
    if (data.containsKey('type_index')) {
      context.handle(_typeIndexMeta,
          typeIndex.isAcceptableOrUnknown(data['type_index']!, _typeIndexMeta));
    } else if (isInserting) {
      context.missing(_typeIndexMeta);
    }
    if (data.containsKey('primary_color')) {
      context.handle(
          _primaryColorMeta,
          primaryColor.isAcceptableOrUnknown(
              data['primary_color']!, _primaryColorMeta));
    } else if (isInserting) {
      context.missing(_primaryColorMeta);
    }
    if (data.containsKey('secondary_color')) {
      context.handle(
          _secondaryColorMeta,
          secondaryColor.isAcceptableOrUnknown(
              data['secondary_color']!, _secondaryColorMeta));
    }
    if (data.containsKey('style_index')) {
      context.handle(
          _styleIndexMeta,
          styleIndex.isAcceptableOrUnknown(
              data['style_index']!, _styleIndexMeta));
    } else if (isInserting) {
      context.missing(_styleIndexMeta);
    }
    if (data.containsKey('material')) {
      context.handle(_materialMeta,
          material.isAcceptableOrUnknown(data['material']!, _materialMeta));
    }
    if (data.containsKey('season')) {
      context.handle(_seasonMeta,
          season.isAcceptableOrUnknown(data['season']!, _seasonMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('is_clean')) {
      context.handle(_isCleanMeta,
          isClean.isAcceptableOrUnknown(data['is_clean']!, _isCleanMeta));
    }
    if (data.containsKey('has_removable_hood')) {
      context.handle(
          _hasRemovableHoodMeta,
          hasRemovableHood.isAcceptableOrUnknown(
              data['has_removable_hood']!, _hasRemovableHoodMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta,
          rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('brand')) {
      context.handle(
          _brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    }
    if (data.containsKey('price')) {
      context.handle(
          _priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    }
    if (data.containsKey('image_asset_id')) {
      context.handle(
          _imageAssetIdMeta,
          imageAssetId.isAcceptableOrUnknown(
              data['image_asset_id']!, _imageAssetIdMeta));
    }
    if (data.containsKey('image_details_path')) {
      context.handle(
          _imageDetailsPathMeta,
          imageDetailsPath.isAcceptableOrUnknown(
              data['image_details_path']!, _imageDetailsPathMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WardrobeGarmentEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WardrobeGarmentEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      typeIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type_index'])!,
      primaryColor: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}primary_color'])!,
      secondaryColor: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}secondary_color'])!,
      styleIndex: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}style_index'])!,
      material: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}material'])!,
      season: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}season'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      isClean: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_clean'])!,
      hasRemovableHood: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}has_removable_hood'])!,
      rating: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rating'])!,
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}size']),
      brand: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}brand']),
      price: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}price']),
      imageAssetId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_asset_id']),
      imageDetailsPath: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}image_details_path']),
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $WardrobeGarmentsTable createAlias(String alias) {
    return $WardrobeGarmentsTable(attachedDatabase, alias);
  }
}

class WardrobeGarmentEntry extends DataClass
    implements Insertable<WardrobeGarmentEntry> {
  final String id;
  final String name;
  final int typeIndex;
  final String primaryColor;
  final String secondaryColor;
  final int styleIndex;
  final String material;
  final String season;
  final bool isFavorite;
  final bool isClean;
  final bool hasRemovableHood;
  final int rating;
  final String? size;
  final String? brand;
  final double? price;
  final String? imageAssetId;
  final String? imageDetailsPath;
  final DateTime addedAt;
  const WardrobeGarmentEntry(
      {required this.id,
      required this.name,
      required this.typeIndex,
      required this.primaryColor,
      required this.secondaryColor,
      required this.styleIndex,
      required this.material,
      required this.season,
      required this.isFavorite,
      required this.isClean,
      required this.hasRemovableHood,
      required this.rating,
      this.size,
      this.brand,
      this.price,
      this.imageAssetId,
      this.imageDetailsPath,
      required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type_index'] = Variable<int>(typeIndex);
    map['primary_color'] = Variable<String>(primaryColor);
    map['secondary_color'] = Variable<String>(secondaryColor);
    map['style_index'] = Variable<int>(styleIndex);
    map['material'] = Variable<String>(material);
    map['season'] = Variable<String>(season);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['is_clean'] = Variable<bool>(isClean);
    map['has_removable_hood'] = Variable<bool>(hasRemovableHood);
    map['rating'] = Variable<int>(rating);
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<String>(size);
    }
    if (!nullToAbsent || brand != null) {
      map['brand'] = Variable<String>(brand);
    }
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<double>(price);
    }
    if (!nullToAbsent || imageAssetId != null) {
      map['image_asset_id'] = Variable<String>(imageAssetId);
    }
    if (!nullToAbsent || imageDetailsPath != null) {
      map['image_details_path'] = Variable<String>(imageDetailsPath);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  WardrobeGarmentsCompanion toCompanion(bool nullToAbsent) {
    return WardrobeGarmentsCompanion(
      id: Value(id),
      name: Value(name),
      typeIndex: Value(typeIndex),
      primaryColor: Value(primaryColor),
      secondaryColor: Value(secondaryColor),
      styleIndex: Value(styleIndex),
      material: Value(material),
      season: Value(season),
      isFavorite: Value(isFavorite),
      isClean: Value(isClean),
      hasRemovableHood: Value(hasRemovableHood),
      rating: Value(rating),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      brand:
          brand == null && nullToAbsent ? const Value.absent() : Value(brand),
      price:
          price == null && nullToAbsent ? const Value.absent() : Value(price),
      imageAssetId: imageAssetId == null && nullToAbsent
          ? const Value.absent()
          : Value(imageAssetId),
      imageDetailsPath: imageDetailsPath == null && nullToAbsent
          ? const Value.absent()
          : Value(imageDetailsPath),
      addedAt: Value(addedAt),
    );
  }

  factory WardrobeGarmentEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WardrobeGarmentEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      typeIndex: serializer.fromJson<int>(json['typeIndex']),
      primaryColor: serializer.fromJson<String>(json['primaryColor']),
      secondaryColor: serializer.fromJson<String>(json['secondaryColor']),
      styleIndex: serializer.fromJson<int>(json['styleIndex']),
      material: serializer.fromJson<String>(json['material']),
      season: serializer.fromJson<String>(json['season']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      isClean: serializer.fromJson<bool>(json['isClean']),
      hasRemovableHood: serializer.fromJson<bool>(json['hasRemovableHood']),
      rating: serializer.fromJson<int>(json['rating']),
      size: serializer.fromJson<String?>(json['size']),
      brand: serializer.fromJson<String?>(json['brand']),
      price: serializer.fromJson<double?>(json['price']),
      imageAssetId: serializer.fromJson<String?>(json['imageAssetId']),
      imageDetailsPath: serializer.fromJson<String?>(json['imageDetailsPath']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'typeIndex': serializer.toJson<int>(typeIndex),
      'primaryColor': serializer.toJson<String>(primaryColor),
      'secondaryColor': serializer.toJson<String>(secondaryColor),
      'styleIndex': serializer.toJson<int>(styleIndex),
      'material': serializer.toJson<String>(material),
      'season': serializer.toJson<String>(season),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'isClean': serializer.toJson<bool>(isClean),
      'hasRemovableHood': serializer.toJson<bool>(hasRemovableHood),
      'rating': serializer.toJson<int>(rating),
      'size': serializer.toJson<String?>(size),
      'brand': serializer.toJson<String?>(brand),
      'price': serializer.toJson<double?>(price),
      'imageAssetId': serializer.toJson<String?>(imageAssetId),
      'imageDetailsPath': serializer.toJson<String?>(imageDetailsPath),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  WardrobeGarmentEntry copyWith(
          {String? id,
          String? name,
          int? typeIndex,
          String? primaryColor,
          String? secondaryColor,
          int? styleIndex,
          String? material,
          String? season,
          bool? isFavorite,
          bool? isClean,
          bool? hasRemovableHood,
          int? rating,
          Value<String?> size = const Value.absent(),
          Value<String?> brand = const Value.absent(),
          Value<double?> price = const Value.absent(),
          Value<String?> imageAssetId = const Value.absent(),
          Value<String?> imageDetailsPath = const Value.absent(),
          DateTime? addedAt}) =>
      WardrobeGarmentEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        typeIndex: typeIndex ?? this.typeIndex,
        primaryColor: primaryColor ?? this.primaryColor,
        secondaryColor: secondaryColor ?? this.secondaryColor,
        styleIndex: styleIndex ?? this.styleIndex,
        material: material ?? this.material,
        season: season ?? this.season,
        isFavorite: isFavorite ?? this.isFavorite,
        isClean: isClean ?? this.isClean,
        hasRemovableHood: hasRemovableHood ?? this.hasRemovableHood,
        rating: rating ?? this.rating,
        size: size.present ? size.value : this.size,
        brand: brand.present ? brand.value : this.brand,
        price: price.present ? price.value : this.price,
        imageAssetId:
            imageAssetId.present ? imageAssetId.value : this.imageAssetId,
        imageDetailsPath: imageDetailsPath.present
            ? imageDetailsPath.value
            : this.imageDetailsPath,
        addedAt: addedAt ?? this.addedAt,
      );
  WardrobeGarmentEntry copyWithCompanion(WardrobeGarmentsCompanion data) {
    return WardrobeGarmentEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      typeIndex: data.typeIndex.present ? data.typeIndex.value : this.typeIndex,
      primaryColor: data.primaryColor.present
          ? data.primaryColor.value
          : this.primaryColor,
      secondaryColor: data.secondaryColor.present
          ? data.secondaryColor.value
          : this.secondaryColor,
      styleIndex:
          data.styleIndex.present ? data.styleIndex.value : this.styleIndex,
      material: data.material.present ? data.material.value : this.material,
      season: data.season.present ? data.season.value : this.season,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      isClean: data.isClean.present ? data.isClean.value : this.isClean,
      hasRemovableHood: data.hasRemovableHood.present
          ? data.hasRemovableHood.value
          : this.hasRemovableHood,
      rating: data.rating.present ? data.rating.value : this.rating,
      size: data.size.present ? data.size.value : this.size,
      brand: data.brand.present ? data.brand.value : this.brand,
      price: data.price.present ? data.price.value : this.price,
      imageAssetId: data.imageAssetId.present
          ? data.imageAssetId.value
          : this.imageAssetId,
      imageDetailsPath: data.imageDetailsPath.present
          ? data.imageDetailsPath.value
          : this.imageDetailsPath,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WardrobeGarmentEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('typeIndex: $typeIndex, ')
          ..write('primaryColor: $primaryColor, ')
          ..write('secondaryColor: $secondaryColor, ')
          ..write('styleIndex: $styleIndex, ')
          ..write('material: $material, ')
          ..write('season: $season, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isClean: $isClean, ')
          ..write('hasRemovableHood: $hasRemovableHood, ')
          ..write('rating: $rating, ')
          ..write('size: $size, ')
          ..write('brand: $brand, ')
          ..write('price: $price, ')
          ..write('imageAssetId: $imageAssetId, ')
          ..write('imageDetailsPath: $imageDetailsPath, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      typeIndex,
      primaryColor,
      secondaryColor,
      styleIndex,
      material,
      season,
      isFavorite,
      isClean,
      hasRemovableHood,
      rating,
      size,
      brand,
      price,
      imageAssetId,
      imageDetailsPath,
      addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WardrobeGarmentEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.typeIndex == this.typeIndex &&
          other.primaryColor == this.primaryColor &&
          other.secondaryColor == this.secondaryColor &&
          other.styleIndex == this.styleIndex &&
          other.material == this.material &&
          other.season == this.season &&
          other.isFavorite == this.isFavorite &&
          other.isClean == this.isClean &&
          other.hasRemovableHood == this.hasRemovableHood &&
          other.rating == this.rating &&
          other.size == this.size &&
          other.brand == this.brand &&
          other.price == this.price &&
          other.imageAssetId == this.imageAssetId &&
          other.imageDetailsPath == this.imageDetailsPath &&
          other.addedAt == this.addedAt);
}

class WardrobeGarmentsCompanion extends UpdateCompanion<WardrobeGarmentEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> typeIndex;
  final Value<String> primaryColor;
  final Value<String> secondaryColor;
  final Value<int> styleIndex;
  final Value<String> material;
  final Value<String> season;
  final Value<bool> isFavorite;
  final Value<bool> isClean;
  final Value<bool> hasRemovableHood;
  final Value<int> rating;
  final Value<String?> size;
  final Value<String?> brand;
  final Value<double?> price;
  final Value<String?> imageAssetId;
  final Value<String?> imageDetailsPath;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const WardrobeGarmentsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.typeIndex = const Value.absent(),
    this.primaryColor = const Value.absent(),
    this.secondaryColor = const Value.absent(),
    this.styleIndex = const Value.absent(),
    this.material = const Value.absent(),
    this.season = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isClean = const Value.absent(),
    this.hasRemovableHood = const Value.absent(),
    this.rating = const Value.absent(),
    this.size = const Value.absent(),
    this.brand = const Value.absent(),
    this.price = const Value.absent(),
    this.imageAssetId = const Value.absent(),
    this.imageDetailsPath = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WardrobeGarmentsCompanion.insert({
    required String id,
    required String name,
    required int typeIndex,
    required String primaryColor,
    this.secondaryColor = const Value.absent(),
    required int styleIndex,
    this.material = const Value.absent(),
    this.season = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.isClean = const Value.absent(),
    this.hasRemovableHood = const Value.absent(),
    this.rating = const Value.absent(),
    this.size = const Value.absent(),
    this.brand = const Value.absent(),
    this.price = const Value.absent(),
    this.imageAssetId = const Value.absent(),
    this.imageDetailsPath = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        typeIndex = Value(typeIndex),
        primaryColor = Value(primaryColor),
        styleIndex = Value(styleIndex),
        addedAt = Value(addedAt);
  static Insertable<WardrobeGarmentEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? typeIndex,
    Expression<String>? primaryColor,
    Expression<String>? secondaryColor,
    Expression<int>? styleIndex,
    Expression<String>? material,
    Expression<String>? season,
    Expression<bool>? isFavorite,
    Expression<bool>? isClean,
    Expression<bool>? hasRemovableHood,
    Expression<int>? rating,
    Expression<String>? size,
    Expression<String>? brand,
    Expression<double>? price,
    Expression<String>? imageAssetId,
    Expression<String>? imageDetailsPath,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (typeIndex != null) 'type_index': typeIndex,
      if (primaryColor != null) 'primary_color': primaryColor,
      if (secondaryColor != null) 'secondary_color': secondaryColor,
      if (styleIndex != null) 'style_index': styleIndex,
      if (material != null) 'material': material,
      if (season != null) 'season': season,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (isClean != null) 'is_clean': isClean,
      if (hasRemovableHood != null) 'has_removable_hood': hasRemovableHood,
      if (rating != null) 'rating': rating,
      if (size != null) 'size': size,
      if (brand != null) 'brand': brand,
      if (price != null) 'price': price,
      if (imageAssetId != null) 'image_asset_id': imageAssetId,
      if (imageDetailsPath != null) 'image_details_path': imageDetailsPath,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WardrobeGarmentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<int>? typeIndex,
      Value<String>? primaryColor,
      Value<String>? secondaryColor,
      Value<int>? styleIndex,
      Value<String>? material,
      Value<String>? season,
      Value<bool>? isFavorite,
      Value<bool>? isClean,
      Value<bool>? hasRemovableHood,
      Value<int>? rating,
      Value<String?>? size,
      Value<String?>? brand,
      Value<double?>? price,
      Value<String?>? imageAssetId,
      Value<String?>? imageDetailsPath,
      Value<DateTime>? addedAt,
      Value<int>? rowid}) {
    return WardrobeGarmentsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      typeIndex: typeIndex ?? this.typeIndex,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      styleIndex: styleIndex ?? this.styleIndex,
      material: material ?? this.material,
      season: season ?? this.season,
      isFavorite: isFavorite ?? this.isFavorite,
      isClean: isClean ?? this.isClean,
      hasRemovableHood: hasRemovableHood ?? this.hasRemovableHood,
      rating: rating ?? this.rating,
      size: size ?? this.size,
      brand: brand ?? this.brand,
      price: price ?? this.price,
      imageAssetId: imageAssetId ?? this.imageAssetId,
      imageDetailsPath: imageDetailsPath ?? this.imageDetailsPath,
      addedAt: addedAt ?? this.addedAt,
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
    if (typeIndex.present) {
      map['type_index'] = Variable<int>(typeIndex.value);
    }
    if (primaryColor.present) {
      map['primary_color'] = Variable<String>(primaryColor.value);
    }
    if (secondaryColor.present) {
      map['secondary_color'] = Variable<String>(secondaryColor.value);
    }
    if (styleIndex.present) {
      map['style_index'] = Variable<int>(styleIndex.value);
    }
    if (material.present) {
      map['material'] = Variable<String>(material.value);
    }
    if (season.present) {
      map['season'] = Variable<String>(season.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (isClean.present) {
      map['is_clean'] = Variable<bool>(isClean.value);
    }
    if (hasRemovableHood.present) {
      map['has_removable_hood'] = Variable<bool>(hasRemovableHood.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (size.present) {
      map['size'] = Variable<String>(size.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (price.present) {
      map['price'] = Variable<double>(price.value);
    }
    if (imageAssetId.present) {
      map['image_asset_id'] = Variable<String>(imageAssetId.value);
    }
    if (imageDetailsPath.present) {
      map['image_details_path'] = Variable<String>(imageDetailsPath.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WardrobeGarmentsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('typeIndex: $typeIndex, ')
          ..write('primaryColor: $primaryColor, ')
          ..write('secondaryColor: $secondaryColor, ')
          ..write('styleIndex: $styleIndex, ')
          ..write('material: $material, ')
          ..write('season: $season, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('isClean: $isClean, ')
          ..write('hasRemovableHood: $hasRemovableHood, ')
          ..write('rating: $rating, ')
          ..write('size: $size, ')
          ..write('brand: $brand, ')
          ..write('price: $price, ')
          ..write('imageAssetId: $imageAssetId, ')
          ..write('imageDetailsPath: $imageDetailsPath, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutfitsTable extends Outfits with TableInfo<$OutfitsTable, OutfitEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutfitsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _garmentIdsCsvMeta =
      const VerificationMeta('garmentIdsCsv');
  @override
  late final GeneratedColumn<String> garmentIdsCsv = GeneratedColumn<String>(
      'garment_ids_csv', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _occasionMeta =
      const VerificationMeta('occasion');
  @override
  late final GeneratedColumn<String> occasion = GeneratedColumn<String>(
      'occasion', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('casual'));
  static const VerificationMeta _seasonMeta = const VerificationMeta('season');
  @override
  late final GeneratedColumn<String> season = GeneratedColumn<String>(
      'season', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('all'));
  static const VerificationMeta _timesWornMeta =
      const VerificationMeta('timesWorn');
  @override
  late final GeneratedColumn<int> timesWorn = GeneratedColumn<int>(
      'times_worn', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, garmentIdsCsv, occasion, season, timesWorn, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outfits';
  @override
  VerificationContext validateIntegrity(Insertable<OutfitEntry> instance,
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
    if (data.containsKey('garment_ids_csv')) {
      context.handle(
          _garmentIdsCsvMeta,
          garmentIdsCsv.isAcceptableOrUnknown(
              data['garment_ids_csv']!, _garmentIdsCsvMeta));
    } else if (isInserting) {
      context.missing(_garmentIdsCsvMeta);
    }
    if (data.containsKey('occasion')) {
      context.handle(_occasionMeta,
          occasion.isAcceptableOrUnknown(data['occasion']!, _occasionMeta));
    }
    if (data.containsKey('season')) {
      context.handle(_seasonMeta,
          season.isAcceptableOrUnknown(data['season']!, _seasonMeta));
    }
    if (data.containsKey('times_worn')) {
      context.handle(_timesWornMeta,
          timesWorn.isAcceptableOrUnknown(data['times_worn']!, _timesWornMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutfitEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutfitEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      garmentIdsCsv: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}garment_ids_csv'])!,
      occasion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}occasion'])!,
      season: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}season'])!,
      timesWorn: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}times_worn'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $OutfitsTable createAlias(String alias) {
    return $OutfitsTable(attachedDatabase, alias);
  }
}

class OutfitEntry extends DataClass implements Insertable<OutfitEntry> {
  final String id;
  final String name;
  final String garmentIdsCsv;
  final String occasion;
  final String season;
  final int timesWorn;
  final DateTime createdAt;
  const OutfitEntry(
      {required this.id,
      required this.name,
      required this.garmentIdsCsv,
      required this.occasion,
      required this.season,
      required this.timesWorn,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['garment_ids_csv'] = Variable<String>(garmentIdsCsv);
    map['occasion'] = Variable<String>(occasion);
    map['season'] = Variable<String>(season);
    map['times_worn'] = Variable<int>(timesWorn);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutfitsCompanion toCompanion(bool nullToAbsent) {
    return OutfitsCompanion(
      id: Value(id),
      name: Value(name),
      garmentIdsCsv: Value(garmentIdsCsv),
      occasion: Value(occasion),
      season: Value(season),
      timesWorn: Value(timesWorn),
      createdAt: Value(createdAt),
    );
  }

  factory OutfitEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutfitEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      garmentIdsCsv: serializer.fromJson<String>(json['garmentIdsCsv']),
      occasion: serializer.fromJson<String>(json['occasion']),
      season: serializer.fromJson<String>(json['season']),
      timesWorn: serializer.fromJson<int>(json['timesWorn']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'garmentIdsCsv': serializer.toJson<String>(garmentIdsCsv),
      'occasion': serializer.toJson<String>(occasion),
      'season': serializer.toJson<String>(season),
      'timesWorn': serializer.toJson<int>(timesWorn),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutfitEntry copyWith(
          {String? id,
          String? name,
          String? garmentIdsCsv,
          String? occasion,
          String? season,
          int? timesWorn,
          DateTime? createdAt}) =>
      OutfitEntry(
        id: id ?? this.id,
        name: name ?? this.name,
        garmentIdsCsv: garmentIdsCsv ?? this.garmentIdsCsv,
        occasion: occasion ?? this.occasion,
        season: season ?? this.season,
        timesWorn: timesWorn ?? this.timesWorn,
        createdAt: createdAt ?? this.createdAt,
      );
  OutfitEntry copyWithCompanion(OutfitsCompanion data) {
    return OutfitEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      garmentIdsCsv: data.garmentIdsCsv.present
          ? data.garmentIdsCsv.value
          : this.garmentIdsCsv,
      occasion: data.occasion.present ? data.occasion.value : this.occasion,
      season: data.season.present ? data.season.value : this.season,
      timesWorn: data.timesWorn.present ? data.timesWorn.value : this.timesWorn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutfitEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('garmentIdsCsv: $garmentIdsCsv, ')
          ..write('occasion: $occasion, ')
          ..write('season: $season, ')
          ..write('timesWorn: $timesWorn, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, name, garmentIdsCsv, occasion, season, timesWorn, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutfitEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.garmentIdsCsv == this.garmentIdsCsv &&
          other.occasion == this.occasion &&
          other.season == this.season &&
          other.timesWorn == this.timesWorn &&
          other.createdAt == this.createdAt);
}

class OutfitsCompanion extends UpdateCompanion<OutfitEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> garmentIdsCsv;
  final Value<String> occasion;
  final Value<String> season;
  final Value<int> timesWorn;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutfitsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.garmentIdsCsv = const Value.absent(),
    this.occasion = const Value.absent(),
    this.season = const Value.absent(),
    this.timesWorn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutfitsCompanion.insert({
    required String id,
    required String name,
    required String garmentIdsCsv,
    this.occasion = const Value.absent(),
    this.season = const Value.absent(),
    this.timesWorn = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        garmentIdsCsv = Value(garmentIdsCsv),
        createdAt = Value(createdAt);
  static Insertable<OutfitEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? garmentIdsCsv,
    Expression<String>? occasion,
    Expression<String>? season,
    Expression<int>? timesWorn,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (garmentIdsCsv != null) 'garment_ids_csv': garmentIdsCsv,
      if (occasion != null) 'occasion': occasion,
      if (season != null) 'season': season,
      if (timesWorn != null) 'times_worn': timesWorn,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutfitsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? garmentIdsCsv,
      Value<String>? occasion,
      Value<String>? season,
      Value<int>? timesWorn,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return OutfitsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      garmentIdsCsv: garmentIdsCsv ?? this.garmentIdsCsv,
      occasion: occasion ?? this.occasion,
      season: season ?? this.season,
      timesWorn: timesWorn ?? this.timesWorn,
      createdAt: createdAt ?? this.createdAt,
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
    if (garmentIdsCsv.present) {
      map['garment_ids_csv'] = Variable<String>(garmentIdsCsv.value);
    }
    if (occasion.present) {
      map['occasion'] = Variable<String>(occasion.value);
    }
    if (season.present) {
      map['season'] = Variable<String>(season.value);
    }
    if (timesWorn.present) {
      map['times_worn'] = Variable<int>(timesWorn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutfitsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('garmentIdsCsv: $garmentIdsCsv, ')
          ..write('occasion: $occasion, ')
          ..write('season: $season, ')
          ..write('timesWorn: $timesWorn, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfileTable extends UserProfile
    with TableInfo<$UserProfileTable, UserProfileEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skinToneMeta =
      const VerificationMeta('skinTone');
  @override
  late final GeneratedColumn<String> skinTone = GeneratedColumn<String>(
      'skin_tone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bodyTypeMeta =
      const VerificationMeta('bodyType');
  @override
  late final GeneratedColumn<String> bodyType = GeneratedColumn<String>(
      'body_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<String> height = GeneratedColumn<String>(
      'height', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<String> weight = GeneratedColumn<String>(
      'weight', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _hairTypeMeta =
      const VerificationMeta('hairType');
  @override
  late final GeneratedColumn<String> hairType = GeneratedColumn<String>(
      'hair_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorimetryMeta =
      const VerificationMeta('colorimetry');
  @override
  late final GeneratedColumn<String> colorimetry = GeneratedColumn<String>(
      'colorimetry', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _bodyShapeMeta =
      const VerificationMeta('bodyShape');
  @override
  late final GeneratedColumn<String> bodyShape = GeneratedColumn<String>(
      'body_shape', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _consentGrantedMeta =
      const VerificationMeta('consentGranted');
  @override
  late final GeneratedColumn<bool> consentGranted = GeneratedColumn<bool>(
      'consent_granted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("consent_granted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        skinTone,
        bodyType,
        height,
        weight,
        hairType,
        colorimetry,
        bodyShape,
        consentGranted,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(Insertable<UserProfileEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('skin_tone')) {
      context.handle(_skinToneMeta,
          skinTone.isAcceptableOrUnknown(data['skin_tone']!, _skinToneMeta));
    }
    if (data.containsKey('body_type')) {
      context.handle(_bodyTypeMeta,
          bodyType.isAcceptableOrUnknown(data['body_type']!, _bodyTypeMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    }
    if (data.containsKey('weight')) {
      context.handle(_weightMeta,
          weight.isAcceptableOrUnknown(data['weight']!, _weightMeta));
    }
    if (data.containsKey('hair_type')) {
      context.handle(_hairTypeMeta,
          hairType.isAcceptableOrUnknown(data['hair_type']!, _hairTypeMeta));
    }
    if (data.containsKey('colorimetry')) {
      context.handle(
          _colorimetryMeta,
          colorimetry.isAcceptableOrUnknown(
              data['colorimetry']!, _colorimetryMeta));
    }
    if (data.containsKey('body_shape')) {
      context.handle(_bodyShapeMeta,
          bodyShape.isAcceptableOrUnknown(data['body_shape']!, _bodyShapeMeta));
    }
    if (data.containsKey('consent_granted')) {
      context.handle(
          _consentGrantedMeta,
          consentGranted.isAcceptableOrUnknown(
              data['consent_granted']!, _consentGrantedMeta));
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
  UserProfileEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      skinTone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skin_tone']),
      bodyType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body_type']),
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}height']),
      weight: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}weight']),
      hairType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hair_type']),
      colorimetry: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}colorimetry']),
      bodyShape: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body_shape']),
      consentGranted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}consent_granted'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $UserProfileTable createAlias(String alias) {
    return $UserProfileTable(attachedDatabase, alias);
  }
}

class UserProfileEntry extends DataClass
    implements Insertable<UserProfileEntry> {
  final String id;
  final String? skinTone;
  final String? bodyType;
  final String? height;
  final String? weight;
  final String? hairType;
  final String? colorimetry;
  final String? bodyShape;
  final bool consentGranted;
  final DateTime updatedAt;
  const UserProfileEntry(
      {required this.id,
      this.skinTone,
      this.bodyType,
      this.height,
      this.weight,
      this.hairType,
      this.colorimetry,
      this.bodyShape,
      required this.consentGranted,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || skinTone != null) {
      map['skin_tone'] = Variable<String>(skinTone);
    }
    if (!nullToAbsent || bodyType != null) {
      map['body_type'] = Variable<String>(bodyType);
    }
    if (!nullToAbsent || height != null) {
      map['height'] = Variable<String>(height);
    }
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<String>(weight);
    }
    if (!nullToAbsent || hairType != null) {
      map['hair_type'] = Variable<String>(hairType);
    }
    if (!nullToAbsent || colorimetry != null) {
      map['colorimetry'] = Variable<String>(colorimetry);
    }
    if (!nullToAbsent || bodyShape != null) {
      map['body_shape'] = Variable<String>(bodyShape);
    }
    map['consent_granted'] = Variable<bool>(consentGranted);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfileCompanion toCompanion(bool nullToAbsent) {
    return UserProfileCompanion(
      id: Value(id),
      skinTone: skinTone == null && nullToAbsent
          ? const Value.absent()
          : Value(skinTone),
      bodyType: bodyType == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyType),
      height:
          height == null && nullToAbsent ? const Value.absent() : Value(height),
      weight:
          weight == null && nullToAbsent ? const Value.absent() : Value(weight),
      hairType: hairType == null && nullToAbsent
          ? const Value.absent()
          : Value(hairType),
      colorimetry: colorimetry == null && nullToAbsent
          ? const Value.absent()
          : Value(colorimetry),
      bodyShape: bodyShape == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyShape),
      consentGranted: Value(consentGranted),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfileEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileEntry(
      id: serializer.fromJson<String>(json['id']),
      skinTone: serializer.fromJson<String?>(json['skinTone']),
      bodyType: serializer.fromJson<String?>(json['bodyType']),
      height: serializer.fromJson<String?>(json['height']),
      weight: serializer.fromJson<String?>(json['weight']),
      hairType: serializer.fromJson<String?>(json['hairType']),
      colorimetry: serializer.fromJson<String?>(json['colorimetry']),
      bodyShape: serializer.fromJson<String?>(json['bodyShape']),
      consentGranted: serializer.fromJson<bool>(json['consentGranted']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'skinTone': serializer.toJson<String?>(skinTone),
      'bodyType': serializer.toJson<String?>(bodyType),
      'height': serializer.toJson<String?>(height),
      'weight': serializer.toJson<String?>(weight),
      'hairType': serializer.toJson<String?>(hairType),
      'colorimetry': serializer.toJson<String?>(colorimetry),
      'bodyShape': serializer.toJson<String?>(bodyShape),
      'consentGranted': serializer.toJson<bool>(consentGranted),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProfileEntry copyWith(
          {String? id,
          Value<String?> skinTone = const Value.absent(),
          Value<String?> bodyType = const Value.absent(),
          Value<String?> height = const Value.absent(),
          Value<String?> weight = const Value.absent(),
          Value<String?> hairType = const Value.absent(),
          Value<String?> colorimetry = const Value.absent(),
          Value<String?> bodyShape = const Value.absent(),
          bool? consentGranted,
          DateTime? updatedAt}) =>
      UserProfileEntry(
        id: id ?? this.id,
        skinTone: skinTone.present ? skinTone.value : this.skinTone,
        bodyType: bodyType.present ? bodyType.value : this.bodyType,
        height: height.present ? height.value : this.height,
        weight: weight.present ? weight.value : this.weight,
        hairType: hairType.present ? hairType.value : this.hairType,
        colorimetry: colorimetry.present ? colorimetry.value : this.colorimetry,
        bodyShape: bodyShape.present ? bodyShape.value : this.bodyShape,
        consentGranted: consentGranted ?? this.consentGranted,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  UserProfileEntry copyWithCompanion(UserProfileCompanion data) {
    return UserProfileEntry(
      id: data.id.present ? data.id.value : this.id,
      skinTone: data.skinTone.present ? data.skinTone.value : this.skinTone,
      bodyType: data.bodyType.present ? data.bodyType.value : this.bodyType,
      height: data.height.present ? data.height.value : this.height,
      weight: data.weight.present ? data.weight.value : this.weight,
      hairType: data.hairType.present ? data.hairType.value : this.hairType,
      colorimetry:
          data.colorimetry.present ? data.colorimetry.value : this.colorimetry,
      bodyShape: data.bodyShape.present ? data.bodyShape.value : this.bodyShape,
      consentGranted: data.consentGranted.present
          ? data.consentGranted.value
          : this.consentGranted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileEntry(')
          ..write('id: $id, ')
          ..write('skinTone: $skinTone, ')
          ..write('bodyType: $bodyType, ')
          ..write('height: $height, ')
          ..write('weight: $weight, ')
          ..write('hairType: $hairType, ')
          ..write('colorimetry: $colorimetry, ')
          ..write('bodyShape: $bodyShape, ')
          ..write('consentGranted: $consentGranted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, skinTone, bodyType, height, weight,
      hairType, colorimetry, bodyShape, consentGranted, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileEntry &&
          other.id == this.id &&
          other.skinTone == this.skinTone &&
          other.bodyType == this.bodyType &&
          other.height == this.height &&
          other.weight == this.weight &&
          other.hairType == this.hairType &&
          other.colorimetry == this.colorimetry &&
          other.bodyShape == this.bodyShape &&
          other.consentGranted == this.consentGranted &&
          other.updatedAt == this.updatedAt);
}

class UserProfileCompanion extends UpdateCompanion<UserProfileEntry> {
  final Value<String> id;
  final Value<String?> skinTone;
  final Value<String?> bodyType;
  final Value<String?> height;
  final Value<String?> weight;
  final Value<String?> hairType;
  final Value<String?> colorimetry;
  final Value<String?> bodyShape;
  final Value<bool> consentGranted;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserProfileCompanion({
    this.id = const Value.absent(),
    this.skinTone = const Value.absent(),
    this.bodyType = const Value.absent(),
    this.height = const Value.absent(),
    this.weight = const Value.absent(),
    this.hairType = const Value.absent(),
    this.colorimetry = const Value.absent(),
    this.bodyShape = const Value.absent(),
    this.consentGranted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfileCompanion.insert({
    required String id,
    this.skinTone = const Value.absent(),
    this.bodyType = const Value.absent(),
    this.height = const Value.absent(),
    this.weight = const Value.absent(),
    this.hairType = const Value.absent(),
    this.colorimetry = const Value.absent(),
    this.bodyShape = const Value.absent(),
    this.consentGranted = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        updatedAt = Value(updatedAt);
  static Insertable<UserProfileEntry> custom({
    Expression<String>? id,
    Expression<String>? skinTone,
    Expression<String>? bodyType,
    Expression<String>? height,
    Expression<String>? weight,
    Expression<String>? hairType,
    Expression<String>? colorimetry,
    Expression<String>? bodyShape,
    Expression<bool>? consentGranted,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (skinTone != null) 'skin_tone': skinTone,
      if (bodyType != null) 'body_type': bodyType,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
      if (hairType != null) 'hair_type': hairType,
      if (colorimetry != null) 'colorimetry': colorimetry,
      if (bodyShape != null) 'body_shape': bodyShape,
      if (consentGranted != null) 'consent_granted': consentGranted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfileCompanion copyWith(
      {Value<String>? id,
      Value<String?>? skinTone,
      Value<String?>? bodyType,
      Value<String?>? height,
      Value<String?>? weight,
      Value<String?>? hairType,
      Value<String?>? colorimetry,
      Value<String?>? bodyShape,
      Value<bool>? consentGranted,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return UserProfileCompanion(
      id: id ?? this.id,
      skinTone: skinTone ?? this.skinTone,
      bodyType: bodyType ?? this.bodyType,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      hairType: hairType ?? this.hairType,
      colorimetry: colorimetry ?? this.colorimetry,
      bodyShape: bodyShape ?? this.bodyShape,
      consentGranted: consentGranted ?? this.consentGranted,
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
    if (skinTone.present) {
      map['skin_tone'] = Variable<String>(skinTone.value);
    }
    if (bodyType.present) {
      map['body_type'] = Variable<String>(bodyType.value);
    }
    if (height.present) {
      map['height'] = Variable<String>(height.value);
    }
    if (weight.present) {
      map['weight'] = Variable<String>(weight.value);
    }
    if (hairType.present) {
      map['hair_type'] = Variable<String>(hairType.value);
    }
    if (colorimetry.present) {
      map['colorimetry'] = Variable<String>(colorimetry.value);
    }
    if (bodyShape.present) {
      map['body_shape'] = Variable<String>(bodyShape.value);
    }
    if (consentGranted.present) {
      map['consent_granted'] = Variable<bool>(consentGranted.value);
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
    return (StringBuffer('UserProfileCompanion(')
          ..write('id: $id, ')
          ..write('skinTone: $skinTone, ')
          ..write('bodyType: $bodyType, ')
          ..write('height: $height, ')
          ..write('weight: $weight, ')
          ..write('hairType: $hairType, ')
          ..write('colorimetry: $colorimetry, ')
          ..write('bodyShape: $bodyShape, ')
          ..write('consentGranted: $consentGranted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MealLogsTable mealLogs = $MealLogsTable(this);
  late final $InventoryIngredientsTable inventoryIngredients =
      $InventoryIngredientsTable(this);
  late final $RecipesTable recipes = $RecipesTable(this);
  late final $RecipeIngredientsTable recipeIngredients =
      $RecipeIngredientsTable(this);
  late final $AppliancesTable appliances = $AppliancesTable(this);
  late final $ShoppingItemsTable shoppingItems = $ShoppingItemsTable(this);
  late final $WardrobeGarmentsTable wardrobeGarments =
      $WardrobeGarmentsTable(this);
  late final $OutfitsTable outfits = $OutfitsTable(this);
  late final $UserProfileTable userProfile = $UserProfileTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        mealLogs,
        inventoryIngredients,
        recipes,
        recipeIngredients,
        appliances,
        shoppingItems,
        wardrobeGarments,
        outfits,
        userProfile
      ];
}

typedef $$MealLogsTableCreateCompanionBuilder = MealLogsCompanion Function({
  required String id,
  required DateTime timestamp,
  required String photoPath,
  required int classificationIndex,
  required String feedback,
  Value<String> detectedIngredientsCsv,
  Value<int> rowid,
});
typedef $$MealLogsTableUpdateCompanionBuilder = MealLogsCompanion Function({
  Value<String> id,
  Value<DateTime> timestamp,
  Value<String> photoPath,
  Value<int> classificationIndex,
  Value<String> feedback,
  Value<String> detectedIngredientsCsv,
  Value<int> rowid,
});

class $$MealLogsTableFilterComposer
    extends Composer<_$AppDatabase, $MealLogsTable> {
  $$MealLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get photoPath => $composableBuilder(
      column: $table.photoPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get classificationIndex => $composableBuilder(
      column: $table.classificationIndex,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get feedback => $composableBuilder(
      column: $table.feedback, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get detectedIngredientsCsv => $composableBuilder(
      column: $table.detectedIngredientsCsv,
      builder: (column) => ColumnFilters(column));
}

class $$MealLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealLogsTable> {
  $$MealLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get photoPath => $composableBuilder(
      column: $table.photoPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get classificationIndex => $composableBuilder(
      column: $table.classificationIndex,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get feedback => $composableBuilder(
      column: $table.feedback, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get detectedIngredientsCsv => $composableBuilder(
      column: $table.detectedIngredientsCsv,
      builder: (column) => ColumnOrderings(column));
}

class $$MealLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealLogsTable> {
  $$MealLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<int> get classificationIndex => $composableBuilder(
      column: $table.classificationIndex, builder: (column) => column);

  GeneratedColumn<String> get feedback =>
      $composableBuilder(column: $table.feedback, builder: (column) => column);

  GeneratedColumn<String> get detectedIngredientsCsv => $composableBuilder(
      column: $table.detectedIngredientsCsv, builder: (column) => column);
}

class $$MealLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MealLogsTable,
    MealLogEntry,
    $$MealLogsTableFilterComposer,
    $$MealLogsTableOrderingComposer,
    $$MealLogsTableAnnotationComposer,
    $$MealLogsTableCreateCompanionBuilder,
    $$MealLogsTableUpdateCompanionBuilder,
    (MealLogEntry, BaseReferences<_$AppDatabase, $MealLogsTable, MealLogEntry>),
    MealLogEntry,
    PrefetchHooks Function()> {
  $$MealLogsTableTableManager(_$AppDatabase db, $MealLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<String> photoPath = const Value.absent(),
            Value<int> classificationIndex = const Value.absent(),
            Value<String> feedback = const Value.absent(),
            Value<String> detectedIngredientsCsv = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MealLogsCompanion(
            id: id,
            timestamp: timestamp,
            photoPath: photoPath,
            classificationIndex: classificationIndex,
            feedback: feedback,
            detectedIngredientsCsv: detectedIngredientsCsv,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required DateTime timestamp,
            required String photoPath,
            required int classificationIndex,
            required String feedback,
            Value<String> detectedIngredientsCsv = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MealLogsCompanion.insert(
            id: id,
            timestamp: timestamp,
            photoPath: photoPath,
            classificationIndex: classificationIndex,
            feedback: feedback,
            detectedIngredientsCsv: detectedIngredientsCsv,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MealLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MealLogsTable,
    MealLogEntry,
    $$MealLogsTableFilterComposer,
    $$MealLogsTableOrderingComposer,
    $$MealLogsTableAnnotationComposer,
    $$MealLogsTableCreateCompanionBuilder,
    $$MealLogsTableUpdateCompanionBuilder,
    (MealLogEntry, BaseReferences<_$AppDatabase, $MealLogsTable, MealLogEntry>),
    MealLogEntry,
    PrefetchHooks Function()>;
typedef $$InventoryIngredientsTableCreateCompanionBuilder
    = InventoryIngredientsCompanion Function({
  required String id,
  required String name,
  Value<String> primaryCategory,
  Value<String?> subCategory,
  Value<String> preparation,
  required double quantity,
  required String unit,
  Value<DateTime?> expirationDate,
  Value<String?> imageAssetId,
  Value<String?> storageArea,
  Value<int> rowid,
});
typedef $$InventoryIngredientsTableUpdateCompanionBuilder
    = InventoryIngredientsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> primaryCategory,
  Value<String?> subCategory,
  Value<String> preparation,
  Value<double> quantity,
  Value<String> unit,
  Value<DateTime?> expirationDate,
  Value<String?> imageAssetId,
  Value<String?> storageArea,
  Value<int> rowid,
});

class $$InventoryIngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $InventoryIngredientsTable> {
  $$InventoryIngredientsTableFilterComposer({
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

  ColumnFilters<String> get primaryCategory => $composableBuilder(
      column: $table.primaryCategory,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get subCategory => $composableBuilder(
      column: $table.subCategory, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preparation => $composableBuilder(
      column: $table.preparation, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get expirationDate => $composableBuilder(
      column: $table.expirationDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get storageArea => $composableBuilder(
      column: $table.storageArea, builder: (column) => ColumnFilters(column));
}

class $$InventoryIngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $InventoryIngredientsTable> {
  $$InventoryIngredientsTableOrderingComposer({
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

  ColumnOrderings<String> get primaryCategory => $composableBuilder(
      column: $table.primaryCategory,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get subCategory => $composableBuilder(
      column: $table.subCategory, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preparation => $composableBuilder(
      column: $table.preparation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get expirationDate => $composableBuilder(
      column: $table.expirationDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get storageArea => $composableBuilder(
      column: $table.storageArea, builder: (column) => ColumnOrderings(column));
}

class $$InventoryIngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InventoryIngredientsTable> {
  $$InventoryIngredientsTableAnnotationComposer({
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

  GeneratedColumn<String> get primaryCategory => $composableBuilder(
      column: $table.primaryCategory, builder: (column) => column);

  GeneratedColumn<String> get subCategory => $composableBuilder(
      column: $table.subCategory, builder: (column) => column);

  GeneratedColumn<String> get preparation => $composableBuilder(
      column: $table.preparation, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<DateTime> get expirationDate => $composableBuilder(
      column: $table.expirationDate, builder: (column) => column);

  GeneratedColumn<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId, builder: (column) => column);

  GeneratedColumn<String> get storageArea => $composableBuilder(
      column: $table.storageArea, builder: (column) => column);
}

class $$InventoryIngredientsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $InventoryIngredientsTable,
    InventoryIngredientEntry,
    $$InventoryIngredientsTableFilterComposer,
    $$InventoryIngredientsTableOrderingComposer,
    $$InventoryIngredientsTableAnnotationComposer,
    $$InventoryIngredientsTableCreateCompanionBuilder,
    $$InventoryIngredientsTableUpdateCompanionBuilder,
    (
      InventoryIngredientEntry,
      BaseReferences<_$AppDatabase, $InventoryIngredientsTable,
          InventoryIngredientEntry>
    ),
    InventoryIngredientEntry,
    PrefetchHooks Function()> {
  $$InventoryIngredientsTableTableManager(
      _$AppDatabase db, $InventoryIngredientsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InventoryIngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InventoryIngredientsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InventoryIngredientsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> primaryCategory = const Value.absent(),
            Value<String?> subCategory = const Value.absent(),
            Value<String> preparation = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<DateTime?> expirationDate = const Value.absent(),
            Value<String?> imageAssetId = const Value.absent(),
            Value<String?> storageArea = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryIngredientsCompanion(
            id: id,
            name: name,
            primaryCategory: primaryCategory,
            subCategory: subCategory,
            preparation: preparation,
            quantity: quantity,
            unit: unit,
            expirationDate: expirationDate,
            imageAssetId: imageAssetId,
            storageArea: storageArea,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> primaryCategory = const Value.absent(),
            Value<String?> subCategory = const Value.absent(),
            Value<String> preparation = const Value.absent(),
            required double quantity,
            required String unit,
            Value<DateTime?> expirationDate = const Value.absent(),
            Value<String?> imageAssetId = const Value.absent(),
            Value<String?> storageArea = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              InventoryIngredientsCompanion.insert(
            id: id,
            name: name,
            primaryCategory: primaryCategory,
            subCategory: subCategory,
            preparation: preparation,
            quantity: quantity,
            unit: unit,
            expirationDate: expirationDate,
            imageAssetId: imageAssetId,
            storageArea: storageArea,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$InventoryIngredientsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $InventoryIngredientsTable,
        InventoryIngredientEntry,
        $$InventoryIngredientsTableFilterComposer,
        $$InventoryIngredientsTableOrderingComposer,
        $$InventoryIngredientsTableAnnotationComposer,
        $$InventoryIngredientsTableCreateCompanionBuilder,
        $$InventoryIngredientsTableUpdateCompanionBuilder,
        (
          InventoryIngredientEntry,
          BaseReferences<_$AppDatabase, $InventoryIngredientsTable,
              InventoryIngredientEntry>
        ),
        InventoryIngredientEntry,
        PrefetchHooks Function()>;
typedef $$RecipesTableCreateCompanionBuilder = RecipesCompanion Function({
  required String id,
  required String name,
  Value<String> description,
  Value<int> durationMinutes,
  Value<int> servings,
  Value<String> instructionsJson,
  Value<String> tagsCsv,
  Value<String?> imageAssetId,
  Value<int> goalIndex,
  Value<bool> isFavorite,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$RecipesTableUpdateCompanionBuilder = RecipesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> description,
  Value<int> durationMinutes,
  Value<int> servings,
  Value<String> instructionsJson,
  Value<String> tagsCsv,
  Value<String?> imageAssetId,
  Value<int> goalIndex,
  Value<bool> isFavorite,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$RecipesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipesTable, RecipeEntry> {
  $$RecipesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecipeIngredientsTable,
      List<RecipeIngredientEntry>> _recipeIngredientsRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.recipeIngredients,
          aliasName: $_aliasNameGenerator(
              db.recipes.id, db.recipeIngredients.recipeId));

  $$RecipeIngredientsTableProcessedTableManager get recipeIngredientsRefs {
    final manager = $$RecipeIngredientsTableTableManager(
            $_db, $_db.recipeIngredients)
        .filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache =
        $_typedResult.readTableOrNull(_recipeIngredientsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RecipesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get servings => $composableBuilder(
      column: $table.servings, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get instructionsJson => $composableBuilder(
      column: $table.instructionsJson,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tagsCsv => $composableBuilder(
      column: $table.tagsCsv, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get goalIndex => $composableBuilder(
      column: $table.goalIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> recipeIngredientsRefs(
      Expression<bool> Function($$RecipeIngredientsTableFilterComposer f) f) {
    final $$RecipeIngredientsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.recipeIngredients,
        getReferencedColumn: (t) => t.recipeId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecipeIngredientsTableFilterComposer(
              $db: $db,
              $table: $db.recipeIngredients,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get servings => $composableBuilder(
      column: $table.servings, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get instructionsJson => $composableBuilder(
      column: $table.instructionsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tagsCsv => $composableBuilder(
      column: $table.tagsCsv, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get goalIndex => $composableBuilder(
      column: $table.goalIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$RecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<int> get durationMinutes => $composableBuilder(
      column: $table.durationMinutes, builder: (column) => column);

  GeneratedColumn<int> get servings =>
      $composableBuilder(column: $table.servings, builder: (column) => column);

  GeneratedColumn<String> get instructionsJson => $composableBuilder(
      column: $table.instructionsJson, builder: (column) => column);

  GeneratedColumn<String> get tagsCsv =>
      $composableBuilder(column: $table.tagsCsv, builder: (column) => column);

  GeneratedColumn<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId, builder: (column) => column);

  GeneratedColumn<int> get goalIndex =>
      $composableBuilder(column: $table.goalIndex, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> recipeIngredientsRefs<T extends Object>(
      Expression<T> Function($$RecipeIngredientsTableAnnotationComposer a) f) {
    final $$RecipeIngredientsTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.recipeIngredients,
            getReferencedColumn: (t) => t.recipeId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$RecipeIngredientsTableAnnotationComposer(
                  $db: $db,
                  $table: $db.recipeIngredients,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$RecipesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecipesTable,
    RecipeEntry,
    $$RecipesTableFilterComposer,
    $$RecipesTableOrderingComposer,
    $$RecipesTableAnnotationComposer,
    $$RecipesTableCreateCompanionBuilder,
    $$RecipesTableUpdateCompanionBuilder,
    (RecipeEntry, $$RecipesTableReferences),
    RecipeEntry,
    PrefetchHooks Function({bool recipeIngredientsRefs})> {
  $$RecipesTableTableManager(_$AppDatabase db, $RecipesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> description = const Value.absent(),
            Value<int> durationMinutes = const Value.absent(),
            Value<int> servings = const Value.absent(),
            Value<String> instructionsJson = const Value.absent(),
            Value<String> tagsCsv = const Value.absent(),
            Value<String?> imageAssetId = const Value.absent(),
            Value<int> goalIndex = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecipesCompanion(
            id: id,
            name: name,
            description: description,
            durationMinutes: durationMinutes,
            servings: servings,
            instructionsJson: instructionsJson,
            tagsCsv: tagsCsv,
            imageAssetId: imageAssetId,
            goalIndex: goalIndex,
            isFavorite: isFavorite,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String> description = const Value.absent(),
            Value<int> durationMinutes = const Value.absent(),
            Value<int> servings = const Value.absent(),
            Value<String> instructionsJson = const Value.absent(),
            Value<String> tagsCsv = const Value.absent(),
            Value<String?> imageAssetId = const Value.absent(),
            Value<int> goalIndex = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecipesCompanion.insert(
            id: id,
            name: name,
            description: description,
            durationMinutes: durationMinutes,
            servings: servings,
            instructionsJson: instructionsJson,
            tagsCsv: tagsCsv,
            imageAssetId: imageAssetId,
            goalIndex: goalIndex,
            isFavorite: isFavorite,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$RecipesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({recipeIngredientsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (recipeIngredientsRefs) db.recipeIngredients
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (recipeIngredientsRefs)
                    await $_getPrefetchedData<RecipeEntry, $RecipesTable, RecipeIngredientEntry>(
                        currentTable: table,
                        referencedTable: $$RecipesTableReferences
                            ._recipeIngredientsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RecipesTableReferences(db, table, p0)
                                .recipeIngredientsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.recipeId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RecipesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecipesTable,
    RecipeEntry,
    $$RecipesTableFilterComposer,
    $$RecipesTableOrderingComposer,
    $$RecipesTableAnnotationComposer,
    $$RecipesTableCreateCompanionBuilder,
    $$RecipesTableUpdateCompanionBuilder,
    (RecipeEntry, $$RecipesTableReferences),
    RecipeEntry,
    PrefetchHooks Function({bool recipeIngredientsRefs})>;
typedef $$RecipeIngredientsTableCreateCompanionBuilder
    = RecipeIngredientsCompanion Function({
  required String id,
  required String recipeId,
  required String ingredientName,
  required double quantity,
  required String unit,
  Value<int> rowid,
});
typedef $$RecipeIngredientsTableUpdateCompanionBuilder
    = RecipeIngredientsCompanion Function({
  Value<String> id,
  Value<String> recipeId,
  Value<String> ingredientName,
  Value<double> quantity,
  Value<String> unit,
  Value<int> rowid,
});

final class $$RecipeIngredientsTableReferences extends BaseReferences<
    _$AppDatabase, $RecipeIngredientsTable, RecipeIngredientEntry> {
  $$RecipeIngredientsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias(
          $_aliasNameGenerator(db.recipeIngredients.recipeId, db.recipes.id));

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$RecipesTableTableManager($_db, $_db.recipes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RecipeIngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ingredientName => $composableBuilder(
      column: $table.ingredientName,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recipeId,
        referencedTable: $db.recipes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecipesTableFilterComposer(
              $db: $db,
              $table: $db.recipes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecipeIngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ingredientName => $composableBuilder(
      column: $table.ingredientName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recipeId,
        referencedTable: $db.recipes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecipesTableOrderingComposer(
              $db: $db,
              $table: $db.recipes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecipeIngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ingredientName => $composableBuilder(
      column: $table.ingredientName, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.recipeId,
        referencedTable: $db.recipes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RecipesTableAnnotationComposer(
              $db: $db,
              $table: $db.recipes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RecipeIngredientsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecipeIngredientsTable,
    RecipeIngredientEntry,
    $$RecipeIngredientsTableFilterComposer,
    $$RecipeIngredientsTableOrderingComposer,
    $$RecipeIngredientsTableAnnotationComposer,
    $$RecipeIngredientsTableCreateCompanionBuilder,
    $$RecipeIngredientsTableUpdateCompanionBuilder,
    (RecipeIngredientEntry, $$RecipeIngredientsTableReferences),
    RecipeIngredientEntry,
    PrefetchHooks Function({bool recipeId})> {
  $$RecipeIngredientsTableTableManager(
      _$AppDatabase db, $RecipeIngredientsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeIngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeIngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeIngredientsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> recipeId = const Value.absent(),
            Value<String> ingredientName = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecipeIngredientsCompanion(
            id: id,
            recipeId: recipeId,
            ingredientName: ingredientName,
            quantity: quantity,
            unit: unit,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String recipeId,
            required String ingredientName,
            required double quantity,
            required String unit,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecipeIngredientsCompanion.insert(
            id: id,
            recipeId: recipeId,
            ingredientName: ingredientName,
            quantity: quantity,
            unit: unit,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RecipeIngredientsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({recipeId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (recipeId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.recipeId,
                    referencedTable:
                        $$RecipeIngredientsTableReferences._recipeIdTable(db),
                    referencedColumn: $$RecipeIngredientsTableReferences
                        ._recipeIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$RecipeIngredientsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecipeIngredientsTable,
    RecipeIngredientEntry,
    $$RecipeIngredientsTableFilterComposer,
    $$RecipeIngredientsTableOrderingComposer,
    $$RecipeIngredientsTableAnnotationComposer,
    $$RecipeIngredientsTableCreateCompanionBuilder,
    $$RecipeIngredientsTableUpdateCompanionBuilder,
    (RecipeIngredientEntry, $$RecipeIngredientsTableReferences),
    RecipeIngredientEntry,
    PrefetchHooks Function({bool recipeId})>;
typedef $$AppliancesTableCreateCompanionBuilder = AppliancesCompanion Function({
  required String id,
  required String name,
  required String type,
  Value<String?> imageAssetId,
  Value<int> rowid,
});
typedef $$AppliancesTableUpdateCompanionBuilder = AppliancesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<String?> imageAssetId,
  Value<int> rowid,
});

class $$AppliancesTableFilterComposer
    extends Composer<_$AppDatabase, $AppliancesTable> {
  $$AppliancesTableFilterComposer({
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

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId, builder: (column) => ColumnFilters(column));
}

class $$AppliancesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppliancesTable> {
  $$AppliancesTableOrderingComposer({
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

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId,
      builder: (column) => ColumnOrderings(column));
}

class $$AppliancesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppliancesTable> {
  $$AppliancesTableAnnotationComposer({
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

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId, builder: (column) => column);
}

class $$AppliancesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppliancesTable,
    ApplianceEntry,
    $$AppliancesTableFilterComposer,
    $$AppliancesTableOrderingComposer,
    $$AppliancesTableAnnotationComposer,
    $$AppliancesTableCreateCompanionBuilder,
    $$AppliancesTableUpdateCompanionBuilder,
    (
      ApplianceEntry,
      BaseReferences<_$AppDatabase, $AppliancesTable, ApplianceEntry>
    ),
    ApplianceEntry,
    PrefetchHooks Function()> {
  $$AppliancesTableTableManager(_$AppDatabase db, $AppliancesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppliancesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppliancesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppliancesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> imageAssetId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppliancesCompanion(
            id: id,
            name: name,
            type: type,
            imageAssetId: imageAssetId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String type,
            Value<String?> imageAssetId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppliancesCompanion.insert(
            id: id,
            name: name,
            type: type,
            imageAssetId: imageAssetId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppliancesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppliancesTable,
    ApplianceEntry,
    $$AppliancesTableFilterComposer,
    $$AppliancesTableOrderingComposer,
    $$AppliancesTableAnnotationComposer,
    $$AppliancesTableCreateCompanionBuilder,
    $$AppliancesTableUpdateCompanionBuilder,
    (
      ApplianceEntry,
      BaseReferences<_$AppDatabase, $AppliancesTable, ApplianceEntry>
    ),
    ApplianceEntry,
    PrefetchHooks Function()>;
typedef $$ShoppingItemsTableCreateCompanionBuilder = ShoppingItemsCompanion
    Function({
  required String id,
  required String name,
  required double quantity,
  required String unit,
  Value<bool> bought,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$ShoppingItemsTableUpdateCompanionBuilder = ShoppingItemsCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<double> quantity,
  Value<String> unit,
  Value<bool> bought,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ShoppingItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableFilterComposer({
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

  ColumnFilters<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get bought => $composableBuilder(
      column: $table.bought, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ShoppingItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableOrderingComposer({
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

  ColumnOrderings<double> get quantity => $composableBuilder(
      column: $table.quantity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get unit => $composableBuilder(
      column: $table.unit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get bought => $composableBuilder(
      column: $table.bought, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ShoppingItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ShoppingItemsTable> {
  $$ShoppingItemsTableAnnotationComposer({
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

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<bool> get bought =>
      $composableBuilder(column: $table.bought, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ShoppingItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ShoppingItemsTable,
    ShoppingItemEntry,
    $$ShoppingItemsTableFilterComposer,
    $$ShoppingItemsTableOrderingComposer,
    $$ShoppingItemsTableAnnotationComposer,
    $$ShoppingItemsTableCreateCompanionBuilder,
    $$ShoppingItemsTableUpdateCompanionBuilder,
    (
      ShoppingItemEntry,
      BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItemEntry>
    ),
    ShoppingItemEntry,
    PrefetchHooks Function()> {
  $$ShoppingItemsTableTableManager(_$AppDatabase db, $ShoppingItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ShoppingItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ShoppingItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ShoppingItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<double> quantity = const Value.absent(),
            Value<String> unit = const Value.absent(),
            Value<bool> bought = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ShoppingItemsCompanion(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit,
            bought: bought,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required double quantity,
            required String unit,
            Value<bool> bought = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ShoppingItemsCompanion.insert(
            id: id,
            name: name,
            quantity: quantity,
            unit: unit,
            bought: bought,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ShoppingItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ShoppingItemsTable,
    ShoppingItemEntry,
    $$ShoppingItemsTableFilterComposer,
    $$ShoppingItemsTableOrderingComposer,
    $$ShoppingItemsTableAnnotationComposer,
    $$ShoppingItemsTableCreateCompanionBuilder,
    $$ShoppingItemsTableUpdateCompanionBuilder,
    (
      ShoppingItemEntry,
      BaseReferences<_$AppDatabase, $ShoppingItemsTable, ShoppingItemEntry>
    ),
    ShoppingItemEntry,
    PrefetchHooks Function()>;
typedef $$WardrobeGarmentsTableCreateCompanionBuilder
    = WardrobeGarmentsCompanion Function({
  required String id,
  required String name,
  required int typeIndex,
  required String primaryColor,
  Value<String> secondaryColor,
  required int styleIndex,
  Value<String> material,
  Value<String> season,
  Value<bool> isFavorite,
  Value<bool> isClean,
  Value<bool> hasRemovableHood,
  Value<int> rating,
  Value<String?> size,
  Value<String?> brand,
  Value<double?> price,
  Value<String?> imageAssetId,
  Value<String?> imageDetailsPath,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$WardrobeGarmentsTableUpdateCompanionBuilder
    = WardrobeGarmentsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<int> typeIndex,
  Value<String> primaryColor,
  Value<String> secondaryColor,
  Value<int> styleIndex,
  Value<String> material,
  Value<String> season,
  Value<bool> isFavorite,
  Value<bool> isClean,
  Value<bool> hasRemovableHood,
  Value<int> rating,
  Value<String?> size,
  Value<String?> brand,
  Value<double?> price,
  Value<String?> imageAssetId,
  Value<String?> imageDetailsPath,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$WardrobeGarmentsTableFilterComposer
    extends Composer<_$AppDatabase, $WardrobeGarmentsTable> {
  $$WardrobeGarmentsTableFilterComposer({
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

  ColumnFilters<int> get typeIndex => $composableBuilder(
      column: $table.typeIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get primaryColor => $composableBuilder(
      column: $table.primaryColor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get secondaryColor => $composableBuilder(
      column: $table.secondaryColor,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get styleIndex => $composableBuilder(
      column: $table.styleIndex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get material => $composableBuilder(
      column: $table.material, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get season => $composableBuilder(
      column: $table.season, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isClean => $composableBuilder(
      column: $table.isClean, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hasRemovableHood => $composableBuilder(
      column: $table.hasRemovableHood,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imageDetailsPath => $composableBuilder(
      column: $table.imageDetailsPath,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$WardrobeGarmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $WardrobeGarmentsTable> {
  $$WardrobeGarmentsTableOrderingComposer({
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

  ColumnOrderings<int> get typeIndex => $composableBuilder(
      column: $table.typeIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get primaryColor => $composableBuilder(
      column: $table.primaryColor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get secondaryColor => $composableBuilder(
      column: $table.secondaryColor,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get styleIndex => $composableBuilder(
      column: $table.styleIndex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get material => $composableBuilder(
      column: $table.material, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get season => $composableBuilder(
      column: $table.season, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isClean => $composableBuilder(
      column: $table.isClean, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hasRemovableHood => $composableBuilder(
      column: $table.hasRemovableHood,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rating => $composableBuilder(
      column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get size => $composableBuilder(
      column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brand => $composableBuilder(
      column: $table.brand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get price => $composableBuilder(
      column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imageDetailsPath => $composableBuilder(
      column: $table.imageDetailsPath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$WardrobeGarmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WardrobeGarmentsTable> {
  $$WardrobeGarmentsTableAnnotationComposer({
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

  GeneratedColumn<int> get typeIndex =>
      $composableBuilder(column: $table.typeIndex, builder: (column) => column);

  GeneratedColumn<String> get primaryColor => $composableBuilder(
      column: $table.primaryColor, builder: (column) => column);

  GeneratedColumn<String> get secondaryColor => $composableBuilder(
      column: $table.secondaryColor, builder: (column) => column);

  GeneratedColumn<int> get styleIndex => $composableBuilder(
      column: $table.styleIndex, builder: (column) => column);

  GeneratedColumn<String> get material =>
      $composableBuilder(column: $table.material, builder: (column) => column);

  GeneratedColumn<String> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<bool> get isClean =>
      $composableBuilder(column: $table.isClean, builder: (column) => column);

  GeneratedColumn<bool> get hasRemovableHood => $composableBuilder(
      column: $table.hasRemovableHood, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<String> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<double> get price =>
      $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get imageAssetId => $composableBuilder(
      column: $table.imageAssetId, builder: (column) => column);

  GeneratedColumn<String> get imageDetailsPath => $composableBuilder(
      column: $table.imageDetailsPath, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$WardrobeGarmentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WardrobeGarmentsTable,
    WardrobeGarmentEntry,
    $$WardrobeGarmentsTableFilterComposer,
    $$WardrobeGarmentsTableOrderingComposer,
    $$WardrobeGarmentsTableAnnotationComposer,
    $$WardrobeGarmentsTableCreateCompanionBuilder,
    $$WardrobeGarmentsTableUpdateCompanionBuilder,
    (
      WardrobeGarmentEntry,
      BaseReferences<_$AppDatabase, $WardrobeGarmentsTable,
          WardrobeGarmentEntry>
    ),
    WardrobeGarmentEntry,
    PrefetchHooks Function()> {
  $$WardrobeGarmentsTableTableManager(
      _$AppDatabase db, $WardrobeGarmentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WardrobeGarmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WardrobeGarmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WardrobeGarmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int> typeIndex = const Value.absent(),
            Value<String> primaryColor = const Value.absent(),
            Value<String> secondaryColor = const Value.absent(),
            Value<int> styleIndex = const Value.absent(),
            Value<String> material = const Value.absent(),
            Value<String> season = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<bool> isClean = const Value.absent(),
            Value<bool> hasRemovableHood = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<String?> size = const Value.absent(),
            Value<String?> brand = const Value.absent(),
            Value<double?> price = const Value.absent(),
            Value<String?> imageAssetId = const Value.absent(),
            Value<String?> imageDetailsPath = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WardrobeGarmentsCompanion(
            id: id,
            name: name,
            typeIndex: typeIndex,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            styleIndex: styleIndex,
            material: material,
            season: season,
            isFavorite: isFavorite,
            isClean: isClean,
            hasRemovableHood: hasRemovableHood,
            rating: rating,
            size: size,
            brand: brand,
            price: price,
            imageAssetId: imageAssetId,
            imageDetailsPath: imageDetailsPath,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required int typeIndex,
            required String primaryColor,
            Value<String> secondaryColor = const Value.absent(),
            required int styleIndex,
            Value<String> material = const Value.absent(),
            Value<String> season = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<bool> isClean = const Value.absent(),
            Value<bool> hasRemovableHood = const Value.absent(),
            Value<int> rating = const Value.absent(),
            Value<String?> size = const Value.absent(),
            Value<String?> brand = const Value.absent(),
            Value<double?> price = const Value.absent(),
            Value<String?> imageAssetId = const Value.absent(),
            Value<String?> imageDetailsPath = const Value.absent(),
            required DateTime addedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              WardrobeGarmentsCompanion.insert(
            id: id,
            name: name,
            typeIndex: typeIndex,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            styleIndex: styleIndex,
            material: material,
            season: season,
            isFavorite: isFavorite,
            isClean: isClean,
            hasRemovableHood: hasRemovableHood,
            rating: rating,
            size: size,
            brand: brand,
            price: price,
            imageAssetId: imageAssetId,
            imageDetailsPath: imageDetailsPath,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WardrobeGarmentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WardrobeGarmentsTable,
    WardrobeGarmentEntry,
    $$WardrobeGarmentsTableFilterComposer,
    $$WardrobeGarmentsTableOrderingComposer,
    $$WardrobeGarmentsTableAnnotationComposer,
    $$WardrobeGarmentsTableCreateCompanionBuilder,
    $$WardrobeGarmentsTableUpdateCompanionBuilder,
    (
      WardrobeGarmentEntry,
      BaseReferences<_$AppDatabase, $WardrobeGarmentsTable,
          WardrobeGarmentEntry>
    ),
    WardrobeGarmentEntry,
    PrefetchHooks Function()>;
typedef $$OutfitsTableCreateCompanionBuilder = OutfitsCompanion Function({
  required String id,
  required String name,
  required String garmentIdsCsv,
  Value<String> occasion,
  Value<String> season,
  Value<int> timesWorn,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$OutfitsTableUpdateCompanionBuilder = OutfitsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> garmentIdsCsv,
  Value<String> occasion,
  Value<String> season,
  Value<int> timesWorn,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$OutfitsTableFilterComposer
    extends Composer<_$AppDatabase, $OutfitsTable> {
  $$OutfitsTableFilterComposer({
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

  ColumnFilters<String> get garmentIdsCsv => $composableBuilder(
      column: $table.garmentIdsCsv, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get occasion => $composableBuilder(
      column: $table.occasion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get season => $composableBuilder(
      column: $table.season, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timesWorn => $composableBuilder(
      column: $table.timesWorn, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$OutfitsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutfitsTable> {
  $$OutfitsTableOrderingComposer({
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

  ColumnOrderings<String> get garmentIdsCsv => $composableBuilder(
      column: $table.garmentIdsCsv,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get occasion => $composableBuilder(
      column: $table.occasion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get season => $composableBuilder(
      column: $table.season, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timesWorn => $composableBuilder(
      column: $table.timesWorn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$OutfitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutfitsTable> {
  $$OutfitsTableAnnotationComposer({
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

  GeneratedColumn<String> get garmentIdsCsv => $composableBuilder(
      column: $table.garmentIdsCsv, builder: (column) => column);

  GeneratedColumn<String> get occasion =>
      $composableBuilder(column: $table.occasion, builder: (column) => column);

  GeneratedColumn<String> get season =>
      $composableBuilder(column: $table.season, builder: (column) => column);

  GeneratedColumn<int> get timesWorn =>
      $composableBuilder(column: $table.timesWorn, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutfitsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OutfitsTable,
    OutfitEntry,
    $$OutfitsTableFilterComposer,
    $$OutfitsTableOrderingComposer,
    $$OutfitsTableAnnotationComposer,
    $$OutfitsTableCreateCompanionBuilder,
    $$OutfitsTableUpdateCompanionBuilder,
    (OutfitEntry, BaseReferences<_$AppDatabase, $OutfitsTable, OutfitEntry>),
    OutfitEntry,
    PrefetchHooks Function()> {
  $$OutfitsTableTableManager(_$AppDatabase db, $OutfitsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutfitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutfitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutfitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> garmentIdsCsv = const Value.absent(),
            Value<String> occasion = const Value.absent(),
            Value<String> season = const Value.absent(),
            Value<int> timesWorn = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OutfitsCompanion(
            id: id,
            name: name,
            garmentIdsCsv: garmentIdsCsv,
            occasion: occasion,
            season: season,
            timesWorn: timesWorn,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String garmentIdsCsv,
            Value<String> occasion = const Value.absent(),
            Value<String> season = const Value.absent(),
            Value<int> timesWorn = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              OutfitsCompanion.insert(
            id: id,
            name: name,
            garmentIdsCsv: garmentIdsCsv,
            occasion: occasion,
            season: season,
            timesWorn: timesWorn,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OutfitsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OutfitsTable,
    OutfitEntry,
    $$OutfitsTableFilterComposer,
    $$OutfitsTableOrderingComposer,
    $$OutfitsTableAnnotationComposer,
    $$OutfitsTableCreateCompanionBuilder,
    $$OutfitsTableUpdateCompanionBuilder,
    (OutfitEntry, BaseReferences<_$AppDatabase, $OutfitsTable, OutfitEntry>),
    OutfitEntry,
    PrefetchHooks Function()>;
typedef $$UserProfileTableCreateCompanionBuilder = UserProfileCompanion
    Function({
  required String id,
  Value<String?> skinTone,
  Value<String?> bodyType,
  Value<String?> height,
  Value<String?> weight,
  Value<String?> hairType,
  Value<String?> colorimetry,
  Value<String?> bodyShape,
  Value<bool> consentGranted,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$UserProfileTableUpdateCompanionBuilder = UserProfileCompanion
    Function({
  Value<String> id,
  Value<String?> skinTone,
  Value<String?> bodyType,
  Value<String?> height,
  Value<String?> weight,
  Value<String?> hairType,
  Value<String?> colorimetry,
  Value<String?> bodyShape,
  Value<bool> consentGranted,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$UserProfileTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skinTone => $composableBuilder(
      column: $table.skinTone, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bodyType => $composableBuilder(
      column: $table.bodyType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hairType => $composableBuilder(
      column: $table.hairType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get colorimetry => $composableBuilder(
      column: $table.colorimetry, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bodyShape => $composableBuilder(
      column: $table.bodyShape, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get consentGranted => $composableBuilder(
      column: $table.consentGranted,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$UserProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skinTone => $composableBuilder(
      column: $table.skinTone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bodyType => $composableBuilder(
      column: $table.bodyType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get height => $composableBuilder(
      column: $table.height, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get weight => $composableBuilder(
      column: $table.weight, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hairType => $composableBuilder(
      column: $table.hairType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get colorimetry => $composableBuilder(
      column: $table.colorimetry, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bodyShape => $composableBuilder(
      column: $table.bodyShape, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get consentGranted => $composableBuilder(
      column: $table.consentGranted,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$UserProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get skinTone =>
      $composableBuilder(column: $table.skinTone, builder: (column) => column);

  GeneratedColumn<String> get bodyType =>
      $composableBuilder(column: $table.bodyType, builder: (column) => column);

  GeneratedColumn<String> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<String> get hairType =>
      $composableBuilder(column: $table.hairType, builder: (column) => column);

  GeneratedColumn<String> get colorimetry => $composableBuilder(
      column: $table.colorimetry, builder: (column) => column);

  GeneratedColumn<String> get bodyShape =>
      $composableBuilder(column: $table.bodyShape, builder: (column) => column);

  GeneratedColumn<bool> get consentGranted => $composableBuilder(
      column: $table.consentGranted, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProfileTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserProfileTable,
    UserProfileEntry,
    $$UserProfileTableFilterComposer,
    $$UserProfileTableOrderingComposer,
    $$UserProfileTableAnnotationComposer,
    $$UserProfileTableCreateCompanionBuilder,
    $$UserProfileTableUpdateCompanionBuilder,
    (
      UserProfileEntry,
      BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileEntry>
    ),
    UserProfileEntry,
    PrefetchHooks Function()> {
  $$UserProfileTableTableManager(_$AppDatabase db, $UserProfileTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String?> skinTone = const Value.absent(),
            Value<String?> bodyType = const Value.absent(),
            Value<String?> height = const Value.absent(),
            Value<String?> weight = const Value.absent(),
            Value<String?> hairType = const Value.absent(),
            Value<String?> colorimetry = const Value.absent(),
            Value<String?> bodyShape = const Value.absent(),
            Value<bool> consentGranted = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfileCompanion(
            id: id,
            skinTone: skinTone,
            bodyType: bodyType,
            height: height,
            weight: weight,
            hairType: hairType,
            colorimetry: colorimetry,
            bodyShape: bodyShape,
            consentGranted: consentGranted,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String?> skinTone = const Value.absent(),
            Value<String?> bodyType = const Value.absent(),
            Value<String?> height = const Value.absent(),
            Value<String?> weight = const Value.absent(),
            Value<String?> hairType = const Value.absent(),
            Value<String?> colorimetry = const Value.absent(),
            Value<String?> bodyShape = const Value.absent(),
            Value<bool> consentGranted = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              UserProfileCompanion.insert(
            id: id,
            skinTone: skinTone,
            bodyType: bodyType,
            height: height,
            weight: weight,
            hairType: hairType,
            colorimetry: colorimetry,
            bodyShape: bodyShape,
            consentGranted: consentGranted,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserProfileTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserProfileTable,
    UserProfileEntry,
    $$UserProfileTableFilterComposer,
    $$UserProfileTableOrderingComposer,
    $$UserProfileTableAnnotationComposer,
    $$UserProfileTableCreateCompanionBuilder,
    $$UserProfileTableUpdateCompanionBuilder,
    (
      UserProfileEntry,
      BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileEntry>
    ),
    UserProfileEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MealLogsTableTableManager get mealLogs =>
      $$MealLogsTableTableManager(_db, _db.mealLogs);
  $$InventoryIngredientsTableTableManager get inventoryIngredients =>
      $$InventoryIngredientsTableTableManager(_db, _db.inventoryIngredients);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$RecipeIngredientsTableTableManager get recipeIngredients =>
      $$RecipeIngredientsTableTableManager(_db, _db.recipeIngredients);
  $$AppliancesTableTableManager get appliances =>
      $$AppliancesTableTableManager(_db, _db.appliances);
  $$ShoppingItemsTableTableManager get shoppingItems =>
      $$ShoppingItemsTableTableManager(_db, _db.shoppingItems);
  $$WardrobeGarmentsTableTableManager get wardrobeGarments =>
      $$WardrobeGarmentsTableTableManager(_db, _db.wardrobeGarments);
  $$OutfitsTableTableManager get outfits =>
      $$OutfitsTableTableManager(_db, _db.outfits);
  $$UserProfileTableTableManager get userProfile =>
      $$UserProfileTableTableManager(_db, _db.userProfile);
}
