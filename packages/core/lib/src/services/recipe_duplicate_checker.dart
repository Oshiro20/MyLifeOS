import 'package:domain/domain.dart';

class RecipeDuplicateChecker {
  static List<DuplicateMatch> findDuplicates(
    Recipe newRecipe,
    List<Recipe> existingRecipes, {
    double threshold = 0.70,
  }) {
    final matches = <DuplicateMatch>[];
    for (final existing in existingRecipes) {
      final score = _calculateSimilarity(newRecipe, existing);
      if (score >= threshold) {
        matches.add(DuplicateMatch(recipe: existing, similarityScore: score));
      }
    }
    matches.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return matches;
  }

  static double _calculateSimilarity(Recipe a, Recipe b) {
    final nameScore = _textSimilarity(a.name.toLowerCase(), b.name.toLowerCase());
    final ingredientScore = _ingredientOverlap(a.ingredients, b.ingredients);
    final cuisineScore = (a.cuisineStyle?.toLowerCase() == b.cuisineStyle?.toLowerCase()) ? 1.0 : 0.5;
    final mealTypeScore = (a.tipoComida == b.tipoComida) ? 1.0 : 0.5;
    return (nameScore * 0.4) + (ingredientScore * 0.4) + (cuisineScore * 0.1) + (mealTypeScore * 0.1);
  }

  static double _textSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a.contains(b) || b.contains(a)) return 0.85;
    final wordsA = a.split(RegExp(r'\s+')).toSet();
    final wordsB = b.split(RegExp(r'\s+')).toSet();
    if (wordsA.isEmpty && wordsB.isEmpty) return 1.0;
    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;
    final intersection = wordsA.intersection(wordsB);
    final union = wordsA.union(wordsB);
    return intersection.length / union.length;
  }

  static double _ingredientOverlap(List<RecipeIngredient> a, List<RecipeIngredient> b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final namesA = a.map((i) => i.ingredientName.toLowerCase().trim()).toSet();
    final namesB = b.map((i) => i.ingredientName.toLowerCase().trim()).toSet();
    int matches = 0;
    for (final ingA in namesA) {
      for (final ingB in namesB) {
        if (ingA == ingB || ingA.contains(ingB) || ingB.contains(ingA)) { matches++; break; }
      }
    }
    final maxLen = namesA.length > namesB.length ? namesA.length : namesB.length;
    return matches / maxLen;
  }
}

class DuplicateMatch {
  final Recipe recipe;
  final double similarityScore;
  const DuplicateMatch({required this.recipe, required this.similarityScore});
}
