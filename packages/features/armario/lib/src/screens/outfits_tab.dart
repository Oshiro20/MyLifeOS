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

    Widget content;
    if (outfits.isEmpty) {
      content = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.style_outlined, size: 64, color: Colors.white12),
            SizedBox(height: 12),
            Text('Sin outfits guardados',
                style: TextStyle(color: Colors.white38, fontSize: 17)),
            SizedBox(height: 6),
            Text(
              'Guarda un outfit desde "Sugeridos"\no créalo aquí con el botón +.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 13),
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

        return Container(
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
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                Text('${outfit.timesWorn}× usado',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 11)),
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
                _Tag(outfit.occasion), const SizedBox(width: 6),
                _Tag(outfit.season.name),
              ]),
            ],
          ),
        );
      },
    );
    }

    return Stack(
      children: [
        content,
        Positioned(
          right: 16, bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_outfit',
            backgroundColor: const Color(0xFF00C896),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MannequinCanvasScreen()),
              );
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
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
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Crear Outfit', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Nombre (ej: Outfit de playa)',
              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
              filled: true, fillColor: const Color(0xFF2A2A40),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Prendas:', style: TextStyle(color: Colors.white70)),
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
                  title: Text(g.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                  subtitle: Text(g.type.label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
                  trailing: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? const Color(0xFF00C896) : Colors.white38,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (_name.text.trim().isEmpty || _selected.isEmpty) return;
              widget.onCreate(_name.text.trim(), _selected.toList(), _occasion, _season);
              Navigator.pop(context);
            },
            child: const Text('Guardar Outfit', style: TextStyle(color: Colors.white, fontSize: 16)),
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
        width: 20, height: 20,
        decoration: BoxDecoration(
          color: _color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white12, width: 1),
        ),
      );
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A40),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 10)),
      );
}
