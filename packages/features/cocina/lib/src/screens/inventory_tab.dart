import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:domain/domain.dart';
import 'package:data/data.dart';
import 'package:uuid/uuid.dart';
import 'package:core/core.dart';
import '../providers/cocina_providers.dart';

class InventoryTab extends ConsumerWidget with AppFeedback {
  const InventoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00C896)));
    }

    final List<Widget> listChildren = [];
    
    final Set<String> categories = state.ingredients.map((i) => i.primaryCategory).toSet();
    final sortedCategories = categories.toList()..sort();

    // Group by primary category
    for (final cat in sortedCategories) {
      final itemsInCat = state.ingredients.where((i) => i.primaryCategory == cat).toList();
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
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
            ),
            const Spacer(),
            Text('${itemsInCat.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontWeight: FontWeight.bold)),
          ],
        ),
      ));
      
      listChildren.addAll(itemsInCat.map((i) => _IngredientTile(
          ingredient: i,
          onEdit: () => _showEditDialog(context, ref, i),
          onDelete: () => _confirmDelete(context, ref, i.id, i.name))));
    }

    return Stack(
      children: [
        state.ingredients.isEmpty
            ? Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.kitchen_outlined, size: 64, color: Colors.white12),
                  const SizedBox(height: 12),
                  const Text('Tu despensa está vacía',
                      style: TextStyle(color: Colors.white38, fontSize: 17)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => _showAddDialog(context, ref),
                    icon: const Icon(Icons.add, color: Color(0xFF00C896)),
                    label: const Text('Agregar ingrediente',
                        style: TextStyle(color: Color(0xFF00C896))),
                  ),
                ]),
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: listChildren,
              ),
        Positioned(
          right: 16, bottom: 16,
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
    final confirmed = await showConfirmDelete(context, itemName: name,
        subtitle: 'Se eliminará de tu despensa.');
    if (!confirmed) return;
    await ref.read(inventoryProvider.notifier).delete(id);
    if (context.mounted) showSuccess(context, '"$name" eliminado de la despensa.');
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
              showSuccess(ctx, '${ings.length} productos añadidos a la despensa ✨');
            }
          }
        },
      ),
    );
  }

  void _showEditDialog(BuildContext ctx, WidgetRef ref, InventoryIngredient itemToEdit) {
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
          await ref.read(inventoryProvider.notifier).delete(itemToEdit.id);
          await ref.read(inventoryProvider.notifier).add(ings.first);
          if (ctx.mounted) {
            showSuccess(ctx, '"${ings.first.name}" actualizado ✓');
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
  const _IngredientTile({required this.ingredient, required this.onDelete, required this.onEdit});

  static String _getCategoryIcon(String primaryCategory) {
    final lower = primaryCategory.toLowerCase();
    if (lower.contains('proteína') || lower.contains('carne')) return '🥩';
    if (lower.contains('lácteo')) return '🥛';
    if (lower.contains('fruta')) return '🍎';
    if (lower.contains('verdura')) return '🥦';
    if (lower.contains('tubérculo') || lower.contains('raíz') || lower.contains('raices')) return '🥔';
    if (lower.contains('legumbre')) return '🫘';
    if (lower.contains('cereal') || lower.contains('grano')) return '🌾';
    if (lower.contains('harina') || lower.contains('pasta')) return '🥖';
    if (lower.contains('aceite') || lower.contains('grasa')) return '🫒';
    if (lower.contains('salsa')) return '🥫';
    if (lower.contains('condimento') || lower.contains('especia')) return '🌶️';
    if (lower.contains('endulzante')) return '🍯';
    if (lower.contains('frutos secos') || lower.contains('semilla')) return '🥜';
    return '📦';
  }

  Color get _expiryColor {
    if (ingredient.isExpired) return const Color(0xFFFF4D4D);
    if (ingredient.isExpiringSoon) return const Color(0xFFFFB74D);
    return Colors.white54;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: ingredient.isExpiringSoon
            ? Border.all(color: _expiryColor.withAlpha(100), width: 1)
            : null,
      ),
      child: ListTile(
        onTap: onEdit,
        leading: Text(_getEmojiFor(ingredient.name, ingredient.primaryCategory),
            style: const TextStyle(fontSize: 28)),
        title: Text(ingredient.name,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${ingredient.subCategory != null ? "${ingredient.subCategory} • " : ""}${ingredient.quantity} ${ingredient.unit}'
          '${ingredient.expirationDate != null ? " · cad. ${_fmt(ingredient.expirationDate!)}" : ""}',
          style: TextStyle(color: _expiryColor, fontSize: 12),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
          onPressed: onDelete,
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
    if (lowerName.contains('papa') || lowerName.contains('patata') || lowerName.contains('olluco') || lowerName.contains('olluquito')) return '🥔';
    if (lowerName.contains('palta') || lowerName.contains('aguacate')) return '🥑';
    if (lowerName.contains('platano') || lowerName.contains('plátano') || lowerName.contains('banana')) return '🍌';
    if (lowerName.contains('manzana')) return '🍎';
    if (lowerName.contains('naranja')) return '🍊';
    if (lowerName.contains('fresa') || lowerName.contains('frutilla')) return '🍓';
    if (lowerName.contains('uva') || lowerName.contains('pasa') || lowerName.contains('pasas')) return '🍇';
    if (lowerName.contains('sandia') || lowerName.contains('sandía')) return '🍉';
    if (lowerName.contains('champiñon') || lowerName.contains('hongo')) return '🍄';
    if (lowerName.contains('lechuga') || lowerName.contains('espinaca')) return '🥬';
    if (lowerName.contains('maiz') || lowerName.contains('choclo') || lowerName.contains('maíz')) return '🌽';
    if (lowerName.contains('pepino')) return '🥒';
    if (lowerName.contains('berenjena')) return '🍆';
    if (lowerName.contains('pimiento') || lowerName.contains('morrón')) return '🫑';
    if (lowerName.contains('brócoli') || lowerName.contains('brocoli')) return '🥦';
    if (lowerName.contains('kiwi')) return '🥝';
    if (lowerName.contains('coco')) return '🥥';
    if (lowerName.contains('piña')) return '🍍';
    if (lowerName.contains('durazno') || lowerName.contains('melocoton')) return '🍑';
    if (lowerName.contains('cereza')) return '🍒';
    
    // Proteínas
    if (lowerName.contains('pollo')) return '🍗';
    if (lowerName.contains('carne') || lowerName.contains('bisteck') || lowerName.contains('res') || lowerName.contains('chancho') || lowerName.contains('cerdo')) return '🥩';
    if (lowerName.contains('pescado') || lowerName.contains('atún') || lowerName.contains('atun')) return '🐟';
    if (lowerName.contains('camaron') || lowerName.contains('camarón') || lowerName.contains('langostino')) return '🦐';
    if (lowerName.contains('huevo')) return '🥚';
    if (lowerName.contains('tocino') || lowerName.contains('panceta')) return '🥓';
    if (lowerName.contains('salchicha') || lowerName.contains('hot dog') || lowerName.contains('chorizo')) return '🌭';
    if (lowerName.contains('marisco') || lowerName.contains('cangrejo') || lowerName.contains('pulpo') || lowerName.contains('calamar')) return '🦑';
    
    // Lácteos
    if (lowerName.contains('leche')) return '🥛';
    if (lowerName.contains('queso')) return '🧀';
    if (lowerName.contains('mantequilla') || lowerName.contains('margarina')) return '🧈';
    if (lowerName.contains('yogurt')) return '🥣';
    
    // Granos, Masas y Cereales
    if (lowerName.contains('arroz')) return '🍚';
    if (lowerName.contains('pan')) return '🍞';
    if (lowerName.contains('fideo') || lowerName.contains('pasta') || lowerName.contains('espagueti') || lowerName.contains('tallarin')) return '🍝';
    if (lowerName.contains('pizza')) return '🍕';
    if (lowerName.contains('harina')) return '🌾';
    if (lowerName.contains('avena')) return '🥣';
    if (lowerName.contains('lenteja') || lowerName.contains('frijol') || lowerName.contains('pallar') || lowerName.contains('garbanzo')) return '🫘';
    
    // Condimentos, Aceites, Salsas y Repostería
    if (lowerName.contains('aceite')) return '🫒';
    if (lowerName.contains('sal')) return '🧂';
    if (lowerName.contains('azucar') || lowerName.contains('azúcar') || lowerName.contains('endulzante') || lowerName.contains('stevia')) return '🧊';
    if (lowerName.contains('pimienta') || lowerName.contains('comino')) return '🧂'; 
    if (lowerName.contains('ají') || lowerName.contains('aji') || lowerName.contains('chile') || lowerName.contains('rocoto')) return '🌶️';
    if (lowerName.contains('laurel') || lowerName.contains('oregano') || lowerName.contains('orégano') || lowerName.contains('perejil') || lowerName.contains('cilantro') || lowerName.contains('albahaca') || lowerName.contains('romero')) return '🌿';
    if (lowerName.contains('miel') || lowerName.contains('mermelada') || lowerName.contains('jalea') || lowerName.contains('compota')) return '🍯';
    if (lowerName.contains('sillao') || lowerName.contains('salsa de soya') || lowerName.contains('vinagre')) return '🧉';
    if (lowerName.contains('vainilla')) return '🌸'; // Esencia de vainilla
    if (lowerName.contains('canela')) return '🟤';
    if (lowerName.contains('ketchup') || lowerName.contains('mayonesa') || lowerName.contains('mostaza')) return '🥫';
    if (lowerName.contains('chocolate') || lowerName.contains('cacao')) return '🍫';
    if (lowerName.contains('galleta')) return '🍪';
    if (lowerName.contains('mani') || lowerName.contains('maní') || lowerName.contains('almendra') || lowerName.contains('nuez')) return '🥜';
    
    // Bebidas
    if (lowerName.contains('agua')) return '💧';
    if (lowerName.contains('vino')) return '🍷';
    if (lowerName.contains('cerveza')) return '🍺';
    if (lowerName.contains('cafe') || lowerName.contains('café')) return '☕';
    if (lowerName.contains('te') || lowerName.contains('té') || lowerName.contains('infusión') || lowerName.contains('manzanilla')) return '🍵';
    if (lowerName.contains('jugo') || lowerName.contains('zumo')) return '🧃';
    if (lowerName.contains('gaseosa') || lowerName.contains('soda') || lowerName.contains('coca cola')) return '🥤';
    
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
  ConsumerState<_AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends ConsumerState<_AddIngredientSheet> {
  static const List<String> _masterCategories = [
    'Proteínas animales', 'Lácteos', 'Frutas', 'Verduras',
    'Tubérculos y raíces', 'Legumbres', 'Cereales y granos',
    'Harinas y derivados', 'Aceites y grasas', 'Salsas',
    'Condimentos y especias', 'Endulzantes', 'Frutos secos y semillas',
    'Otros'
  ];

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _subCategoryCtrl = TextEditingController();
  MeasurementUnit _unit = MeasurementUnit.unidades;
  String _primaryCategory = 'Otros';
  DateTime? _expiry;
  String? _qtyError;
  String? _nameError;
  bool _saving = false;
  bool _autoDetected = false;

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
      _qtyCtrl.text = i.quantity.toString();
      _primaryCategory = _masterCategories.contains(i.primaryCategory) ? i.primaryCategory : 'Otros';
      _subCategoryCtrl.text = i.subCategory ?? '';
      _expiry = i.expirationDate;
      _storageArea = i.storageArea ?? 'Alacena';
      try { _unit = MeasurementUnit.values.firstWhere((u) => u.label == i.unit); } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Agregar ingrediente',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _saving ? null : _aiScanSingle,
                      icon: const Icon(Icons.camera_alt, color: Color(0xFF00C896)),
                      tooltip: 'Escanear un solo producto',
                    ),
                    ElevatedButton.icon(
                      onPressed: _saving ? null : _aiScan,
                      icon: const Icon(Icons.document_scanner, size: 16, color: Colors.white),
                      label: const Text('IA Múltiple', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C896),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nombre con auto-detección
            _field(_nameCtrl, 'Nombre (ej: Sillao, Arroz, Pollo)', Icons.label_outline,
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
                    keyboardType: TextInputType.number, errorText: _qtyError,
                    onChanged: (_) => setState(() => _qtyError = null)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<MeasurementUnit>(
                  initialValue: _unit,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  decoration: _inputDeco('Unidad', Icons.scale_outlined),
                  items: MeasurementUnit.values.map((u) => DropdownMenuItem(
                      value: u, child: Text(u.label,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))).toList(),
                  onChanged: (v) => setState(() => _unit = v!),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // Categoría
            Row(children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  initialValue: _primaryCategory,
                  dropdownColor: Theme.of(context).cardColor,
                  isExpanded: true,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                  decoration: _inputDeco('Categoría', Icons.category_outlined),
                  items: _masterCategories.map((c) => DropdownMenuItem(
                      value: c, child: Text(c,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))).toList(),
                  onChanged: (v) => setState(() => _primaryCategory = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _field(_subCategoryCtrl, 'Sub (opcional)', Icons.subdirectory_arrow_right,
                    keyboardType: TextInputType.text),
              ),
            ]),
            const SizedBox(height: 10),

            // Lugar de Guardado
            DropdownButtonFormField<String>(
              initialValue: _storageArea,
              dropdownColor: Theme.of(context).cardColor,
              isExpanded: true,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
              decoration: _inputDeco('Lugar de guardado', Icons.kitchen_outlined),
              items: _storageAreas.map((c) => DropdownMenuItem(
                  value: c, child: Text(c,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))).toList(),
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
                  border: Border.all(color: const Color(0xFF00C896).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.tips_and_updates, color: Color(0xFF00C896), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_aiStorageTip!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12, height: 1.3)),
                    ),
                  ],
                ),
              ),
            ],

            // Fecha de caducidad
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.today_outlined, color: Colors.white38),
              title: Text(
                _expiry == null ? 'Sin fecha de caducidad'
                    : 'Caduca: ${_expiry!.day}/${_expiry!.month}/${_expiry!.year}',
                style: TextStyle(
                    color: _expiry == null ? Colors.white38 : Colors.white70,
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
                child: const Text('Elegir', style: TextStyle(color: Color(0xFF00C896))),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Agregar',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
    setState(() {
      if (suggestion.primaryCategory != null) {
        _primaryCategory = _masterCategories.contains(suggestion.primaryCategory) ? suggestion.primaryCategory! : 'Otros';
        _subCategoryCtrl.text = suggestion.subCategory ?? '';
      }
      if (suggestion.suggestedUnit != null) _unit = suggestion.suggestedUnit!;
      _autoDetected = suggestion.primaryCategory != null;
    });
  }

  Future<void> _aiScan() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _saving = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      final jsonResponse = await gemini.analyzePantryItems(photoPath: pickedFile.path);
      
      if (jsonResponse == null || jsonResponse.isEmpty) {
        throw Exception("No se recibió respuesta de Gemini");
      }

      // Limpiar markdown
      var cleanJson = jsonResponse.trim();
      if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
      if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
      if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      cleanJson = cleanJson.trim();

      final List<dynamic> data = json.decode(cleanJson);
      final newItems = <InventoryIngredient>[];

      for (var item in data) {
        if (item is Map<String, dynamic>) {
          final catString = item['primaryCategory']?.toString() ?? 'Otros';
          final subCatString = item['subCategory']?.toString();
          final unitStr = item['unit']?.toString() ?? 'unidades';
          final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;

          MeasurementUnit properUnit = MeasurementUnit.unidades;
          try {
            properUnit = MeasurementUnit.values.firstWhere((u) => u.label.toLowerCase() == unitStr.toLowerCase() || u.name.toLowerCase() == unitStr.toLowerCase(), orElse: () => MeasurementUnit.unidades);
          } catch (_) {}

          final pDays = item['pantryLifeDays'] as int?;
          DateTime? exp;
          if (pDays != null && pDays > 0) exp = DateTime.now().add(Duration(days: pDays));

          newItems.add(InventoryIngredient(
            id: const Uuid().v4(),
            name: item['name']?.toString() ?? 'Producto',
            primaryCategory: _masterCategories.contains(catString) ? catString : 'Otros',
            subCategory: subCatString,
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
           builder: (_) => _ReviewMultipleDialog(items: newItems),
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
          SnackBar(content: Text('Error IA: $e'), backgroundColor: const Color(0xFFFF5252)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _aiScanSingle() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _saving = true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      final jsonResponse = await gemini.analyzeSinglePantryItem(photoPath: pickedFile.path);
      
      if (jsonResponse == null || jsonResponse.isEmpty) {
        throw Exception("No se recibió respuesta de Gemini");
      }

      var cleanJson = jsonResponse.trim();
      if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
      if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
      if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      cleanJson = cleanJson.trim();

      final Map<String, dynamic> item = json.decode(cleanJson);
      final catString = item['primaryCategory']?.toString() ?? 'Otros';
      final subCatString = item['subCategory']?.toString();
      final unitStr = item['unit']?.toString() ?? 'unidades';
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;

      MeasurementUnit properUnit = MeasurementUnit.unidades;
      try {
        properUnit = MeasurementUnit.values.firstWhere((u) => u.label.toLowerCase() == unitStr.toLowerCase() || u.name.toLowerCase() == unitStr.toLowerCase(), orElse: () => MeasurementUnit.unidades);
      } catch (_) {}

      final pDays = item['pantryLifeDays'] as int?;
      final rDays = item['fridgeLifeDays'] as int?;
      final cDays = item['freezerLifeDays'] as int?;
      final sTip = item['storageTip']?.toString();

      if (mounted) {
        setState(() {
          _nameCtrl.text = item['name']?.toString() ?? 'Producto';
          _qtyCtrl.text = qty.toString();
          _unit = properUnit;
          _primaryCategory = _masterCategories.contains(catString) ? catString : 'Otros';
          _subCategoryCtrl.text = subCatString ?? '';
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
          content: Text('Revisa los datos antes de agregar.', style: TextStyle(color: Colors.white)),
          backgroundColor: Color(0xFF00C896), duration: Duration(seconds: 2),
        ));
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error IA Simple: $e'), backgroundColor: const Color(0xFFFF5252)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final nameVal = Validator.ingredientName(_nameCtrl.text);
    final qtyVal = Validator.ingredientQuantity(double.tryParse(_qtyCtrl.text));

    if (!nameVal.isValid || !qtyVal.isValid) {
      setState(() {
        _nameError = nameVal.errorMessage;
        _qtyError = qtyVal.errorMessage;
      });
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onAdd([InventoryIngredient(
        id: widget.itemToEdit?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        primaryCategory: _primaryCategory,
        subCategory: _subCategoryCtrl.text.trim().isEmpty ? null : _subCategoryCtrl.text.trim(),
        quantity: double.parse(_qtyCtrl.text),
        unit: _unit.label,
        expirationDate: _expiry,
        storageArea: _storageArea,
      )]);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: const Color(0xFFFF5252)),
        );
      }
    }
  }

  Widget _field(TextEditingController ctrl, String hint, IconData icon, {
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
        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
  const _ReviewMultipleDialog({required this.items});
  @override
  State<_ReviewMultipleDialog> createState() => _ReviewMultipleDialogState();
}

class _ReviewMultipleDialogState extends State<_ReviewMultipleDialog> {
  late List<InventoryIngredient> items;

  @override
  void initState() {
    super.initState();
    items = List.from(widget.items);
  }

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
            const Text('🔍 Revisar Productos (IA)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                itemBuilder: (ctx, i) {
                  final item = items[i];
                  return Card(
                    color: Theme.of(context).appBarTheme.backgroundColor,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      title: TextFormField(
                        initialValue: item.name,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                        onChanged: (val) {
                          items[i] = InventoryIngredient(id: item.id, name: val, primaryCategory: item.primaryCategory, subCategory: item.subCategory, quantity: item.quantity, unit: item.unit);
                        },
                      ),
                      subtitle: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: item.quantity.toString(),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                              onChanged: (val) {
                                items[i] = InventoryIngredient(id: item.id, name: item.name, primaryCategory: item.primaryCategory, subCategory: item.subCategory, quantity: double.tryParse(val) ?? 1.0, unit: item.unit);
                              },
                            ),
                          ),
                          Text(item.unit, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 13)),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white38),
                        onPressed: () => setState(() => items.removeAt(i)),
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
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C896)),
                onPressed: () => Navigator.pop(context, items),
                child: const Text('Confirmar y Guardar', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
