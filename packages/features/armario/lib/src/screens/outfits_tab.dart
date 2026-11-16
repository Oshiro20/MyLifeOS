import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import '../providers/armario_provider.dart';
import 'mannequin_canvas_screen.dart';

class OutfitsTab extends ConsumerWidget {
  const OutfitsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(armarioProvider);
    final outfits = state.outfits;
    final garmentMap = {for (final g in state.garments) g.id: g};

    final onSurface = Theme.of(context).colorScheme.onSurface;

    Widget content;
    if (outfits.isEmpty) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_outlined,
                size: 64, color: onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 12),
            Text('Sin outfits guardados',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.45), fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              'Guarda un outfit desde "Sugeridos"\no créalo aquí con el botón +.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: onSurface.withValues(alpha: 0.35), fontSize: 13),
            ),
          ],
        ),
      );
    } else {
      content = ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: outfits.length,
        itemBuilder: (ctx, i) {
          final outfit = outfits[i];
          final garments = outfit.garmentIds
              .map((id) => garmentMap[id])
              .whereType<WardrobeGarment>()
              .toList();

          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _showOutfitDetail(context, ref, outfit, garments),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(outfit.name,
                          style: TextStyle(
                              color: onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                    ),
                    Text('${outfit.timesWorn}× usado',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38),
                            fontSize: 11)),
                  ]),
                  const SizedBox(height: 8),
                  Row(
                    children: garments
                        .take(4)
                        .map((g) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _ColorDot(hex: g.primaryColor),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    _Tag(outfit.occasion),
                    const SizedBox(width: 6),
                    _Tag(outfit.season.name),
                    const Spacer(),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () async {
                        await ref
                            .read(armarioProvider.notifier)
                            .wearOutfit(outfit.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '✨ "${outfit.name}" marcado como usado hoy'),
                              backgroundColor: const Color(0xFF00C896),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.checkroom,
                          size: 16, color: Color(0xFF00C896)),
                      label: const Text('Usar hoy',
                          style: TextStyle(
                              color: Color(0xFF00C896), fontSize: 12)),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Eliminar outfit',
                      icon: Icon(Icons.delete_outline,
                          size: 18,
                          color: onSurface.withValues(alpha: 0.45)),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => AlertDialog(
                            backgroundColor: Theme.of(dialogCtx).cardColor,
                            title: const Text('¿Eliminar outfit?'),
                            content: Text(
                                'Se eliminará "${outfit.name}" de tus outfits guardados.'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogCtx, false),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent),
                                onPressed: () =>
                                    Navigator.pop(dialogCtx, true),
                                child: const Text('Eliminar',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(armarioProvider.notifier)
                              .deleteOutfit(outfit.id);
                        }
                      },
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      );
    }

    return Stack(
      children: [
        content,
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_outfit',
            backgroundColor: const Color(0xFF00C896),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const MannequinCanvasScreen()),
              );
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showOutfitDetail(
    BuildContext context,
    WidgetRef ref,
    Outfit outfit,
    List<WardrobeGarment> garments,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(outfit.name,
                style: TextStyle(
                    color: onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('${outfit.occasion} · ${outfit.season.label} · ${outfit.timesWorn}× usado',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.55), fontSize: 12)),
            const SizedBox(height: 12),
            if (garments.isEmpty)
              Text('Las prendas asociadas ya no están en el armario.',
                  style: TextStyle(
                      color: onSurface.withValues(alpha: 0.6), fontSize: 13))
            else
              ...garments.map((g) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _ColorDot(hex: g.primaryColor),
                    title: Text(g.name, style: TextStyle(color: onSurface)),
                    subtitle: Text(g.type.label,
                        style: TextStyle(
                            color: onSurface.withValues(alpha: 0.5),
                            fontSize: 12)),
                  )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C896)),
                onPressed: () async {
                  await ref.read(armarioProvider.notifier).wearOutfit(outfit.id);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.checkroom, color: Colors.white),
                label: const Text('Usar hoy',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateOutfitSheet extends StatefulWidget {
  final List<WardrobeGarment> garments;
  final Function(String, List<String>, String, Season) onCreate;
  const _CreateOutfitSheet({required this.garments, required this.onCreate});
  @override
  State<_CreateOutfitSheet> createState() => _CreateOutfitSheetState();
}

class _CreateOutfitSheetState extends State<_CreateOutfitSheet> {
  final _name = TextEditingController();
  final Set<String> _selected = {};
  final String _occasion = 'casual';
  final Season _season = Season.all;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Crear Outfit',
              style: TextStyle(
                  color: onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            style: TextStyle(color: onSurface),
            decoration: InputDecoration(
              hintText: 'Nombre (ej: Outfit de playa)',
              hintStyle: TextStyle(
                  color: onSurface.withValues(alpha: 0.38)),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF2A2A40)
                  : const Color(0xFFEAF4F0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          Text('Prendas:',
              style: TextStyle(color: onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: widget.garments.length,
              itemBuilder: (ctx, i) {
                final g = widget.garments[i];
                final isSelected = _selected.contains(g.id);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _ColorDot(hex: g.primaryColor),
                  title: Text(g.name, style: TextStyle(color: onSurface)),
                  subtitle: Text(g.type.label,
                      style:
                          TextStyle(color: onSurface.withValues(alpha: 0.45))),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? const Color(0xFF00C896)
                        : onSurface.withValues(alpha: 0.38),
                  ),
                  onTap: () => setState(() {
                    if (isSelected) {
                      _selected.remove(g.id);
                    } else {
                      _selected.add(g.id);
                    }
                  }),
                );
              },
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C896),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_name.text.trim().isEmpty || _selected.isEmpty) return;
              widget.onCreate(
                  _name.text.trim(), _selected.toList(), _occasion, _season);
              Navigator.pop(context);
            },
            child: const Text('Guardar Outfit',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final String hex;
  const _ColorDot({required this.hex});

  Color get _color {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.15),
              width: 1),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A40) : const Color(0xFFE0F7F0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.65),
              fontSize: 10)),
    );
  }
}
