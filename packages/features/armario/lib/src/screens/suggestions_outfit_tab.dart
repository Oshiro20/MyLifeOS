import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/src/armario/entities/wardrobe_garment.dart';
import '../providers/armario_provider.dart';

/// Tab "Sugeridos" — pregunta "¿A dónde irás?" y muestra 3 outfits.
class SuggestionsOutfitTab extends ConsumerStatefulWidget {
  const SuggestionsOutfitTab({super.key});

  @override
  ConsumerState<SuggestionsOutfitTab> createState() =>
      _SuggestionsOutfitTabState();
}

class _SuggestionsOutfitTabState extends ConsumerState<SuggestionsOutfitTab> {
  String? _selectedOccasion;

  static const _occasions = <String, (IconData, String)>{
    'casual': (Icons.weekend_outlined, '🏠 Casual / Día a día'),
    'trabajo': (Icons.work_outline, '💼 Trabajo / Oficina'),
    'cita': (Icons.favorite_outline, '❤️ Cita romántica'),
    'fiesta': (Icons.celebration_outlined, '🎉 Fiesta / Evento'),
    'deporte': (Icons.fitness_center_outlined, '🏃 Deporte / Gym'),
    'formal': (Icons.school_outlined, '👔 Formal / Ceremonia'),
    'paseo': (Icons.park_outlined, '🌳 Paseo / Aire libre'),
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(armarioProvider);
    final profile = state.userProfile;

    // Si no tiene perfil, pedir que lo llene
    if (profile == null || !profile.consentGranted) {
      return _NoProfileBanner(
        onSetup: () => _showProfileForm(context, ref, profile),
      );
    }

    // Si no eligió ocasión, mostrar selector
    if (_selectedOccasion == null) {
      return _OccasionPicker(
        profile: profile,
        onPick: (occasion) => setState(() => _selectedOccasion = occasion),
      );
    }

    // Mostrar 3 outfits filtrados
    return _OutfitResults(
      occasion: _selectedOccasion!,
      suggestions: state.suggestions,
      garments: state.garments,
      onBack: () => setState(() => _selectedOccasion = null),
      onSave: (name, occasion, ids) {
        ref.read(armarioProvider.notifier).saveOutfit(Outfit(
              id: '',
              name: name,
              garmentIds: ids,
              occasion: occasion,
              createdAt: DateTime.now(),
            ));
      },
    );
  }

  void _showProfileForm(
      BuildContext ctx, WidgetRef ref, UserPhysicalProfile? current) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileFormSheet(
        current: current,
        onSave: (p) async {
          await ref.read(armarioProvider.notifier).saveProfile(p);
        },
      ),
    );
  }
}

// ── Banner: "Completa tu perfil" ─────────────────────────────────────────────

class _NoProfileBanner extends StatelessWidget {
  final VoidCallback onSetup;
  const _NoProfileBanner({required this.onSetup});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.person_outline, size: 72, color: Colors.white12),
          const SizedBox(height: 16),
          const Text('Configura tu perfil',
              style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Para sugerirte los mejores outfits necesito conocer tu estatura, peso, tono de piel y contextura.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C896),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onSetup,
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            label: const Text('Completar perfil',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

// ── Selector de ocasión ──────────────────────────────────────────────────────

class _OccasionPicker extends StatelessWidget {
  final UserPhysicalProfile profile;
  final void Function(String) onPick;

  const _OccasionPicker({required this.profile, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final greeting = profile.bodyType != null
        ? '${profile.height ?? ''}cm · ${profile.weight ?? ''}kg · ${profile.bodyType}'
        : '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        const Text('¿A dónde irás hoy?',
            style: TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (greeting.isNotEmpty)
          Text('Tu perfil: $greeting',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 12)),
        const SizedBox(height: 16),
        ..._SuggestionsOutfitTabState._occasions.entries.map((e) =>
            _OccasionCard(
              label: e.value.$2,
              icon: e.value.$1,
              onTap: () => onPick(e.key),
            )),
      ],
    );
  }
}

class _OccasionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _OccasionCard(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF152019), Color(0xFF1A2E22)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFF00C896).withAlpha(40), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF00C896), size: 24),
            const SizedBox(width: 16),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── Resultados: 3 outfits ────────────────────────────────────────────────────

class _OutfitResults extends StatelessWidget {
  final String occasion;
  final List<List<WardrobeGarment>> suggestions;
  final List<WardrobeGarment> garments;
  final VoidCallback onBack;
  final void Function(String name, String occasion, List<String> ids) onSave;

  const _OutfitResults({
    required this.occasion,
    required this.suggestions,
    required this.garments,
    required this.onBack,
    required this.onSave,
  });

  static const _typeEmoji = {
    GarmentType.shirt: '👕',
    GarmentType.tshirt: '👚',
    GarmentType.pants: '👖',
    GarmentType.jeans: '🩱',
    GarmentType.shoes: '👟',
    GarmentType.jacket: '🧥',
    GarmentType.accessories: '💍',
    GarmentType.dress: '👗',
    GarmentType.shorts: '🩳',
    GarmentType.sweater: '🧶',
    GarmentType.hoodie: '🧥',
    GarmentType.skirt: '👗',
    GarmentType.other: '🎽',
  };

  static const _occasionLabel = {
    'casual': '🏠 Casual',
    'trabajo': '💼 Trabajo',
    'cita': '❤️ Cita',
    'fiesta': '🎉 Fiesta',
    'deporte': '🏃 Deporte',
    'formal': '👔 Formal',
    'paseo': '🌳 Paseo',
  };

  List<List<WardrobeGarment>> _filterByOccasion() {
    // Map occasion → GarmentStyle preference
    final preferredStyles = <GarmentStyle>{};
    switch (occasion) {
      case 'casual':
      case 'paseo':
        preferredStyles.addAll([GarmentStyle.casual, GarmentStyle.streetwear]);
        break;
      case 'trabajo':
      case 'formal':
        preferredStyles.addAll([GarmentStyle.formal, GarmentStyle.elegant]);
        break;
      case 'cita':
        preferredStyles
            .addAll([GarmentStyle.elegant, GarmentStyle.casual, GarmentStyle.formal]);
        break;
      case 'fiesta':
        preferredStyles.addAll([GarmentStyle.streetwear, GarmentStyle.elegant]);
        break;
      case 'deporte':
        preferredStyles.add(GarmentStyle.sport);
        break;
    }

    final clean = garments.where((g) => g.isClean).toList();
    final tops = clean.where((g) =>
        g.type == GarmentType.shirt ||
        g.type == GarmentType.tshirt ||
        g.type == GarmentType.sweater ||
        g.type == GarmentType.hoodie);
    final bottoms = clean.where((g) =>
        g.type == GarmentType.pants ||
        g.type == GarmentType.jeans ||
        g.type == GarmentType.shorts ||
        g.type == GarmentType.skirt);
    final shoes = clean.where((g) => g.type == GarmentType.shoes).toList();

    // Prioritize matching styles
    final scoredTops = tops.toList()
      ..sort((a, b) {
        final aMatch = preferredStyles.contains(a.style) ? 0 : 1;
        final bMatch = preferredStyles.contains(b.style) ? 0 : 1;
        return aMatch.compareTo(bMatch);
      });
    final scoredBottoms = bottoms.toList()
      ..sort((a, b) {
        final aMatch = preferredStyles.contains(a.style) ? 0 : 1;
        final bMatch = preferredStyles.contains(b.style) ? 0 : 1;
        return aMatch.compareTo(bMatch);
      });

    final results = <List<WardrobeGarment>>[];
    for (final top in scoredTops) {
      for (final bottom in scoredBottoms) {
        final shoe = shoes.isNotEmpty ? shoes.first : null;
        results.add([top, bottom, if (shoe != null) shoe]);
        if (results.length >= 3) return results;
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterByOccasion();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(Icons.arrow_back_ios,
                    color: Colors.white54, size: 18),
              ),
              const SizedBox(width: 8),
              Text(_occasionLabel[occasion] ?? occasion,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${filtered.length} opciones',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                      'No hay suficientes prendas para esta ocasión.\nAgrega más prendas limpias.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 14)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final combo = filtered[i];
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF152019), Color(0xFF1A2E22)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF00C896).withAlpha(50)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Opción ${i + 1}',
                              style: const TextStyle(
                                  color: Color(0xFF00C896),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 12),
                          Row(
                            children: combo
                                .map((g) => Expanded(
                                      child: Column(
                                        children: [
                                          Text(
                                              _typeEmoji[g.type] ?? '🎽',
                                              style: const TextStyle(
                                                  fontSize: 36)),
                                          const SizedBox(height: 4),
                                          Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              color: _parseColor(
                                                  g.primaryColor),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                  color: Colors.white24),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(g.name,
                                              style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          Text(g.type.label,
                                              style: const TextStyle(
                                                  color: Colors.white30,
                                                  fontSize: 9)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C896),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                final ids =
                                    combo.map((g) => g.id).toList();
                                onSave(
                                    'Outfit ${occasion} ${i + 1}',
                                    occasion,
                                    ids);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Outfit guardado ✓'),
                                      backgroundColor:
                                          Color(0xFF66BB6A)),
                                );
                              },
                              icon: const Icon(
                                  Icons.bookmark_add_outlined,
                                  color: Colors.white,
                                  size: 16),
                              label: const Text('Guardar',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(
          int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

// ── Formulario de Perfil Físico ──────────────────────────────────────────────

class _ProfileFormSheet extends StatefulWidget {
  final UserPhysicalProfile? current;
  final Future<void> Function(UserPhysicalProfile) onSave;
  const _ProfileFormSheet({this.current, required this.onSave});
  @override
  State<_ProfileFormSheet> createState() => _ProfileFormSheetState();
}

class _ProfileFormSheetState extends State<_ProfileFormSheet> {
  late final TextEditingController _heightCtrl;
  late final TextEditingController _weightCtrl;
  String _skinTone = 'medio';
  String _bodyType = 'promedio';
  String _hairType = 'lacio';
  bool _saving = false;

  static const _skinOptions = ['claro', 'medio', 'trigueño', 'oscuro'];
  static const _bodyOptions = ['delgado', 'atlético', 'promedio', 'robusto'];
  static const _hairOptions = ['lacio', 'ondulado', 'rizado'];

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _heightCtrl = TextEditingController(text: c?.height ?? '');
    _weightCtrl = TextEditingController(text: c?.weight ?? '');
    _skinTone = c?.skinTone ?? 'medio';
    _bodyType = c?.bodyType ?? 'promedio';
    _hairType = c?.hairType ?? 'lacio';
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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)))),
            const Text('Tu perfil físico',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
                'Esta información se guarda localmente y se usa solo para sugerirte outfits.',
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 16),

            // Estatura y Peso
            Row(children: [
              Expanded(child: _field(_heightCtrl, 'Estatura (cm)', Icons.height,
                  keyboardType: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _field(_weightCtrl, 'Peso (kg)', Icons.monitor_weight_outlined,
                  keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 10),

            // Tono de piel
            _dropdownField('Tono de piel', Icons.palette_outlined, _skinTone,
                _skinOptions, (v) => setState(() => _skinTone = v!)),
            const SizedBox(height: 10),

            // Contextura
            _dropdownField('Contextura', Icons.accessibility_new_outlined,
                _bodyType, _bodyOptions, (v) => setState(() => _bodyType = v!)),
            const SizedBox(height: 10),

            // Tipo de cabello
            _dropdownField('Tipo de cabello', Icons.face_outlined, _hairType,
                _hairOptions, (v) => setState(() => _hairType = v!)),
            const SizedBox(height: 20),

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
                    : const Text('Guardar perfil',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(UserPhysicalProfile(
        id: widget.current?.id ?? 'user_profile_singleton',
        skinTone: _skinTone,
        bodyType: _bodyType,
        height: _heightCtrl.text.trim(),
        weight: _weightCtrl.text.trim(),
        hairType: _hairType,
        consentGranted: true,
        updatedAt: DateTime.now(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: const Color(0xFFFF5252)),
        );
      }
    }
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
          {TextInputType keyboardType = TextInputType.text}) =>
      TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: _deco(hint, icon),
      );

  Widget _dropdownField(String label, IconData icon, String value,
          List<String> options, void Function(String?) onChanged) =>
      DropdownButtonFormField<String>(
        value: value,
        dropdowncolor: Theme.of(context).cardColor,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: _deco(label, icon),
        items: options
            .map((o) => DropdownMenuItem(
                value: o,
                child: Text(o[0].toUpperCase() + o.substring(1),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface))))
            .toList(),
        onChanged: onChanged,
      );

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintstyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillcolor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF00C896), width: 1.5)),
      );
}
