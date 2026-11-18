import 'package:core/core.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/cocina_providers.dart';
import '../../providers/cooking_session_provider.dart';
import '../../utils/cooking_history_service.dart';

String formatIngredientQty(double qty) {
  if (qty == qty.roundToDouble()) return qty.toInt().toString();
  final s = qty.toStringAsFixed(2);
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

List<RecipeIngredient> scaleRecipeIngredients(
  Recipe recipe,
  int scaledServings,
) {
  final baseServings = recipe.servings > 0 ? recipe.servings : 1;
  final scaleRatio = scaledServings / baseServings;
  return recipe.ingredients
      .map(
        (ing) => RecipeIngredient(
          id: ing.id,
          recipeId: ing.recipeId,
          ingredientName: ing.ingredientName,
          quantity: ing.quantity * scaleRatio,
          unit: ing.unit,
        ),
      )
      .toList();
}

/// Lista de ingredientes con semáforo de disponibilidad real frente a la despensa
/// y botón rápido para mandar faltantes a la Lista de compras.
class RecipeIngredientCheckList extends ConsumerWidget {
  final List<RecipeIngredient> scaledIngredients;
  final bool isScaled;

  const RecipeIngredientCheckList({
    required this.scaledIngredients,
    this.isScaled = false,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory =
        ref.watch(inventoryProvider.select((s) => s.ingredients));
    final shoppingList =
        ref.watch(recipesProvider.select((s) => s.shoppingList));
    final equivalences = ref.watch(ingredientEquivalencesProvider);
    final pendingShoppingKeys = shoppingList
        .where((i) => !i.bought)
        .map((i) => IngredientMatcher.normalizeText(i.name))
        .toSet();

    final checks = IngredientMatcher.evaluateRecipe(
      recipeIngredients: scaledIngredients,
      inventory: inventory,
      customGramsPerUnit: equivalences,
    );

    final theme = Theme.of(context);
    final availableCount = checks
        .where((c) => c.availability == IngredientAvailability.available)
        .length;
    final missingCount = checks
        .where((c) => c.availability != IngredientAvailability.available)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (checks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _summaryChip(
                  color: const Color(0xFF00C896),
                  text: '$availableCount/${checks.length} listos',
                ),
                if (missingCount > 0)
                  _summaryChip(
                    color: Colors.amber,
                    text: '$missingCount por revisar',
                  ),
              ],
            ),
          ),
        ...checks.map((check) {
          final req = check.requirement;
          final (dotColor, subtitleText) = switch (check.availability) {
            IngredientAvailability.available => (
                const Color(0xFF00C896),
                () {
                  final match = check.pantryMatch;
                  if (match == null) return null;
                  final diffName = IngredientMatcher.normalizeText(match.name) !=
                      IngredientMatcher.normalizeText(req.ingredientName);
                  if (check.isApproximateConversion &&
                      check.deductedInPantryUnit != null) {
                    return 'Descontará ≈ ${formatIngredientQty(check.deductedInPantryUnit!)} ${match.unit} de ${match.name}';
                  }
                  if (diffName) {
                    return 'En despensa: ${match.name} (${formatIngredientQty(match.quantity)} ${match.unit})';
                  }
                  return null;
                }(),
              ),
            IngredientAvailability.insufficient => (
                Colors.amber,
                'Tienes ${formatIngredientQty(check.pantryMatch!.quantity)} ${check.pantryMatch!.unit} (te falta)',
              ),
            IngredientAvailability.incompatibleUnit => (
                Colors.orange,
                'En despensa: ${formatIngredientQty(check.pantryMatch!.quantity)} ${check.pantryMatch!.unit} (otra unidad)',
              ),
            IngredientAvailability.missing => (
                Colors.redAccent,
                'No en despensa',
              ),
          };

          final reqKey = IngredientMatcher.normalizeText(req.ingredientName);
          final alreadyInList = pendingShoppingKeys.contains(reqKey);
          final showShoppingAction =
              check.availability == IngredientAvailability.missing ||
                  check.availability == IngredientAvailability.insufficient;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.fiber_manual_record, size: 9, color: dotColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.ingredientName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                      if (subtitleText != null)
                        Text(
                          subtitleText,
                          style: TextStyle(
                            color: dotColor.withValues(alpha: 0.9),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${formatIngredientQty(req.quantity)} ${req.unit}',
                  style: TextStyle(
                    color: isScaled
                        ? const Color(0xFFFF9800)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: isScaled ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (showShoppingAction) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: alreadyInList
                        ? null
                        : () async {
                            final qtyToAdd =
                                check.missingInRecipeUnit ?? req.quantity;
                            await ref
                                .read(recipesProvider.notifier)
                                .addMissingToShoppingList([
                              (
                                name: req.ingredientName,
                                quantity: qtyToAdd,
                                unit: req.unit,
                              )
                            ]);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '🛒 ${req.ingredientName} agregado a Lista de compras'),
                                duration: const Duration(milliseconds: 1600),
                              ),
                            );
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: (alreadyInList
                                ? const Color(0xFF00C896)
                                : Colors.amber)
                            .withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        alreadyInList
                            ? Icons.check
                            : Icons.add_shopping_cart,
                        size: 14,
                        color: alreadyInList
                            ? const Color(0xFF00C896)
                            : Colors.amber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _summaryChip({required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CookConfirmPlan {
  final Set<String> skipPantryIds;
  final bool addMissingToShoppingList;
  final bool addDepletedToShoppingList;

  const _CookConfirmPlan({
    required this.skipPantryIds,
    required this.addMissingToShoppingList,
    required this.addDepletedToShoppingList,
  });
}

/// Flujo unificado al pulsar "¡Cocinar!":
/// - Si faltan ingredientes, hay unidades incompatibles o alguno quedará en 0,
///   abre confirmación editable antes de descontar (nunca bloquea cocinar).
/// - Descuenta lo disponible con `IngredientMatcher`, inicia sesión y ofrece "Deshacer" real.
Future<bool> confirmAndCookRecipe({
  required BuildContext context,
  required Recipe recipe,
  int? scaledServings,
  bool popSheetOnSuccess = false,
}) async {
  final container = ProviderScope.containerOf(context);
  final inventoryNotifier = container.read(inventoryProvider.notifier);
  await inventoryNotifier.load();

  final baseServings = recipe.servings > 0 ? recipe.servings : 1;
  final targetServings = scaledServings ?? baseServings;
  final scaledIngredients = scaleRecipeIngredients(recipe, targetServings);
  final pantryBefore =
      List<InventoryIngredient>.from(container.read(inventoryProvider).ingredients);
  final equivalences = container.read(ingredientEquivalencesProvider);

  final checks = IngredientMatcher.evaluateRecipe(
    recipeIngredients: scaledIngredients,
    inventory: pantryBefore,
    customGramsPerUnit: equivalences,
  );

  final needsConfirmation = checks.any(
    (c) =>
        c.availability != IngredientAvailability.available || c.willDeplete,
  );

  var plan = const _CookConfirmPlan(
    skipPantryIds: {},
    addMissingToShoppingList: false,
    addDepletedToShoppingList: false,
  );

  if (needsConfirmation) {
    if (!context.mounted) return false;
    final confirmed = await showModalBottomSheet<_CookConfirmPlan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _CookConfirmationSheet(
        recipeName: recipe.name,
        checks: checks,
      ),
    );
    if (confirmed == null) return false;
    plan = confirmed;
  }

  // Capturar snapshot exacto solo de ítems que se intentarán descontar.
  final affectedSnapshots = <InventoryIngredient>[];
  final seenSnapshotIds = <String>{};
  for (final check in checks) {
    final pantry = check.pantryMatch;
    if (check.canDeduct &&
        pantry != null &&
        !plan.skipPantryIds.contains(pantry.id) &&
        seenSnapshotIds.add(pantry.id)) {
      final original =
          pantryBefore.where((i) => i.id == pantry.id).firstOrNull;
      if (original != null) affectedSnapshots.add(original);
    }
  }

  final deducted = await inventoryNotifier.deductRecipeIngredients(
    scaledIngredients,
    skipPantryIds: plan.skipPantryIds,
  );

  // Preparar ítems para Lista de compras si el usuario lo activó.
  final shoppingEntries = <({String name, double quantity, String unit})>[];
  if (plan.addMissingToShoppingList) {
    for (final c in checks) {
      if (c.availability == IngredientAvailability.missing ||
          c.availability == IngredientAvailability.insufficient ||
          c.availability == IngredientAvailability.incompatibleUnit) {
        shoppingEntries.add((
          name: c.requirement.ingredientName,
          quantity: c.missingInRecipeUnit ?? c.requirement.quantity,
          unit: c.requirement.unit,
        ));
      }
    }
  }
  if (plan.addDepletedToShoppingList) {
    for (final c in checks) {
      final pantry = c.pantryMatch;
      if (pantry != null &&
          c.willDeplete &&
          !plan.skipPantryIds.contains(pantry.id)) {
        shoppingEntries.add((
          name: pantry.name,
          quantity: c.deductedInPantryUnit ?? c.requirement.quantity,
          unit: pantry.unit,
        ));
      }
    }
  }

  var addedShoppingCount = 0;
  if (shoppingEntries.isNotEmpty) {
    addedShoppingCount = await container
        .read(recipesProvider.notifier)
        .addMissingToShoppingList(shoppingEntries);
  }

  container.read(cookingSessionProvider.notifier).startSession(
        recipeName: recipe.name,
        recipeId: recipe.id,
        originalServings: baseServings,
        scaledServings: targetServings,
        estimatedDurationMinutes: recipe.durationMinutes,
      );
  await CookingHistoryService().recordCooked(recipe.name);

  if (!context.mounted) return true;

  final messenger = ScaffoldMessenger.of(context);
  final summaryParts = <String>[
    if (deducted.isNotEmpty)
      'Descontados: ${deducted.join(", ")}'
    else
      'Cocinado sin descuentos en despensa',
    if (addedShoppingCount > 0) '+$addedShoppingCount en Lista de compras',
  ];

  messenger.showSnackBar(
    SnackBar(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🍳 ¡Cocinando "${recipe.name}" ($targetServings porción${targetServings == 1 ? '' : 'es'})!',
          ),
          const SizedBox(height: 3),
          Text(
            summaryParts.join(' · '),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFFF9800),
      duration: const Duration(milliseconds: 4000),
      action: affectedSnapshots.isEmpty
          ? null
          : SnackBarAction(
              label: 'Deshacer',
              textColor: Colors.white,
              onPressed: () async {
                await inventoryNotifier
                    .restoreCookedIngredients(affectedSnapshots);
                await inventoryNotifier.load();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('↩️ Despensa restaurada'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            ),
    ),
  );

  await inventoryNotifier.load();
  if (popSheetOnSuccess && context.mounted) {
    Navigator.of(context).pop();
  }
  return true;
}

class _CookConfirmationSheet extends ConsumerStatefulWidget {
  final String recipeName;
  final List<RecipeIngredientCheck> checks;

  const _CookConfirmationSheet({
    required this.recipeName,
    required this.checks,
  });

  @override
  ConsumerState<_CookConfirmationSheet> createState() =>
      _CookConfirmationSheetState();
}

class _CookConfirmationSheetState extends ConsumerState<_CookConfirmationSheet> {
  final Set<String> _skipPantryIds = {};
  late bool _addMissingToShoppingList;
  bool _addDepletedToShoppingList = false;
  bool _loadingSubstitutes = false;
  String? _aiSubstitutesText;

  late final List<RecipeIngredientCheck> _deductibleChecks;
  late final List<RecipeIngredientCheck> _alertChecks;
  late final bool _hasDepleting;

  @override
  void initState() {
    super.initState();
    _deductibleChecks = widget.checks.where((c) => c.canDeduct).toList();
    _alertChecks = widget.checks
        .where((c) => c.availability != IngredientAvailability.available)
        .toList();
    _hasDepleting = _deductibleChecks.any((c) => c.willDeplete);
    _addMissingToShoppingList = _alertChecks.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Antes de cocinar "${widget.recipeName}"',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _deductibleChecks.isEmpty
                ? 'No hay coincidencias automáticas para descontar, pero igual puedes cocinar esta receta.'
                : 'Revisa qué se descontará de tu despensa y qué te falta.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_deductibleChecks.isNotEmpty) ...[
                    Text(
                      'SE DESCONTARÁ DE TU DESPENSA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._deductibleChecks.map((c) {
                      final pantry = c.pantryMatch!;
                      final checked = !_skipPantryIds.contains(pantry.id);
                      final remText = c.willDeplete
                          ? 'quedará en 0'
                          : 'quedarán ${formatIngredientQty(c.remainingAfterCook)} ${pantry.unit}';
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        value: checked,
                        activeColor: const Color(0xFF00C896),
                        title: Text(pantry.name,
                            style: const TextStyle(fontSize: 14)),
                        subtitle: Text(
                          '-${formatIngredientQty(c.deductedInPantryUnit!)} ${pantry.unit} ($remText)',
                          style: TextStyle(
                            fontSize: 12,
                            color: c.willDeplete
                                ? Colors.amber
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == false) {
                              _skipPantryIds.add(pantry.id);
                            } else {
                              _skipPantryIds.remove(pantry.id);
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 10),
                  ],
                  if (_alertChecks.isNotEmpty) ...[
                    Text(
                      'FALTANTES O CON OTRA UNIDAD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: Colors.amber.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ..._alertChecks.map((c) {
                      final req = c.requirement;
                      final reason = switch (c.availability) {
                        IngredientAvailability.missing =>
                          'Falta ${formatIngredientQty(req.quantity)} ${req.unit}',
                        IngredientAvailability.insufficient =>
                          'Tienes ${formatIngredientQty(c.pantryMatch!.quantity)} ${c.pantryMatch!.unit} de ${formatIngredientQty(req.quantity)} ${req.unit}',
                        IngredientAvailability.incompatibleUnit =>
                          'En despensa: ${c.pantryMatch!.name} (${formatIngredientQty(c.pantryMatch!.quantity)} ${c.pantryMatch!.unit} vs ${req.unit})',
                        IngredientAvailability.available => '',
                      };
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              c.availability == IngredientAvailability.missing
                                  ? Icons.error_outline
                                  : Icons.warning_amber_rounded,
                              size: 18,
                              color: c.availability ==
                                      IngredientAvailability.missing
                                  ? Colors.redAccent
                                  : Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(req.ingredientName,
                                      style: const TextStyle(fontSize: 13)),
                                  Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _loadingSubstitutes
                            ? null
                            : () async {
                                setState(() => _loadingSubstitutes = true);
                                try {
                                  final pantryNames = ref
                                      .read(inventoryProvider)
                                      .ingredients
                                      .map((i) => i.name)
                                      .toList();
                                  final missingNames = _alertChecks
                                      .map((c) => c.requirement.ingredientName)
                                      .toList();
                                  final reply = await ref
                                      .read(geminiProvider)
                                      .suggestIngredientSubstitutesGemini(
                                        recipeName: widget.recipeName,
                                        missingIngredients: missingNames,
                                        pantryNames: pantryNames,
                                      );
                                  if (mounted) {
                                    setState(() {
                                      _aiSubstitutesText = (reply == null ||
                                              reply.trim().isEmpty)
                                          ? 'No se pudieron obtener sugerencias en este momento.'
                                          : reply.trim();
                                    });
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _loadingSubstitutes = false);
                                  }
                                }
                              },
                        icon: _loadingSubstitutes
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome,
                                size: 16, color: Color(0xFF00C896)),
                        label: Text(
                          _loadingSubstitutes
                              ? 'Buscando sustitutos en tu despensa...'
                              : '✨ Sugerir sustituto con mi despensa (IA)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF00C896),
                          ),
                        ),
                      ),
                    ),
                    if (_aiSubstitutesText != null)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF00C896).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                const Color(0xFF00C896).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          _aiSubstitutesText!,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                        ),
                      ),
                    SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Agregar faltantes a Lista de compras',
                          style: TextStyle(fontSize: 13)),
                      value: _addMissingToShoppingList,
                      activeTrackColor: const Color(0xFF00C896),
                      onChanged: (v) =>
                          setState(() => _addMissingToShoppingList = v),
                    ),
                  ],
                  if (_hasDepleting)
                    SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                          'Reponer en Lista de compras los que queden en 0',
                          style: TextStyle(fontSize: 13)),
                      value: _addDepletedToShoppingList,
                      activeTrackColor: const Color(0xFF00C896),
                      onChanged: (v) =>
                          setState(() => _addDepletedToShoppingList = v),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(
                    _CookConfirmPlan(
                      skipPantryIds: Set<String>.from(_skipPantryIds),
                      addMissingToShoppingList: _addMissingToShoppingList,
                      addDepletedToShoppingList: _addDepletedToShoppingList,
                    ),
                  ),
                  icon: const Icon(Icons.whatshot, color: Colors.black),
                  label: Text(
                    _deductibleChecks.isEmpty
                        ? 'Cocinar igual'
                        : '¡Cocinar ahora!',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9800),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
