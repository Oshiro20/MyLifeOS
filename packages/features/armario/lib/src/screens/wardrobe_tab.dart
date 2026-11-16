import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';
import '../providers/armario_provider.dart';

class WardrobeTab extends ConsumerWidget with AppFeedback {
  final String filterByType; // 'ropa' o 'calzado'
  const WardrobeTab({super.key, this.filterByType = 'ropa'});

  static const _typeEmoji = {
    GarmentType.shirt: '👕',
    GarmentType.tshirt: '👚',
    GarmentType.polo: '👕',
    GarmentType.pants: '👖',
    GarmentType.jeans: '🩱',
    GarmentType.shoes: '👟',
    GarmentType.sneakers: '👟',
    GarmentType.boots: '🥾',
    GarmentType.sandals: '🩴',
    GarmentType.jacket: '🧥',
    GarmentType.accessories: '💍',
    GarmentType.dress: '👗',
    GarmentType.shorts: '🩳',
    GarmentType.sweater: '🧣',
    GarmentType.hoodie: '🧥',
    GarmentType.skirt: '👗',
    GarmentType.other: '🎽',
  };

  static const _shoeTypes = {
    GarmentType.shoes,
    GarmentType.sneakers,
    GarmentType.boots,
    GarmentType.sandals,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(armarioProvider);
    final notifier = ref.read(armarioProvider.notifier);

    final isShoesTab = filterByType == 'calzado';

    // Filtrar prendas (ropa vs calzado)
    final filteredGarments = state.garments.where((g) {
      final isShoe = _shoeTypes.contains(g.type);
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.18)),
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
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.1)),
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
  final VoidCallback? onRecordWear;

  const _GarmentCard({
    required this.garment,
    required this.emoji,
    required this.onToggleClean,
    required this.onToggleFav,
    required this.onDelete,
    this.onRecordWear,
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
              if (garment.imageAssetId != null &&
                  File(garment.imageAssetId!).existsSync())
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.file(
                      File(garment.imageAssetId!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Center(child: Text(emoji, style: const TextStyle(fontSize: 40))),
              if (garment.imageDetailsPath != null &&
                  File(garment.imageDetailsPath!).existsSync())
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
            if (garment.timesWorn > 0 ||
                (garment.price != null && garment.price! > 0)) ...[
              const SizedBox(height: 2),
              Text(
                _wearAndCostLabel(garment),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF00C896),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(children: [
              _SmallBtn(
                icon: garment.isClean
                    ? Icons.local_laundry_service
                    : Icons.local_laundry_service_outlined,
                color: garment.isClean
                    ? Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.35)
                    : const Color(0xFFFFB74D),
                tooltip: garment.isClean ? 'Marcar sucia' : 'Marcar limpia',
                onTap: onToggleClean,
              ),
              if (onRecordWear != null) ...[
                const SizedBox(width: 4),
                _SmallBtn(
                  icon: Icons.exposure_plus_1,
                  color: const Color(0xFF00C896),
                  tooltip: 'Registrar +1 uso',
                  onTap: onRecordWear!,
                ),
              ],
              _SmallBtn(
                icon:
                    garment.isFavorite ? Icons.favorite : Icons.favorite_border,
                color: garment.isFavorite
                    ? const Color(0xFFFF4D4D)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.35),
                tooltip: 'Favorito',
                onTap: onToggleFav,
              ),
              _SmallBtn(
                  icon: Icons.delete_outline,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35),
                  tooltip: 'Eliminar',
                  onTap: onDelete),
            ]),
          ]),
        ),
      ]),
    );
  }

  static String _wearAndCostLabel(WardrobeGarment g) {
    final usesLabel = '${g.timesWorn} ${g.timesWorn == 1 ? 'uso' : 'usos'}';
    final price = g.price;
    if (price == null || price <= 0) return usesLabel;
    final cpw = g.timesWorn > 0 ? price / g.timesWorn : price;
    return '$usesLabel · S/ ${cpw.toStringAsFixed(1)}/uso';
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
  bool _removingBg = false;
  bool _sendPurchaseToWallet = false;

  @override
  void initState() {
    super.initState();
    _type = widget.isShoesTab ? GarmentType.shoes : GarmentType.tshirt;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _colorCtrl.dispose();
    _matCtrl.dispose();
    _brandCtrl.dispose();
    _sizeCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
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
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(2)))),
            Text('Nueva prenda',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
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
            if (_photo != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _removingBg ? null : _removePhotoBackground,
                  icon: _removingBg
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF00C896),
                          ),
                        )
                      : const Icon(Icons.auto_fix_high,
                          size: 16, color: Color(0xFF00C896)),
                  label: Text(
                    _removingBg ? 'Quitando fondo...' : 'Quitar fondo (IA)',
                    style: const TextStyle(
                        color: Color(0xFF00C896), fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF00C896)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                  ),
                ),
              ),
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
                title: Text('¿Tiene capucha desmontable?',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13)),
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
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: const Color(0xFF00C896),
              activeTrackColor:
                  const Color(0xFF00C896).withValues(alpha: 0.35),
              title: const Text('Registrar gasto en WalletAI',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Si ingresas precio, se enviará como gasto pendiente',
                style: TextStyle(fontSize: 11),
              ),
              value: _sendPurchaseToWallet,
              onChanged: (v) => setState(() => _sendPurchaseToWallet = v),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('Rating:',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 13)),
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
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

  Future<void> _takePhoto({bool isDetails = false}) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF00C896)),
              title: Text('Cámara', style: TextStyle(color: onSurface)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF00C896)),
              title: Text('Galería', style: TextStyle(color: onSurface)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ]),
        );
      },
    );
    if (source == null) return;

    final xfile = await picker.pickImage(source: source, maxWidth: 800);
    if (xfile == null || !mounted) return;

    // Compress and persist the image inside Documents/media/garments
    final compressedFile = await ImageCompressionUtil.compressImage(
      originalFile: File(xfile.path),
      subfolder: 'garments',
      deleteOriginal: true,
    );
    if (!mounted) return;

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
Analiza esta prenda de vestir o calzado y devuelve ÚNICAMENTE un JSON válido con:
- name: nombre corto y descriptivo de la prenda en español
- typeIndex: entero 0-16 según GarmentType (0=shirt, 1=tshirt, 2=pants, 3=jeans, 4=shoes, 5=jacket, 6=accessories, 7=dress, 8=shorts, 9=sweater, 10=hoodie, 11=skirt, 12=other, 13=polo, 14=sneakers, 15=boots, 16=sandals)
- primaryColor: color principal en formato hex #RRGGBB
- material: material principal (ej: Algodón, Poliéster, Cuero)
- brand: marca si es visible o ""
- size: talla si es visible o ""
- season: estación ("all", "summer", "winter", "spring", "autumn")
- styleIndex: entero 0-6 según GarmentStyle (0=casual, 1=formal, 2=sport, 3=streetwear, 4=elegant, 5=smartCasual, 6=workwear)

JSON: {"name":"...","typeIndex":1,"primaryColor":"#FFFFFF","material":"Algodón","brand":"","size":"","season":"all","styleIndex":0}
''';
      final jsonStr = await ai.generateJsonText(
        prompt: prompt,
        mediaPaths: _photo != null ? [_photo!.path] : const [],
      );
      if (jsonStr != null && mounted) {
        final decoded = AiJsonParser.decodeMap(jsonStr);
        if (decoded == null) return;

        int parseInt(dynamic val, int def) {
          if (val is num) return val.toInt();
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
      if ((_type == GarmentType.tshirt ||
              _type == GarmentType.shirt ||
              _type == GarmentType.polo) &&
          _style == GarmentStyle.sport) {
        wantShort = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (ctx) {
                  final onSurface = Theme.of(ctx).colorScheme.onSurface;
                  return AlertDialog(
                      backgroundColor: Theme.of(ctx).cardColor,
                      title: Text('🏃 Conjunto Deportivo',
                          style: TextStyle(color: onSurface)),
                      content: Text(
                          'Has guardado un top deportivo. ¿Deseas escanear el short ahora para armar tu conjunto automáticamente?',
                          style: TextStyle(
                              color: onSurface.withValues(alpha: 0.72))),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text('No por ahora',
                                style: TextStyle(
                                    color: onSurface.withValues(alpha: 0.5)))),
                        ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C896)),
                            child: const Text('Sí, escanear',
                                style: TextStyle(color: Colors.white))),
                      ]);
                }) ??
            false;
      }

      final savedTop = await widget.onAdd(garment);

      if (_sendPurchaseToWallet &&
          garment.price != null &&
          garment.price! > 0) {
        final walletRes = await WalletCloudService.sendPendingTransaction(
          amount: garment.price!,
          description: 'Prenda: ${garment.name}',
          categoryHint: 'Ropa y Calzado',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(walletRes.success
                  ? 'Gasto enviado a WalletAI'
                  : 'Prenda guardada (${walletRes.message})'),
              backgroundColor: walletRes.success
                  ? const Color(0xFF00C896)
                  : const Color(0xFFFFB74D),
            ),
          );
        }
      }

      if (wantShort) {
        final picker = ImagePicker();
        final xfile = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1200,
          maxHeight: 1200,
          imageQuality: 85,
        );
        if (xfile != null) {
          final persistedShort = await ImageCompressionUtil.compressImage(
            originalFile: File(xfile.path),
            subfolder: 'garments',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analizando short con IA...')));
          }
          final ai = ref.read(geminiProvider);
          final promptShort = '''
Analiza esta prenda (short deportivo) y devuelve ÚNICAMENTE un JSON válido con:
- name: "Short de ${garment.name}"
- typeIndex: 8
- primaryColor: color principal en hex #RRGGBB
- material: material principal
- brand: marca si es visible o ""
- size: talla si es visible o ""
- season: "all"
- styleIndex: 2

JSON: {"name":"Short de ${garment.name}","typeIndex":8,"primaryColor":"#000000","material":"Poliéster","brand":"","size":"","season":"all","styleIndex":2}
''';
          final jsonStr = await ai.generateJsonText(
            prompt: promptShort,
            mediaPaths: [persistedShort.path],
          );

          final decoded =
              jsonStr != null ? AiJsonParser.decodeMap(jsonStr) : null;
          final shortGarment = WardrobeGarment(
            id: '',
            name: 'Short de ${garment.name}',
            type: GarmentType.shorts,
            primaryColor: decoded?['primaryColor']?.toString() ?? '#000000',
            style: GarmentStyle.sport,
            material: decoded?['material']?.toString() ?? garment.material,
            season: garment.season,
            imageAssetId: persistedShort.path,
            addedAt: DateTime.now(),
          );
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

  Future<void> _removePhotoBackground() async {
    final current = _photo;
    if (current == null || _removingBg) return;
    setState(() => _removingBg = true);
    try {
      final processed = await ref
          .read(backgroundRemoverServiceProvider)
          .removeBackground(current.path);
      if (processed == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo quitar el fondo en este dispositivo'),
              backgroundColor: Color(0xFFFFB74D),
            ),
          );
        }
        return;
      }
      final persisted = await ImageCompressionUtil.compressImage(
        originalFile: File(processed),
        subfolder: 'garments',
        deleteOriginal: true,
        preserveTransparency: true,
      );
      if (mounted) {
        setState(() => _photo = persisted);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fondo removido correctamente'),
            backgroundColor: Color(0xFF00C896),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al quitar fondo: $e'),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _removingBg = false);
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
        iconTheme:
            IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        title: Text(
            '${WardrobeTab._typeEmoji[type] ?? '🎽'} ${type.label} (${items.length})',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      ),
      body: items.isEmpty
          ? Center(
              child: Text('No quedan prendas.',
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.45))))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.74,
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
                onRecordWear: () async {
                  await notifier.incrementGarmentWear(items[i].id);
                  if (context.mounted) {
                    showInfo(
                        context, '+1 uso registrado para "${items[i].name}"');
                  }
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
