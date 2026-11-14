import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:domain/domain.dart';
import '../providers/armario_provider.dart';
import 'physical_scanner_screen.dart';
import 'mannequin_canvas_screen.dart';

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> {
  String _currentWeather = WeatherService.seasonalFallback();
  String _selectedCity = 'Lima';

  @override
  void initState() {
    super.initState();
    _loadRealWeather();
  }

  Future<void> _loadRealWeather({bool forceRefresh = false}) async {
    final city = await WeatherService.getSelectedCity();
    final weather =
        await WeatherService.fetchCurrentWeather(forceRefresh: forceRefresh);
    if (!mounted) return;
    setState(() {
      _selectedCity = city;
      _currentWeather = weather;
    });
    _checkAndGenerateOotd();
  }

  Future<void> _pickCity() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'Seleccionar ciudad para clima',
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            for (final city in WeatherService.presets.keys)
              ListTile(
                title: Text(city),
                trailing: city == _selectedCity
                    ? const Icon(Icons.check, color: Color(0xFF00C896))
                    : null,
                onTap: () => Navigator.pop(ctx, city),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && chosen != _selectedCity) {
      await WeatherService.setSelectedCity(chosen);
      await _loadRealWeather(forceRefresh: true);
    }
  }

  void _checkAndGenerateOotd() {
    final state = ref.read(armarioProvider);
    if (!state.isLoading &&
        !state.isLoadingOotd &&
        state.ootd == null &&
        state.garments.where((g) => g.isClean).isNotEmpty) {
      ref.read(armarioProvider.notifier).generateOutfitOfTheDay(
            ref.read(geminiProvider),
            _currentWeather,
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
    final userName = ref.watch(userDisplayNameProvider);
    const themeColor = Color(0xFF00C896);

    return RefreshIndicator(
      color: themeColor,
      onRefresh: () async {
        await ref.read(armarioProvider.notifier).load();
        await _loadRealWeather(forceRefresh: true);
      },
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Greeting Card
          Text(
            '${_getGreeting()}, $userName',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tienes ${state.garments.length} prendas registradas (${state.garments.where((g) => g.isClean).length} limpias).',
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.54),
                fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Weather Card (Open-Meteo real + selector de ciudad)
          GestureDetector(
            onTap: () => _loadRealWeather(forceRefresh: true),
            onLongPress: _pickCity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? const [Color(0xFF152019), Color(0xFF1A2E22)]
                      : [
                          themeColor.withValues(alpha: 0.14),
                          themeColor.withValues(alpha: 0.05),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: themeColor.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined,
                      color: Color(0xFFFFB74D), size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clima en $_selectedCity (toca para actualizar)',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(_currentWeather,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cambiar ciudad',
                    onPressed: _pickCity,
                    icon: Icon(Icons.location_on_outlined,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.55),
                        size: 20),
                  ),
                ],
              ),
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
              Text(
                'Outfit del Día (AI Stylist)',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (state.isLoadingOotd)
            _buildLoadingOotd()
          else if (state.ootd != null)
            _buildOotdCard(state.ootd!, themeColor)
          else if (state.error != null)
            _buildErrorOotd(state.error!, themeColor)
          else
            _buildEmptyOotd(themeColor),
        ],
      ),
    );
  }

  Widget _buildLoadingOotd() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00C896)),
            const SizedBox(height: 16),
            Text('Analizando tu armario...',
                style: TextStyle(color: onSurface.withValues(alpha: 0.6))),
            Text('Gemini está creando tu outfit ideal',
                style: TextStyle(
                    color: onSurface.withValues(alpha: 0.45), fontSize: 12)),
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
          Text(error,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7))),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            onPressed: () => ref
                .read(armarioProvider.notifier)
                .generateOutfitOfTheDay(
                    ref.read(geminiProvider), _currentWeather),
            child:
                const Text('Reintentar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyOotd(Color themeColor) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.checkroom_outlined,
              color: onSurface.withValues(alpha: 0.45), size: 40),
          const SizedBox(height: 12),
          Text('No hay sugerencia disponible',
              style: TextStyle(color: onSurface.withValues(alpha: 0.72))),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: themeColor),
            onPressed: () => ref
                .read(armarioProvider.notifier)
                .generateOutfitOfTheDay(
                    ref.read(geminiProvider), _currentWeather),
            child: const Text('Generar Outfit',
                style: TextStyle(color: Colors.white)),
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
              '"$explanation"',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontStyle: FontStyle.italic),
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
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) =>
                          MannequinCanvasScreen(suggestedOutfit: ootd)),
                );
              },
              icon: const Icon(Icons.style_rounded,
                  color: Colors.white, size: 20),
              label: const Text('Ver en Maniquí',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalProfileBanner(
      BuildContext context, UserPhysicalProfile? profile, Color themeColor) {
    final hasData = profile != null &&
        profile.colorimetry != null &&
        profile.bodyShape != null;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PhysicalScannerScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasData
              ? themeColor.withAlpha(20)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasData
                ? themeColor.withAlpha(80)
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasData
                    ? themeColor.withAlpha(40)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasData
                    ? Icons.accessibility_new_rounded
                    : Icons.camera_front_outlined,
                color: hasData
                    ? themeColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasData
                        ? 'Perfil Físico IA Activo'
                        : 'Escáner Físico con I.A.',
                    style: TextStyle(
                      color: hasData
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasData) ...[
                    Text(
                      '${profile.colorimetry} • ${profile.bodyShape}',
                      style: TextStyle(
                          color: themeColor.withAlpha(200),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    hasData
                        ? 'Gemini usa esta info para tus outfits.'
                        : 'Descubre qué ropa te favorece.',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.54),
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: hasData
                    ? themeColor
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45)),
          ],
        ),
      ),
    );
  }

  Widget _garmentMiniCard(WardrobeGarment g) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onSurface.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(_emojiFor(g.type), style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _parseColor(g.primaryColor),
              shape: BoxShape.circle,
              border: Border.all(color: onSurface.withValues(alpha: 0.25)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            g.name,
            style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 10),
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
      case GarmentType.shirt:
        return '👕';
      case GarmentType.tshirt:
        return '👚';
      case GarmentType.pants:
        return '👖';
      case GarmentType.shoes:
      case GarmentType.sneakers:
        return '👟';
      case GarmentType.boots:
        return '🥾';
      case GarmentType.sandals:
        return '🩴';
      case GarmentType.jacket:
        return '🧥';
      case GarmentType.shorts:
        return '🩳';
      case GarmentType.dress:
        return '👗';
      default:
        return '🎽';
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
