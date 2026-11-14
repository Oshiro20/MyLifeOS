import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/foodcoach_provider.dart';

class EvaluateTab extends ConsumerStatefulWidget with AppFeedback {
  const EvaluateTab({super.key});

  @override
  ConsumerState<EvaluateTab> createState() => _EvaluateTabState();
}

class _EvaluateTabState extends ConsumerState<EvaluateTab> {
  final _ingredientCtrl = TextEditingController();
  String? _photoPath;

  @override
  void dispose() {
    _ingredientCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(foodCoachProvider);
    final canEvaluate = state.currentIngredients.isNotEmpty || _photoPath != null;

    // Mostrar resultado si hay evaluación
    if (state.currentEvaluation != null) {
      return _ResultView(
        evaluation: state.currentEvaluation!,
        onReset: () {
          setState(() => _photoPath = null);
          ref.read(foodCoachProvider.notifier).clearResult();
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: Theme.of(context).brightness == Brightness.dark
                    ? const [Color(0xFF152019), Color(0xFF1A2E22)]
                    : [
                        const Color(0xFF00C896).withValues(alpha: 0.12),
                        const Color(0xFF00C896).withValues(alpha: 0.05),
                      ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00C896).withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined,
                    color: Color(0xFF00C896), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Ingresa los ingredientes de tu comida y te diré si es saludable.',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.78),
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Foto opcional
          Text('Foto (opcional)',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.12)),
              ),
              child: _photoPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_photoPath!),
                          fit: BoxFit.cover, width: double.infinity),
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.35),
                              size: 32),
                          const SizedBox(height: 6),
                          Text('Toca para añadir foto',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.4),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Input de ingredientes
          Text('Ingredientes',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ingredientCtrl,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  textInputAction: TextInputAction.done,
                  onSubmitted: _addIngredient,
                  decoration: InputDecoration(
                    hintText: 'ej: pollo, brócoli, arroz…',
                    hintStyle: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38)),
                    prefixIcon: const Icon(Icons.add_circle_outline,
                        color: Color(0xFF00C896), size: 20),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF00C896), width: 1.5)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                ),
                onPressed: () => _addIngredient(_ingredientCtrl.text),
                child: const Text('Añadir',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chips de ingredientes
          if (state.currentIngredients.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: state.currentIngredients.map((ing) {
                return Chip(
                  label: Text(ing,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12)),
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  deleteIcon: Icon(Icons.close,
                      size: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45)),
                  onDeleted: () => ref
                      .read(foodCoachProvider.notifier)
                      .removeIngredient(ing),
                  padding: EdgeInsets.zero,
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () =>
                  ref.read(foodCoachProvider.notifier).clearIngredients(),
              icon: Icon(Icons.clear_all,
                  size: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5)),
              label: Text('Limpiar todo',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontSize: 12)),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Aún no hay ingredientes.',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.38),
                      fontSize: 13)),
            ),

          // Sugerencias rápidas
          const SizedBox(height: 8),
          Text('Sugerencias rápidas',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickSuggestions
                .map((s) => ActionChip(
                      label: Text(s,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.54),
                              fontSize: 11)),
                      backgroundColor: Theme.of(context).cardColor,
                      onPressed: () =>
                          ref.read(foodCoachProvider.notifier).addIngredient(s),
                      padding: EdgeInsets.zero,
                    ))
                .toList(),
          ),

          const SizedBox(height: 28),

          // Error si falló la evaluación
          if (state.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withAlpha(80)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Botón evaluar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: !canEvaluate
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.12)
                    : const Color(0xFF00C896),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: !canEvaluate || state.isEvaluating
                  ? null
                  : () async {
                      final selectedPhoto = _photoPath;
                      await ref
                          .read(foodCoachProvider.notifier)
                          .evaluate(photoPath: selectedPhoto);
                      if (mounted &&
                          ref.read(foodCoachProvider).currentEvaluation != null) {
                        setState(() => _photoPath = null);
                      }
                    },
              icon: state.isEvaluating
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.analytics_outlined, color: Colors.white),
              label: Text(
                state.isEvaluating ? 'Evaluando…' : 'Evaluar comida',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _quickSuggestions = [
    'pollo',
    'arroz',
    'ensalada',
    'brócoli',
    'salmón',
    'papas fritas',
    'hamburguesa',
    'pizza',
    'tomate',
    'aguacate',
    'yogur',
    'avena',
    'huevo',
    'atún',
    'quinoa',
  ];

  void _addIngredient(String text) {
    if (text.trim().isEmpty) return;
    ref.read(foodCoachProvider.notifier).addIngredient(text);
    _ingredientCtrl.clear();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null) {
      final compressedFile = await ImageCompressionUtil.compressImage(
        originalFile: File(picked.path),
        subfolder: 'meals',
        deleteOriginal: true,
      );
      if (mounted) {
        setState(() => _photoPath = compressedFile.path);
      }
    }
  }
}

// ── Resultado de evaluación ───────────────────────────────────────────────────
class _ResultView extends StatelessWidget {
  final MealEvaluation evaluation;
  final VoidCallback onReset;

  const _ResultView({required this.evaluation, required this.onReset});

  Color get _classColor {
    switch (evaluation.classification) {
      case FoodClassification.healthy:
        return const Color(0xFF4CAF50);
      case FoodClassification.balanced:
        return const Color(0xFFFFB74D);
      case FoodClassification.junk:
        return const Color(0xFFFF5252);
    }
  }

  String get _classEmoji {
    switch (evaluation.classification) {
      case FoodClassification.healthy:
        return '💚';
      case FoodClassification.balanced:
        return '💛';
      case FoodClassification.junk:
        return '🔴';
    }
  }

  String get _classLabel {
    switch (evaluation.classification) {
      case FoodClassification.healthy:
        return 'Saludable';
      case FoodClassification.balanced:
        return 'Balanceado';
      case FoodClassification.junk:
        return 'No recomendable';
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = (evaluation.healthScore * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Foto si existe
          if (evaluation.photoPath != null &&
              File(evaluation.photoPath!).existsSync()) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(evaluation.photoPath!),
                  width: double.infinity, height: 160, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
          ],

          // Clasificación central
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_classColor.withAlpha(40), _classColor.withAlpha(15)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _classColor.withAlpha(80), width: 1.5),
            ),
            child: Column(
              children: [
                Text(_classEmoji, style: const TextStyle(fontSize: 56)),
                const SizedBox(height: 8),
                Text(_classLabel,
                    style: TextStyle(
                        color: _classColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                // Barra de salud
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: evaluation.healthScore,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(_classColor),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Puntuación de salud: $score / 100',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.54),
                        fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Feedback
          _InfoCard(
            icon: Icons.chat_bubble_outline,
            title: 'Análisis',
            content: evaluation.feedback,
          ),
          const SizedBox(height: 10),

          // Factores positivos
          if (evaluation.positiveFactors.isNotEmpty)
            _InfoCard(
              icon: Icons.thumb_up_outlined,
              title: 'Lo que suma ✓',
              color: const Color(0xFF4CAF50),
              content: evaluation.positiveFactors.join(', '),
            ),
          if (evaluation.positiveFactors.isNotEmpty) const SizedBox(height: 10),

          // Factores negativos
          if (evaluation.negativeFactors.isNotEmpty)
            _InfoCard(
              icon: Icons.thumb_down_outlined,
              title: 'Lo que resta',
              color: const Color(0xFFFF5252),
              content: evaluation.negativeFactors.join(', '),
            ),
          if (evaluation.negativeFactors.isNotEmpty) const SizedBox(height: 10),

          // Recomendación
          _InfoCard(
            icon: Icons.lightbulb_outline,
            title: 'Consejo',
            color: const Color(0xFF00C896),
            content: evaluation.recommendation,
          ),
          const SizedBox(height: 24),

          // Botón nueva evaluación
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onReset,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Evaluar otra comida',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color? color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.content,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: effectiveColor, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: effectiveColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: effectiveColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                const SizedBox(height: 4),
                Text(content,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
