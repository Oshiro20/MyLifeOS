import 'dart:async';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../providers/cocina_providers.dart';
import '../../providers/cooking_session_provider.dart';
import 'recipe_cook_helper.dart';

/// Banner global de sesión activa visible en todas las pestañas de Cocina:
/// permite sumar ingredientes extra mientras cocinas y guardar sobras/porciones
/// listas en Despensa (para Cena o Mañana) al finalizar.
class CookingSessionBanner extends ConsumerStatefulWidget {
  final CookingSession session;

  const CookingSessionBanner({required this.session, super.key});

  @override
  ConsumerState<CookingSessionBanner> createState() =>
      _CookingSessionBannerState();
}

class _CookingSessionBannerState extends ConsumerState<CookingSessionBanner> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final elapsedMinutes = DateTime.now().difference(session.startedAt).inMinutes;
    final estimatedMinutes = session.estimatedDurationMinutes;

    String timeInfo;
    Color bgColor;
    if (estimatedMinutes != null) {
      final remaining = estimatedMinutes - elapsedMinutes;
      if (remaining > 0) {
        timeInfo = '~$remaining min restantes';
        bgColor = const Color(0xFFFF9800);
      } else {
        timeInfo = '⏰ Tiempo cumplido';
        bgColor = const Color(0xFF4CAF50);
      }
    } else {
      timeInfo = '$elapsedMinutes min cocinando';
      bgColor = const Color(0xFFFF9800);
    }

    final extrasSummary = session.extras.isEmpty
        ? null
        : '+${session.extras.map((e) => '${formatIngredientQty(e.quantity)} ${e.unit} ${e.name}').join(', ')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          const Icon(Icons.restaurant_menu, color: Colors.black, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeInfo,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  session.recipeName,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (extrasSummary != null)
                  Text(
                    extrasSummary,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => showAddCookingExtraSheet(context, ref),
            icon: const Icon(Icons.add, size: 15, color: Colors.black),
            label: const Text(
              'Extra',
              style: TextStyle(
                color: Colors.black,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            onPressed: () => _openFinishSheet(context, session),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Terminar',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFinishSheet(
    BuildContext context,
    CookingSession session,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FinishCookingSheet(session: session),
    );
  }
}

/// Abre el selector rápido de ingredientes de Despensa y devuelve ítem + cantidad.
Future<({InventoryIngredient item, double qty})?> pickCookingExtra(
  BuildContext context,
  List<InventoryIngredient> pantry,
) =>
    showModalBottomSheet<({InventoryIngredient item, double qty})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickExtraSheet(pantry: pantry),
    );

/// Abre una hoja rápida para añadir y descontar un ingrediente extra desde Despensa
/// (ej. "6 huevos" mientras cocinas menestra).
Future<bool> showAddCookingExtraSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final invNotifier = ref.read(inventoryProvider.notifier);
  await invNotifier.load();
  if (!context.mounted) return false;

  final pantry = ref.read(inventoryProvider).ingredients;
  if (pantry.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tu Despensa está vacía; agrega ingredientes primero.'),
      ),
    );
    return false;
  }

  final picked = await pickCookingExtra(context, pantry);
  if (picked == null) return false;

  final deducted = await invNotifier.deductRecipeIngredients([
    RecipeIngredient(
      id: 'extra_${DateTime.now().microsecondsSinceEpoch}',
      recipeId: 'extra',
      ingredientName: picked.item.name,
      quantity: picked.qty,
      unit: picked.item.unit,
    ),
  ]);

  ref.read(cookingSessionProvider.notifier).addExtra(
        pantryId: picked.item.id,
        name: picked.item.name,
        quantity: picked.qty,
        unit: picked.item.unit,
      );

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deducted.isEmpty
              ? '+${formatIngredientQty(picked.qty)} ${picked.item.unit} de ${picked.item.name} anotado en cocción'
              : '🥚 +${formatIngredientQty(picked.qty)} ${picked.item.unit} de ${picked.item.name} descontado y agregado',
        ),
        backgroundColor: const Color(0xFF00C896),
        duration: const Duration(milliseconds: 2200),
      ),
    );
  }
  return true;
}

class _PickExtraSheet extends StatefulWidget {
  final List<InventoryIngredient> pantry;
  const _PickExtraSheet({required this.pantry});

  @override
  State<_PickExtraSheet> createState() => _PickExtraSheetState();
}

class _PickExtraSheetState extends State<_PickExtraSheet> {
  String _query = '';
  InventoryIngredient? _selected;
  double _qty = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _query.isEmpty
        ? widget.pantry
        : widget.pantry
            .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.78,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
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
          const SizedBox(height: 12),
          Text(
            '➕ Añadir ingrediente extra al plato',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar en despensa (ej. Huevo, Arroz, Queso)...',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (_, idx) {
                final item = filtered[idx];
                final isSelected = _selected?.id == item.id;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor:
                      const Color(0xFF00C896).withValues(alpha: 0.14),
                  title: Text(item.name, style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    'Disponible: ${formatIngredientQty(item.quantity)} ${item.unit}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF00C896))
                      : null,
                  onTap: () => setState(() {
                    _selected = item;
                    _qty = item.quantity >= 1 ? 1.0 : item.quantity;
                  }),
                );
              },
            ),
          ),
          if (_selected != null) ...[
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Cantidad de ${_selected!.name}:',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _qty > 0.25
                      ? () => setState(() {
                            _qty = (_qty - (_qty > 1 ? 1.0 : 0.25))
                                .clamp(0.1, _selected!.quantity);
                          })
                      : null,
                ),
                Text(
                  '${formatIngredientQty(_qty)} ${_selected!.unit}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C896),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _qty < _selected!.quantity
                      ? () => setState(() {
                            _qty = (_qty + 1.0)
                                .clamp(0.1, _selected!.quantity);
                          })
                      : null,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final quick in const [1.0, 2.0, 3.0, 4.0, 6.0])
                  if (quick <= _selected!.quantity + 0.001)
                    ChoiceChip(
                      label: Text(formatIngredientQty(quick),
                          style: const TextStyle(fontSize: 11)),
                      selected: (_qty - quick).abs() < 0.01,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _qty = quick),
                    ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.pop(context, (item: _selected!, qty: _qty)),
                icon: const Icon(Icons.check, color: Colors.black),
                label: const Text('Descontar y agregar a cocción',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  foregroundColor: Colors.black,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FinishCookingSheet extends ConsumerStatefulWidget {
  final CookingSession session;
  const _FinishCookingSheet({required this.session});

  @override
  ConsumerState<_FinishCookingSheet> createState() =>
      _FinishCookingSheetState();
}

class _FinishCookingSheetState extends ConsumerState<_FinishCookingSheet> {
  bool _saveLeftover = false;
  double _leftoverFraction = 0.5;
  final Map<String, double> _extraLeftoverQty = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final e in widget.session.extras) {
      _extraLeftoverQty[e.name] =
          double.parse((e.quantity * 0.5).toStringAsFixed(2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = widget.session;

    return Container(
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
            '🍽️ Finalizar "${session.recipeName}"',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          SwitchListTile.adaptive(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Guardé resto preparado para Cena / Mañana',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Se guardará en Despensa → Preparados / Listos (Refrigerador)',
              style: TextStyle(fontSize: 11),
            ),
            value: _saveLeftover,
            activeTrackColor: const Color(0xFF00C896),
            onChanged: (v) => setState(() => _saveLeftover = v),
          ),
          if (_saveLeftover) ...[
            const SizedBox(height: 6),
            Text(
              '¿Qué fracción del plato principal quedó?',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final opt in const [
                  (0.5, 'Mitad (1/2)'),
                  (0.33, '1/3'),
                  (0.67, '2/3'),
                  (0.25, '1/4'),
                  (1.0, 'Todo para luego'),
                ])
                  ChoiceChip(
                    label: Text(opt.$2, style: const TextStyle(fontSize: 11.5)),
                    selected: (_leftoverFraction - opt.$1).abs() < 0.02,
                    onSelected: (_) =>
                        setState(() => _leftoverFraction = opt.$1),
                  ),
              ],
            ),
            if (session.extras.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '¿Cuántos extras quedaron para luego?',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              ...session.extras.map((extra) {
                final cur = _extraLeftoverQty[extra.name] ?? 0;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${extra.name} (preparaste ${formatIngredientQty(extra.quantity)})',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                      onPressed: cur > 0
                          ? () => setState(() {
                                final next = (cur - 1).clamp(0.0, extra.quantity);
                                _extraLeftoverQty[extra.name] = next;
                              })
                          : null,
                    ),
                    Text('${formatIngredientQty(cur)} ${extra.unit}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      onPressed: cur < extra.quantity
                          ? () => setState(() {
                                final next = (cur + 1).clamp(0.0, extra.quantity);
                                _extraLeftoverQty[extra.name] = next;
                              })
                          : null,
                    ),
                  ],
                );
              }),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _confirmFinish,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, color: Colors.black),
              label: Text(
                _saveLeftover
                    ? 'Guardar resto y finalizar'
                    : 'Todo consumido · Finalizar',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmFinish() async {
    setState(() => _saving = true);
    try {
      final session = widget.session;
      if (_saveLeftover) {
        final invNotifier = ref.read(inventoryProvider.notifier);
        final expiry = DateTime.now().add(const Duration(days: 3));
        const uuid = Uuid();

        final servingsRemaining = (session.scaledServings * _leftoverFraction)
            .clamp(0.25, session.scaledServings.toDouble());
        await invNotifier.add(
          InventoryIngredient(
            id: uuid.v4(),
            name: '${session.recipeName} (preparado)',
            primaryCategory: 'Preparados / Listos',
            subCategory: 'Porción guardada',
            preparation: 'cocido / listo',
            quantity: double.parse(servingsRemaining.toStringAsFixed(2)),
            unit: 'unidades',
            expirationDate: expiry,
            storageArea: 'Refrigerador',
          ),
        );

        for (final extra in session.extras) {
          final rem = _extraLeftoverQty[extra.name] ?? 0;
          if (rem <= 0) continue;
          await invNotifier.add(
            InventoryIngredient(
              id: uuid.v4(),
              name: '${extra.name} (cocido)',
              primaryCategory: 'Preparados / Listos',
              subCategory: 'Extra listo',
              preparation: 'cocido / listo',
              quantity: rem,
              unit: extra.unit,
              expirationDate: expiry,
              storageArea: 'Refrigerador',
            ),
          );
        }
      }

      ref.read(cookingSessionProvider.notifier).endSession();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (_saveLeftover) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '🥡 Porciones guardadas en Despensa → Preparados / Listos (Refrigerador)'),
            backgroundColor: Color(0xFF00C896),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
