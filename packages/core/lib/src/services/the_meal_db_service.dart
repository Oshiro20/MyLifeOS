import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:domain/domain.dart';
import 'package:uuid/uuid.dart';

/// Service to fetch recipes from TheMealDB (Free Public API)
class TheMealDBService {
  final String _baseUrl = 'https://www.themealdb.com/api/json/v1/1';
  final _uuid = const Uuid();

  /// Filter by main ingredient (Optimized: Parallel requests)
  Future<List<Recipe>> searchByIngredient(String ingredient) async {
    final url = Uri.parse('$_baseUrl/filter.php?i=$ingredient');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final meals = data['meals'] as List<dynamic>? ?? [];

      // Fetch full details for first 3 results IN PARALLEL to keep it fast
      final idsToFetch = meals.take(3).map((meal) => meal['idMeal']).toList();

      final futures = idsToFetch.map((id) async {
        final detailUrl = Uri.parse('$_baseUrl/lookup.php?i=$id');
        final detailResponse = await http.get(detailUrl);
        if (detailResponse.statusCode == 200) {
          final detailData = json.decode(detailResponse.body);
          final details = detailData['meals']?.first;
          if (details != null) {
            return _parseMeal(details);
          }
        }
        return null;
      });

      final results = await Future.wait(futures);
      return results.whereType<Recipe>().toList();
    }
    return [];
  }

  /// Filter by Area (e.g., Peruvian, Italian)
  Future<List<Recipe>> searchByArea(String area) async {
    final url = Uri.parse('$_baseUrl/filter.php?a=$area');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final meals = data['meals'] as List<dynamic>? ?? [];
      return meals.take(10).map((meal) => _parseMeal(meal)).toList();
    }
    return [];
  }

  /// Filter by Category (e.g., Dessert, Starter, Side, Snack)
  Future<List<Recipe>> searchByCategory(String category) async {
    final url = Uri.parse('$_baseUrl/filter.php?c=$category');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final meals = data['meals'] as List<dynamic>? ?? [];
      return meals.take(10).map((meal) => _parseMeal(meal)).toList();
    }
    return [];
  }

  Recipe _parseMeal(Map<String, dynamic> meal) {
    final ingredients = <RecipeIngredient>[];
    for (int i = 1; i <= 20; i++) {
      final ing = meal['strIngredient$i'];
      final measure = meal['strMeasure$i'];
      if (ing != null && ing.toString().isNotEmpty) {
        // Simple parsing: "1 cup" -> quantity: 1.0, unit: cup
        double qty = 1.0;
        String unit = 'unidades';
        final parts = measure.toString().trim().split(' ');
        if (parts.isNotEmpty) {
          final parsed = double.tryParse(parts[0]);
          if (parsed != null) {
            qty = parsed;
            if (parts.length > 1) unit = parts.sublist(1).join(' ');
          } else {
            unit = measure.toString();
          }
        }

        ingredients.add(RecipeIngredient(
          id: _uuid.v4(),
          recipeId: meal['idMeal'],
          ingredientName: ing.toString(),
          quantity: qty,
          unit: unit,
        ));
      }
    }

    return Recipe(
      id: _uuid.v4(), // Generate new ID for our app
      name: meal['strMeal'],
      description: meal['strTags']?.toString() ?? '',
      durationMinutes: 45, // API doesn't provide time, using average
      servings: 4,
      instructions: [meal['strInstructions'] ?? 'Ver detalles.'],
      ingredients: ingredients,
      tags: (meal['strTags'] as String?)
              ?.split(',')
              .map((e) => e.trim())
              .toList() ??
          [],
      createdAt: DateTime.now(),
    );
  }
}
