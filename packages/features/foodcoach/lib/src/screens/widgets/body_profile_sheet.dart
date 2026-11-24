import 'package:core/core.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Abre el modal de configuración del Perfil Corporal y Meta Calórica Real.
Future<void> showBodyProfileSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _BodyProfileSheet(),
  );
}

class _BodyProfileSheet extends ConsumerStatefulWidget {
  const _BodyProfileSheet();

  @override
  ConsumerState<_BodyProfileSheet> createState() => _BodyProfileSheetState();
}

class _BodyProfileSheetState extends ConsumerState<_BodyProfileSheet> {
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _neckCtrl;
  late final TextEditingController _waistCtrl;
  late final TextEditingController _hipCtrl;
  late final TextEditingController _manualBfCtrl;

  late BiologicalSex _sex;
  late ActivityLevel _activity;
  late BodyGoalMode _goalMode;
  bool _recordCheckIn = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(bodyProfileProvider);
    _heightCtrl = TextEditingController(
      text: p.heightCm != null ? p.heightCm!.toStringAsFixed(0) : '',
    );
    _weightCtrl = TextEditingController(
      text: p.weightKg != null ? p.weightKg!.toStringAsFixed(1) : '',
    );
    _ageCtrl = TextEditingController(
      text: p.age != null ? p.age.toString() : '',
    );
    _neckCtrl = TextEditingController(
      text: p.neckCm != null ? p.neckCm!.toStringAsFixed(1) : '',
    );
    _waistCtrl = TextEditingController(
      text: p.waistCm != null ? p.waistCm!.toStringAsFixed(1) : '',
    );
    _hipCtrl = TextEditingController(
      text: p.hipCm != null ? p.hipCm!.toStringAsFixed(1) : '',
    );
    _manualBfCtrl = TextEditingController(
      text: p.manualBodyFatPercent != null
          ? p.manualBodyFatPercent!.toStringAsFixed(1)
          : '',
    );
    _sex = p.sex;
    _activity = p.activityLevel;
    _goalMode = p.goalMode;
  }

  @override
  void dispose() {
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    _neckCtrl.dispose();
    _waistCtrl.dispose();
    _hipCtrl.dispose();
    _manualBfCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(TextEditingController c) {
    final txt = c.text.trim().replaceAll(',', '.');
    if (txt.isEmpty) return null;
    return double.tryParse(txt);
  }

  BodyCompositionProfile _buildDraft(BodyCompositionProfile base) {
    final neck = _parseDouble(_neckCtrl);
    final waist = _parseDouble(_waistCtrl);
    final hip = _parseDouble(_hipCtrl);
    final manualBf = _parseDouble(_manualBfCtrl);
    return base.copyWith(
      heightCm: _parseDouble(_heightCtrl),
      weightKg: _parseDouble(_weightCtrl),
      age: int.tryParse(_ageCtrl.text.trim()),
      sex: _sex,
      activityLevel: _activity,
      goalMode: _goalMode,
      neckCm: neck,
      waistCm: waist,
      hipCm: hip,
      manualBodyFatPercent: manualBf,
      clearNeck: neck == null,
      clearWaist: waist == null,
      clearHip: hip == null,
      clearManualBodyFat: manualBf == null,
    );
  }

  Future<void> _save() async {
    final base = ref.read(bodyProfileProvider);
    final draft = _buildDraft(base);
    if (!draft.hasCoreMetrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa al menos tu estatura (cm) y peso (kg).'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(bodyProfileProvider.notifier).saveProfile(
            draft,
            recordCheckIn: _recordCheckIn,
            syncCocinaGoal: true,
          );
      ref.read(todayMacrosRefreshTickProvider.notifier).bump();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Perfil corporal guardado · metas actualizadas en FoodCoach y Cocina',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(bodyProfileProvider);
    final draft = _buildDraft(base);
    final preview = BodyNutritionCalculator.calculateTargets(draft);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurface.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('🧬', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perfil Corporal y Meta Real',
                        style: TextStyle(
                          color: onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Calcula tu % grasa (US Navy), TDEE y macros para FoodCoach y Cocina',
                        style: TextStyle(
                          color: onSurface.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Sexo biológico ──────────────────────────────────────────────
            Row(
              children: [
                for (final sex in BiologicalSex.values)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: sex == BiologicalSex.male ? 8 : 0),
                      child: ChoiceChip(
                        label: Center(
                          child: Text('${sex.emoji} ${sex.label}'),
                        ),
                        selected: _sex == sex,
                        onSelected: (_) => setState(() => _sex = sex),
                        selectedColor:
                            const Color(0xFF00C896).withValues(alpha: 0.24),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Estatura, Peso, Edad ────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _numField(
                    controller: _heightCtrl,
                    label: 'Estatura (cm)',
                    hint: '172',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField(
                    controller: _weightCtrl,
                    label: 'Peso (kg)',
                    hint: '74.5',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField(
                    controller: _ageCtrl,
                    label: 'Edad',
                    hint: '27',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Objetivo corporal ───────────────────────────────────────────
            Text(
              'OBJETIVO CORPORAL',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final mode in BodyGoalMode.values)
                  ChoiceChip(
                    label: Text('${mode.emoji} ${mode.label}'),
                    selected: _goalMode == mode,
                    onSelected: (_) => setState(() => _goalMode = mode),
                    selectedColor:
                        const Color(0xFF00C896).withValues(alpha: 0.25),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _goalMode.subtitle,
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.62),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 14),

            // ── Nivel de actividad ──────────────────────────────────────────
            Text(
              'NIVEL DE ACTIVIDAD FÍSICA',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final act in ActivityLevel.values)
                  ChoiceChip(
                    label: Text(act.label, style: const TextStyle(fontSize: 11.5)),
                    selected: _activity == act,
                    onSelected: (_) => setState(() => _activity = act),
                    selectedColor:
                        const Color(0xFF00C896).withValues(alpha: 0.22),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Composición corporal (% grasa) ──────────────────────────────
            Text(
              '% DE GRASA CORPORAL (OPCIONAL · MÁS PRECISO)',
              style: TextStyle(
                color: onSurface.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            if (base.hasVisualEstimate) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFB74D).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  '📸 Referencia visual del Escáner de Armario: ~${base.visualBodyFatMin!.round()}%–${base.visualBodyFatMax!.round()}%'
                  '${base.visualBuildNote != null ? ' · ${base.visualBuildNote}' : ''}\n'
                  'Ingresa cinta métrica o % manual abajo para mayor precisión.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: onSurface.withValues(alpha: 0.8),
                    height: 1.35,
                  ),
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  child: _numField(
                    controller: _neckCtrl,
                    label: 'Cuello (cm)',
                    hint: '38',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _numField(
                    controller: _waistCtrl,
                    label: 'Cintura (cm)',
                    hint: '84',
                  ),
                ),
                if (_sex == BiologicalSex.female) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _numField(
                      controller: _hipCtrl,
                      label: 'Cadera (cm)',
                      hint: '96',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _numField(
              controller: _manualBfCtrl,
              label: '% Grasa manual (si tienes balanza o nutricionista)',
              hint: 'Ej: 18.5 (tiene prioridad sobre US Navy)',
            ),
            const SizedBox(height: 14),

            // ── Vista previa calculada en vivo ──────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00C896).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF00C896).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '🎯 Meta diaria calculada',
                        style: TextStyle(
                          color: Color(0xFF00C896),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      if (preview.estimatedBodyFatPercent != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C896)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '~${preview.estimatedBodyFatPercent!.toStringAsFixed(1)}% grasa (${preview.bodyFatSource.shortBadge})',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF00C896),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _previewChip('🔥 ${preview.caloriesKcal} kcal'),
                      _previewChip('🥩 ${preview.proteinGrams.round()}g prot'),
                      _previewChip('🍚 ${preview.carbsGrams.round()}g carb'),
                      _previewChip('🥑 ${preview.fatGrams.round()}g gras'),
                      _previewChip(
                          '💧 ${preview.waterLiters.toStringAsFixed(1)} L (${preview.waterGlasses} vasos)'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${preview.summaryNote}'
                    '${preview.leanMassKg != null ? ' · Masa magra ~${preview.leanMassKg} kg' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _recordCheckIn,
              onChanged: (v) => setState(() => _recordCheckIn = v ?? true),
              activeColor: const Color(0xFF00C896),
              title: const Text(
                'Registrar punto de seguimiento de hoy en mi historial',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(_saving ? 'Guardando...' : 'Guardar y aplicar metas'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _previewChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }
}
