import 'dart:math' as math;
import 'package:equatable/equatable.dart';
import '../../cocina/entities/recipe.dart';

/// Sexo biológico usado en fórmulas antropométricas (US Navy y Mifflin-St Jeor).
enum BiologicalSex {
  male,
  female;

  String get label => switch (this) {
        BiologicalSex.male => 'Masculino',
        BiologicalSex.female => 'Femenino',
      };

  String get emoji => switch (this) {
        BiologicalSex.male => '♂️',
        BiologicalSex.female => '♀️',
      };

  static BiologicalSex fromName(String? raw) {
    if (raw == 'female') return BiologicalSex.female;
    return BiologicalSex.male;
  }
}

/// Nivel de actividad física semanal para calcular el gasto energético total (TDEE).
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive;

  double get multiplier => switch (this) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };

  String get label => switch (this) {
        ActivityLevel.sedentary => 'Sedentario',
        ActivityLevel.light => 'Ligero (1-2 d/sem)',
        ActivityLevel.moderate => 'Moderado (3-4 d/sem)',
        ActivityLevel.active => 'Activo (5-6 d/sem)',
        ActivityLevel.veryActive => 'Muy activo',
      };

  String get shortLabel => switch (this) {
        ActivityLevel.sedentary => 'Sedentario',
        ActivityLevel.light => 'Ligero',
        ActivityLevel.moderate => 'Moderado',
        ActivityLevel.active => 'Activo',
        ActivityLevel.veryActive => 'Muy activo',
      };

  static ActivityLevel fromName(String? raw) {
    for (final v in ActivityLevel.values) {
      if (v.name == raw) return v;
    }
    return ActivityLevel.moderate;
  }
}

/// Objetivo de composición corporal.
enum BodyGoalMode {
  fatLoss,
  recomposition,
  muscleGain,
  maintain;

  String get label => switch (this) {
        BodyGoalMode.fatLoss => 'Bajar grasa',
        BodyGoalMode.recomposition => 'Recomposición',
        BodyGoalMode.muscleGain => 'Ganar músculo',
        BodyGoalMode.maintain => 'Mantener',
      };

  String get emoji => switch (this) {
        BodyGoalMode.fatLoss => '🔥',
        BodyGoalMode.recomposition => '⚖️',
        BodyGoalMode.muscleGain => '💪',
        BodyGoalMode.maintain => '🌿',
      };

  String get subtitle => switch (this) {
        BodyGoalMode.fatLoss => 'Déficit controlado (-18%) + proteína alta',
        BodyGoalMode.recomposition =>
          'Bajar grasa y ganar músculo (-5% kcal + proteína alta)',
        BodyGoalMode.muscleGain => 'Superávit limpio (+12%) + fuerza',
        BodyGoalMode.maintain => 'Balance energético y hábitos sostenibles',
      };

  NutritionGoal toNutritionGoal() => switch (this) {
        BodyGoalMode.fatLoss => NutritionGoal.loseWeight,
        BodyGoalMode.recomposition => NutritionGoal.gainMuscle,
        BodyGoalMode.muscleGain => NutritionGoal.gainMuscle,
        BodyGoalMode.maintain => NutritionGoal.maintain,
      };

  static BodyGoalMode fromNutritionGoal(NutritionGoal goal) => switch (goal) {
        NutritionGoal.loseWeight => BodyGoalMode.fatLoss,
        NutritionGoal.gainMuscle => BodyGoalMode.muscleGain,
        NutritionGoal.light => BodyGoalMode.fatLoss,
        NutritionGoal.maintain || NutritionGoal.other => BodyGoalMode.maintain,
      };

  static BodyGoalMode fromName(String? raw) {
    for (final v in BodyGoalMode.values) {
      if (v.name == raw) return v;
    }
    return BodyGoalMode.maintain;
  }
}

/// Origen de la estimación del porcentaje de grasa corporal.
enum BodyFatSource {
  manual,
  usNavy,
  visualEstimate,
  none;

  String get label => switch (this) {
        BodyFatSource.manual => 'Medición manual',
        BodyFatSource.usNavy => 'Fórmula US Navy',
        BodyFatSource.visualEstimate => 'Est. visual Escáner (aprox.)',
        BodyFatSource.none => 'Sin estimar',
      };

  String get shortBadge => switch (this) {
        BodyFatSource.manual => 'Manual',
        BodyFatSource.usNavy => 'US Navy',
        BodyFatSource.visualEstimate => 'Est. visual',
        BodyFatSource.none => 'Sin dato',
      };

  static BodyFatSource fromName(String? raw) {
    for (final v in BodyFatSource.values) {
      if (v.name == raw) return v;
    }
    return BodyFatSource.none;
  }
}

/// Punto histórico de evolución corporal.
class BodyCheckIn extends Equatable {
  final DateTime date;
  final double weightKg;
  final double? bodyFatPercent;
  final double? waistCm;
  final BodyFatSource source;

  const BodyCheckIn({
    required this.date,
    required this.weightKg,
    this.bodyFatPercent,
    this.waistCm,
    this.source = BodyFatSource.none,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weightKg': weightKg,
        if (bodyFatPercent != null) 'bodyFatPercent': bodyFatPercent,
        if (waistCm != null) 'waistCm': waistCm,
        'source': source.name,
      };

  factory BodyCheckIn.fromJson(Map<String, dynamic> json) => BodyCheckIn(
        date: DateTime.tryParse(json['date']?.toString() ?? '') ??
            DateTime.now(),
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
        bodyFatPercent: (json['bodyFatPercent'] as num?)?.toDouble(),
        waistCm: (json['waistCm'] as num?)?.toDouble(),
        source: BodyFatSource.fromName(json['source']?.toString()),
      );

  @override
  List<Object?> get props => [date, weightKg, bodyFatPercent, waistCm, source];
}

/// Perfil corporal y nutricional compartido entre Armario, FoodCoach y Cocina.
class BodyCompositionProfile extends Equatable {
  final double? heightCm;
  final double? weightKg;
  final int? age;
  final BiologicalSex sex;
  final ActivityLevel activityLevel;
  final BodyGoalMode goalMode;
  final double? neckCm;
  final double? waistCm;
  final double? hipCm;
  final double? manualBodyFatPercent;
  final double? visualBodyFatMin;
  final double? visualBodyFatMax;
  final String? visualBuildNote;
  final DateTime? updatedAt;
  final List<BodyCheckIn> history;

  const BodyCompositionProfile({
    this.heightCm,
    this.weightKg,
    this.age,
    this.sex = BiologicalSex.male,
    this.activityLevel = ActivityLevel.moderate,
    this.goalMode = BodyGoalMode.maintain,
    this.neckCm,
    this.waistCm,
    this.hipCm,
    this.manualBodyFatPercent,
    this.visualBodyFatMin,
    this.visualBodyFatMax,
    this.visualBuildNote,
    this.updatedAt,
    this.history = const [],
  });

  bool get hasCoreMetrics =>
      (heightCm ?? 0) >= 100 && (weightKg ?? 0) >= 30;

  bool get hasVisualEstimate =>
      visualBodyFatMin != null &&
      visualBodyFatMax != null &&
      visualBodyFatMin! > 0 &&
      visualBodyFatMax! >= visualBodyFatMin!;

  BodyCompositionProfile copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    BiologicalSex? sex,
    ActivityLevel? activityLevel,
    BodyGoalMode? goalMode,
    double? neckCm,
    double? waistCm,
    double? hipCm,
    double? manualBodyFatPercent,
    double? visualBodyFatMin,
    double? visualBodyFatMax,
    String? visualBuildNote,
    DateTime? updatedAt,
    List<BodyCheckIn>? history,
    bool clearNeck = false,
    bool clearWaist = false,
    bool clearHip = false,
    bool clearManualBodyFat = false,
  }) {
    return BodyCompositionProfile(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      goalMode: goalMode ?? this.goalMode,
      neckCm: clearNeck ? null : (neckCm ?? this.neckCm),
      waistCm: clearWaist ? null : (waistCm ?? this.waistCm),
      hipCm: clearHip ? null : (hipCm ?? this.hipCm),
      manualBodyFatPercent: clearManualBodyFat
          ? null
          : (manualBodyFatPercent ?? this.manualBodyFatPercent),
      visualBodyFatMin: visualBodyFatMin ?? this.visualBodyFatMin,
      visualBodyFatMax: visualBodyFatMax ?? this.visualBodyFatMax,
      visualBuildNote: visualBuildNote ?? this.visualBuildNote,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
    );
  }

  Map<String, dynamic> toJson() => {
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
        if (age != null) 'age': age,
        'sex': sex.name,
        'activityLevel': activityLevel.name,
        'goalMode': goalMode.name,
        if (neckCm != null) 'neckCm': neckCm,
        if (waistCm != null) 'waistCm': waistCm,
        if (hipCm != null) 'hipCm': hipCm,
        if (manualBodyFatPercent != null)
          'manualBodyFatPercent': manualBodyFatPercent,
        if (visualBodyFatMin != null) 'visualBodyFatMin': visualBodyFatMin,
        if (visualBodyFatMax != null) 'visualBodyFatMax': visualBodyFatMax,
        if (visualBuildNote != null) 'visualBuildNote': visualBuildNote,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'history': history.map((e) => e.toJson()).toList(),
      };

  factory BodyCompositionProfile.fromJson(Map<String, dynamic> json) {
    final rawHistory = json['history'];
    final history = rawHistory is List
        ? rawHistory
            .whereType<Map>()
            .map((e) => BodyCheckIn.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <BodyCheckIn>[];
    return BodyCompositionProfile(
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      age: (json['age'] as num?)?.toInt(),
      sex: BiologicalSex.fromName(json['sex']?.toString()),
      activityLevel: ActivityLevel.fromName(json['activityLevel']?.toString()),
      goalMode: BodyGoalMode.fromName(json['goalMode']?.toString()),
      neckCm: (json['neckCm'] as num?)?.toDouble(),
      waistCm: (json['waistCm'] as num?)?.toDouble(),
      hipCm: (json['hipCm'] as num?)?.toDouble(),
      manualBodyFatPercent: (json['manualBodyFatPercent'] as num?)?.toDouble(),
      visualBodyFatMin: (json['visualBodyFatMin'] as num?)?.toDouble(),
      visualBodyFatMax: (json['visualBodyFatMax'] as num?)?.toDouble(),
      visualBuildNote: json['visualBuildNote']?.toString(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
      history: history,
    );
  }

  @override
  List<Object?> get props => [
        heightCm,
        weightKg,
        age,
        sex,
        activityLevel,
        goalMode,
        neckCm,
        waistCm,
        hipCm,
        manualBodyFatPercent,
        visualBodyFatMin,
        visualBodyFatMax,
        visualBuildNote,
        updatedAt,
        history,
      ];
}

/// Metas diarias calculadas a partir del perfil corporal.
class DailyNutritionTargets extends Equatable {
  final int caloriesKcal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double fiberGrams;
  final double waterLiters;
  final int bmrKcal;
  final int tdeeKcal;
  final double? estimatedBodyFatPercent;
  final BodyFatSource bodyFatSource;
  final double? leanMassKg;
  final double? bmi;
  final bool isPersonalized;
  final BodyGoalMode effectiveGoal;
  final String summaryNote;

  const DailyNutritionTargets({
    required this.caloriesKcal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.fiberGrams,
    required this.waterLiters,
    required this.bmrKcal,
    required this.tdeeKcal,
    this.estimatedBodyFatPercent,
    this.bodyFatSource = BodyFatSource.none,
    this.leanMassKg,
    this.bmi,
    this.isPersonalized = false,
    this.effectiveGoal = BodyGoalMode.maintain,
    this.summaryNote = '',
  });

  /// Meta diaria en vasos de 250 ml.
  int get waterGlasses => (waterLiters / 0.25).round().clamp(6, 16);

  @override
  List<Object?> get props => [
        caloriesKcal,
        proteinGrams,
        carbsGrams,
        fatGrams,
        fiberGrams,
        waterLiters,
        bmrKcal,
        tdeeKcal,
        estimatedBodyFatPercent,
        bodyFatSource,
        leanMassKg,
        bmi,
        isPersonalized,
        effectiveGoal,
        summaryNote,
      ];
}

/// Saldo nutricional restante del día para guiar a FoodCoach y Cocina.
class DailyMacroBudget extends Equatable {
  final DailyNutritionTargets targets;
  final int consumedCalories;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFat;

  const DailyMacroBudget({
    required this.targets,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFat,
  });

  int get remainingCalories =>
      (targets.caloriesKcal - consumedCalories).clamp(0, 9999);
  int get calorieDelta => targets.caloriesKcal - consumedCalories;
  double get remainingProtein =>
      (targets.proteinGrams - consumedProtein).clamp(0.0, 500.0);
  double get remainingCarbs =>
      (targets.carbsGrams - consumedCarbs).clamp(0.0, 800.0);
  double get remainingFat =>
      (targets.fatGrams - consumedFat).clamp(0.0, 300.0);

  bool get isOverCalories => consumedCalories > targets.caloriesKcal + 100;

  /// Texto corto para UI de Cocina y FoodCoach.
  String get shortGuidance {
    if (isOverCalories) {
      final over = consumedCalories - targets.caloriesKcal;
      if (remainingProtein >= 18) {
        return '+$over kcal sobre tu meta · prioriza proteína magra (${remainingProtein.round()}g pendientes)';
      }
      return '+$over kcal sobre tu meta · elige algo ligero y con verduras';
    }
    if (remainingCalories <= 350 && remainingProtein >= 20) {
      return 'Te quedan ~$remainingCalories kcal y ${remainingProtein.round()}g prot · ideal proteína magra';
    }
    return 'Te faltan ~$remainingCalories kcal · ${remainingProtein.round()}g prot hoy';
  }

  /// Bloque compacto de contexto para inyectar al Chef IA de Cocina.
  String toChefPromptContext(BodyCompositionProfile profile) {
    final buf = StringBuffer()
      ..writeln('🧬 PERFIL CORPORAL Y SALDO NUTRICIONAL DE HOY:');
    if (profile.weightKg != null && profile.heightCm != null) {
      buf.write(
          '- Usuario: ${profile.weightKg!.toStringAsFixed(1)} kg, ${profile.heightCm!.round()} cm');
      if (targets.estimatedBodyFatPercent != null) {
        buf.write(
            ', ~${targets.estimatedBodyFatPercent!.toStringAsFixed(1)}% grasa (${targets.bodyFatSource.shortBadge})');
      }
      buf.writeln('.');
    }
    buf.writeln(
        '- Objetivo corporal: ${targets.effectiveGoal.label} (${targets.effectiveGoal.subtitle}).');
    buf.writeln(
        '- Meta diaria calculada: ${targets.caloriesKcal} kcal | ${targets.proteinGrams.round()}g proteína | ${targets.carbsGrams.round()}g carbos | ${targets.fatGrams.round()}g grasas.');
    buf.writeln(
        '- Ya consumió hoy: $consumedCalories kcal y ${consumedProtein.round()}g proteína.');
    if (isOverCalories) {
      buf.writeln(
          '- Ya superó sus calorías diarias: sugiere opciones ligeras, altas en verduras y proteína magra, evitando frituras y harinas.');
    } else {
      buf.writeln(
          '- Saldo disponible hoy: ~$remainingCalories kcal y ~${remainingProtein.round()}g de proteína pendientes. Ajusta el tipo de plato y tamaño de porción para ayudar a cubrir ese saldo sin excederlo.');
    }
    return buf.toString();
  }

  @override
  List<Object?> get props => [
        targets,
        consumedCalories,
        consumedProtein,
        consumedCarbs,
        consumedFat,
      ];
}

/// Calculadora pura de composición corporal, % grasa (US Navy) y metas de macros.
class BodyNutritionCalculator {
  const BodyNutritionCalculator._();

  static double _log10(double x) => math.log(x) / math.ln10;

  /// Fórmula estándar US Navy (Hodgdon-Beckett) en centímetros.
  /// Devuelve `null` si las medidas están incompletas o son inválidas.
  static double? calculateUsNavyBodyFat({
    required BiologicalSex sex,
    required double heightCm,
    required double neckCm,
    required double waistCm,
    double? hipCm,
  }) {
    if (heightCm < 100 || neckCm < 20 || waistCm < 40) return null;
    double bf;
    if (sex == BiologicalSex.male) {
      final diff = waistCm - neckCm;
      if (diff <= 1.0) return null;
      final denom = 1.0324 - 0.19077 * _log10(diff) + 0.15456 * _log10(heightCm);
      if (denom <= 0.1) return null;
      bf = 495.0 / denom - 450.0;
    } else {
      if (hipCm == null || hipCm < 50) return null;
      final sum = waistCm + hipCm - neckCm;
      if (sum <= 1.0) return null;
      final denom = 1.29579 - 0.35004 * _log10(sum) + 0.22100 * _log10(heightCm);
      if (denom <= 0.1) return null;
      bf = 495.0 / denom - 450.0;
    }
    if (bf.isNaN || bf.isInfinite) return null;
    return double.parse(bf.clamp(4.0, 55.0).toStringAsFixed(1));
  }

  /// Determina el % de grasa priorizando: Manual > US Navy > Est. visual Escáner.
  static ({double? percent, BodyFatSource source}) resolveBodyFat(
    BodyCompositionProfile profile,
  ) {
    if (profile.manualBodyFatPercent != null &&
        profile.manualBodyFatPercent! >= 3 &&
        profile.manualBodyFatPercent! <= 60) {
      return (
        percent:
            double.parse(profile.manualBodyFatPercent!.toStringAsFixed(1)),
        source: BodyFatSource.manual,
      );
    }

    if (profile.heightCm != null &&
        profile.neckCm != null &&
        profile.waistCm != null) {
      final navy = calculateUsNavyBodyFat(
        sex: profile.sex,
        heightCm: profile.heightCm!,
        neckCm: profile.neckCm!,
        waistCm: profile.waistCm!,
        hipCm: profile.hipCm,
      );
      if (navy != null) {
        return (percent: navy, source: BodyFatSource.usNavy);
      }
    }

    if (profile.hasVisualEstimate) {
      final avg = (profile.visualBodyFatMin! + profile.visualBodyFatMax!) / 2.0;
      return (
        percent: double.parse(avg.clamp(5.0, 55.0).toStringAsFixed(1)),
        source: BodyFatSource.visualEstimate,
      );
    }

    return (percent: null, source: BodyFatSource.none);
  }

  /// Categoría descriptiva simple del % de grasa según sexo biológico.
  static String bodyFatCategory(double bf, BiologicalSex sex) {
    if (sex == BiologicalSex.male) {
      if (bf < 14) return 'Atlético / Definido';
      if (bf < 18) return 'Fitness';
      if (bf < 25) return 'Promedio saludable';
      return 'Alto (ideal priorizar déficit)';
    } else {
      if (bf < 21) return 'Atlético / Definido';
      if (bf < 25) return 'Fitness';
      if (bf < 32) return 'Promedio saludable';
      return 'Alto (ideal priorizar déficit)';
    }
  }

  /// Calcula metas diarias reales; si el perfil está vacío usa un respaldo seguro.
  static DailyNutritionTargets calculateTargets(
    BodyCompositionProfile profile, {
    NutritionGoal? fallbackGoal,
  }) {
    final resolved = resolveBodyFat(profile);
    final goal = profile.hasCoreMetrics
        ? profile.goalMode
        : (fallbackGoal != null
            ? BodyGoalMode.fromNutritionGoal(fallbackGoal)
            : profile.goalMode);

    if (!profile.hasCoreMetrics) {
      return switch (goal) {
        BodyGoalMode.muscleGain => const DailyNutritionTargets(
            caloriesKcal: 2450,
            proteinGrams: 135,
            carbsGrams: 300,
            fatGrams: 75,
            fiberGrams: 30,
            waterLiters: 2.5,
            bmrKcal: 1650,
            tdeeKcal: 2200,
            isPersonalized: false,
            effectiveGoal: BodyGoalMode.muscleGain,
            summaryNote:
                'Meta genérica · configura tu peso y estatura para personalizarla',
          ),
        BodyGoalMode.fatLoss => const DailyNutritionTargets(
            caloriesKcal: 1750,
            proteinGrams: 115,
            carbsGrams: 175,
            fatGrams: 55,
            fiberGrams: 28,
            waterLiters: 2.25,
            bmrKcal: 1600,
            tdeeKcal: 2100,
            isPersonalized: false,
            effectiveGoal: BodyGoalMode.fatLoss,
            summaryNote:
                'Meta genérica · configura tu peso y estatura para personalizarla',
          ),
        BodyGoalMode.recomposition => const DailyNutritionTargets(
            caloriesKcal: 2050,
            proteinGrams: 135,
            carbsGrams: 215,
            fatGrams: 65,
            fiberGrams: 30,
            waterLiters: 2.5,
            bmrKcal: 1650,
            tdeeKcal: 2150,
            isPersonalized: false,
            effectiveGoal: BodyGoalMode.recomposition,
            summaryNote:
                'Meta genérica · configura tu peso y estatura para personalizarla',
          ),
        BodyGoalMode.maintain => const DailyNutritionTargets(
            caloriesKcal: 2100,
            proteinGrams: 100,
            carbsGrams: 255,
            fatGrams: 68,
            fiberGrams: 28,
            waterLiters: 2.0,
            bmrKcal: 1600,
            tdeeKcal: 2100,
            isPersonalized: false,
            effectiveGoal: BodyGoalMode.maintain,
            summaryNote:
                'Meta genérica · configura tu peso y estatura para personalizarla',
          ),
      };
    }

    final weight = profile.weightKg!;
    final height = profile.heightCm!;
    final age = (profile.age ?? 28).clamp(15, 90);
    final heightM = height / 100.0;
    final bmi = double.parse((weight / (heightM * heightM)).toStringAsFixed(1));

    final double? leanMassKg = resolved.percent != null
        ? double.parse(
            (weight * (1.0 - resolved.percent! / 100.0)).toStringAsFixed(1))
        : null;

    // BMR: Katch-McArdle cuando tenemos % grasa confiable (manual o US Navy),
    // Mifflin-St Jeor en caso contrario.
    final bool useKatch = leanMassKg != null &&
        (resolved.source == BodyFatSource.manual ||
            resolved.source == BodyFatSource.usNavy);

    final double bmrRaw = useKatch
        ? 370.0 + 21.6 * leanMassKg
        : (10.0 * weight +
            6.25 * height -
            5.0 * age +
            (profile.sex == BiologicalSex.male ? 5.0 : -161.0));
    final bmr = bmrRaw.round().clamp(1100, 3200);
    final tdee = (bmr * profile.activityLevel.multiplier).round();

    final double deltaFactor = switch (goal) {
      BodyGoalMode.fatLoss => 0.82,
      BodyGoalMode.recomposition => 0.95,
      BodyGoalMode.muscleGain => 1.12,
      BodyGoalMode.maintain => 1.00,
    };

    final minSafeKcal = profile.sex == BiologicalSex.male ? 1500 : 1300;
    final targetKcal = (tdee * deltaFactor).round().clamp(minSafeKcal, 4500);

    // Proteína basada en masa magra cuando está disponible, o peso ajustado.
    final proteinBaseKg = leanMassKg ?? weight;
    final proteinFactor = switch (goal) {
      BodyGoalMode.fatLoss => leanMassKg != null ? 2.1 : 1.8,
      BodyGoalMode.recomposition => leanMassKg != null ? 2.2 : 1.9,
      BodyGoalMode.muscleGain => leanMassKg != null ? 2.1 : 1.85,
      BodyGoalMode.maintain => leanMassKg != null ? 1.7 : 1.5,
    };
    final proteinG = (proteinBaseKg * proteinFactor).clamp(65.0, 240.0);

    final fatRatio = goal == BodyGoalMode.maintain ? 0.28 : 0.25;
    final fatG = ((targetKcal * fatRatio) / 9.0).clamp(40.0, 140.0);
    final remainingForCarbs = targetKcal - (proteinG * 4.0) - (fatG * 9.0);
    final carbsG = (remainingForCarbs / 4.0).clamp(70.0, 600.0);
    final fiberG = ((targetKcal / 1000.0) * 14.0).clamp(22.0, 45.0);
    final waterL =
        double.parse((weight * 0.035).clamp(2.0, 4.0).toStringAsFixed(2));

    final formulaUsed = useKatch ? 'Katch-McArdle' : 'Mifflin-St Jeor';
    return DailyNutritionTargets(
      caloriesKcal: targetKcal,
      proteinGrams: double.parse(proteinG.toStringAsFixed(0)),
      carbsGrams: double.parse(carbsG.toStringAsFixed(0)),
      fatGrams: double.parse(fatG.toStringAsFixed(0)),
      fiberGrams: double.parse(fiberG.toStringAsFixed(0)),
      waterLiters: waterL,
      bmrKcal: bmr,
      tdeeKcal: tdee,
      estimatedBodyFatPercent: resolved.percent,
      bodyFatSource: resolved.source,
      leanMassKg: leanMassKg,
      bmi: bmi,
      isPersonalized: true,
      effectiveGoal: goal,
      summaryNote:
          'Calculado con $formulaUsed · TDEE ~$tdee kcal (${profile.activityLevel.shortLabel})',
    );
  }
}
