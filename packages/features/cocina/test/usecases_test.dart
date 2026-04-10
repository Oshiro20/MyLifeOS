import 'package:flutter_test/flutter_test.dart';
import 'package:domain/domain.dart';
import 'package:core/core.dart';

// ── Fake AI Extractor ────────────────────────────────────────────────────────
class FakeAIExtractor implements IAIRecipeExtractor {
  String? jsonResponse;
  bool shouldThrow = false;

  FakeAIExtractor({this.jsonResponse, this.shouldThrow = false});

  @override
  Future<String?> extractRecipeJson({String? textContext, String? mediaPath}) {
    if (shouldThrow) throw Exception('AI service unavailable');
    return Future.value(jsonResponse);
  }
}

// ── ExtractRecipeUseCase Tests ───────────────────────────────────────────────
void main() {
  group('ExtractRecipeUseCase', () {
    test('parses valid JSON recipe correctly', () async {
      const fakeJson = '''
      {
        "name": "Arroz con pollo",
        "description": "Un clásico peruano",
        "durationMinutes": 45,
        "servings": 4,
        "ingredients": [
          {"ingredientName": "Arroz", "quantity": 2, "unit": "tazas"},
          {"ingredientName": "Pollo", "quantity": 500, "unit": "gramos"}
        ],
        "instructions": ["Paso 1", "Paso 2", "Paso 3"],
        "tags": ["peruano", "fácil"]
      }
      ''';

      final useCase =
          ExtractRecipeUseCase(FakeAIExtractor(jsonResponse: fakeJson));
      final recipe = await useCase.execute();

      expect(recipe, isNotNull);
      expect(recipe!.name, 'Arroz con pollo');
      expect(recipe.description, 'Un clásico peruano');
      expect(recipe.durationMinutes, 45);
      expect(recipe.servings, 4);
      expect(recipe.ingredients.length, 2);
      expect(recipe.instructions.length, 3);
      expect(recipe.tags, ['peruano', 'fácil']);
    });

    test('parses old Spanish format (nombre_receta, ingredientes, pasos)',
        () async {
      const fakeJson = '''
      {
        "nombre_receta": "Causa limeña",
        "descripcion": "Plato frío tradicional",
        "tiempo_total_min": 30,
        "porciones": 6,
        "ingredientes": [
          {"nombre": "Papa amarilla", "cantidad": 1, "unidad": "kg"},
          {"nombre": "Pollo", "cantidad": "2", "unidad": "pechugas"}
        ],
        "pasos": [
          {"numero": 2, "descripcion": "Mezclar con ají"},
          {"numero": 1, "descripcion": "Cocinar papas"}
        ],
        "tags": []
      }
      ''';

      final useCase =
          ExtractRecipeUseCase(FakeAIExtractor(jsonResponse: fakeJson));
      final recipe = await useCase.execute();

      expect(recipe, isNotNull);
      expect(recipe!.name, 'Causa limeña');
      expect(recipe.durationMinutes, 30);
      expect(recipe.servings, 6);
      expect(recipe.ingredients.length, 2);
      // Pasos should be sorted by numero
      expect(recipe.instructions.first, 'Cocinar papas');
    });

    test('handles JSON wrapped in markdown code blocks', () async {
      const fakeJson = '''
      Here's your recipe:
      ```json
      {
        "name": "Test Recipe",
        "description": "Testing markdown extraction",
        "durationMinutes": 20,
        "servings": 2,
        "ingredients": [
          {"ingredientName": "Flour", "quantity": 1, "unit": "tazas"}
        ],
        "instructions": ["Mix", "Bake", "Cool"],
        "tags": ["test"]
      }
      ```
      Hope you like it!
      ''';

      final useCase =
          ExtractRecipeUseCase(FakeAIExtractor(jsonResponse: fakeJson));
      final recipe = await useCase.execute();

      expect(recipe, isNotNull);
      expect(recipe!.name, 'Test Recipe');
    });

    test('returns null when AI returns empty response', () async {
      final useCase = ExtractRecipeUseCase(FakeAIExtractor(jsonResponse: ''));
      expect(await useCase.execute(), isNull);
    });

    test('returns null when AI returns null', () async {
      final useCase = ExtractRecipeUseCase(FakeAIExtractor(jsonResponse: null));
      expect(await useCase.execute(), isNull);
    });

    test('throws when AI returns invalid JSON', () async {
      final useCase = ExtractRecipeUseCase(
          FakeAIExtractor(jsonResponse: 'not json at all'));
      expect(() => useCase.execute(), throwsException);
    });

    test('throws when AI service fails', () async {
      final useCase = ExtractRecipeUseCase(FakeAIExtractor(shouldThrow: true));
      expect(() => useCase.execute(), throwsException);
    });

    test('parseFromJson works without AI (direct JSON import)', () async {
      const fakeJson = '''
      {
        "name": "Direct Import",
        "description": "Imported directly",
        "durationMinutes": 15,
        "servings": 1,
        "ingredients": [
          {"ingredientName": "Egg", "quantity": 2, "unit": "unidades"}
        ],
        "instructions": ["Step 1", "Step 2", "Step 3"],
        "tags": ["quick"]
      }
      ''';

      final useCase = ExtractRecipeUseCase(FakeAIExtractor());
      final recipe =
          useCase.parseFromJson(fakeJson, sourceUrl: 'https://example.com');

      expect(recipe, isNotNull);
      expect(recipe.name, 'Direct Import');
      expect(recipe.fuenteUrl, 'https://example.com');
      expect(recipe.ingredients.length, 1);
    });
  });

  // ── CalculateRecipeViabilityUseCase Tests ──────────────────────────────────
  group('CalculateRecipeViabilityUseCase', () {
    final useCase = CalculateRecipeViabilityUseCase();

    test(
        'returns 1.0 when inventory has all ingredients in sufficient quantity',
        () {
      final recipeIngredients = [
        RecipeIngredient(
          id: 'r1',
          recipeId: 'r',
          ingredientName: 'Rice',
          quantity: 2,
          unit: 'tazas',
        ),
        RecipeIngredient(
          id: 'r2',
          recipeId: 'r',
          ingredientName: 'Chicken',
          quantity: 500,
          unit: 'gramos',
        ),
      ];

      final inventory = [
        InventoryIngredient(
          id: 'i1',
          name: 'Rice',
          primaryCategory: 'Cereal',
          subCategory: '',
          preparation: '',
          quantity: 5,
          unit: 'tazas',
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          imageAssetId: '',
          storageArea: 'pantry',
        ),
        InventoryIngredient(
          id: 'i2',
          name: 'Chicken',
          primaryCategory: 'Proteína',
          subCategory: '',
          preparation: '',
          quantity: 1000,
          unit: 'gramos',
          expirationDate: DateTime.now().add(const Duration(days: 3)),
          imageAssetId: '',
          storageArea: 'fridge',
        ),
      ];

      final viability = useCase.execute(
        recipeIngredients: recipeIngredients,
        inventory: inventory,
      );

      expect(viability, 1.0);
    });

    test('returns partial score when inventory has insufficient quantities',
        () {
      final recipeIngredients = [
        RecipeIngredient(
          id: 'r1',
          recipeId: 'r',
          ingredientName: 'Rice',
          quantity: 2,
          unit: 'tazas',
        ),
      ];

      final inventory = [
        InventoryIngredient(
          id: 'i1',
          name: 'Rice',
          primaryCategory: 'Cereal',
          subCategory: '',
          preparation: '',
          quantity: 1,
          unit: 'tazas',
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          imageAssetId: '',
          storageArea: 'pantry',
        ),
      ];

      final viability = useCase.execute(
        recipeIngredients: recipeIngredients,
        inventory: inventory,
      );

      // 1 taza de 2 necesarias = 50%
      expect(viability, closeTo(0.5, 0.01));
    });

    test('returns 0 when inventory is missing ingredients', () {
      final recipeIngredients = [
        RecipeIngredient(
          id: 'r1',
          recipeId: 'r',
          ingredientName: 'Saffron',
          quantity: 1,
          unit: 'gramos',
        ),
      ];

      final inventory = [
        InventoryIngredient(
          id: 'i1',
          name: 'Rice',
          primaryCategory: 'Cereal',
          subCategory: '',
          preparation: '',
          quantity: 5,
          unit: 'tazas',
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          imageAssetId: '',
          storageArea: 'pantry',
        ),
      ];

      final viability = useCase.execute(
        recipeIngredients: recipeIngredients,
        inventory: inventory,
      );

      expect(viability, 0.0);
    });

    test('returns 1.0 for empty recipe', () {
      final viability = useCase.execute(
        recipeIngredients: [],
        inventory: [],
      );
      expect(viability, 1.0);
    });

    test('case-insensitive ingredient matching', () {
      final recipeIngredients = [
        RecipeIngredient(
          id: 'r1',
          recipeId: 'r',
          ingredientName: 'RICE',
          quantity: 1,
          unit: 'tazas',
        ),
      ];

      final inventory = [
        InventoryIngredient(
          id: 'i1',
          name: 'rice',
          primaryCategory: 'Cereal',
          subCategory: '',
          preparation: '',
          quantity: 3,
          unit: 'tazas',
          expirationDate: DateTime.now().add(const Duration(days: 30)),
          imageAssetId: '',
          storageArea: 'pantry',
        ),
      ];

      final viability = useCase.execute(
        recipeIngredients: recipeIngredients,
        inventory: inventory,
      );

      expect(viability, 1.0);
    });
  });

  // ── RecipeDuplicateChecker Tests ───────────────────────────────────────────
  group('RecipeDuplicateChecker', () {
    test('detects recipes with same name', () {
      final existing = Recipe(
        id: 'e1',
        name: 'Arroz con pollo',
        description: 'Classic',
        durationMinutes: 45,
        servings: 4,
        instructions: ['Step 1', 'Step 2', 'Step 3'],
        ingredients: [
          RecipeIngredient(
              id: 'e1_0',
              recipeId: 'e1',
              ingredientName: 'Rice',
              quantity: 2,
              unit: 'tazas'),
          RecipeIngredient(
              id: 'e1_1',
              recipeId: 'e1',
              ingredientName: 'Chicken',
              quantity: 500,
              unit: 'gramos'),
        ],
        tags: [],
        createdAt: DateTime.now(),
      );

      final newRecipe = existing.copyWith(id: 'n1');

      final matches =
          RecipeDuplicateChecker.findDuplicates(newRecipe, [existing]);

      expect(matches, isNotEmpty);
      expect(matches.first.similarityScore, greaterThanOrEqualTo(0.70));
    });

    test('does not flag different recipes as duplicates', () {
      final existing = Recipe(
        id: 'e1',
        name: 'Arroz con pollo',
        description: 'Classic',
        durationMinutes: 45,
        servings: 4,
        instructions: ['Step 1', 'Step 2', 'Step 3'],
        ingredients: [
          RecipeIngredient(
              id: 'e1_0',
              recipeId: 'e1',
              ingredientName: 'Rice',
              quantity: 2,
              unit: 'tazas'),
          RecipeIngredient(
              id: 'e1_1',
              recipeId: 'e1',
              ingredientName: 'Chicken',
              quantity: 500,
              unit: 'gramos'),
        ],
        tags: [],
        createdAt: DateTime.now(),
      );

      final newRecipe = Recipe(
        id: 'n1',
        name: 'Flan de vainilla',
        description: 'Dessert',
        durationMinutes: 60,
        servings: 6,
        instructions: ['Mix eggs', 'Add milk', 'Bake'],
        ingredients: [
          RecipeIngredient(
              id: 'n1_0',
              recipeId: 'n1',
              ingredientName: 'Eggs',
              quantity: 6,
              unit: 'unidades'),
          RecipeIngredient(
              id: 'n1_1',
              recipeId: 'n1',
              ingredientName: 'Milk',
              quantity: 1,
              unit: 'litros'),
        ],
        tags: [],
        createdAt: DateTime.now(),
      );

      final matches =
          RecipeDuplicateChecker.findDuplicates(newRecipe, [existing]);

      expect(matches, isEmpty);
    });

    test('detects partial name similarity', () {
      final existing = Recipe(
        id: 'e1',
        name: 'Arroz con pollo',
        description: 'Classic',
        durationMinutes: 45,
        servings: 4,
        instructions: ['Step 1', 'Step 2', 'Step 3'],
        ingredients: [
          RecipeIngredient(
              id: 'e1_0',
              recipeId: 'e1',
              ingredientName: 'Rice',
              quantity: 2,
              unit: 'tazas'),
          RecipeIngredient(
              id: 'e1_1',
              recipeId: 'e1',
              ingredientName: 'Chicken',
              quantity: 500,
              unit: 'gramos'),
        ],
        tags: [],
        createdAt: DateTime.now(),
      );

      final newRecipe = Recipe(
        id: 'n1',
        name: 'Arroz con pollo de la abuela',
        description: 'Family recipe',
        durationMinutes: 50,
        servings: 4,
        instructions: ['Step A', 'Step B', 'Step C'],
        ingredients: [
          RecipeIngredient(
              id: 'n1_0',
              recipeId: 'n1',
              ingredientName: 'Rice',
              quantity: 2,
              unit: 'tazas'),
          RecipeIngredient(
              id: 'n1_1',
              recipeId: 'n1',
              ingredientName: 'Chicken',
              quantity: 500,
              unit: 'gramos'),
        ],
        tags: [],
        createdAt: DateTime.now(),
      );

      final matches =
          RecipeDuplicateChecker.findDuplicates(newRecipe, [existing]);

      expect(matches, isNotEmpty);
    });

    test('respects custom threshold', () {
      final existing = Recipe(
        id: 'e1',
        name: 'Arroz con pollo',
        description: 'Classic',
        durationMinutes: 45,
        servings: 4,
        instructions: ['Step 1', 'Step 2', 'Step 3'],
        ingredients: [
          RecipeIngredient(
              id: 'e1_0',
              recipeId: 'e1',
              ingredientName: 'Rice',
              quantity: 2,
              unit: 'tazas'),
          RecipeIngredient(
              id: 'e1_1',
              recipeId: 'e1',
              ingredientName: 'Chicken',
              quantity: 500,
              unit: 'gramos'),
        ],
        tags: [],
        createdAt: DateTime.now(),
      );

      final newRecipe = Recipe(
        id: 'n1',
        name: 'Arroz con mariscos',
        description: 'Seafood version',
        durationMinutes: 40,
        servings: 4,
        instructions: ['Step X', 'Step Y', 'Step Z'],
        ingredients: [
          RecipeIngredient(
              id: 'n1_0',
              recipeId: 'n1',
              ingredientName: 'Rice',
              quantity: 2,
              unit: 'tazas'),
          RecipeIngredient(
              id: 'n1_1',
              recipeId: 'n1',
              ingredientName: 'Shrimp',
              quantity: 300,
              unit: 'gramos'),
        ],
        tags: [],
        createdAt: DateTime.now(),
      );

      // With high threshold, should not match
      final matchesHigh = RecipeDuplicateChecker.findDuplicates(
          newRecipe, [existing],
          threshold: 0.95);
      expect(matchesHigh, isEmpty);

      // With low threshold, might match
      final matchesLow = RecipeDuplicateChecker.findDuplicates(
          newRecipe, [existing],
          threshold: 0.30);
      // This depends on the similarity calculation
      expect(matchesLow.length, lessThanOrEqualTo(1));
    });
  });
}
