import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/recipe_importer_provider.dart';
import '../providers/cocina_providers.dart';

class RecipeImporterScreen extends ConsumerStatefulWidget {
  const RecipeImporterScreen({super.key});

  @override
  ConsumerState<RecipeImporterScreen> createState() =>
      _RecipeImporterScreenState();
}

class _RecipeImporterScreenState extends ConsumerState<RecipeImporterScreen> {
  final _urlController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      ref.read(recipeImportProvider.notifier).importFromVideoFile(video.path);
    }
  }

  void _importUrl() {
    final url = _urlController.text.trim();
    if (url.isNotEmpty) {
      ref.read(recipeImportProvider.notifier).importFromTikTokUrl(url);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      _urlController.text = clipboardData.text!;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enlace pegado desde el portapapeles'),
            backgroundColor: Color(0xFF00E676),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recipeImportProvider);
    final notifier = ref.read(recipeImportProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF031411), // Emerald Night Deep Background
      appBar: AppBar(
        title: const Text('Chef IA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Background soft glow
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F0FF).withValues(alpha: 0.1),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildContent(state, notifier),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(RecipeImportState state, RecipeImportNotifier notifier) {
    if (state == RecipeImportState.downloadingVideo ||
        state == RecipeImportState.extractingAI) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00E676)),
            const SizedBox(height: 24),
            Text(
              notifier.currentStatusMessage,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (state == RecipeImportState.success && notifier.importedRecipe != null) {
      final recipe = notifier.importedRecipe!;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle_outline,
                color: Color(0xFF00E676), size: 64),
            const SizedBox(height: 16),
            const Text(
              '¡Receta Importada!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name,
                        style: const TextStyle(
                            color: Color(0xFF00F0FF),
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(recipe.description,
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.timer,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text('\${recipe.durationMinutes} min',
                            style: const TextStyle(color: Colors.white)),
                        const SizedBox(width: 16),
                        const Icon(Icons.restaurant,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text('\${recipe.servings} porciones',
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 32),
                    const Text('Ingredientes detectados:',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...recipe.ingredients.map((ing) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                              '- \${ing.quantity} \${ing.unit} de \${ing.ingredientName}',
                              style: const TextStyle(color: Colors.white70)),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () async {
                // Save to Drift Repository
                try {
                  await ref.read(recipesProvider.notifier).saveRecipe(recipe);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('¡Receta guardada exitosamente!'),
                        backgroundColor: Color(0xFF00E676),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error al guardar: $e'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar en mi recetario',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: notifier.reset,
              child: const Text('Empezar de nuevo',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Inspiración al Alcance',
            style: TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pega un link de TikTok o sube un video para convertirlo mágicamente en una receta estructurada.',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 40),
          if (state == RecipeImportState.error) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Text('Error: ${notifier.errorMessage}',
                  style: const TextStyle(color: Colors.redAccent)),
            ),
            const SizedBox(height: 24),
          ],
          _GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://vm.tiktok.com/...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon:
                          const Icon(Icons.link, color: Color(0xFF00F0FF)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste, color: Color(0xFF00E676)),
                        tooltip: 'Pegar desde portapapeles',
                        onPressed: _pasteFromClipboard,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00F0FF),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _importUrl,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome),
                        SizedBox(width: 8),
                        Text('Analizar Enlace',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
              child: Text('— O —',
                  style: TextStyle(
                      color: Colors.white54, fontWeight: FontWeight.bold))),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF00E676), width: 1.5),
              foregroundColor: const Color(0xFF00E676),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.video_library),
            label: const Text('Subir video desde Galería',
                style: TextStyle(fontSize: 16)),
            onPressed: _pickVideo,
          ),
        ],
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }
}
