import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cocina_providers.dart';

class ShoppingTab extends ConsumerWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipesProvider);
    final items = state.shoppingList;
    final notifier = ref.read(recipesProvider.notifier);

    final pending = items.where((i) => !i.bought).toList();
    final bought = items.where((i) => i.bought).toList();

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
                padding: const EdgeInsets.all(12),
                children: [
                  if (pending.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Por comprar',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    ...pending.map(
                      (item) => _ShoppingTile(
                        key: ValueKey(item.id),
                        name: item.name,
                        subtitle: '${item.quantity} ${item.unit}',
                        checked: false,
                        onToggle: () => notifier.toggleShoppingItem(item.id),
                      ),
                    ),
                  ],
                  if (bought.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Ya comprado ✓',
                          style: TextStyle(
                              color: Colors.white24,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    ...bought.map(
                      (item) => _ShoppingTile(
                        key: ValueKey(item.id),
                        name: item.name,
                        subtitle: '${item.quantity} ${item.unit}',
                        checked: true,
                        onToggle: () => notifier.toggleShoppingItem(item.id),
                      ),
                    ),
                  ],
                ],
              ),
        // Botón: generar lista desde recetas con ≥75% cobertura
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'gen_shopping',
            backgroundColor: const Color(0xFF00C896),
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('Generar lista',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            onPressed: () => notifier.generateShoppingList(state.suggestions),
          ),
        ),
      ],
    );
  }
}

class _ShoppingTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final bool checked;
  final VoidCallback onToggle;

  const _ShoppingTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.checked,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CheckboxListTile(
        value: checked,
        onChanged: (_) => onToggle(),
        activeColor: const Color(0xFF00C896),
        title: Text(
          name,
          style: TextStyle(
            color: checked ? Colors.white24 : Colors.white,
            decoration: checked ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle,
            style: TextStyle(
                color: checked ? Colors.white12 : Colors.white38, fontSize: 12)),
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
