import 'package:core/core.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/foodcoach_provider.dart';
import 'widgets/body_profile_sheet.dart';

class StatsTab extends ConsumerStatefulWidget {
  const StatsTab({super.key});

  @override
  ConsumerState<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends ConsumerState<StatsTab> {
  static const _analyticsUseCase = ConsumptionAnalyticsUseCase();
  bool _loadingReview = false;
  String? _aiWeeklyReview;

  Future<void> _requestWeeklyAiReview(
    WeeklyStats stats,
    ConsumptionAnalytics analytics,
    BodyCompositionProfile bodyProfile,
    DailyNutritionTargets targets,
  ) async {
    setState(() => _loadingReview = true);
    try {
      final ctx = StringBuffer()
        ..writeln('- Comidas últimos 7 días: ${stats.totalMeals}')
        ..writeln(
            '- Score promedio: ${(stats.averageHealthScore * 100).round()}/100 (Saludables: ${stats.healthyCount}, Balanceadas: ${stats.balancedCount}, Chatarra: ${stats.junkCount})')
        ..writeln(
            '- Promedio diario real: ~${stats.avgDailyCalories} kcal, ${stats.avgDailyProtein}g proteína')
        ..writeln(
            '- Meta diaria personalizada (${targets.effectiveGoal.label}): ${targets.caloriesKcal} kcal, ${targets.proteinGrams.round()}g proteína, ${targets.carbsGrams.round()}g carbos, ${targets.fatGrams.round()}g grasas (TDEE ~${targets.tdeeKcal} kcal)');

      if (bodyProfile.hasCoreMetrics) {
        ctx.writeln(
            '- Perfil corporal: ${bodyProfile.weightKg!.toStringAsFixed(1)} kg, ${bodyProfile.heightCm!.round()} cm, ${bodyProfile.sex.label}, actividad ${bodyProfile.activityLevel.shortLabel}');
      }
      if (targets.estimatedBodyFatPercent != null) {
        ctx.writeln(
            '- Grasa corporal estimada: ~${targets.estimatedBodyFatPercent!.toStringAsFixed(1)}% (${targets.bodyFatSource.label})${targets.leanMassKg != null ? ', masa magra ~${targets.leanMassKg} kg' : ''}');
      }
      if (bodyProfile.history.length >= 2) {
        final first = bodyProfile.history.first;
        final last = bodyProfile.history.last;
        final wDelta = last.weightKg - first.weightKg;
        ctx.writeln(
            '- Evolución registrada (${bodyProfile.history.length} check-ins): peso ${wDelta >= 0 ? '+' : ''}${wDelta.toStringAsFixed(1)} kg (${first.weightKg.toStringAsFixed(1)} -> ${last.weightKg.toStringAsFixed(1)} kg)');
      }

      ctx
        ..writeln(
            '- Platos más repetidos: ${analytics.topMeals.map((e) => '${e.name} (${e.count}x)').join(', ')}')
        ..writeln(
            '- Frutas consumidas: ${analytics.topFruits.isEmpty ? 'ninguna registrada' : analytics.topFruits.map((e) => '${e.name} (${e.count}x)').join(', ')}')
        ..writeln(
            '- Verduras consumidas: ${analytics.topVegetables.isEmpty ? 'ninguna registrada' : analytics.topVegetables.map((e) => '${e.name} (${e.count}x)').join(', ')}')
        ..writeln(
            '- Proteínas frecuentes: ${analytics.topProteins.map((e) => '${e.name} (${e.count}x)').join(', ')}')
        ..writeln('- Preparaciones fritas: ${analytics.friedMealsCount}');

      final reply = await ref.read(geminiProvider).reviewWeeklyNutritionGemini(
            summaryContext: ctx.toString(),
            goalLabel:
                '${targets.effectiveGoal.emoji} ${targets.effectiveGoal.label}',
          );
      if (mounted) {
        setState(() {
          _aiWeeklyReview = (reply == null || reply.trim().isEmpty)
              ? 'No se pudo generar la revisión ahora (verifica tu conexión).'
              : reply.trim();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiWeeklyReview = 'Error al consultar IA: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodCoachProvider);
    final stats = state.weeklyStats;
    final waterGlasses = ref.watch(dailyWaterProvider);
    final bodyProfile = ref.watch(bodyProfileProvider);
    final activeGoal = ref.watch(foodCoachNutritionGoalProvider).asData?.value ??
        NutritionGoal.maintain;
    final targets = BodyNutritionCalculator.calculateTargets(
      bodyProfile,
      fallbackGoal: activeGoal,
    );
    final analytics = _analyticsUseCase(state.history, lastDays: 30);

    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (state.isLoading && stats == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00C896)),
      );
    }

    if (state.error != null && stats == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Error al cargar estadísticas',
                style: TextStyle(
                    color: onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.6), fontSize: 12),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(foodCoachProvider.notifier).load(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Perfil Corporal y Meta Real (compartido con Armario y Cocina) ─
          _BodyCompositionCard(
            profile: bodyProfile,
            targets: targets,
            onEdit: () => showBodyProfileSheet(context),
          ),
          const SizedBox(height: 14),

          // ── Hidratación diaria (personalizada por peso) ──────────────────
          _WaterTrackerCard(
            glasses: waterGlasses,
            goalGlasses: targets.waterGlasses,
            onDecrement: () =>
                ref.read(dailyWaterProvider.notifier).decrement(),
            onIncrement: () =>
                ref.read(dailyWaterProvider.notifier).increment(),
          ),
          const SizedBox(height: 16),

          if (stats == null || stats.totalMeals == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_outlined,
                        size: 58, color: onSurface.withValues(alpha: 0.18)),
                    const SizedBox(height: 12),
                    Text('Aún no hay comidas evaluadas esta semana',
                        style: TextStyle(
                            color: onSurface.withValues(alpha: 0.55),
                            fontSize: 15)),
                    const SizedBox(height: 6),
                    Text(
                      'Evalúa tus comidas o envíalas desde Cocina para ver tus macros, frutas, verduras y platos frecuentes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: onSurface.withValues(alpha: 0.42),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // ── Macros de HOY vs Meta Personalizada ─────────────────────────
            _DailyMacrosCard(
              stats: stats,
              targets: targets,
              onConfigureProfile: () => showBodyProfileSheet(context),
            ),
            const SizedBox(height: 16),

            // ── Resumen semanal ─────────────────────────────────────────────
            Text('RESUMEN SEMANAL',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _scoreColor(stats.averageHealthScore).withAlpha(40),
                    _scoreColor(stats.averageHealthScore).withAlpha(10),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Text('${(stats.averageHealthScore * 100).round()}',
                      style: TextStyle(
                          color: _scoreColor(stats.averageHealthScore),
                          fontSize: 54,
                          fontWeight: FontWeight.w900)),
                  Text(
                      'puntos promedio · ${stats.totalMeals} comida(s) esta semana',
                      style: TextStyle(
                          color: _scoreColor(stats.averageHealthScore)
                              .withAlpha(200),
                          fontSize: 12)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: stats.averageHealthScore,
                      backgroundColor: onSurface.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _scoreColor(stats.averageHealthScore)),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _ClassCard(
                        emoji: '💚',
                        label: 'Saludable',
                        count: stats.healthyCount,
                        total: stats.totalMeals,
                        color: const Color(0xFF4CAF50))),
                const SizedBox(width: 8),
                Expanded(
                    child: _ClassCard(
                        emoji: '💛',
                        label: 'Balanceado',
                        count: stats.balancedCount,
                        total: stats.totalMeals,
                        color: const Color(0xFFFFB74D))),
                const SizedBox(width: 8),
                Expanded(
                    child: _ClassCard(
                        emoji: '🔴',
                        label: 'Chatarra',
                        count: stats.junkCount,
                        total: stats.totalMeals,
                        color: const Color(0xFFFF5252))),
              ],
            ),
            const SizedBox(height: 16),

            // ── Analítica de consumo (últimos 30 días) ──────────────────────
            if (analytics.totalMealsAnalyzed > 0) ...[
              Text('QUÉ CONSUMES MÁS (30 DÍAS)',
                  style: TextStyle(
                      color: onSurface.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4)),
              const SizedBox(height: 10),
              if (analytics.topMeals.isNotEmpty) ...[
                _TopChipsCard(
                  title: '🏆 Platos / Recetas más repetidos',
                  accent: const Color(0xFFFF9800),
                  entries: analytics.topMeals
                      .map((e) => '${e.name} (${e.count}x)')
                      .toList(),
                ),
                const SizedBox(height: 10),
              ],
              _TopChipsCard(
                title: '🍎 Frutas más consumidas',
                accent: const Color(0xFF00C896),
                emptyLabel: 'Sin frutas registradas aún en este periodo',
                entries: analytics.topFruits
                    .map((e) => '${e.name} (${e.count}x)')
                    .toList(),
              ),
              const SizedBox(height: 10),
              _TopChipsCard(
                title: '🥦 Verduras más consumidas',
                accent: const Color(0xFF4CAF50),
                emptyLabel: 'Sin verduras registradas aún en este periodo',
                entries: analytics.topVegetables
                    .map((e) => '${e.name} (${e.count}x)')
                    .toList(),
              ),
              const SizedBox(height: 10),
              if (analytics.topProteins.isNotEmpty) ...[
                _TopChipsCard(
                  title: '🍗 Proteínas frecuentes',
                  accent: const Color(0xFF00F0FF),
                  entries: analytics.topProteins
                      .map((e) => '${e.name} (${e.count}x)')
                      .toList(),
                ),
                const SizedBox(height: 10),
              ],
              if (analytics.balanceAlerts.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF00C896).withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚖️ Balance nutricional detectado',
                        style: TextStyle(
                          color: Color(0xFF00C896),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final alert in analytics.balanceAlerts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            alert,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: onSurface.withValues(alpha: 0.78),
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],

            // ── Revisión semanal con Nutricionista IA ───────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingReview
                    ? null
                    : () => _requestWeeklyAiReview(
                          stats,
                          analytics,
                          bodyProfile,
                          targets,
                        ),
                icon: _loadingReview
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome,
                        size: 16, color: Color(0xFF00C896)),
                label: Text(
                  _loadingReview
                      ? 'Analizando tu semana...'
                      : '✨ Revisión del Nutricionista IA',
                  style: const TextStyle(
                    color: Color(0xFF00C896),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00C896)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (_aiWeeklyReview != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C896).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF00C896).withValues(alpha: 0.35)),
                ),
                child: Text(
                  _aiWeeklyReview!,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: onSurface.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.68) return const Color(0xFF4CAF50);
    if (score >= 0.40) return const Color(0xFFFFB74D);
    return const Color(0xFFFF5252);
  }
}

class _BodyCompositionCard extends StatelessWidget {
  final BodyCompositionProfile profile;
  final DailyNutritionTargets targets;
  final VoidCallback onEdit;

  const _BodyCompositionCard({
    required this.profile,
    required this.targets,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bf = targets.estimatedBodyFatPercent;
    final hasHistory = profile.history.length >= 2;
    double? weightDelta;
    if (hasHistory) {
      weightDelta =
          profile.history.last.weightKg - profile.history.first.weightKg;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C896).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧬', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.hasCoreMetrics
                          ? 'Tu Perfil Corporal (${targets.effectiveGoal.emoji} ${targets.effectiveGoal.label})'
                          : 'Configura tu Perfil Corporal',
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      targets.summaryNote,
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.58),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: Icon(
                  profile.hasCoreMetrics ? Icons.tune : Icons.add_circle_outline,
                  size: 16,
                  color: const Color(0xFF00C896),
                ),
                label: Text(
                  profile.hasCoreMetrics ? 'Editar' : 'Configurar',
                  style: const TextStyle(
                    color: Color(0xFF00C896),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (profile.hasCoreMetrics) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _metricPill(
                  context,
                  '⚖️ ${profile.weightKg!.toStringAsFixed(1)} kg',
                  const Color(0xFF00F0FF),
                ),
                if (bf != null)
                  _metricPill(
                    context,
                    '📐 ~${bf.toStringAsFixed(1)}% grasa (${targets.bodyFatSource.shortBadge})',
                    const Color(0xFFFFB74D),
                  ),
                if (targets.leanMassKg != null)
                  _metricPill(
                    context,
                    '💪 Magra ${targets.leanMassKg} kg',
                    const Color(0xFF00C896),
                  ),
                if (targets.bmi != null)
                  _metricPill(
                    context,
                    'IMC ${targets.bmi}',
                    onSurface.withValues(alpha: 0.72),
                  ),
              ],
            ),
            if (bf != null) ...[
              const SizedBox(height: 6),
              Text(
                'Categoría aprox.: ${BodyNutritionCalculator.bodyFatCategory(bf, profile.sex)}'
                '${targets.bodyFatSource == BodyFatSource.visualEstimate ? ' · Afínalo con cinta (US Navy) tocando Editar' : ''}',
                style: TextStyle(
                  fontSize: 11,
                  color: onSurface.withValues(alpha: 0.62),
                ),
              ),
            ],
            if (weightDelta != null) ...[
              const SizedBox(height: 6),
              Text(
                '📈 Evolución (${profile.history.length} check-ins): ${weightDelta >= 0 ? '+' : ''}${weightDelta.toStringAsFixed(1)} kg desde tu primer registro',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00C896),
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Ingresa tu estatura, peso y medidas (o usa el Escáner Físico de Armario) para calcular tu % de grasa, TDEE y guiar automáticamente a FoodCoach y Cocina.',
              style: TextStyle(
                fontSize: 11.5,
                color: onSurface.withValues(alpha: 0.65),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricPill(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _WaterTrackerCard extends StatelessWidget {
  final int glasses;
  final int goalGlasses;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _WaterTrackerCard({
    required this.glasses,
    this.goalGlasses = 8,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final goal = goalGlasses.clamp(6, 16);
    final progress = (glasses / goal).clamp(0.0, 1.0);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF29B6F6).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('💧', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hidratación de hoy',
                      style: TextStyle(
                        color: onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    Text(
                      '$glasses / $goal vasos (${(glasses * 0.25).toStringAsFixed(2)} L · meta ${(goal * 0.25).toStringAsFixed(2)} L)',
                      style: TextStyle(
                        color: onSurface.withValues(alpha: 0.6),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline,
                    color: Color(0xFF29B6F6)),
                onPressed: glasses > 0 ? onDecrement : null,
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon:
                    const Icon(Icons.add_circle, color: Color(0xFF29B6F6)),
                onPressed: onIncrement,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: onSurface.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF29B6F6)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyMacrosCard extends StatelessWidget {
  final WeeklyStats stats;
  final DailyNutritionTargets targets;
  final VoidCallback onConfigureProfile;

  const _DailyMacrosCard({
    required this.stats,
    required this.targets,
    required this.onConfigureProfile,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final kcalRatio =
        (stats.todayCalories / targets.caloriesKcal).clamp(0.0, 1.0);
    final protRatio =
        (stats.todayProtein / targets.proteinGrams).clamp(0.0, 1.0);
    final budget = DailyMacroBudget(
      targets: targets,
      consumedCalories: stats.todayCalories,
      consumedProtein: stats.todayProtein,
      consumedCarbs: stats.todayCarbs,
      consumedFat: stats.todayFat,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C896).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📊', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Macros de hoy (${targets.effectiveGoal.emoji} ${targets.effectiveGoal.label})',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (stats.avgDailyCalories > 0)
                Text(
                  'Prom: ${stats.avgDailyCalories} kcal/d',
                  style: TextStyle(
                    fontSize: 11,
                    color: onSurface.withValues(alpha: 0.55),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressBarRow(
            label: '🔥 Calorías',
            valueText: '${stats.todayCalories} / ${targets.caloriesKcal} kcal',
            progress: kcalRatio,
            color: const Color(0xFFFF9800),
          ),
          const SizedBox(height: 8),
          _ProgressBarRow(
            label: '💪 Proteína',
            valueText:
                '${stats.todayProtein.toStringAsFixed(0)} / ${targets.proteinGrams.toStringAsFixed(0)} g',
            progress: protRatio,
            color: const Color(0xFF00C896),
          ),
          const SizedBox(height: 8),
          Text(
            'Carbos: ${stats.todayCarbs.round()}/${targets.carbsGrams.round()}g  ·  Grasas: ${stats.todayFat.round()}/${targets.fatGrams.round()}g  ·  Fibra: ${stats.todayFiber.round()}/${targets.fiberGrams.round()}g',
            style: TextStyle(
              fontSize: 11.5,
              color: onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: (budget.isOverCalories
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFF00C896))
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '🎯 ${budget.shortGuidance}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: budget.isOverCalories
                          ? const Color(0xFFFFB74D)
                          : const Color(0xFF00C896),
                    ),
                  ),
                ),
                if (!targets.isPersonalized)
                  TextButton(
                    onPressed: onConfigureProfile,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Personalizar',
                      style: TextStyle(fontSize: 11, color: Color(0xFF00C896)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBarRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double progress;
  final Color color;

  const _ProgressBarRow({
    required this.label,
    required this.valueText,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: onSurface)),
            Text(valueText,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: onSurface.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _TopChipsCard extends StatelessWidget {
  final String title;
  final Color accent;
  final List<String> entries;
  final String? emptyLabel;

  const _TopChipsCard({
    required this.title,
    required this.accent,
    required this.entries,
    this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: onSurface,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Text(
              emptyLabel ?? 'Sin datos todavía',
              style: TextStyle(
                fontSize: 11.5,
                color: onSurface.withValues(alpha: 0.5),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: entries
                  .map(
                    (e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        e,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final String emoji;
  final String label;
  final int count;
  final int total;
  final Color color;

  const _ClassCard({
    required this.emoji,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : ((count / total) * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          Text('$pct%',
              style: TextStyle(color: color.withAlpha(180), fontSize: 11)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                  fontSize: 10),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
