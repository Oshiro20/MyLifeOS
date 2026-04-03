import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/src/armario/entities/wardrobe_garment.dart';
import '../providers/armario_provider.dart';

class CanvasGarment {
  final WardrobeGarment garment;
  Offset position;
  double scale;
  double rotation;

  CanvasGarment({
    required this.garment,
    this.position = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
  });
}

class MannequinCanvasScreen extends ConsumerStatefulWidget {
  final Outfit? initialOutfit;
  final Map<String, dynamic>? suggestedOutfit;

  const MannequinCanvasScreen({
    super.key,
    this.initialOutfit,
    this.suggestedOutfit,
  });

  @override
  ConsumerState<MannequinCanvasScreen> createState() => _MannequinCanvasScreenState();
}

class _MannequinCanvasScreenState extends ConsumerState<MannequinCanvasScreen> {
  final List<CanvasGarment> _items = [];
  CanvasGarment? _activeItem;
  Offset _initialFocalPoint = Offset.zero;
  Offset _initialPosition = Offset.zero;
  double _initialScale = 1.0;
  double _initialRotation = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLayout();
    });
  }

  void _initializeLayout() {
    final size = MediaQuery.of(context).size;
    
    if (widget.suggestedOutfit != null) {
      final ootd = widget.suggestedOutfit!;
      final top = ootd['top'] as WardrobeGarment?;
      final bottom = ootd['bottom'] as WardrobeGarment?;
      final shoes = ootd['shoes'] as WardrobeGarment?;

      setState(() {
        if (top != null) {
          _items.add(CanvasGarment(
            garment: top,
            position: Offset(size.width / 2 - 60, size.height * 0.15),
          ));
        }
        if (bottom != null) {
          _items.add(CanvasGarment(
            garment: bottom,
            position: Offset(size.width / 2 - 60, size.height * 0.45),
          ));
        }
        if (shoes != null) {
          _items.add(CanvasGarment(
            garment: shoes,
            position: Offset(size.width / 2 - 60, size.height * 0.75),
          ));
        }
      });
    }
  }

  void _onScaleStart(ScaleStartDetails details, CanvasGarment item) {
    setState(() {
      // Traer al frente
      _items.remove(item);
      _items.add(item);
      _activeItem = item;
      _initialFocalPoint = details.focalPoint;
      _initialPosition = item.position;
      _initialScale = item.scale;
      _initialRotation = item.rotation;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details, CanvasGarment item) {
    if (_activeItem != item) return;
    setState(() {
      final delta = details.focalPoint - _initialFocalPoint;
      item.position = _initialPosition + delta;
      item.scale = (_initialScale * details.scale).clamp(0.2, 5.0);
      item.rotation = _initialRotation + details.rotation;
    });
  }

  void _onScaleEnd(ScaleEndDetails details, CanvasGarment item) {
    setState(() {
      _activeItem = null;
    });
  }

  void _removeGarment(CanvasGarment item) {
    setState(() {
      _items.remove(item);
    });
  }

  void _openGarmentPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            final garments = ref.read(armarioProvider).garments;
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Selecciona prendas', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: garments.length,
                    itemBuilder: (context, index) {
                      final garment = garments[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            // Centrar prenda al añadir
                            final size = MediaQuery.of(this.context).size;
                            _items.add(CanvasGarment(
                              garment: garment,
                              position: Offset(size.width / 2 - 50, size.height / 2 - 50),
                            ));
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          alignment: Alignment.center,
                          child: garment.imageAssetId != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(garment.imageAssetId!), fit: BoxFit.cover),
                                )
                              : const Icon(Icons.checkroom, color: Colors.white38, size: 40),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveOutfit() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Añade al menos una prenda al lienzo')));
      return;
    }

    final nameCtrl = TextEditingController();
    String occasion = 'casual';
    Season season = Season.all;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            title: const Text('Guardar Outfit 📸', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Outfit',
                      labelStyle: TextStyle(color: Colors.white54),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00C896))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    dropdownColor: Theme.of(context).cardColor,
                    value: occasion,
                    items: const [
                      DropdownMenuItem(value: 'casual', child: Text('Casual', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'sport', child: Text('Deporte', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'formal', child: Text('Formal', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'party', child: Text('Fiesta', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'work', child: Text('Trabajo', style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (v) => setModalState(() => occasion = v!),
                    decoration: const InputDecoration(labelText: 'Ocasión', labelStyle: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Season>(
                    dropdownColor: Theme.of(context).cardColor,
                    value: season,
                    items: Season.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))).toList(),
                    onChanged: (v) => setModalState(() => season = v!),
                    decoration: const InputDecoration(labelText: 'Temporada', labelStyle: TextStyle(color: Colors.white54)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00C896)),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;

                  final garmentIds = _items.map((e) => e.garment.id).toList();
                  final newOutfit = Outfit(
                    id: '', // drift creates one
                    name: nameCtrl.text.trim(),
                    garmentIds: garmentIds,
                    occasion: occasion,
                    season: season,
                    createdAt: DateTime.now(),
                  );

                  await ref.read(armarioProvider.notifier).saveOutfit(newOutfit);
                  if (mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Guardar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Outfit guardado con éxito! ✅'), backgroundColor: Color(0xFF4CAF50)));
      Navigator.pop(context); // Volver al armario
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Creador de Outfits 🎨', style: TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_rounded, color: Color(0xFF00C896)),
            onPressed: _saveOutfit,
            tooltip: 'Guardar Outfit',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background instructions
          if (_items.isEmpty)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app_outlined, size: 60, color: Colors.white12),
                  SizedBox(height: 16),
                  Text('Lienzo vacío', style: TextStyle(color: Colors.white38, fontSize: 18)),
                  SizedBox(height: 8),
                  Text('Toca el botón + para añadir prendas\ny armar tu atuendo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white24)),
                ],
              ),
            ),
          
          // Render garments
          ..._items.map((item) {
            return Positioned(
              left: item.position.dx,
              top: item.position.dy,
              child: GestureDetector(
                onScaleStart: (details) => _onScaleStart(details, item),
                onScaleUpdate: (details) => _onScaleUpdate(details, item),
                onScaleEnd: (details) => _onScaleEnd(details, item),
                onDoubleTap: () => _removeGarment(item), // Quick remove
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translate(0.0, 0.0)
                    ..rotateZ(item.rotation)
                    ..scale(item.scale),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.transparent, // No Background to show biometric transparent images perfectly!
                          border: _activeItem == item ? Border.all(color: const Color(0xFF00C896), width: 2, strokeAlign: BorderSide.strokeAlignOutside) : null,
                        ),
                        child: item.garment.imageAssetId != null
                            ? Image.file(
                                File(item.garment.imageAssetId!),
                                fit: BoxFit.contain, // Maintain original aspect ratio
                              )
                            : Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10),
                                  child: const Icon(Icons.checkroom, color: Colors.white54, size: 40),
                                ),
                              ),
                      ),
                      if (_activeItem == item)
                        Positioned(
                          right: -10,
                          top: -10,
                          child: GestureDetector(
                            onTap: () => _removeGarment(item),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00C896),
        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
        label: const Text('Añadir Prenda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: _openGarmentPicker,
      ),
    );
  }
}
