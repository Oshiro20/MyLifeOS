import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:domain/domain.dart';
import 'package:data/data.dart';
import 'package:uuid/uuid.dart';
import 'package:core/core.dart';
import '../providers/cocina_providers.dart';
import '../providers/user_food_preferences_provider.dart';
import 'widgets/poultry_breakdown_sheet.dart';

class InventoryTab extends ConsumerStatefulWidget {
  const InventoryTab({super.key});

  @override
  ConsumerState<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends ConsumerState<InventoryTab> with AppFeedback {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  Future<void> _showRescueIdeasDialog(
    BuildContext context,
    List<InventoryIngredient> rescueItems,
    List<InventoryIngredient> allItems,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00C896))),
    );
    try {
      final goal = ref.read(recipesProvider).activeGoal;
      final priorityNames = rescueItems
          .map((i) =>
              '${i.name} (${i.quantity} ${i.unit}${i.preparation.isNotEmpty ? ', ${i.preparation}' : ''})')
          .toList();
      final reply = await ref.read(geminiProvider).suggestRescueRecipesGemini(
            priorityIngredients: priorityNames,
            allPantryNames: allItems.map((i) => i.name).toList(),
            goalLabel: '${goal.emoji} ${goal.label}',
          );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('✨ Ideas de rescate con Gemini'),
          content: SingleChildScrollView(
            child: Text(
              (reply == null || reply.trim().isEmpty)
                  ? 'No se pudieron obtener sugerencias en este momento.'
                  : reply.trim(),
              style: const TextStyle(fontSize: 13.5, height: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        showError(context, 'Error al consultar Gemini: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final foodPrefs = ref.watch(userFoodPreferencesProvider);
    final foodPrefsNotifier = ref.read(userFoodPreferencesProvider.notifier);

    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00C896)));
    }

    // Filter ingredients by search query
    final filteredIngredients = _searchQuery.isEmpty
        ? state.ingredients
        : state.ingredients
            .where((i) =>
                i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // Stats calculations
    final expiringCount =
        state.ingredients.where((i) => i.isExpiringSoon).length;
    final expiredCount = state.ingredients.where((i) => i.isExpired).length;

    final List<Widget> listChildren = [];
    final walletCandidates =
        ref.watch(walletGroceryCandidatesProvider).asData?.value ?? const [];
    final pendingPoultry = ref.watch(pendingPoultryBreakdownsProvider);

    if (_searchQuery.isEmpty && pendingPoultry.isNotEmpty) {
      final firstPoultry = pendingPoultry.first;
      listChildren.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF9800).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF9800).withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              const Text('🍗', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${firstPoultry.itemName}${pendingPoultry.length > 1 ? ' (+${pendingPoultry.length - 1})' : ''} desde WalletAI',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Text(
                      '¿En qué presas o octavos lo dividimos?',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  final ok = await PoultryBreakdownSheet.show(
                    context,
                    pending: firstPoultry,
                  );
                  if (ok == true && context.mounted) {
                    showSuccess(context, '🍗 Presas agregadas a tu Despensa');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9800),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text('Desglosar',
                    style:
                        TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchQuery.isEmpty && walletCandidates.isNotEmpty) {
      listChildren.add(
        _WalletGroceryImportBanner(
          candidates: walletCandidates,
          onImportAll: () async {
            final added = await ref
                .read(inventoryProvider.notifier)
                .importGroceryCandidates(walletCandidates);
            if (context.mounted && added > 0) {
              showSuccess(
                  context, '$added ingredientes importados desde WalletAI');
            }
          },
          onImportOne: (c) async {
            final added = await ref
                .read(inventoryProvider.notifier)
                .importGroceryCandidates([c]);
            if (context.mounted && added > 0) {
              showSuccess(context, '${c.itemName} agregado a despensa');
            }
          },
          onDismissOne: (c) async {
            await ref
                .read(walletGroceryBridgeProvider)
                .markTxProcessed(c.transactionKey);
            ref.read(walletPendingGroceryRefreshProvider.notifier).bump();
          },
        ),
      );
    }

    // Stats Panel (only if not searching)
    if (_searchQuery.isEmpty) {
      final rescueItems = state.ingredients
          .where((i) =>
              i.isExpiringSoon ||
              i.preparation.toLowerCase().contains('cocido') ||
              i.preparation.toLowerCase().contains('listo'))
          .toList();

      listChildren.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00C896).withAlpha(40)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatBadge('🟢 ${state.ingredients.length}', 'Total',
                      Theme.of(context).colorScheme.onSurface),
                  _StatBadge('🟡 $expiringCount', 'Por vencer',
                      const Color(0xFFFFB300)),
                  _StatBadge(
                      '🔴 $expiredCount', 'Vencidos', const Color(0xFFFF5252)),
                  _StatBadge(
                      '📂 ${state.ingredients.map((i) => i.primaryCategory).toSet().length}',
                      'Categorías',
                      const Color(0xFF00F0FF)),
                ],
              ),
              if (rescueItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showRescueIdeasDialog(
                        context, rescueItems, state.ingredients),
                    icon: const Icon(Icons.auto_awesome,
                        size: 16, color: Color(0xFF00C896)),
                    label: Text(
                      '✨ ${rescueItems.length} por vencer / listos: ¿Qué preparo hoy?',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF00C896),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color:
                              const Color(0xFF00C896).withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Search bar
    listChildren.add(
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: '🔍 Buscar en tu despensa...',
            hintStyle: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45)),
            prefixIcon: Icon(Icons.search,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55)),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55)),
                    onPressed: () {
                      setState(() {
                        _searchCtrl.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value.trim());
          },
        ),
      ),
    );

    if (_searchQuery.isNotEmpty && filteredIngredients.isEmpty) {
      listChildren.add(Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('No se encontraron ingredientes',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                  fontSize: 14)),
        ),
      ));
    }

    // Disliked ingredients section
    listChildren.add(Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, color: Colors.redAccent, size: 18),
              const SizedBox(width: 6),
              const Text(
                'Ingredientes que NO te gustan',
                style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    _showAddDislikedDialog(context, foodPrefsNotifier),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (foodPrefs.dislikedIngredients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Agrega ingredientes que no te gustan para que el Chef IA los evite.',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                    fontSize: 11),
              ),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: foodPrefs.dislikedIngredients.map((ing) {
                return Chip(
                  label: Text(ing,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 11)),
                  deleteIcon: const Icon(Icons.close,
                      size: 14, color: Colors.redAccent),
                  onDeleted: () =>
                      foodPrefsNotifier.removeDislikedIngredient(ing),
                  backgroundColor: Colors.red.withValues(alpha: 0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                );
              }).toList(),
            ),
        ],
      ),
    ));

    final Set<String> categories =
        filteredIngredients.map((i) => i.primaryCategory).toSet();
    final sortedCategories = categories.toList()..sort();

    // Group by primary category
    for (final cat in sortedCategories) {
      final itemsInCat =
          filteredIngredients.where((i) => i.primaryCategory == cat).toList();
      if (itemsInCat.isEmpty) continue;

      // Sort: Expired -> Expiring Soon -> Others
      itemsInCat.sort((a, b) {
        if (a.isExpired && !b.isExpired) return -1;
        if (!a.isExpired && b.isExpired) return 1;
        if (a.isExpiringSoon && !b.isExpiringSoon) return -1;
        if (!a.isExpiringSoon && b.isExpiringSoon) return 1;
        return a.name.compareTo(b.name);
      });

      final catIcon = _IngredientTile._getCategoryIcon(cat);

      listChildren.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          children: [
            Text(catIcon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(
              cat.toUpperCase(),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2),
            ),
            const Spacer(),
            Text('${itemsInCat.length}',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38),
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ));

      listChildren.addAll(itemsInCat.map((i) => _IngredientTile(
          ingredient: i,
          onEdit: () => _showEditDialog(context, ref, i),
          onQuickLevel: (factor) async {
            if (factor <= 0) {
              await ref.read(inventoryProvider.notifier).delete(i.id);
              if (context.mounted) {
                showSuccess(context, '"${i.name}" marcado como agotado.');
              }
              return;
            }
            final newQty =
                double.parse((i.quantity * factor).toStringAsFixed(2));
            await ref.read(inventoryProvider.notifier).update(
                  i.copyWith(
                    quantity: newQty <= 0 ? 0.1 : newQty,
                    preparation: 'abierto / en uso',
                  ),
                );
          },
          onDelete: () => _confirmDelete(context, ref, i.id, i.name))));
    }

    if (filteredIngredients.isEmpty) {
      listChildren.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.kitchen_outlined,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.18)),
              const SizedBox(height: 12),
              Text(
                  _searchQuery.isNotEmpty
                      ? 'No se encontraron resultados para "$_searchQuery"'
                      : 'Tu despensa está vacía',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45),
                      fontSize: 17)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _showAddDialog(context, ref),
                icon: const Icon(Icons.add, color: Color(0xFF00C896)),
                label: Text(
                    _searchQuery.isNotEmpty
                        ? 'Agregar este ingrediente'
                        : 'Agregar ingrediente',
                    style: const TextStyle(color: Color(0xFF00C896))),
              ),
            ]),
          ),
        ),
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await ref.read(inventoryProvider.notifier).load();
          },
          color: const Color(0xFF00C896),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: listChildren,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_ingredient',
            backgroundColor: const Color(0xFF00C896),
            onPressed: () => _showAddDialog(context, ref),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final confirmed = await showConfirmDelete(context,
        itemName: name, subtitle: 'Se eliminará de tu despensa.');
    if (!confirmed) return;
    await ref.read(inventoryProvider.notifier).delete(id);
    if (context.mounted) {
      showSuccess(context, '"$name" eliminado de la despensa.');
    }
  }

  Future<void> _showAddDislikedDialog(
      BuildContext context, UserFoodPreferencesNotifier notifier) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) {
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        return AlertDialog(
          backgroundColor: Theme.of(ctx).cardColor,
          title: Text('🚫 Ingrediente que NO te gusta',
              style: TextStyle(color: onSurface)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(color: onSurface),
            decoration: InputDecoration(
              hintText: 'Ej: cebolla, cilantro, pescado...',
              hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.55)),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar',
                  style: TextStyle(color: onSurface.withValues(alpha: 0.55))),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  notifier.addDislikedIngredient(text);
                  Navigator.pop(ctx);
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  void _showAddDialog(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddIngredientSheet(
        onAdd: (ings) async {
          for (final ing in ings) {
            await ref.read(inventoryProvider.notifier).add(ing);
          }
          if (ctx.mounted) {
            if (ings.length == 1) {
              showSuccess(ctx, '"${ings.first.name}" añadido a la despensa ✓');
            } else {
              showSuccess(
                  ctx, '${ings.length} productos añadidos a la despensa ✨');
            }
          }
        },
      ),
    );
  }

  void _showEditDialog(
      BuildContext ctx, WidgetRef ref, InventoryIngredient itemToEdit) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddIngredientSheet(
        itemToEdit: itemToEdit,
        onAdd: (ings) async {
          final updated = ings.first.copyWith(id: itemToEdit.id);
          await ref.read(inventoryProvider.notifier).update(updated);
          if (ctx.mounted) {
            showSuccess(ctx, '"${updated.name}" actualizado ✓');
          }
        },
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _IngredientTile extends StatelessWidget {
  final InventoryIngredient ingredient;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final Future<void> Function(double factor)? onQuickLevel;
  const _IngredientTile({
    required this.ingredient,
    required this.onDelete,
    required this.onEdit,
    this.onQuickLevel,
  });

  static String _getCategoryIcon(String primaryCategory) {
    final lower = primaryCategory.toLowerCase();
    if (lower.contains('proteína') || lower.contains('carne')) return '🥩';
    if (lower.contains('lácteo')) return '🥛';
    if (lower.contains('fruta')) return '🍎';
    if (lower.contains('verdura')) return '🥦';
    if (lower.contains('tubérculo') ||
        lower.contains('raíz') ||
        lower.contains('raices')) {
      return '🥔';
    }
    if (lower.contains('legumbre')) return '🫘';
    if (lower.contains('cereal') || lower.contains('grano')) return '🌾';
    if (lower.contains('harina') || lower.contains('pasta')) return '🥖';
    if (lower.contains('aceite') || lower.contains('grasa')) return '🫒';
    if (lower.contains('salsa')) return '🥫';
    if (lower.contains('condimento') || lower.contains('especia')) return '🌶️';
    if (lower.contains('endulzante')) return '🍯';
    if (lower.contains('frutos secos') || lower.contains('semilla')) {
      return '🥜';
    }
    return '📦';
  }

  Color _expiryColor(BuildContext context) {
    if (ingredient.isExpired) return const Color(0xFFFF4D4D);
    if (ingredient.isExpiringSoon) return const Color(0xFFFFB74D);
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
  }

  @override
  Widget build(BuildContext context) {
    final expiryColor = _expiryColor(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: ingredient.isExpiringSoon
            ? Border.all(color: expiryColor.withAlpha(100), width: 1)
            : null,
      ),
      child: ListTile(
        onTap: onEdit,
        leading: Text(_getEmojiFor(ingredient.name, ingredient.primaryCategory),
            style: const TextStyle(fontSize: 28)),
        title: Text(ingredient.displayName,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${ingredient.subCategory != null ? "${ingredient.subCategory} • " : ""}${ingredient.quantity} ${ingredient.unit}'
          '${ingredient.expirationDate != null ? " · cad. ${_fmt(ingredient.expirationDate!)}" : ""}',
          style: TextStyle(color: expiryColor, fontSize: 12),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
              size: 20),
          tooltip: 'Ajustar o eliminar',
          onSelected: (value) async {
            if (value == 'edit') {
              onEdit();
            } else if (value == 'delete') {
              onDelete();
            } else if (value == 'use_25') {
              await onQuickLevel?.call(0.75);
            } else if (value == 'use_50') {
              await onQuickLevel?.call(0.5);
            } else if (value == 'low_10') {
              await onQuickLevel?.call(0.1);
            } else if (value == 'empty') {
              await onQuickLevel?.call(0.0);
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(
              value: 'use_25',
              child: Text('🥄 Usé un poco (-25%)'),
            ),
            PopupMenuItem(
              value: 'use_50',
              child: Text('➗ Queda la mitad (50%)'),
            ),
            PopupMenuItem(
              value: 'low_10',
              child: Text('⚠️ Queda poco (10%)'),
            ),
            PopupMenuItem(
              value: 'empty',
              child: Text('✅ Se acabó (quitar)'),
            ),
            PopupMenuDivider(),
            PopupMenuItem(
              value: 'edit',
              child: Text('✏️ Editar / ver detalle'),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text('🗑️ Eliminar',
                  style: TextStyle(color: Color(0xFFFF5252))),
            ),
          ],
        ),
      ),
    );
  }

  String _getEmojiFor(String name, String primaryCategory) {
    final lowerName = name.toLowerCase();

    // Frutas y Verduras comunes
    if (lowerName.contains('tomate')) return '🍅';
    if (lowerName.contains('limón') || lowerName.contains('limon')) return '🍋';
    if (lowerName.contains('cebolla')) return '🧅';
    if (lowerName.contains('ajo')) return '🧄';
    if (lowerName.contains('zanahoria')) return '🥕';
    if (lowerName.contains('papa') ||
        lowerName.contains('patata') ||
        lowerName.contains('olluco') ||
        lowerName.contains('olluquito')) {
      return '🥔';
    }
    if (lowerName.contains('palta') || lowerName.contains('aguacate')) {
      return '🥑';
    }
    if (lowerName.contains('platano') ||
        lowerName.contains('plátano') ||
        lowerName.contains('banana')) {
      return '🍌';
    }
    if (lowerName.contains('manzana')) return '🍎';
    if (lowerName.contains('naranja')) return '🍊';
    if (lowerName.contains('fresa') || lowerName.contains('frutilla')) {
      return '🍓';
    }
    if (lowerName.contains('uva') ||
        lowerName.contains('pasa') ||
        lowerName.contains('pasas')) {
      return '🍇';
    }
    if (lowerName.contains('sandia') || lowerName.contains('sandía')) {
      return '🍉';
    }
    if (lowerName.contains('champiñon') || lowerName.contains('hongo')) {
      return '🍄';
    }
    if (lowerName.contains('lechuga') || lowerName.contains('espinaca')) {
      return '🥬';
    }
    if (lowerName.contains('maiz') ||
        lowerName.contains('choclo') ||
        lowerName.contains('maíz')) {
      return '🌽';
    }
    if (lowerName.contains('pepino')) return '🥒';
    if (lowerName.contains('berenjena')) return '🍆';
    if (lowerName.contains('pimiento') || lowerName.contains('morrón')) {
      return '🫑';
    }
    if (lowerName.contains('brócoli') || lowerName.contains('brocoli')) {
      return '🥦';
    }
    if (lowerName.contains('kiwi')) return '🥝';
    if (lowerName.contains('coco')) return '🥥';
    if (lowerName.contains('piña')) return '🍍';
    if (lowerName.contains('durazno') || lowerName.contains('melocoton')) {
      return '🍑';
    }
    if (lowerName.contains('cereza')) return '🍒';

    // Proteínas
    if (lowerName.contains('pollo')) return '🍗';
    if (lowerName.contains('carne') ||
        lowerName.contains('bisteck') ||
        lowerName.contains('res') ||
        lowerName.contains('chancho') ||
        lowerName.contains('cerdo')) {
      return '🥩';
    }
    if (lowerName.contains('pescado') ||
        lowerName.contains('atún') ||
        lowerName.contains('atun')) {
      return '🐟';
    }
    if (lowerName.contains('camaron') ||
        lowerName.contains('camarón') ||
        lowerName.contains('langostino')) {
      return '🦐';
    }
    if (lowerName.contains('huevo')) return '🥚';
    if (lowerName.contains('tocino') || lowerName.contains('panceta')) {
      return '🥓';
    }
    if (lowerName.contains('salchicha') ||
        lowerName.contains('hot dog') ||
        lowerName.contains('chorizo')) {
      return '🌭';
    }
    if (lowerName.contains('marisco') ||
        lowerName.contains('cangrejo') ||
        lowerName.contains('pulpo') ||
        lowerName.contains('calamar')) {
      return '🦑';
    }

    // Lácteos
    if (lowerName.contains('leche')) return '🥛';
    if (lowerName.contains('queso')) return '🧀';
    if (lowerName.contains('mantequilla') || lowerName.contains('margarina')) {
      return '🧈';
    }
    if (lowerName.contains('yogurt')) return '🥣';

    // Granos, Masas y Cereales
    if (lowerName.contains('arroz')) return '🍚';
    if (lowerName.contains('pan')) return '🍞';
    if (lowerName.contains('fideo') ||
        lowerName.contains('pasta') ||
        lowerName.contains('espagueti') ||
        lowerName.contains('tallarin')) {
      return '🍝';
    }
    if (lowerName.contains('pizza')) return '🍕';
    if (lowerName.contains('harina')) return '🌾';
    if (lowerName.contains('avena')) return '🥣';
    if (lowerName.contains('lenteja') ||
        lowerName.contains('frijol') ||
        lowerName.contains('pallar') ||
        lowerName.contains('garbanzo')) {
      return '🫘';
    }

    // Condimentos, Aceites, Salsas y Repostería
    if (lowerName.contains('aceite')) return '🫒';
    if (lowerName.contains('sal')) return '🧂';
    if (lowerName.contains('azucar') ||
        lowerName.contains('azúcar') ||
        lowerName.contains('endulzante') ||
        lowerName.contains('stevia')) {
      return '🧊';
    }
    if (lowerName.contains('pimienta') || lowerName.contains('comino')) {
      return '🧂';
    }
    if (lowerName.contains('ají') ||
        lowerName.contains('aji') ||
        lowerName.contains('chile') ||
        lowerName.contains('rocoto')) {
      return '🌶️';
    }
    if (lowerName.contains('laurel') ||
        lowerName.contains('oregano') ||
        lowerName.contains('orégano') ||
        lowerName.contains('perejil') ||
        lowerName.contains('cilantro') ||
        lowerName.contains('albahaca') ||
        lowerName.contains('romero')) {
      return '🌿';
    }
    if (lowerName.contains('miel') ||
        lowerName.contains('mermelada') ||
        lowerName.contains('jalea') ||
        lowerName.contains('compota')) {
      return '🍯';
    }
    if (lowerName.contains('sillao') ||
        lowerName.contains('salsa de soya') ||
        lowerName.contains('vinagre')) {
      return '🧉';
    }
    if (lowerName.contains('vainilla')) return '🌸'; // Esencia de vainilla
    if (lowerName.contains('canela')) return '🟤';
    if (lowerName.contains('ketchup') ||
        lowerName.contains('mayonesa') ||
        lowerName.contains('mostaza')) {
      return '🥫';
    }
    if (lowerName.contains('chocolate') || lowerName.contains('cacao')) {
      return '🍫';
    }
    if (lowerName.contains('galleta')) return '🍪';
    if (lowerName.contains('mani') ||
        lowerName.contains('maní') ||
        lowerName.contains('almendra') ||
        lowerName.contains('nuez')) {
      return '🥜';
    }

    // Bebidas
    if (lowerName.contains('agua')) return '💧';
    if (lowerName.contains('vino')) return '🍷';
    if (lowerName.contains('cerveza')) return '🍺';
    if (lowerName.contains('cafe') || lowerName.contains('café')) return '☕';
    if (lowerName.contains('te') ||
        lowerName.contains('té') ||
        lowerName.contains('infusión') ||
        lowerName.contains('manzanilla')) {
      return '🍵';
    }
    if (lowerName.contains('jugo') || lowerName.contains('zumo')) return '🧃';
    if (lowerName.contains('gaseosa') ||
        lowerName.contains('soda') ||
        lowerName.contains('coca cola')) {
      return '🥤';
    }

    // Default fallback to category
    return _getCategoryIcon(primaryCategory);
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

// ── Formulario con auto-detección ──────────────────────────────────────────

class _AddIngredientSheet extends ConsumerStatefulWidget {
  final Future<void> Function(List<InventoryIngredient>) onAdd;
  final InventoryIngredient? itemToEdit;
  const _AddIngredientSheet({required this.onAdd, this.itemToEdit});
  @override
  ConsumerState<_AddIngredientSheet> createState() =>
      _AddIngredientSheetState();
}

class _AddIngredientSheetState extends ConsumerState<_AddIngredientSheet> {
  static const List<String> _masterCategories = [
    'Proteínas animales',
    'Lácteos',
    'Frutas',
    'Verduras',
    'Tubérculos y raíces',
    'Legumbres',
    'Cereales y granos',
    'Harinas y derivados',
    'Aceites y grasas',
    'Salsas',
    'Condimentos y especias',
    'Endulzantes',
    'Frutos secos y semillas',
    'Preparados / Listos',
    'Otros'
  ];

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _subCategoryCtrl = TextEditingController();
  MeasurementUnit _unit = MeasurementUnit.unidades;
  String _primaryCategory = 'Otros';
  String _preparation =
      ''; // "entero", "licuado", "molido", "fresco", "picado", etc.
  DateTime? _expiry;
  String? _qtyError;
  String? _nameError;
  bool _saving = false;
  bool _autoDetected = false;
  double? _packageBaseQty;
  double? _selectedFraction;
  bool _opaqueContainerWarning = false;

  static const List<String> _preparations = [
    '',
    'cocido / listo',
    'abierto / en uso',
    'entero',
    'licuado',
    'molido',
    'picado',
    'fresco',
    'remojado',
    'congelado',
    'en pasta',
    'en polvo',
    'en granos',
    'en rodajas',
    'desmenuzado',
  ];

  int? _unitsPerKg;

  String _formatQtyValue(double v) {
    if ((v - v.roundToDouble()).abs() < 0.01) {
      return v.round().toString();
    }
    return double.parse(v.toStringAsFixed(2)).toString();
  }

  void _applyFraction(double factor) {
    final current =
        double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.')) ?? 1.0;
    final base = (_packageBaseQty != null && _packageBaseQty! > 0)
        ? _packageBaseQty!
        : (current > 0 ? current : 1.0);
    final scaled = base * factor;
    setState(() {
      _packageBaseQty = base;
      _selectedFraction = factor;
      _qtyCtrl.text = _formatQtyValue(scaled);
      _qtyError = null;
      if (factor < 0.99) {
        _preparation = 'abierto / en uso';
      } else if (_preparation == 'abierto / en uso') {
        _preparation = '';
      }
    });
  }

  String _storageArea = 'Alacena';
  final List<String> _storageAreas = ['Alacena', 'Refrigerador', 'Congelador'];
  int? _aiPantryLifeDays;
  int? _aiFridgeLifeDays;
  int? _aiFreezerLifeDays;
  String? _aiStorageTip;

  void _updateExpirationFromAI() {
    int? days;
    if (_storageArea == 'Alacena') days = _aiPantryLifeDays;
    if (_storageArea == 'Refrigerador') days = _aiFridgeLifeDays;
    if (_storageArea == 'Congelador') days = _aiFreezerLifeDays;

    if (days != null && days > 0) {
      _expiry = DateTime.now().add(Duration(days: days));
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final i = widget.itemToEdit!;
      _nameCtrl.text = i.name;
      _qtyCtrl.text = _formatQtyValue(i.quantity);
      _packageBaseQty = i.quantity > 0 ? i.quantity : null;
      _primaryCategory = _masterCategories.contains(i.primaryCategory)
          ? i.primaryCategory
          : 'Otros';
      _preparation = i.preparation;
      _subCategoryCtrl.text = i.subCategory ?? '';
      _expiry = i.expirationDate;
      _storageArea = i.storageArea ?? 'Alacena';
      try {
        _unit = MeasurementUnit.values.firstWhere((u) => u.label == i.unit);
      } catch (_) {}
      final customMap = ref.read(ingredientEquivalencesProvider);
      final key = IngredientMatcher.normalizeText(i.name);
      final gPerU = customMap[key] ??
          IngredientUnitNormalizer.defaultGramsPerUnit(i.name);
      if (gPerU != null && gPerU > 0) {
        _unitsPerKg = (1000.0 / gPerU).round().clamp(1, 50);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(2)))),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Agregar ingrediente',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _saving ? null : _aiScanSingle,
                      icon: const Icon(Icons.camera_alt,
                          color: Color(0xFF00C896)),
                      tooltip: 'Escanear un solo producto',
                    ),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _aiScan,
                      icon: const Icon(Icons.document_scanner,
                          size: 16, color: Colors.white),
                      label: const Text('IA Múltiple',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C896),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nombre con auto-detección
            _field(_nameCtrl, 'Nombre (ej: Sillao, Arroz, Pollo)',
                Icons.label_outline,
                errorText: _nameError, onChanged: _onNameChanged),
            if (_autoDetected) ...[
              const SizedBox(height: 4),
              const Text('✨ Categoría y unidad sugeridas automáticamente',
                  style: TextStyle(color: Color(0xFF00C896), fontSize: 11)),
            ],
            const SizedBox(height: 10),

            // Cantidad + Unidad
            Row(children: [
              Expanded(
                flex: 2,
                child: _field(_qtyCtrl, 'Cantidad', Icons.exposure,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    errorText: _qtyError, onChanged: (val) {
                  final parsed =
                      double.tryParse(val.trim().replaceAll(',', '.'));
                  setState(() {
                    _qtyError = null;
                    _selectedFraction = null;
                    if (parsed != null && parsed > 0) {
                      _packageBaseQty = parsed;
                    }
                  });
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<MeasurementUnit>(
                  key: ValueKey('unit_${_unit.name}'),
                  initialValue: _unit,
                  dropdownColor: Theme.of(context).cardColor,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: _inputDeco('Unidad', Icons.scale_outlined),
                  items: MeasurementUnit.values
                      .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(u.label,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface))))
                      .toList(),
                  onChanged: (v) => setState(() => _unit = v!),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            // Nivel restante rápido para envases abiertos / usados
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_opaqueContainerWarning)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB300).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              const Color(0xFFFFB300).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '⚠️ Envase opaco detectado (${_packageBaseQty != null ? _formatQtyValue(_packageBaseQty!) : ''} ${_unit.label}). Elige cuánto te queda:',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Text(
                        'Nivel envase:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 6),
                      for (final opt in const [
                        (1.0, 'Nuevo (100%)'),
                        (0.75, '3/4'),
                        (0.5, 'Mitad (1/2)'),
                        (0.25, '1/4'),
                        (0.1, 'Poco'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(opt.$2,
                                style: const TextStyle(fontSize: 11)),
                            selected: _selectedFraction == opt.$1,
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onSelected: (_) => _applyFraction(opt.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('⚡ Cocido / Listo al instante',
                          style: TextStyle(fontSize: 11)),
                      selected: _preparation == 'cocido / listo',
                      selectedColor:
                          const Color(0xFF00C896).withValues(alpha: 0.2),
                      checkmarkColor: const Color(0xFF00C896),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _preparation = 'cocido / listo';
                            if (_storageArea == 'Alacena') {
                              _storageArea = 'Refrigerador';
                            }
                            _expiry ??=
                                DateTime.now().add(const Duration(days: 3));
                          } else if (_preparation == 'cocido / listo') {
                            _preparation = '';
                          }
                        });
                      },
                    ),
                    if (WalletPantryBridgeService.isPoultryBreakdownName(
                        _nameCtrl.text))
                      ActionChip(
                        avatar:
                            const Text('🍗', style: TextStyle(fontSize: 13)),
                        label: const Text('Dividir en presas (8/8)',
                            style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: () async {
                          final rawQty = double.tryParse(
                                  _qtyCtrl.text.trim().replaceAll(',', '.')) ??
                              1.0;
                          final navigator = Navigator.of(context);
                          final ok = await PoultryBreakdownSheet.show(
                            context,
                            initialTitle: _nameCtrl.text.trim(),
                            initialWholeChickens: rawQty,
                          );
                          if (ok == true && mounted) {
                            navigator.pop();
                          }
                        },
                      ),
                  ],
                ),
                if (_unit == MeasurementUnit.kg ||
                    _unit == MeasurementUnit.g) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Text(
                          '1 kg ≈',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.65),
                          ),
                        ),
                        const SizedBox(width: 6),
                        for (final uCount in const [4, 5, 6, 8, 10, 12])
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: ChoiceChip(
                              label: Text('$uCount u',
                                  style: const TextStyle(fontSize: 11)),
                              selected: _unitsPerKg == uCount,
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              onSelected: (sel) => setState(
                                () => _unitsPerKg = sel ? uCount : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Categoría
            Row(children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('cat_$_primaryCategory'),
                  initialValue: _primaryCategory,
                  dropdownColor: Theme.of(context).cardColor,
                  isExpanded: true,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13),
                  decoration: _inputDeco('Categoría', Icons.category_outlined),
                  items: _masterCategories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface))))
                      .toList(),
                  onChanged: (v) => setState(() => _primaryCategory = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _field(_subCategoryCtrl, 'Sub (opcional)',
                    Icons.subdirectory_arrow_right,
                    keyboardType: TextInputType.text),
              ),
            ]),
            const SizedBox(height: 10),

            // Preparación/Estado
            DropdownButtonFormField<String>(
              key: ValueKey('prep_$_preparation'),
              initialValue:
                  _preparations.contains(_preparation) ? _preparation : '',
              dropdownColor: Theme.of(context).cardColor,
              isExpanded: true,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration:
                  _inputDeco('Preparación (opcional)', Icons.restaurant_menu),
              items: _preparations
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c.isEmpty ? 'Sin especificar' : c,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface))))
                  .toList(),
              onChanged: (v) => setState(() => _preparation = v ?? ''),
            ),
            const SizedBox(height: 10),

            // Lugar de Guardado
            DropdownButtonFormField<String>(
              key: ValueKey('area_$_storageArea'),
              initialValue: _storageArea,
              dropdownColor: Theme.of(context).cardColor,
              isExpanded: true,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration:
                  _inputDeco('Lugar de guardado', Icons.kitchen_outlined),
              items: _storageAreas
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface))))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _storageArea = v!;
                  _updateExpirationFromAI();
                });
              },
            ),
            const SizedBox(height: 10),

            // Tip de Almacenamiento (solo si hay IA)
            if (_aiStorageTip != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C896).withValues(alpha: 0.1),
                  border: Border.all(
                      color: const Color(0xFF00C896).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates,
                        color: Color(0xFF00C896), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_aiStorageTip!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                              fontSize: 12,
                              height: 1.3)),
                    ),
                  ],
                ),
              ),
            ],

            // Fecha de caducidad
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.today_outlined,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45)),
              title: Text(
                _expiry == null
                    ? 'Sin fecha de caducidad'
                    : 'Caduca: ${_expiry!.day}/${_expiry!.month}/${_expiry!.year}',
                style: TextStyle(
                    color: _expiry == null
                        ? Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45)
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.78),
                    fontSize: 14),
              ),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                  );
                  if (picked != null) setState(() => _expiry = picked);
                },
                child: const Text('Elegir',
                    style: TextStyle(color: Color(0xFF00C896))),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Agregar',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onNameChanged(String val) {
    setState(() => _nameError = null);
    if (val.length < 2) {
      setState(() => _autoDetected = false);
      return;
    }

    final suggestion = IngredientDetector.detect(val);
    final customMap = ref.read(ingredientEquivalencesProvider);
    final normKey = IngredientMatcher.normalizeText(val);
    final gPerU =
        customMap[normKey] ?? IngredientUnitNormalizer.defaultGramsPerUnit(val);

    setState(() {
      if (suggestion.primaryCategory != null) {
        _primaryCategory =
            _masterCategories.contains(suggestion.primaryCategory)
                ? suggestion.primaryCategory!
                : 'Otros';
        _subCategoryCtrl.text = suggestion.subCategory ?? '';
      }
      if (suggestion.suggestedUnit != null) _unit = suggestion.suggestedUnit!;
      if (suggestion.suggestedPreparation != null) {
        _preparation = suggestion.suggestedPreparation!;
        if (_preparation == 'cocido / listo' && _storageArea == 'Alacena') {
          _storageArea = 'Refrigerador';
          _expiry ??= DateTime.now().add(const Duration(days: 3));
        }
      }
      if (gPerU != null && gPerU > 0) {
        _unitsPerKg = (1000.0 / gPerU).round().clamp(1, 50);
      }
      _autoDetected = suggestion.primaryCategory != null ||
          suggestion.suggestedPreparation != null;
    });
  }

  Future<void> _aiScan() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() => _saving = true);
    try {
      final gemini = ref.read(geminiProvider);
      final jsonResponse =
          await gemini.analyzePantryItems(photoPath: pickedFile.path);

      if (jsonResponse == null || jsonResponse.isEmpty) {
        throw Exception("No se recibió respuesta de Gemini");
      }

      final data = AiJsonParser.decodeList(jsonResponse);
      if (data == null) {
        throw const FormatException('La IA no devolvió una lista JSON válida');
      }
      final newItems = <InventoryIngredient>[];
      final basePackageQtyById = <String, double>{};
      final opaqueIds = <String>{};

      for (var item in data) {
        if (item is Map<String, dynamic>) {
          final catString = item['primaryCategory']?.toString() ?? 'Otros';
          final subCatString = item['subCategory']?.toString();
          final unitStr = item['unit']?.toString() ?? 'unidades';
          final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
          final pkgQty = (item['packageQuantity'] as num?)?.toDouble();
          final isOpened = item['isOpened'] == true;
          final fillPct = (item['fillLevelPercent'] as num?)?.toInt();
          final isOpaque = item['opaqueContainer'] == true;

          MeasurementUnit properUnit = MeasurementUnit.unidades;
          try {
            properUnit = MeasurementUnit.values.firstWhere(
                (u) =>
                    u.label.toLowerCase() == unitStr.toLowerCase() ||
                    u.name.toLowerCase() == unitStr.toLowerCase(),
                orElse: () => MeasurementUnit.unidades);
          } catch (_) {}

          final pDays = (item['pantryLifeDays'] as num?)?.toInt();
          DateTime? exp;
          if (pDays != null && pDays > 0) {
            exp = DateTime.now().add(Duration(days: pDays));
          }

          final id = const Uuid().v4();
          final resolvedBase = (pkgQty != null && pkgQty > 0) ? pkgQty : qty;
          basePackageQtyById[id] = resolvedBase;
          if (isOpaque) opaqueIds.add(id);

          final openNote = (isOpened && fillPct != null && fillPct < 100)
              ? '~$fillPct% restante'
              : null;
          final combinedSub = [
            if (subCatString != null && subCatString.trim().isNotEmpty)
              subCatString.trim(),
            if (openNote != null) openNote,
          ].join(' · ');

          newItems.add(InventoryIngredient(
            id: id,
            name: item['name']?.toString() ?? 'Producto',
            primaryCategory:
                _masterCategories.contains(catString) ? catString : 'Otros',
            subCategory: combinedSub.isEmpty ? null : combinedSub,
            preparation: isOpened ? 'abierto / en uso' : '',
            quantity: qty,
            unit: properUnit.label,
            expirationDate: exp,
            storageArea: 'Alacena',
          ));
        }
      }

      if (newItems.isNotEmpty) {
        if (!mounted) return;
        final confirmed = await showDialog<List<InventoryIngredient>>(
          context: context,
          builder: (_) => _ReviewMultipleDialog(
            items: newItems,
            basePackageQtyById: basePackageQtyById,
            opaqueIds: opaqueIds,
          ),
        );
        if (confirmed != null && confirmed.isNotEmpty) {
          await widget.onAdd(confirmed);
          if (mounted) Navigator.pop(context);
        }
      } else {
        throw Exception("Gemini no detectó productos.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error IA: $e'),
              backgroundColor: const Color(0xFFFF5252)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _aiScanSingle() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    setState(() => _saving = true);
    try {
      final gemini = ref.read(geminiProvider);
      final jsonResponse =
          await gemini.analyzeSinglePantryItem(photoPath: pickedFile.path);

      if (jsonResponse == null || jsonResponse.isEmpty) {
        throw Exception("No se recibió respuesta de Gemini");
      }

      final item = AiJsonParser.decodeMap(jsonResponse);
      if (item == null) {
        throw const FormatException('La IA no devolvió un objeto JSON válido');
      }
      final catString = item['primaryCategory']?.toString() ?? 'Otros';
      final subCatString = item['subCategory']?.toString();
      final unitStr = item['unit']?.toString() ?? 'unidades';
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final pkgQty = (item['packageQuantity'] as num?)?.toDouble();
      final isOpened = item['isOpened'] == true;
      final fillPct = (item['fillLevelPercent'] as num?)?.toInt();
      final isOpaque = item['opaqueContainer'] == true;

      MeasurementUnit properUnit = MeasurementUnit.unidades;
      try {
        properUnit = MeasurementUnit.values.firstWhere(
            (u) =>
                u.label.toLowerCase() == unitStr.toLowerCase() ||
                u.name.toLowerCase() == unitStr.toLowerCase(),
            orElse: () => MeasurementUnit.unidades);
      } catch (_) {}

      final pDays = (item['pantryLifeDays'] as num?)?.toInt();
      final rDays = (item['fridgeLifeDays'] as num?)?.toInt();
      final cDays = (item['freezerLifeDays'] as num?)?.toInt();
      final sTip = item['storageTip']?.toString();

      if (mounted) {
        final resolvedBase = (pkgQty != null && pkgQty > 0) ? pkgQty : qty;
        final inferredFraction =
            (resolvedBase > 0 && isOpened && qty < resolvedBase)
                ? qty / resolvedBase
                : (fillPct != null && fillPct > 0 && fillPct < 100
                    ? fillPct / 100.0
                    : null);
        setState(() {
          _nameCtrl.text = item['name']?.toString() ?? 'Producto';
          _qtyCtrl.text = _formatQtyValue(qty);
          _packageBaseQty = resolvedBase;
          _selectedFraction = inferredFraction;
          _opaqueContainerWarning = isOpaque;
          _unit = properUnit;
          _primaryCategory =
              _masterCategories.contains(catString) ? catString : 'Otros';
          _subCategoryCtrl.text = subCatString ?? '';
          if (isOpened) {
            _preparation = 'abierto / en uso';
          }
          _autoDetected = true;

          _aiPantryLifeDays = pDays;
          _aiFridgeLifeDays = rDays;
          _aiFreezerLifeDays = cDays;
          _aiStorageTip = sTip;

          if (rDays != null && rDays > 0) {
            _storageArea = 'Refrigerador';
          } else {
            _storageArea = 'Alacena';
          }
          _updateExpirationFromAI();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Revisa los datos antes de agregar.',
              style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF00C896),
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error IA Simple: $e'),
              backgroundColor: const Color(0xFFFF5252)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final nameVal = Validator.ingredientName(_nameCtrl.text);
    final parsedQty =
        double.tryParse(_qtyCtrl.text.trim().replaceAll(',', '.'));
    final qtyVal = Validator.ingredientQuantity(parsedQty);

    if (!nameVal.isValid || !qtyVal.isValid || parsedQty == null) {
      setState(() {
        _nameError = nameVal.errorMessage;
        _qtyError = qtyVal.errorMessage;
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final cleanName = _nameCtrl.text.trim();
      if ((_unit == MeasurementUnit.kg || _unit == MeasurementUnit.g) &&
          _unitsPerKg != null &&
          _unitsPerKg! > 0) {
        await ref
            .read(ingredientEquivalencesProvider.notifier)
            .setGramsPerUnit(cleanName, 1000.0 / _unitsPerKg!);
      }
      await widget.onAdd([
        InventoryIngredient(
          id: widget.itemToEdit?.id ?? const Uuid().v4(),
          name: cleanName,
          primaryCategory: _primaryCategory,
          subCategory: _subCategoryCtrl.text.trim().isEmpty
              ? null
              : _subCategoryCtrl.text.trim(),
          preparation: _preparation,
          quantity: parsedQty,
          unit: _unit.label,
          expirationDate: _expiry,
          imageAssetId: widget.itemToEdit?.imageAssetId,
          storageArea: _storageArea,
        )
      ]);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al guardar: $e'),
              backgroundColor: const Color(0xFFFF5252)),
        );
      }
    }
  }

  Widget _field(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        onChanged: onChanged,
        decoration: _inputDeco(hint, icon).copyWith(
          errorText: errorText,
          errorStyle: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
        ),
      );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.38)),
        prefixIcon: Icon(icon,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            size: 18),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00C896), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5)),
      );
}

class _ReviewMultipleDialog extends StatefulWidget {
  final List<InventoryIngredient> items;
  final Map<String, double> basePackageQtyById;
  final Set<String> opaqueIds;
  const _ReviewMultipleDialog({
    required this.items,
    this.basePackageQtyById = const {},
    this.opaqueIds = const {},
  });
  @override
  State<_ReviewMultipleDialog> createState() => _ReviewMultipleDialogState();
}

class _ReviewMultipleDialogState extends State<_ReviewMultipleDialog> {
  late List<InventoryIngredient> items;
  late List<TextEditingController> _qtyCtrls;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.items);
    _qtyCtrls = items
        .map((e) => TextEditingController(text: _fmtQty(e.quantity)))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmtQty(double v) => (v - v.roundToDouble()).abs() < 0.01
      ? v.round().toString()
      : double.parse(v.toStringAsFixed(2)).toString();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍 Revisar Productos (IA)',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  final base =
                      widget.basePackageQtyById[item.id] ?? item.quantity;
                  final isOpaque = widget.opaqueIds.contains(item.id);
                  return Card(
                    color: Theme.of(context).appBarTheme.backgroundColor,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: item.name,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero),
                                  onChanged: (val) {
                                    items[i] = item.copyWith(name: val);
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.45)),
                                onPressed: () {
                                  setState(() {
                                    items.removeAt(i);
                                    _qtyCtrls[i].dispose();
                                    _qtyCtrls.removeAt(i);
                                  });
                                },
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              SizedBox(
                                width: 62,
                                child: TextField(
                                  controller: _qtyCtrls[i],
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.78),
                                      fontSize: 13),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero),
                                  onChanged: (val) {
                                    final parsed = double.tryParse(
                                        val.trim().replaceAll(',', '.'));
                                    if (parsed != null && parsed > 0) {
                                      items[i] =
                                          item.copyWith(quantity: parsed);
                                    }
                                  },
                                ),
                              ),
                              Text(item.unit,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                      fontSize: 13)),
                              if (item.preparation == 'abierto / en uso') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB300)
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Abierto',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFFFFB300),
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                              if (isOpaque) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  'Opaco',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.orangeAccent),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final f in const [
                                (1.0, '100%'),
                                (0.75, '3/4'),
                                (0.5, '1/2'),
                                (0.25, '1/4'),
                              ])
                                InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () {
                                    final newQty = base * f.$1;
                                    setState(() {
                                      _qtyCtrls[i].text = _fmtQty(newQty);
                                      items[i] = item.copyWith(
                                        quantity: newQty,
                                        preparation: f.$1 < 0.99
                                            ? 'abierto / en uso'
                                            : '',
                                      );
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      f.$2,
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C896)),
                onPressed: () => Navigator.pop(context, items),
                child: const Text('Confirmar y Guardar',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;

  const _StatBadge(this.label, this.subtitle, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }
}

class _WalletGroceryImportBanner extends StatelessWidget {
  final List<WalletGroceryCandidate> candidates;
  final VoidCallback onImportAll;
  final ValueChanged<WalletGroceryCandidate> onImportOne;
  final ValueChanged<WalletGroceryCandidate> onDismissOne;

  const _WalletGroceryImportBanner({
    required this.candidates,
    required this.onImportAll,
    required this.onImportOne,
    required this.onDismissOne,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    const accent = Color(0xFF00C896);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🛒 Detectado en WalletAI (${candidates.length})',
                  style: TextStyle(
                    color: onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              if (candidates.length > 1)
                TextButton(
                  onPressed: onImportAll,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Agregar todo',
                    style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...candidates.take(4).map((c) {
            final priceLabel = c.totalPrice != null
                ? ' · ${c.currency} ${c.totalPrice!.toStringAsFixed(2)}'
                : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.itemName} (${c.quantity == c.quantity.roundToDouble() ? c.quantity.toInt() : c.quantity.toStringAsFixed(1)} ${c.unit})$priceLabel',
                          style: TextStyle(
                            color: onSurface,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (c.rawDescription != c.itemName)
                          Text(
                            c.rawDescription,
                            style: TextStyle(
                              color: onSurface.withValues(alpha: 0.55),
                              fontSize: 10.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 17, color: onSurface.withValues(alpha: 0.5)),
                    tooltip: 'Omitir',
                    onPressed: () => onDismissOne(c),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: () => onImportOne(c),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Agregar',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }),
          if (candidates.length > 4)
            Text(
              '+ ${candidates.length - 4} productos más esperando confirmación',
              style: TextStyle(
                fontSize: 11,
                color: onSurface.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }
}
