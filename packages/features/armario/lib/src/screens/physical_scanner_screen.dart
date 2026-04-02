import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:core/core.dart';
import 'package:domain/domain.dart';
import 'package:domain/src/armario/entities/wardrobe_garment.dart';
import '../providers/armario_provider.dart';

class PhysicalScannerScreen extends ConsumerStatefulWidget {
  const PhysicalScannerScreen({super.key});

  @override
  ConsumerState<PhysicalScannerScreen> createState() => _PhysicalScannerScreenState();
}

class _PhysicalScannerScreenState extends ConsumerState<PhysicalScannerScreen> {
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  File? _imageFile;
  bool _isAnalyzing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-poblar campos si ya existen
    final profile = ref.read(armarioProvider).userProfile;
    if (profile != null) {
      _heightController.text = profile.height ?? '';
      _weightController.text = profile.weight ?? '';
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
        _error = null;
      });
    }
  }

  Future<void> _analyze() async {
    if (_imageFile == null) {
      setState(() => _error = 'Por favor, tómate una foto o selecciona una de la galería.');
      return;
    }
    if (_heightController.text.isEmpty || _weightController.text.isEmpty) {
      setState(() => _error = 'Por favor, ingresa tu estatura y peso.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _error = null;
    });

    try {
      final aiService = ref.read(geminiServiceProvider);
      final jsonResponse = await aiService.analyzePhysicalProfile(
        _imageFile!.path,
        _heightController.text,
        _weightController.text,
      );

      if (jsonResponse == null) throw Exception('No se recibió respuesta de la IA.');

      // Limpiar markdown si Gemini lo incluye
      var cleanJson = jsonResponse.trim();
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
        if (cleanJson.endsWith('```')) cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();

      final data = json.decode(cleanJson) as Map<String, dynamic>;

      // Actualizar perfil
      final currentProfile = ref.read(armarioProvider).userProfile;
      final newProfile = UserPhysicalProfile(
        id: currentProfile?.id ?? '',
        skinTone: data['skin_tone']?.toString(),
        colorimetry: data['colorimetry']?.toString(),
        bodyShape: data['body_shape']?.toString(),
        hairType: data['hair_type']?.toString(),
        height: _heightController.text,
        weight: _weightController.text,
        consentGranted: true,
        updatedAt: DateTime.now(),
      );

      await ref.read(armarioProvider.notifier).saveProfile(newProfile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Perfil físico analizado y guardado con éxito!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = 'Error durante el análisis: $e';
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escáner Físico con I.A.'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Tómate una foto de cuerpo completo con ropa ajustada y luz natural para que Gemini pueda determinar tu tipo de cuerpo y colorimetría (Estación).',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Estatura (cm)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Peso (kg)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _showPickerOptions(context),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 2),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageFile == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 48, color: Colors.white54),
                            SizedBox(height: 8),
                            Text('Tocar para añadir foto', style: TextStyle(color: Colors.white54)),
                          ],
                        )
                      : null,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isAnalyzing ? null : _analyze,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isAnalyzing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Analizar Perfil con Gemini ✨', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Tomar Foto', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Elegir de Galería', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
