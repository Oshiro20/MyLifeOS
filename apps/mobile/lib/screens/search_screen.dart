import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cocina/cocina.dart';
import 'package:armario/armario.dart';

// ── Modelo de resultado ───────────────────────────────────────────────────────

enum SearchResultType { recipe, garment, module }

class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String emoji;
  final SearchResultType type;
  final String route; // GoRouter route para navegar al resultado

  const SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.type,
    required this.route,
  });
}

// ── Módulos estáticos ─────────────────────────────────────────────────────────

const _modules = [
  SearchResult(
    id: 'mod_finanzas',
    title: 'Finanzas',
    subtitle: 'WalletAI • Gastos e ingresos del mes',
    emoji: '💰',
    type: SearchResultType.module,
    route: '/finanzas',
  ),
  SearchResult(
    id: 'mod_armario',
    title: 'Armario',
    subtitle: 'Prendas, outfits y sugerencias IA',
    emoji: '👗',
    type: SearchResultType.module,
    route: '/armario',
  ),
  SearchResult(
    id: 'mod_cocina',
    title: 'Cocina',
    subtitle: 'Recetas, despensa y planificación',
    emoji: '🍽️',
    type: SearchResultType.module,
    route: '/cocina',
  ),
  SearchResult(
    id: 'mod_foodcoach',
    title: 'FoodCoach',
    subtitle: 'Evaluación nutricional con IA',
    emoji: '🥗',
    type: SearchResultType.module,
    route: '/foodcoach',
  ),
  SearchResult(
    id: 'mod_settings',
    title: 'Configuración',
    subtitle: 'Ajustes y preferencias de MyLifeOS',
    emoji: '⚙️',
    type: SearchResultType.module,
    route: '/settings',
  ),
];

// ── SearchDelegate ────────────────────────────────────────────────────────────

/// Búsqueda global tipo Spotlight para MyLifeOS.
///
/// Busca en recetas (Cocina), prendas (Armario) y módulos de la app.
class MyLifeOSSearchDelegate extends SearchDelegate<String> {
  final WidgetRef ref;

  MyLifeOSSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Buscar en MyLifeOS...';

  @override
  TextStyle get searchFieldStyle => const TextStyle(
        color: Colors.white,
        fontSize: 16,
      );

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F2017),
        iconTheme: IconThemeData(color: Colors.white70),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white54),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
        onPressed: () => close(context, ''),
      );

  @override
  Widget buildResults(BuildContext context) => _buildResultsList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildResultsList(context);

  // ── Lógica de búsqueda ────────────────────────────────────────────────────

  List<SearchResult> _search() {
    if (query.trim().isEmpty) return _modules;

    final q = query.toLowerCase();
    final results = <SearchResult>[];

    // Recetas
    try {
      final recipesState = ref.read(recipesProvider);
      for (final r in recipesState.recipes) {
        if (r.name.toLowerCase().contains(q) ||
            r.description.toLowerCase().contains(q)) {
          results.add(SearchResult(
            id: 'recipe_${r.id}',
            title: r.name,
            subtitle: r.description.isNotEmpty ? r.description : '${r.durationMinutes} min • ${r.servings} porciones',
            emoji: '🍳',
            type: SearchResultType.recipe,
            route: '/cocina',
          ));
        }
      }
    } catch (_) {}

    // Prendas
    try {
      final armarioState = ref.read(armarioProvider);
      for (final g in armarioState.garments) {
        if (g.name.toLowerCase().contains(q) ||
            g.type.name.toLowerCase().contains(q) ||
            (g.style.name.toLowerCase().contains(q))) {
          results.add(SearchResult(
            id: 'garment_${g.id}',
            title: g.name,
            subtitle:
                '${g.type.name} • ${g.primaryColor} • ${g.isClean ? "✅ Limpia" : "🧺 Para lavar"}',
            emoji: '👔',
            type: SearchResultType.garment,
            route: '/armario',
          ));
        }
      }
    } catch (_) {}

    // Módulos
    for (final m in _modules) {
      if (m.title.toLowerCase().contains(q) ||
          m.subtitle.toLowerCase().contains(q)) {
        results.add(m);
      }
    }

    return results;
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  Widget _buildResultsList(BuildContext context) {
    final results = _search();

    if (results.isEmpty) {
      return _EmptyResults(query: query);
    }

    // Agrupar por tipo
    final recipes = results.where((r) => r.type == SearchResultType.recipe).toList();
    final garments = results.where((r) => r.type == SearchResultType.garment).toList();
    final modules = results.where((r) => r.type == SearchResultType.module).toList();

    return Container(
      color: const Color(0xFF0A1410),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (recipes.isNotEmpty) ...[
            _SectionHeader(label: 'RECETAS', count: recipes.length),
            ...recipes.map((r) => _ResultTile(result: r, onTap: () => _navigate(context, r))),
          ],
          if (garments.isNotEmpty) ...[
            _SectionHeader(label: 'PRENDAS', count: garments.length),
            ...garments.map((r) => _ResultTile(result: r, onTap: () => _navigate(context, r))),
          ],
          if (modules.isNotEmpty) ...[
            _SectionHeader(label: 'MÓDULOS', count: modules.length),
            ...modules.map((r) => _ResultTile(result: r, onTap: () => _navigate(context, r))),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, SearchResult result) {
    close(context, result.route);
    context.go(result.route);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child:
                    Text(result.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.2),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final String query;
  const _EmptyResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1410),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔍', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Sin resultados para "$query"',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Prueba con otro término',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
