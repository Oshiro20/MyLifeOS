import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart'; // Para acceso a geminiServiceProvider si es necesario
import 'package:domain/src/armario/entities/wardrobe_garment.dart';
import '../providers/armario_provider.dart';
import 'physical_scanner_screen.dart';
import 'mannequin_canvas_screen.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  // Para el mock de clima
  final String _mockWeather = "Soleado, 24°C";

  @override
  void initState() {
    super.initState();
    // Generamos sugerencia automáticamente si no hay una y ya cargaron las prendas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndGenerateOotd();
    });
  }

  void _checkAndGenerateOotd() {
    final state = ref.read(armarioProvider);
    if (!state.isLoading && 
        !state.isLoadingOotd && 
        state.ootd == null && 
        state.garments.where((g) => g.isClean).isNotEmpty) {
      ref.read(armarioProvider.notifier).generateOutfitOfTheDay(
        ref.read(geminiServiceProvider), 
        _mockWeather,
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(armarioProvider);
    final themeColor = const Color(0xFF00C896);

    return RefreshIndicator(
      color: themeColor,
      onRefresh: () async {
        await ref.read(armarioProvider.notifier).load();
        ref.read(armarioProvider.notifier).generateOutfitOfTheDay(
          ref.read(geminiServiceProvider), 
          _mockWeather,
        );
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Greeting Card
          Text(
            '${_getGreeting()}, Joel',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tienes ${state.garments.length} prendas registradas (${state.garments.where((g) => g.isClean).length} limpias).',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Weather Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF152019), Color(0xFF1A2E22)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: themeColor.withAlpha(40)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny_outlined, color: Color(0xFFFFB74D), size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Clima hoy (Mock)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(_mockWeather, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Physical Profile AI Banner
          _buildPhysicalProfileBanner(context, state.userProfile, themeColor),
          
          const SizedBox(height: 32),

          // OOTD AI Card
          Row(
            children: [
              Icon(Icons.auto_awesome, color: themeColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Outfit del Día (AI Stylist)',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (state.isLoadingOotd)
            _buildLoadingOotd()
          else if (state.ootd != null)
            _buildOotdCard(state.ootd!, themeColor)
          else if (state.error != null && state.error!.contains('Gemini'))
            _buildErrorOotd(state.error!, themeColor)
          else
            _buildEmptyOotd(themeColor),
        ],
      ),
    );
  }

  Widget _buildLoadingOotd() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00C896)),
            SizedBox(height: 16),
            Text('Analizando tu armario...', style: TextStyle(color: Colors.white54)),
            Text('Gemini está creando tu outfit ideal', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOotd(String error, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            onPressed: () => ref.read(armarioProvider.notifier).generateOutfitOfTheDay(
              ref.read(geminiServiceProvider), _mockWeather
            ),
            child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOotd(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Icon(Icons.checkroom_outlined, color: Colors.white38, size: 40),
          const SizedBox(height: 12),
          const Text('No hay sugerencia disponible', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            onPressed: () => ref.read(armarioProvider.notifier).generateOutfitOfTheDay(
              ref.read(geminiServiceProvider), _mockWeather
            ),
            child: const Text('Generar Outfit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildOotdCard(Map<String, dynamic> ootd, Color themeColor) {
    final top = ootd['top'] as WardrobeGarment?;
    final bottom = ootd['bottom'] as WardrobeGarment?;
    final shoes = ootd['shoes'] as WardrobeGarment?;
    final explanation = ootd['explanation'] as String?;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [themeColor.withAlpha(30), const Color(0xFF0F1A14)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: themeColor.withAlpha(60)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (explanation != null) ...[
            Text(
              '"\$explanation"',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              if (top != null) Expanded(child: _garmentMiniCard(top)),
              const SizedBox(width: 8),
              if (bottom != null) Expanded(child: _garmentMiniCard(bottom)),
              const SizedBox(width: 8),
              if (shoes != null) Expanded(child: _garmentMiniCard(shoes)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MannequinCanvasScreen(suggestedOutfit: ootd)),
                );
              },
              icon: const Icon(Icons.style_rounded, color: Colors.white, size: 20),
              label: const Text('Ver en Maniquí', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalProfileBanner(BuildContext context, UserPhysicalProfile? profile, Color themeColor) {
    final hasData = profile != null && profile.colorimetry != null && profile.bodyShape != null;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PhysicalScannerScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasData ? themeColor.withAlpha(20) : const Color(0xFF152019),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasData ? themeColor.withAlpha(80) : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasData ? themeColor.withAlpha(40) : Colors.white10,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasData ? Icons.accessibility_new_rounded : Icons.camera_front_outlined,
                color: hasData ? themeColor : Colors.white54,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasData ? 'Perfil Físico IA Activo' : 'Escáner Físico con I.A.',
                    style: TextStyle(
                      color: hasData ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasData) ...[
                    Text(
                      '${profile.colorimetry} • ${profile.bodyShape}',
                      style: TextStyle(color: themeColor.withAlpha(200), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    hasData 
                        ? 'Gemini usa esta info para tus outfits.'
                        : 'Descubre qué ropa te favorece.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: hasData ? themeColor : Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _garmentMiniCard(WardrobeGarment g) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Text(_emojiFor(g.type), style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: _parseColor(g.primaryColor),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            g.name,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _emojiFor(GarmentType type) {
    switch (type) {
      case GarmentType.shirt: return '👕';
      case GarmentType.tshirt: return '👚';
      case GarmentType.pants: return '👖';
      case GarmentType.shoes:
      case GarmentType.sneakers: return '👟';
      case GarmentType.boots: return '🥾';
      case GarmentType.sandals: return '🩴';
      case GarmentType.jacket: return '🧥';
      case GarmentType.shorts: return '🩳';
      case GarmentType.dress: return '👗';
      default: return '🎽';
    }
  }

  Color _parseColor(String h) {
    try {
      return Color(int.parse('FF${h.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}
