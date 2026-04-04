import 'package:flutter/material.dart';
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

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _entryController; // entrada de cada slide: 800ms
  late AnimationController _shimmerController; // shimmer del botón final: loop

  late Animation<double> _emojiScale;
  late Animation<double> _emojiOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _featuresDelay;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _setupAnimations();
    _entryController.forward();
  }

  void _setupAnimations() {
    _emojiScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.elasticOut),
    );

    _emojiOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );

    _featuresDelay = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shimmerController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _entryController
      ..reset()
      ..forward();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/home');
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
                    slide: _slides[index],
                    emojiScale: _emojiScale,
                    emojiOpacity: _emojiOpacity,
                    titleSlide: _titleSlide,
                    subtitleOpacity: _subtitleOpacity,
                    featuresDelay: _featuresDelay,
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
                  shimmer: _shimmer,
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
  final Animation<double> emojiScale;
  final Animation<double> emojiOpacity;
  final Animation<Offset> titleSlide;
  final Animation<double> subtitleOpacity;
  final Animation<double> featuresDelay;

  const _SlideContent({
    required this.slide,
    required this.emojiScale,
    required this.emojiOpacity,
    required this.titleSlide,
    required this.subtitleOpacity,
    required this.featuresDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji con escala elástica e icono
          ScaleTransition(
            scale: emojiScale,
            child: FadeTransition(
              opacity: emojiOpacity,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.accentColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: slide.accentColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(slide.emoji, style: const TextStyle(fontSize: 56)),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: slide.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          slide.icon,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Título con slide-up
          SlideTransition(
            position: titleSlide,
            child: Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Subtítulo con fade
          FadeTransition(
            opacity: subtitleOpacity,
            child: Text(
              slide.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Features con animación delay
          if (slide.features.isNotEmpty)
            FadeTransition(
              opacity: featuresDelay,
              child: Column(
                children: slide.features
                    .map((f) => _FeatureChip(
                          label: f,
                          accentColor: slide.accentColor,
                        ))
                    .toList(),
              ),
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
  final Animation<double> shimmer;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.accentColor,
    required this.isLast,
    required this.shimmer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
    );

    // En el último slide, envuelve con efecto shimmer
    if (isLast) {
      button = AnimatedBuilder(
        animation: shimmer,
        builder: (_, child) {
          return ShaderMask(
            shaderCallback: (rect) => LinearGradient(
              colors: [
                accentColor,
                Colors.white.withValues(alpha: 0.9),
                accentColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(shimmer.value - 1, 0),
              end: Alignment(shimmer.value + 1, 0),
            ).createShader(rect),
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: button,
      );
    }

    return button;
  }
}
