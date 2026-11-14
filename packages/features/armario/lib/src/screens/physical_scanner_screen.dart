import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:core/core.dart';
import 'package:domain/domain.dart';
import '../providers/armario_provider.dart';

class PhysicalScannerScreen extends ConsumerStatefulWidget {
  const PhysicalScannerScreen({super.key});

  @override
  ConsumerState<PhysicalScannerScreen> createState() =>
      _PhysicalScannerScreenState();
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

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
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
      setState(() => _error =
          'Por favor, tómate una foto o selecciona una de la galería.');
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
      final aiService = ref.read(geminiProvider);
      final prompt = '''
Analiza la fotografía adjunta de la persona junto con sus medidas para construir su perfil de asesoría de imagen.
Estatura: ${_heightController.text} cm
Peso: ${_weightController.text} kg

Devuelve ÚNICAMENTE un objeto JSON válido con estas claves exactas:
- skin_tone: tono de piel observado ("claro", "medio", "trigueño", "oscuro")
- colorimetry: estación de colorimetría recomendada ("primavera", "verano", "otoño", "invierno")
- body_shape: forma corporal estimada ("rectángulo", "triángulo", "reloj de arena", "triángulo invertido", "atlético")
- hair_type: tipo de cabello observado ("lacio", "ondulado", "rizado")

Formato JSON:
{"skin_tone": "medio", "colorimetry": "otoño", "body_shape": "rectángulo", "hair_type": "lacio"}
''';
      final jsonResponse = await aiService.generateJsonText(
        prompt: prompt,
        mediaPaths: [_imageFile!.path],
      );

      if (jsonResponse == null) {
        throw Exception('No se recibió respuesta de la IA.');
      }

      final match = RegExp(r'\{[\s\S]*\}').firstMatch(jsonResponse);
      final cleanJson = match?.group(0) ?? jsonResponse.trim();

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
        const SnackBar(
            content: Text('¡Perfil físico analizado y guardado con éxito!')),
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
            Text(
              'Tómate una foto de cuerpo completo con ropa ajustada y luz natural para que Gemini pueda determinar tu tipo de cuerpo y colorimetría (Estación).',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.72),
                  fontSize: 14),
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
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.24),
                        width: 2),
                    image: _imageFile != null
                        ? DecorationImage(
                            image: FileImage(_imageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.55)),
                            const SizedBox(height: 8),
                            Text('Tocar para añadir foto',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.55))),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isAnalyzing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Analizar Perfil con Gemini ✨',
                      style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) {
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt, color: onSurface),
                title: Text('Tomar Foto', style: TextStyle(color: onSurface)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library, color: onSurface),
                title: Text('Elegir de Galería',
                    style: TextStyle(color: onSurface)),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
