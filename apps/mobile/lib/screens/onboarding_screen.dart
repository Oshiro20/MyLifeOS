import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Datos de slides ───────────────────────────────────────────────────────────

class _Slide {
  final String emoji;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> features;
  final List<Color> gradient;
  final Color accentColor;

  const _Slide({
    required this.emoji,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.features = const [],
    required this.gradient,
    required this.accentColor,
  });
}

const _slides = [
  _Slide(
    emoji: '🧠',
    icon: Icons.dashboard_outlined,
    title: 'Tu Sistema Operativo Personal',
    subtitle:
        'MyLifeOS centraliza tu vida: finanzas, armario, cocina y nutrición en un solo lugar potenciado por IA.',
    features: ['5 módulos integrados', 'IA con Gemini', '100% offline-first'],
    gradient: [Color(0xFF0F2017), Color(0xFF1A3A28)],
    accentColor: Color(0xFF4CAF82),
  ),
  _Slide(
    emoji: '💰',
    icon: Icons.account_balance_wallet_outlined,
    title: 'Finanzas Inteligentes',
    subtitle:
        'WalletAI analiza tus gastos del mes con Gemini y te da insights personalizados para ahorrar más.',
    features: [
      'Análisis con IA',
      'Balance en tiempo real',
      'Reportes mensuales'
    ],
    gradient: [Color(0xFF1A1500), Color(0xFF2E2500)],
    accentColor: Color(0xFFFFC107),
  ),
  _Slide(
    emoji: '👗',
    icon: Icons.checkroom_outlined,
    title: 'Armario con IA',
    subtitle:
        'Sube tus prendas y deja que la IA sugiera outfits perfectos para cada ocasión del día.',
    features: [
      'Detección automática',
      'Outfits inteligentes',
      'Gestión de lavado'
    ],
    gradient: [Color(0xFF001A2E), Color(0xFF002B4A)],
    accentColor: Color(0xFF29B6F6),
  ),
  _Slide(
    emoji: '🍽️',
    icon: Icons.soup_kitchen_outlined,
    title: 'Cocina y Despensa',
    subtitle:
        'Importa recetas desde TikTok o fotos. Controla tu despensa y evita que los ingredientes caduquen.',
    features: ['Importador TikTok', 'Alertas de caducidad', 'Lista de compras'],
    gradient: [Color(0xFF1A0A00), Color(0xFF2E1500)],
    accentColor: Color(0xFFFF7043),
  ),
  _Slide(
    emoji: '🥗',
    icon: Icons.restaurant_outlined,
    title: 'Food Coach Personal',
    subtitle:
        'FoodCoach evalúa tus comidas con IA, te da feedback de salud y cuida tu nutrición diaria.',
    features: [
      'Evaluación nutricional',
      'Feedback instantáneo',
      'Historial semanal'
    ],
    gradient: [Color(0xFF1A0015), Color(0xFF2E0025)],
    accentColor: Color(0xFFFF5252),
  ),
];

// ── Pantalla ──────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
  }


  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (!mounted) return;
    context.go('/home');
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastLinearToSlowEaseIn,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final isLast = _currentPage == _slides.length - 1;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slide.gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Skip button ─────────────────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _completeOnboarding,
                    child: Text(
                      'Omitir',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // ── PageView ────────────────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: _onPageChanged,
                  itemCount: _slides.length,
                  itemBuilder: (_, index) => _SlideContent(
                    key: ValueKey(index),
                    slide: _slides[index],
                  ),
                ),
              ),

              // ── Dot indicators ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? slide.accentColor
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),

              // ── Action button ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                child: _ActionButton(
                  label: isLast ? '✨ Comenzar' : 'Siguiente',
                  accentColor: slide.accentColor,
                  isLast: isLast,
                  onTap: _nextPage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Slide content widget ──────────────────────────────────────────────────────

 class _SlideContent extends StatelessWidget {
  final _Slide slide;

  const _SlideContent({
    super.key,
    required this.slide,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji y Contenedor Icono
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: slide.accentColor.withValues(alpha: 0.1),
              border: Border.all(
                color: slide.accentColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(slide.emoji, style: const TextStyle(fontSize: 64)),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: slide.accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: slide.accentColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      slide.icon,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .scale(
                duration: 800.ms,
                curve: Curves.elasticOut,
                begin: const Offset(0.3, 0.3),
              )
              .fadeIn(duration: 400.ms),

          const SizedBox(height: 48),

          // Título
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms, delay: 200.ms)
              .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

          const SizedBox(height: 16),

          // Subtítulo
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1.5,
            ),
          ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

          const SizedBox(height: 40),

          // Features
          if (slide.features.isNotEmpty)
            Column(
              children: slide.features
                  .asMap()
                  .entries
                  .map((entry) => _FeatureChip(
                        label: entry.value,
                        accentColor: slide.accentColor,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: (600 + (entry.key * 100)).ms)
                          .slideX(begin: 0.1, end: 0))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ── Feature chip widget ──────────────────────────────────────────────────────

class _FeatureChip extends StatelessWidget {
  final String label;
  final Color accentColor;

  const _FeatureChip({required this.label, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action button con shimmer ─────────────────────────────────────────────────

 class _ActionButton extends StatelessWidget {
  final String label;
  final Color accentColor;
  final bool isLast;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.accentColor,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    );

    if (isLast) {
      return button
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(duration: 2.seconds, color: Colors.white.withValues(alpha: 0.4))
          .then(delay: 1.seconds);
    }

    return button;
  }
}
