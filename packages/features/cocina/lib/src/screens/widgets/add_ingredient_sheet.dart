import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/domain.dart';
import 'package:data/data.dart';
import 'package:core/core.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class AddIngredientSheet extends ConsumerStatefulWidget {
  final Future<void> Function(List<InventoryIngredient>) onAdd;
  final InventoryIngredient? itemToEdit;
  const AddIngredientSheet({super.key, required this.onAdd, this.itemToEdit});

  @override
  ConsumerState<AddIngredientSheet> createState() => _AddIngredientSheetState();
}

class _AddIngredientSheetState extends ConsumerState<AddIngredientSheet> {
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

  static const List<String> _preparations = [
    '',
    'entero',
    'licuado',
    'molido',
    'picado',
    'fresco',
    'en pasta',
    'en polvo',
    'en granos',
    'en rodajas',
    'desmenuzado',
  ];

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
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Agregar ingrediente',
                    style: TextStyle(
                        color: Colors.white,
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
            _field(_nameCtrl, 'Nombre (ej: Sillao, Arroz, Pollo)',
                Icons.label_outline,
                errorText: _nameError, onChanged: _onNameChanged),
            if (_autoDetected) ...[
              const SizedBox(height: 4),
              const Text('✨ Categoría y unidad sugeridas automáticamente',
                  style: TextStyle(color: Color(0xFF00C896), fontSize: 11)),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 2,
                child: _field(_qtyCtrl, 'Cantidad', Icons.exposure,
                    keyboardType: TextInputType.number,
                    errorText: _qtyError,
                    onChanged: (_) => setState(() => _qtyError = null)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<MeasurementUnit>(
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
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
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
            DropdownButtonFormField<String>(
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
            DropdownButtonFormField<String>(
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.today_outlined, color: Colors.white38),
              title: Text(
                _expiry == null
                    ? 'Sin fecha de caducidad'
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
    setState(() {
      if (suggestion.primaryCategory != null) {
        _primaryCategory =
            _masterCategories.contains(suggestion.primaryCategory)
                ? suggestion.primaryCategory!
                : 'Otros';
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
      final gemini = ref.read(geminiProvider);
      final jsonResponse =
          await gemini.analyzePantryItems(photoPath: pickedFile.path);

      if (jsonResponse == null || jsonResponse.isEmpty) {
        throw Exception("No se recibió respuesta de Gemini");
      }

      var cleanJson = jsonResponse.trim();
      if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
      if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
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
            properUnit = MeasurementUnit.values.firstWhere(
                (u) =>
                    u.label.toLowerCase() == unitStr.toLowerCase() ||
                    u.name.toLowerCase() == unitStr.toLowerCase(),
                orElse: () => MeasurementUnit.unidades);
          } catch (_) {}

          final pDays = item['pantryLifeDays'] as int?;
          DateTime? exp;
          if (pDays != null && pDays > 0) {
            exp = DateTime.now().add(Duration(days: pDays));
          }

          newItems.add(InventoryIngredient(
            id: const Uuid().v4(),
            name: item['name']?.toString() ?? 'Producto',
            primaryCategory:
                _masterCategories.contains(catString) ? catString : 'Otros',
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
          builder: (_) => ReviewMultipleDialog(items: newItems),
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
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) return;

    setState(() => _saving = true);
    try {
      final gemini = ref.read(geminiProvider);
      final jsonResponse =
          await gemini.analyzeSinglePantryItem(photoPath: pickedFile.path);

      if (jsonResponse == null || jsonResponse.isEmpty) {
        throw Exception("No se recibió respuesta de Gemini");
      }

      var cleanJson = jsonResponse.trim();
      if (cleanJson.startsWith('```json')) cleanJson = cleanJson.substring(7);
      if (cleanJson.startsWith('```')) cleanJson = cleanJson.substring(3);
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final Map<String, dynamic> item = json.decode(cleanJson);
      final catString = item['primaryCategory']?.toString() ?? 'Otros';
      final subCatString = item['subCategory']?.toString();
      final unitStr = item['unit']?.toString() ?? 'unidades';
      final qty = (item['quantity'] as num?)?.toDouble() ?? 1.0;

      MeasurementUnit properUnit = MeasurementUnit.unidades;
      try {
        properUnit = MeasurementUnit.values.firstWhere(
            (u) =>
                u.label.toLowerCase() == unitStr.toLowerCase() ||
                u.name.toLowerCase() == unitStr.toLowerCase(),
            orElse: () => MeasurementUnit.unidades);
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
          _primaryCategory =
              _masterCategories.contains(catString) ? catString : 'Otros';
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
      await widget.onAdd([
        InventoryIngredient(
          id: widget.itemToEdit?.id ?? const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          primaryCategory: _primaryCategory,
          subCategory: _subCategoryCtrl.text.trim().isEmpty
              ? null
              : _subCategoryCtrl.text.trim(),
          preparation: _preparation,
          quantity: double.parse(_qtyCtrl.text),
          unit: _unit.label,
          expirationDate: _expiry,
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

class ReviewMultipleDialog extends StatefulWidget {
  final List<InventoryIngredient> items;
  const ReviewMultipleDialog({super.key, required this.items});

  @override
  State<ReviewMultipleDialog> createState() => _ReviewMultipleDialogState();
}

class _ReviewMultipleDialogState extends State<ReviewMultipleDialog> {
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
            const Text('🔍 Revisar Productos (IA)',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
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
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 0),
                      title: TextFormField(
                        initialValue: item.name,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15),
                        decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero),
                        onChanged: (val) {
                          items[i] = InventoryIngredient(
                              id: item.id,
                              name: val,
                              primaryCategory: item.primaryCategory,
                              subCategory: item.subCategory,
                              quantity: item.quantity,
                              unit: item.unit);
                        },
                      ),
                      subtitle: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue: item.quantity.toString(),
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                  fontSize: 13),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero),
                              onChanged: (val) {
                                items[i] = InventoryIngredient(
                                    id: item.id,
                                    name: item.name,
                                    primaryCategory: item.primaryCategory,
                                    subCategory: item.subCategory,
                                    quantity: double.tryParse(val) ?? 1.0,
                                    unit: item.unit);
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
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.white38),
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
