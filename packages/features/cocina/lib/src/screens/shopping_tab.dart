import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import '../providers/cocina_providers.dart';

class ShoppingTab extends ConsumerWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipesProvider);
    final items = state.shoppingList;
    final notifier = ref.read(recipesProvider.notifier);

    // Group items by category
    final grouped = _groupByCategory(items);

    return Stack(
      children: [
        items.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart_outlined,
                        size: 64, color: Colors.white12),
                    const SizedBox(height: 12),
                    const Text('Lista de compras vacía',
                        style: TextStyle(color: Colors.white38, fontSize: 17)),
                    const SizedBox(height: 6),
                    const Text(
                      'Genera una lista desde tus recetas favoritas\nen la pestaña de Sugerencias.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 200),
                children: [
                  // Summary card
                  _SummaryCard(
                    total: items.length,
                    bought: items.where((i) => i.bought).length,
                    onShare: () => _shareList(context, items),
                    onClearAll: () => _confirmClearAll(context, ref),
                  ),
                  const SizedBox(height: 12),
                  // Grouped items by category
                  ...grouped.entries.map((entry) {
                    final category = entry.key;
                    final categoryItems = entry.value;
                    return _CategorySection(
                      category: category,
                      items: categoryItems,
                      onToggle: (item) => notifier.toggleShoppingItem(item.id),
                      onDelete: (item) => notifier.deleteShoppingItem(item.id),
                      onAddToPantry: (item) => _addToPantry(context, ref, item),
                    );
                  }),
                  // Add manual item button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddManualItemDialog(context, ref),
                      icon: const Icon(Icons.add, color: Color(0xFF00C896)),
                      label: const Text('Agregar item manual',
                          style: TextStyle(color: Color(0xFF00C896))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00C896)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  // Bought items section
                  if (items.where((i) => i.bought).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('✅ Ya comprado',
                          style: TextStyle(
                              color: Colors.white38,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    ...items.where((i) => i.bought).map((item) =>
                        _BoughtItemTile(
                          item: item,
                          onToggle: () => notifier.toggleShoppingItem(item.id),
                          onDelete: () => notifier.deleteShoppingItem(item.id),
                        )),
                  ],
                ],
              ),
        // FABs
        Positioned(
          right: 16,
          bottom: 240,
          child: FloatingActionButton(
            heroTag: 'share_shopping',
            backgroundColor: const Color(0xFF25D366),
            mini: true,
            onPressed:
                items.isNotEmpty ? () => _shareList(context, items) : null,
            child: const Icon(Icons.share, color: Colors.white),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 160,
          child: FloatingActionButton(
            heroTag: 'clear_shopping',
            backgroundColor: const Color(0xFFFF5252),
            mini: true,
            onPressed:
                items.isNotEmpty ? () => _confirmClearAll(context, ref) : null,
            child: const Icon(Icons.delete_sweep, color: Colors.white),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 80,
          child: FloatingActionButton.extended(
            heroTag: 'gen_shopping',
            backgroundColor: const Color(0xFF00C896),
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('Generar lista',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
            onPressed: () {
              final recipesToUse = state.suggestions.isNotEmpty
                  ? state.suggestions
                  : state.recipes;

              if (recipesToUse.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'No hay recetas disponibles. Agrega recetas primero.'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              notifier.generateShoppingList(recipesToUse);
            },
          ),
        ),
      ],
    );
  }

  Map<String, List<ShoppingItem>> _groupByCategory(List<ShoppingItem> items) {
    final grouped = <String, List<ShoppingItem>>{};

    // Category mapping
    const categoryMap = {
      // Proteínas
      'pollo': '🥩 Proteínas y Carnes',
      'carne': '🥩 Proteínas y Carnes',
      'res': '🥩 Proteínas y Carnes',
      'cerdo': '🥩 Proteínas y Carnes',
      'pescado': '🥩 Proteínas y Carnes',
      'atún': '🥩 Proteínas y Carnes',
      'huevo': '🥩 Proteínas y Carnes',
      // Lácteos
      'leche': '🧀 Lácteos',
      'queso': '🧀 Lácteos',
      'crema': '🧀 Lácteos',
      'yogur': '🧀 Lácteos',
      'yogurt': '🧀 Lácteos',
      'mantequilla': '🧀 Lácteos',
      // Verduras y frutas
      'cebolla': '🥬 Verduras y Frutas',
      'ajo': '🥬 Verduras y Frutas',
      'tomate': '🥬 Verduras y Frutas',
      'papa': '🥬 Verduras y Frutas',
      'zanahoria': '🥬 Verduras y Frutas',
      'limón': '🥬 Verduras y Frutas',
      'limon': '🥬 Verduras y Frutas',
      'perejil': '🥬 Verduras y Frutas',
      'culantro': '🥬 Verduras y Frutas',
      'cilantro': '🥬 Verduras y Frutas',
      // Granos y harinas
      'arroz': '🌾 Granos y Harinas',
      'harina': '🌾 Granos y Harinas',
      'fideo': '🌾 Granos y Harinas',
      'tallarín': '🌾 Granos y Harinas',
      'tallarin': '🌾 Granos y Harinas',
      'pasta': '🌾 Granos y Harinas',
      'spaghetti': '🌾 Granos y Harinas',
      'azúcar': '🌾 Granos y Harinas',
      'azucar': '🌾 Granos y Harinas',
      // Condimentos y aceites
      'aceite': '🧂 Condimentos y Aceites',
      'sal': '🧂 Condimentos y Aceites',
      'pimienta': '🧂 Condimentos y Aceites',
      'comino': '🧂 Condimentos y Aceites',
      'ají': '🧂 Condimentos y Aceites',
      'aji': '🧂 Condimentos y Aceites',
      // Salsas y envasados
      'ketchup': '🥫 Salsas y Envasados',
      'mayonesa': '🥫 Salsas y Envasados',
      'mostaza': '🥫 Salsas y Envasados',
      'soya': '🥫 Salsas y Envasados',
      'vinagre': '🥫 Salsas y Envasados',
      // Bebidas
      'agua': '🥤 Bebidas',
      'jugo': '🥤 Bebidas',
      'gaseosa': '🥤 Bebidas',
      'refresco': '🥤 Bebidas',
    };

    for (final item in items) {
      if (item.bought) continue; // Skip bought items

      String category = '🛒 Otros';
      final lower = item.name.toLowerCase();
      for (final entry in categoryMap.entries) {
        if (lower.contains(entry.key)) {
          category = entry.value;
          break;
        }
      }

      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(item);
    }

    return grouped;
  }

  Future<void> _shareList(
      BuildContext context, List<ShoppingItem> items) async {
    final pending = items.where((i) => !i.bought).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay items pendientes para compartir')),
      );
      return;
    }

    // Group by category for sharing
    final grouped = <String, List<ShoppingItem>>{};
    for (final item in pending) {
      final category = item.unit;
      if (!grouped.containsKey(category)) grouped[category] = [];
      grouped[category]!.add(item);
    }

    final buffer = StringBuffer();
    buffer.writeln('🛒 *Lista de Compras - MyLifeOS*');
    buffer.writeln('📅 ${DateTime.now().toString().split(' ')[0]}');
    buffer.writeln('');
    for (final entry in grouped.entries) {
      buffer.writeln('📦 ${entry.key.toUpperCase()}');
      for (final item in entry.value) {
        final check = item.bought ? '✅' : '☐';
        buffer.writeln('  $check ${item.name} (${item.quantity} ${item.unit})');
      }
      buffer.writeln('');
    }
    buffer.writeln('📊 Total: ${pending.length} productos');
    buffer.writeln('📱 Generado por MyLifeOS');

    final text = buffer.toString();

    // Show sharing options dialog
    if (context.mounted) {
      _showShareOptionsDialog(context, text);
    }
  }

  Future<void> _showShareOptionsDialog(
      BuildContext context, String text) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152019),
        title: const Text('📤 Compartir lista',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Cómo quieres compartir tu lista?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            // WhatsApp button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _shareToWhatsApp(context, text);
                },
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text('Compartir por WhatsApp',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Copy to clipboard button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _copyToClipboard(context, text);
                },
                icon: const Icon(Icons.copy, color: Color(0xFF00C896)),
                label: const Text('Copiar al portapapeles',
                    style: TextStyle(color: Color(0xFF00C896))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00C896)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareToWhatsApp(BuildContext context, String text) async {
    // Copy to clipboard first
    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '📋 Lista copiada. Abre WhatsApp y pega la lista.',
          ),
          backgroundColor: const Color(0xFF25D366),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Lista copiada al portapapeles'),
          backgroundColor: Color(0xFF00E676),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addToPantry(
      BuildContext context, WidgetRef ref, ShoppingItem item) async {
    final pantryNotifier = ref.read(inventoryProvider.notifier);

    try {
      await pantryNotifier.add(InventoryIngredient(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: item.name,
        primaryCategory: _guessCategory(item.name),
        quantity: item.quantity,
        unit: item.unit,
      ));

      // Remove from shopping list
      await ref.read(recipesProvider.notifier).deleteShoppingItem(item.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${item.name} añadido a la despensa'),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al añadir a despensa: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _guessCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('pollo') ||
        lower.contains('carne') ||
        lower.contains('pescado')) {
      return 'Proteínas animales';
    }
    if (lower.contains('leche') ||
        lower.contains('queso') ||
        lower.contains('yogur')) {
      return 'Lácteos';
    }
    if (lower.contains('cebolla') ||
        lower.contains('tomate') ||
        lower.contains('papa')) {
      return 'Verduras';
    }
    if (lower.contains('arroz') ||
        lower.contains('harina') ||
        lower.contains('fideo')) {
      return 'Cereales y granos';
    }
    if (lower.contains('aceite') ||
        lower.contains('sal') ||
        lower.contains('pimienta')) {
      return 'Condimentos y especias';
    }
    return 'Otros';
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF152019),
        title: const Text('🗑️ Limpiar lista completa',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro de que quieres eliminar TODOS los items de la lista de compras?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar todo',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final state = ref.read(recipesProvider);
      for (final item in state.shoppingList) {
        await ref.read(recipesProvider.notifier).deleteShoppingItem(item.id);
      }
    }
  }

  Future<void> _showAddManualItemDialog(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String selectedUnit = 'unidades';

    final units = [
      'unidades',
      'paquete',
      'botella',
      'lata',
      'frasco',
      'kilos',
      'gramos',
      'litros'
    ];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF152019),
          title: const Text('🛒 Agregar item manual',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre del producto',
                  hintText: 'Ej: Arroz, Leche, Aceite...',
                  labelStyle: TextStyle(color: Colors.white54),
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      dropdownColor: const Color(0xFF152019),
                      items: units.map((u) {
                        return DropdownMenuItem(
                          value: u,
                          child: Text(u,
                              style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedUnit = val);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Unidad',
                        labelStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '📝 "$name" añadido a la lista (próximamente editable)'),
                      backgroundColor: const Color(0xFF00E676),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896)),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int total;
  final int bought;
  final VoidCallback onShare;
  final VoidCallback onClearAll;

  const _SummaryCard({
    required this.total,
    required this.bought,
    required this.onShare,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final pending = total - bought;
    final progress = total > 0 ? bought / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF152019),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00C896).withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pending por comprar',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                    ),
                    Text(
                      '$bought de $total comprados',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.54),
                          fontSize: 12),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: onShare,
                    icon: const Icon(Icons.share,
                        color: Color(0xFF25D366), size: 20),
                    tooltip: 'Compartir lista',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onClearAll,
                    icon: const Icon(Icons.delete_forever,
                        color: Color(0xFFFF5252), size: 20),
                    tooltip: 'Limpiar todo',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF00C896)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}% completado',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.54), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Category Section ─────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<ShoppingItem> items;
  final Function(ShoppingItem) onToggle;
  final Function(ShoppingItem) onDelete;
  final Function(ShoppingItem) onAddToPantry;

  const _CategorySection({
    required this.category,
    required this.items,
    required this.onToggle,
    required this.onDelete,
    required this.onAddToPantry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            category,
            style: const TextStyle(
                color: Color(0xFFFF9800),
                fontWeight: FontWeight.w700,
                fontSize: 13),
          ),
        ),
        ...items.map((item) => _ShoppingTile(
              item: item,
              onToggle: () => onToggle(item),
              onDelete: () => onDelete(item),
              onAddToPantry: () => onAddToPantry(item),
            )),
      ],
    );
  }
}

// ── Shopping Tile ────────────────────────────────────────────────────────────

class _ShoppingTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onAddToPantry;

  const _ShoppingTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
    required this.onAddToPantry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: item.bought ? const Color(0xFF1A2E22) : const Color(0xFF152019),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.bought
              ? const Color(0xFF66BB6A).withAlpha(60)
              : const Color(0xFF00C896).withAlpha(40),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Checkbox(
          value: item.bought,
          onChanged: (_) => onToggle(),
          activeColor: const Color(0xFF00C896),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            color: item.bought ? Colors.white38 : Colors.white,
            decoration: item.bought ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${item.quantity} ${item.unit}',
          style: TextStyle(
            color: item.bought ? Colors.white24 : Colors.white54,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onAddToPantry,
              icon:
                  const Icon(Icons.kitchen, size: 20, color: Color(0xFF00F0FF)),
              tooltip: 'Añadir a despensa',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Color(0xFFFF5252)),
              tooltip: 'Eliminar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        onTap: onToggle,
      ),
    );
  }
}

// ── Bought Item Tile ─────────────────────────────────────────────────────────

class _BoughtItemTile extends StatelessWidget {
  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _BoughtItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF66BB6A).withAlpha(30)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Checkbox(
          value: item.bought,
          onChanged: (_) => onToggle(),
          activeColor: const Color(0xFF66BB6A),
        ),
        title: Text(
          item.name,
          style: const TextStyle(
            color: Colors.white38,
            decoration: TextDecoration.lineThrough,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          '${item.quantity} ${item.unit}',
          style: const TextStyle(color: Colors.white24, fontSize: 12),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline,
              size: 20, color: Color(0xFFFF5252)),
          tooltip: 'Eliminar',
        ),
        onTap: onToggle,
      ),
    );
  }
}
