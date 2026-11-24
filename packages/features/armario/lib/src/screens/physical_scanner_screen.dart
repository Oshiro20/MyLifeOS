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
  bool _estimateBodyFatForFoodCoach = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-poblar campos desde Armario o el Perfil Corporal compartido
    final profile = ref.read(armarioProvider).userProfile;
    final bodyProfile = ref.read(bodyProfileProvider);
    _heightController.text = profile?.height ??
        (bodyProfile.heightCm != null ? bodyProfile.heightCm!.round().toString() : '');
    _weightController.text = profile?.weight ??
        (bodyProfile.weightKg != null
            ? bodyProfile.weightKg!.toStringAsFixed(1)
            : '');
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      final compressed = await ImageCompressionUtil.compressImage(
        originalFile: File(picked.path),
        subfolder: 'scanner',
      );
      if (!mounted) return;
      setState(() {
        _imageFile = compressed;
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
      final bodyFatPromptBlock = _estimateBodyFatForFoodCoach
          ? '''
- body_fat_min: estimación visual orientativa MÍNIMA de % grasa corporal (número entero entre 8 y 45, basado en estatura, peso y complexión visible con ropa; es solo referencia orientativa)
- body_fat_max: estimación visual orientativa MÁXIMA de % grasa corporal (número entero, típicamente 3 a 5 puntos arriba de body_fat_min)
- body_build_note: frase breve (máx 12 palabras) describiendo complexión general observada para guiar nutrición'''
          : '';
      final exampleJson = _estimateBodyFatForFoodCoach
          ? '{"skin_tone": "medio", "colorimetry": "otoño", "body_shape": "rectángulo", "hair_type": "lacio", "body_fat_min": 17, "body_fat_max": 21, "body_build_note": "Complexión media equilibrada"}'
          : '{"skin_tone": "medio", "colorimetry": "otoño", "body_shape": "rectángulo", "hair_type": "lacio"}';

      final prompt = '''
Analiza la fotografía adjunta de la persona junto con sus medidas para construir su perfil de asesoría de imagen${_estimateBodyFatForFoodCoach ? ' y referencia general de complexión física' : ''}.
Estatura: ${_heightController.text} cm
Peso: ${_weightController.text} kg

Devuelve ÚNICAMENTE un objeto JSON válido con estas claves exactas:
- skin_tone: tono de piel observado ("claro", "medio", "trigueño", "oscuro")
- colorimetry: estación de colorimetría recomendada ("primavera", "verano", "otoño", "invierno")
- body_shape: forma corporal estimada ("rectángulo", "triángulo", "reloj de arena", "triángulo invertido", "atlético")
- hair_type: tipo de cabello observado ("lacio", "ondulado", "rizado")
$bodyFatPromptBlock

Formato JSON:
$exampleJson
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

      // Actualizar perfil en Armario
      final currentProfile = ref.read(armarioProvider).userProfile;
      final newProfile = UserPhysicalProfile(
        id: currentProfile?.id ?? '',
        skinTone: data['skin_tone']?.toString(),
        colorimetry: data['colorimetry']?.toString(),
        bodyShape: data['body_shape']?.toString(),
        hairType: data['hair_type']?.toString(),
        height: _heightController.text.trim(),
        weight: _weightController.text.trim(),
        consentGranted: true,
        updatedAt: DateTime.now(),
      );

      await ref.read(armarioProvider.notifier).saveProfile(newProfile);

      // Sincronizar con Perfil Corporal compartido (FoodCoach y Cocina)
      final heightCm = double.tryParse(
          _heightController.text.trim().replaceAll(',', '.'));
      final weightKg = double.tryParse(
          _weightController.text.trim().replaceAll(',', '.'));
      double? bfMin;
      double? bfMax;
      String? buildNote;
      if (_estimateBodyFatForFoodCoach) {
        final rawMin = (data['body_fat_min'] as num?)?.toDouble() ??
            double.tryParse(data['body_fat_min']?.toString() ?? '');
        final rawMax = (data['body_fat_max'] as num?)?.toDouble() ??
            double.tryParse(data['body_fat_max']?.toString() ?? '');
        if (rawMin != null && rawMax != null && rawMin >= 5 && rawMax <= 55) {
          bfMin = rawMin <= rawMax ? rawMin : rawMax;
          bfMax = rawMax >= rawMin ? rawMax : rawMin;
        }
        buildNote = data['body_build_note']?.toString().trim();
        if (buildNote != null && buildNote.isEmpty) buildNote = null;
      }

      await ref.read(bodyProfileProvider.notifier).syncFromPhysicalScanner(
            heightCm: heightCm,
            weightKg: weightKg,
            visualBodyFatMin: bfMin,
            visualBodyFatMax: bfMax,
            visualBuildNote: buildNote,
          );

      if (!mounted) return;
      final syncedMsg = (bfMin != null && bfMax != null)
          ? '¡Perfil guardado! Rango visual aprox. ${bfMin.round()}-${bfMax.round()}% grasa sincronizado con FoodCoach.'
          : '¡Perfil físico analizado y sincronizado con FoodCoach!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(syncedMsg)),
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
            const SizedBox(height: 20),
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
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF00C896).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00C896).withValues(alpha: 0.3),
                ),
              ),
              child: SwitchListTile(
                value: _estimateBodyFatForFoodCoach,
                onChanged: (v) =>
                    setState(() => _estimateBodyFatForFoodCoach = v),
                activeThumbColor: const Color(0xFF00C896),
                title: const Text(
                  'Estimar rango orientativo de % grasa para FoodCoach',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Referencia visual aproximada (±5% con ropa). Puedes afinarla con medidas US Navy en FoodCoach.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
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
