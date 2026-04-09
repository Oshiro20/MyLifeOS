import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:domain/domain.dart';
import 'dart:convert';
import 'package:core/core.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../providers/armario_provider.dart';

class WardrobeTab extends ConsumerWidget with AppFeedback {
  final String filterByType; // 'ropa' o 'calzado'
  const WardrobeTab({super.key, this.filterByType = 'ropa'});

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
    GarmentType.sweater: '🧣',
    GarmentType.hoodie: '🧥',
    GarmentType.skirt: '👗',
    GarmentType.other: '🎽',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(armarioProvider);
    final notifier = ref.read(armarioProvider.notifier);

    final isShoesTab = filterByType == 'calzado';

    // Filtrar prendas (ropa vs calzado)
    final filteredGarments = state.garments.where((g) {
      final isShoe = g.type == GarmentType.shoes;
      return isShoesTab ? isShoe : !isShoe;
    }).toList();

    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF00C896)));
    }

    final total = filteredGarments.length;
    final dirty = filteredGarments.where((g) => !g.isClean).length;

    // Agrupar por categoría
    final groupedGarments = <GarmentType, List<WardrobeGarment>>{};
    for (var g in filteredGarments) {
      if (!groupedGarments.containsKey(g.type)) {
        groupedGarments[g.type] = [];
      }
      groupedGarments[g.type]!.add(g);
    }

    // Sort keys just to have a consistent order
    final sortedTypes = groupedGarments.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            await ref.read(armarioProvider.notifier).load();
          },
          color: const Color(0xFF00C896),
          child: Column(
            children: [
              if (total > 0)
                Container(
                  color: Theme.of(context).appBarTheme.backgroundColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    _StatBadge(
                        icon: isShoesTab ? Icons.snowshoeing : Icons.checkroom,
                        label: '$total ${isShoesTab ? 'pares' : 'prendas'}',
                        color: const Color(0xFF00C896)),
                    const SizedBox(width: 12),
                    if (dirty > 0)
                      _StatBadge(
                          icon: Icons.local_laundry_service_outlined,
                          label: '$dirty para lavar',
                          color: const Color(0xFFFFB74D)),
                  ]),
                ),
              Expanded(
                child: filteredGarments.isEmpty
                    ? Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              isShoesTab
                                  ? Icons.snowshoeing
                                  : Icons.checkroom_outlined,
                              size: 64,
                              color: Colors.white12),
                          const SizedBox(height: 12),
                          Text('No hay ${isShoesTab ? 'calzado' : 'ropa'} aquí',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.38),
                                  fontSize: 17)),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () =>
                                _showAddSheet(context, notifier, isShoesTab),
                            icon:
                                const Icon(Icons.add, color: Color(0xFF00C896)),
                            label: const Text('Agregar',
                                style: TextStyle(color: Color(0xFF00C896))),
                          ),
                        ]),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                        ),
                        itemCount: sortedTypes.length,
                        itemBuilder: (ctx, sectionIndex) {
                          final type = sortedTypes[sectionIndex];
                          final items = groupedGarments[type]!;

                          return InkWell(
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        WardrobeCategoryScreen(type: type))),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_typeEmoji[type] ?? '🎽',
                                      style: const TextStyle(fontSize: 40)),
                                  const SizedBox(height: 12),
                                  Text(type.label,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('${items.length} prendas',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.38),
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_garment',
            backgroundColor: const Color(0xFF00C896),
            onPressed: () => _showAddSheet(context, notifier, isShoesTab),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _showAddSheet(
      BuildContext ctx, ArmarioNotifier notifier, bool isShoesTab) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(ctx).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddGarmentSheet(
        isShoesTab: isShoesTab,
        onAdd: (g) async {
          final saved = await notifier.addGarment(g);
          if (ctx.mounted) showSuccess(ctx, '"${g.name}" añadida al armario ✓');
          return saved;
        },
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatBadge(
      {required this.icon, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]);
}

class _GarmentCard extends StatelessWidget {
  final WardrobeGarment garment;
  final String emoji;
  final VoidCallback onToggleClean, onToggleFav, onDelete;

  const _GarmentCard({
    required this.garment,
    required this.emoji,
    required this.onToggleClean,
    required this.onToggleFav,
    required this.onDelete,
  });

  Color get _color {
    try {
      return Color(int.parse('FF${garment.primaryColor.replaceAll('#', '')}',
          radix: 16));
    } catch (_) {
      return const Color(0xFF00C896);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border(bottom: BorderSide(color: _color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: _color.withAlpha(30),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          ),
          child: Stack(
            children: [
              Center(child: Text(emoji, style: const TextStyle(fontSize: 40))),
              if (garment.imageDetailsPath != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                      image: DecorationImage(
                        image: FileImage(File(garment.imageDetailsPath!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(garment.name,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('${garment.type.label} · ${garment.style.label}',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.38),
                    fontSize: 11)),
            const SizedBox(height: 8),
            Row(children: [
              _SmallBtn(
                icon: garment.isClean
                    ? Icons.local_laundry_service
                    : Icons.local_laundry_service_outlined,
                color:
                    garment.isClean ? Colors.white24 : const Color(0xFFFFB74D),
                tooltip: garment.isClean ? 'Marcar sucia' : 'Marcar limpia',
                onTap: onToggleClean,
              ),
              _SmallBtn(
                icon:
                    garment.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: garment.isFavorite
                    ? const Color(0xFFFF4D4D)
                    : Colors.white24,
                tooltip: 'Favorito',
                onTap: onToggleFav,
              ),
              _SmallBtn(
                  icon: Icons.delete_outline,
                  color: Colors.white24,
                  tooltip: 'Eliminar',
                  onTap: onDelete),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _SmallBtn(
      {required this.icon,
      required this.color,
      required this.tooltip,
      required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(icon, size: 16, color: color)),
        ),
      );
}

// ── Formulario con auto-detección ──────────────────────────────────────────

class _AddGarmentSheet extends ConsumerStatefulWidget {
  final Future<WardrobeGarment> Function(WardrobeGarment) onAdd;
  final bool isShoesTab;
  const _AddGarmentSheet({required this.onAdd, this.isShoesTab = false});
  @override
  ConsumerState<_AddGarmentSheet> createState() => _AddGarmentSheetState();
}

class _AddGarmentSheetState extends ConsumerState<_AddGarmentSheet> {
  final _nameCtrl = TextEditingController();
  final _colorCtrl = TextEditingController(text: '#FFFFFF');
  final _matCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  int _rating = 0;
  GarmentType _type = GarmentType.tshirt;
  GarmentStyle _style = GarmentStyle.casual;
  Season _season = Season.all;
  String? _nameError;
  String? _colorError;
  bool _saving = false;
  File? _photo;
  File? _photoDetails;
  bool _autoDetected = false;
  bool _hasRemovableHood = false;

  @override
  void initState() {
    super.initState();
    _type = widget.isShoesTab ? GarmentType.shoes : GarmentType.tshirt;
  }

  Color _parseColor(String h) {
    try {
      return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)))),
            const Text('Nueva prenda',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),

            // Botón foto
            Row(
              children: [
                Expanded(
                  child: _buildPhotoBox(
                    file: _photo,
                    label: 'Foto principal',
                    onTap: () => _takePhoto(isDetails: false),
                    onClear: () => setState(() => _photo = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPhotoBox(
                    file: _photoDetails,
                    label: 'Detalle\n(Talla/Tela)',
                    onTap: () => _takePhoto(isDetails: true),
                    onClear: () => setState(() => _photoDetails = null),
                  ),
                ),
              ],
            ),
            if (_autoDetected) ...[
              const SizedBox(height: 6),
              const Text('✨ Auto-detección aplicada',
                  style: TextStyle(color: Color(0xFF00C896), fontSize: 11)),
            ],
            const SizedBox(height: 12),

            _field(_nameCtrl, 'Nombre (ej: Polo negro)', Icons.label_outline,
                errorText: _nameError, onChanged: _onNameChanged),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _field(_colorCtrl, 'Color hex (ej: #3A86FF)',
                      Icons.color_lens_outlined,
                      errorText: _colorError,
                      onChanged: (_) => setState(() => _colorError = null)),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _parseColor(_colorCtrl.text),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _field(_matCtrl, 'Material (ej: Algodón)', Icons.texture),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final shoeTypes = [
                GarmentType.shoes,
                GarmentType.sneakers,
                GarmentType.boots,
                GarmentType.sandals
              ];
              final items = widget.isShoesTab
                  ? shoeTypes
                  : GarmentType.values
                      .where((t) => !shoeTypes.contains(t))
                      .toList();

              return _dropdown<GarmentType>(
                  'Tipo',
                  Icons.checkroom_outlined,
                  _type,
                  items,
                  (v) => v.label,
                  (v) => setState(() => _type = v!));
            }),
            const SizedBox(height: 8),
            _dropdown<GarmentStyle>(
                'Estilo',
                Icons.style_outlined,
                _style,
                GarmentStyle.values,
                (v) => v.label,
                (v) => setState(() => _style = v!)),
            const SizedBox(height: 8),
            _dropdown<Season>(
                'Temporada',
                Icons.wb_sunny_outlined,
                _season,
                Season.values,
                (v) => v.label,
                (v) => setState(() => _season = v!)),
            const SizedBox(height: 8),
            if ([GarmentType.jacket, GarmentType.hoodie, GarmentType.sweater]
                .contains(_type)) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: const Color(0xFF00C896),
                title: const Text('¿Tiene capucha desmontable?',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
                value: _hasRemovableHood,
                onChanged: (val) => setState(() => _hasRemovableHood = val),
              ),
            ],
            const SizedBox(height: 8),
            _field(_brandCtrl, 'Marca (opcional)',
                Icons.branding_watermark_outlined),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _field(
                      _sizeCtrl, 'Talla (opc)', Icons.straighten_outlined)),
              const SizedBox(width: 8),
              Expanded(
                  child: _field(
                      _priceCtrl, 'Precio (opc)', Icons.attach_money_outlined)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Rating:',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              const SizedBox(width: 8),
              ...List.generate(
                  5,
                  (index) => IconButton(
                        onPressed: () => setState(() => _rating = index + 1),
                        icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                            color: const Color(0xFFFFB74D),
                            size: 28),
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        constraints: const BoxConstraints(),
                      )),
            ]),
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
                    : const Text('Guardar prenda',
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
  }

  Widget _buildPhotoBox(
      {required File? file,
      required String label,
      required VoidCallback onTap,
      required VoidCallback onClear}) {
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 0.85,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161626),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF00C896).withAlpha(80), width: 1.5),
              ),
              child: file != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(file,
                          fit: BoxFit.cover, width: double.infinity))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          const Icon(Icons.camera_alt_outlined,
                              color: Color(0xFF00C896), size: 24),
                          const SizedBox(height: 4),
                          Text(label,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.38),
                                  fontSize: 10),
                              textAlign: TextAlign.center),
                        ]),
            ),
          ),
        ),
        if (file != null)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }

  Future<File> _compressImage(File originalFile) async {
    try {
      final dir = Directory('${originalFile.parent.path}/compressed');
      if (!await dir.exists()) {
        await dir.create();
      }

      final compressedPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        originalFile.path,
        compressedPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result != null) {
        final compressedFile = File(result.path);
        // Delete original file to save space
        if (await originalFile.exists()) {
          await originalFile.delete();
        }
        return compressedFile;
      }

      // If compression fails, return original file
      return originalFile;
    } catch (e) {
      // If compression fails, return original file
      return originalFile;
    }
  }

  Future<void> _takePhoto({bool isDetails = false}) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Color(0xFF00C896)),
            title: const Text('Cámara', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(0xFF00C896)),
            title: const Text('Galería', style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;

    final xfile = await picker.pickImage(source: source, maxWidth: 800);
    if (xfile == null) return;

    // Compress the image
    final compressedFile = await _compressImage(File(xfile.path));

    final file = compressedFile;
    setState(() {
      if (isDetails) {
        _photoDetails = file;
      } else {
        _photo = file;
        _saving = true; // Usamos _saving como flag de carga
      }
    });

    if (isDetails) {
      return; // No AI on the secondary picture (just save the path locally)
    }

    // Inferencia con Gemini AI
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Gemini analizando prenda...'),
            duration: Duration(seconds: 1)));
      }
      final ai = ref.read(geminiProvider);
      final prompt = '''
Analiza esta prenda de vestir y devuelve un JSON con:
- name: nombre de la prenda
- typeIndex: índice del tipo (0-14: tshirt, shirt, pants, shorts, skirt, dress, jacket, sweater, shoes, accessory, sock, underwear, swimwear, sleepwear, sport)
- primaryColor: color principal en hex
- material: material principal
- brand: marca si es visible
- size: talla si es visible
- season: estación (all, summer, winter, spring, autumn)
- styleIndex: estilo (0-4: casual, formal, sport, streetwear, vintage)

JSON: {"name":"...","typeIndex":0,"primaryColor":"#...","material":"...","brand":"...","size":"...","season":"all","styleIndex":0}
''';
      final jsonStr = await ai.extractRecipe(
        textContext: prompt,
        mediaPath: _photo!.path,
      );
      if (jsonStr != null && mounted) {
        final cleanJson =
            jsonStr.replaceAll(RegExp(r'```json\n|```'), '').trim();
        final decoded = json.decode(cleanJson) as Map<String, dynamic>;

        int parseInt(dynamic val, int def) {
          if (val == null) return def;
          if (val is int) return val;
          if (val is String) return int.tryParse(val) ?? def;
          return def;
        }

        setState(() {
          if (_nameCtrl.text.trim().isEmpty && decoded['name'] != null) {
            _nameCtrl.text = decoded['name'].toString();
          }
          _type = GarmentType.values[parseInt(decoded['typeIndex'], 1)
              .clamp(0, GarmentType.values.length - 1)];
          _colorCtrl.text = decoded['primaryColor']?.toString() ?? '#FFFFFF';
          _matCtrl.text = decoded['material']?.toString() ?? '';
          _brandCtrl.text = decoded['brand']?.toString() ?? '';
          _sizeCtrl.text = decoded['size']?.toString() ?? '';

          final sc = decoded['season']?.toString() ?? 'all';
          _season = Season.values
              .firstWhere((e) => e.name == sc, orElse: () => Season.all);

          _style = GarmentStyle.values[parseInt(decoded['styleIndex'], 0)
              .clamp(0, GarmentStyle.values.length - 1)];
          _autoDetected = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error AI Garment: $e'),
            backgroundColor: const Color(0xFFFF5252)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final nameVal = Validator.garmentName(_nameCtrl.text);
    final colorVal = Validator.hexColor(_colorCtrl.text);
    final combined = Validator.combine([nameVal, colorVal]);

    if (!combined.isValid) {
      setState(() {
        _nameError = nameVal.errorMessage;
        _colorError = colorVal.errorMessage;
      });
      return;
    }

    setState(() => _saving = true);
    try {
      final priceStr = _priceCtrl.text.trim();
      final garment = WardrobeGarment(
        id: '',
        name: _nameCtrl.text.trim(),
        type: _type,
        primaryColor: _colorCtrl.text.trim(),
        style: _style,
        material: _matCtrl.text.trim(),
        season: _season,
        hasRemovableHood: _hasRemovableHood,
        rating: _rating,
        size: _sizeCtrl.text.trim().isEmpty ? null : _sizeCtrl.text.trim(),
        brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
        price: priceStr.isEmpty ? null : double.tryParse(priceStr),
        imageAssetId: _photo?.path,
        imageDetailsPath: _photoDetails?.path,
        addedAt: DateTime.now(),
      );

      bool wantShort = false;
      if ((_type == GarmentType.tshirt || _type == GarmentType.shirt) &&
          _style == GarmentStyle.sport) {
        wantShort = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                        backgroundColor: Theme.of(context).cardColor,
                        title: const Text('🏃 Conjunto Deportivo',
                            style: TextStyle(color: Colors.white)),
                        content: const Text(
                            'Has guardado un top deportivo. ¿Deseas escanear el short ahora para armar tu conjunto automáticamente?',
                            style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('No por ahora',
                                  style: TextStyle(color: Colors.white38))),
                          ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C896)),
                              child: const Text('Sí, escanear',
                                  style: TextStyle(color: Colors.white))),
                        ])) ??
            false;
      }

      final savedTop = await widget.onAdd(garment);

      if (wantShort) {
        final picker = ImagePicker();
        final xfile =
            await picker.pickImage(source: ImageSource.camera, maxWidth: 800);
        if (xfile != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analizando short con IA...')));
          }
          final ai = ref.read(geminiProvider);
          final promptShort = '''
Analiza esta prenda (short deportivo) y devuelve un JSON con:
- name: "Short de ${garment.name}"
- typeIndex: 3 (shorts)
- primaryColor: color principal en hex
- material: material principal
- brand: marca si es visible
- size: talla si es visible
- season: all
- styleIndex: 2 (sport)

JSON: {"name":"Short de ${garment.name}","typeIndex":3,"primaryColor":"#...","material":"...","brand":"...","size":"...","season":"all","styleIndex":2}
''';
          final jsonStr = await ai.extractRecipe(
            textContext: promptShort,
            mediaPath: xfile.path,
          );

          WardrobeGarment shortGarment;
          if (jsonStr != null) {
            final cleanJson =
                jsonStr.replaceAll(RegExp(r'```json\n|```'), '').trim();
            final decoded = json.decode(cleanJson) as Map<String, dynamic>;
            shortGarment = WardrobeGarment(
                id: '',
                name: 'Short de ${garment.name}',
                type: GarmentType.shorts,
                primaryColor: decoded['primaryColor'] as String? ?? '#000000',
                style: GarmentStyle.sport,
                material: decoded['material'] as String? ?? garment.material,
                season: garment.season,
                addedAt: DateTime.now());
          } else {
            shortGarment = WardrobeGarment(
                id: '',
                name: 'Short de ${garment.name}',
                type: GarmentType.shorts,
                primaryColor: '#000000',
                style: GarmentStyle.sport,
                addedAt: DateTime.now());
          }
          final savedShort =
              await ref.read(armarioProvider.notifier).addGarment(shortGarment);

          final outfit = Outfit(
            id: '',
            name: 'Conjunto ${garment.name}',
            garmentIds: [savedTop.id, savedShort.id],
            occasion: 'sport',
            season: garment.season,
            createdAt: DateTime.now(),
          );
          await ref.read(armarioProvider.notifier).saveOutfit(outfit);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('¡Conjunto deportivo creado! ✨'),
                backgroundColor: Color(0xFF4CAF50)));
          }
        }
      }
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
    TextEditingController c,
    String hint,
    IconData icon, {
    String? errorText,
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: c,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        onChanged: onChanged,
        decoration: _deco(hint, icon).copyWith(
          errorText: errorText,
          errorStyle: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
        ),
      );

  Widget _dropdown<T>(String label, IconData icon, T value, List<T> items,
      String Function(T) display, void Function(T?) onChanged) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      dropdownColor: Theme.of(context).cardColor,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      decoration: _deco(label, icon),
      items: items
          .map((v) => DropdownMenuItem(
              value: v,
              child: Text(display(v),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface))))
          .toList(),
      onChanged: onChanged,
    );
  }

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.38)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
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

// ── Screen for category details ──────────────────────────────────────────────

class WardrobeCategoryScreen extends ConsumerWidget with AppFeedback {
  final GarmentType type;

  const WardrobeCategoryScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchar el state global para reflejar limpiezas/borrados en vivo
    final state = ref.watch(armarioProvider);
    final notifier = ref.read(armarioProvider.notifier);
    final items = state.garments.where((g) => g.type == type).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
            '${WardrobeTab._typeEmoji[type] ?? '🎽'} ${type.label} (${items.length})',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: items.isEmpty
          ? const Center(
              child: Text('No quedan prendas.',
                  style: TextStyle(color: Colors.white38)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: items.length,
              itemBuilder: (ctx, i) => _GarmentCard(
                garment: items[i],
                emoji: WardrobeTab._typeEmoji[items[i].type] ?? '🎽',
                onToggleClean: () {
                  notifier.toggleClean(items[i].id);
                  showInfo(
                      context,
                      items[i].isClean
                          ? '"${items[i].name}" marcada como sucia'
                          : '"${items[i].name}" marcada como limpia');
                },
                onToggleFav: () {
                  notifier.toggleFavorite(items[i].id);
                  showInfo(
                      context,
                      items[i].isFavorite
                          ? '"${items[i].name}" quitado de favoritos'
                          : '"${items[i].name}" añadido a favoritos ❤️');
                },
                onDelete: () => _confirmDeleteCategory(context, ref, items[i]),
              ),
            ),
    );
  }

  Future<void> _confirmDeleteCategory(
      BuildContext context, WidgetRef ref, WardrobeGarment g) async {
    final confirmed = await showConfirmDelete(context,
        itemName: g.name, subtitle: '${g.type.label} · ${g.style.label}');
    if (!confirmed) return;
    await ref.read(armarioProvider.notifier).deleteGarment(g.id);
    if (context.mounted) {
      showSuccess(context, '"${g.name}" eliminada del armario.');
    }
  }
}
