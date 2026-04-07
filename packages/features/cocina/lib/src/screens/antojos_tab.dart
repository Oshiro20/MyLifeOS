import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import '../providers/what_can_i_cook_provider.dart';
import '../providers/cocina_providers.dart';

/// "Antojos" tab - Shows only cravings (postres, snacks, bebidas)
/// This is a wrapper around SuggestionsTab pre-configured for cravings mode
class AntojosTab extends ConsumerStatefulWidget {
  const AntojosTab({super.key});

  @override
  ConsumerState<AntojosTab> createState() => _AntojosTabState();
}

class _AntojosTabState extends ConsumerState<AntojosTab> {
  @override
  void initState() {
    super.initState();
    // Auto-load cravings on first entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final invState = ref.read(inventoryProvider);
      final aiNotifier = ref.read(whatCanICookProvider.notifier);
      if (invState.ingredients.isNotEmpty && aiNotifier.needsRefresh) {
        aiNotifier.generateSuggestions(mode: SuggestionMode.cravings);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final invState = ref.watch(inventoryProvider);
    final aiState = ref.watch(whatCanICookProvider);
    final aiNotifier = ref.read(whatCanICookProvider.notifier);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('🍫 Antojos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFF9800)),
            onPressed: aiState == WhatCanICookState.loading
                ? null
                : () => aiNotifier.generateSuggestions(
                      mode: SuggestionMode.cravings,
                    ),
            tooltip: 'Obtener nuevos antojos',
          ),
        ],
      ),
      body: invState.ingredients.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.no_food, size: 64, color: Colors.white24),
                  SizedBox(height: 12),
                  Text(
                    'Agrega ingredientes a tu despensa\npara ver sugerencias de antojos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            )
          : _AntojosContent(
              aiState: aiState,
              aiNotifier: aiNotifier,
              onShowDetail: (recipe) => _showRecipeDetail(context, recipe),
            ),
    );
  }

  void _showRecipeDetail(BuildContext context, dynamic recipe) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecipeDetailSheet(recipe: recipe),
    );
  }
}

class _AntojosContent extends StatelessWidget {
  final WhatCanICookState aiState;
  final WhatCanICookNotifier aiNotifier;
  final Function(dynamic) onShowDetail;

  const _AntojosContent({
    required this.aiState,
    required this.aiNotifier,
    required this.onShowDetail,
  });

  @override
  Widget build(BuildContext context) {
    if (aiState == WhatCanICookState.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFFFF9800)),
            SizedBox(height: 16),
            Text(
              'El Chef IA está pensando en antojos...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (aiState == WhatCanICookState.success &&
        aiNotifier.visibleSuggestions.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: aiNotifier.visibleSuggestions.length,
          itemBuilder: (ctx, i) {
            final suggestion = aiNotifier.visibleSuggestions[i];
            return _AntojoCard(
              suggestion: suggestion,
              onTap: () => onShowDetail(suggestion.recipe),
              onSave: () => _saveSuggestion(context, aiNotifier, suggestion),
              onCook: () => _cookSuggestion(context, aiNotifier, suggestion),
            );
          },
        ),
      );
    }

    if (aiState == WhatCanICookState.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              aiNotifier.errorMessage ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => aiNotifier.generateSuggestions(
                mode: SuggestionMode.cravings,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      );
    }

    // Initial state - show prompt to load
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cookie, size: 64, color: Colors.white24),
          const SizedBox(height: 12),
          const Text(
            '¿Qué se te antoja hoy?',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Postres, snacks, bebidas y más...',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => aiNotifier.generateSuggestions(
              mode: SuggestionMode.cravings,
            ),
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Generar Antojos'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9800),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSuggestion(
    BuildContext context,
    WhatCanICookNotifier notifier,
    dynamic suggestion,
  ) async {
    final saved = await notifier.saveSuggestion(suggestion);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(saved
              ? '✅ "${suggestion.recipe.name}" guardada'
              : '❌ Error al guardar'),
          backgroundColor: saved ? const Color(0xFF00E676) : Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _cookSuggestion(
    BuildContext context,
    WhatCanICookNotifier notifier,
    dynamic suggestion,
  ) async {
    final result = await notifier.cookSuggestion(suggestion);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor:
              result.success ? const Color(0xFFFF9800) : Colors.redAccent,
        ),
      );
    }
  }
}

class _AntojoCard extends StatelessWidget {
  final dynamic suggestion;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCook;

  const _AntojoCard({
    required this.suggestion,
    required this.onTap,
    required this.onSave,
    required this.onCook,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = suggestion.recipe;
    final mealType = recipe.tipoComida;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A1F0D), Color(0xFF1F1709)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFF9800).withAlpha(60), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with emoji
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        mealType?.emoji ?? '🍫',
                        style: const TextStyle(fontSize: 28),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${suggestion.matchPercentage}%',
                          style: const TextStyle(
                              color: Color(0xFFFF9800),
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipe.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child:
                          const Text('Guardar', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onCook,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        minimumSize: const Size(0, 28),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child:
                          const Text('Cocinar', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stub for recipe detail - will be replaced with actual implementation
class _RecipeDetailSheet extends StatelessWidget {
  final dynamic recipe;
  const _RecipeDetailSheet({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Recipe detail not implemented')),
    );
  }
}
