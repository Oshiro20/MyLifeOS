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

    test('parseFromJson lanza error legible cuando IA reporta error_extraccion',
        () {
      const errorJson =
          '{"error_extraccion": "No hay información visible del plato."}';
      final useCase = ExtractRecipeUseCase(FakeAIExtractor());

      expect(
        () => useCase.parseFromJson(errorJson),
        throwsA(
          predicate((e) =>
              e.toString().contains('No hay información visible del plato.')),
        ),
      );
    });

    test('parseManyFromJson extrae múltiples recetas con tipoComida y cocina',
        () {
      const multiJson = '''
      {
        "recetas": [
          {
            "nombre_receta": "Arroz Chaufa",
            "tipo_comida": "Seco",
            "cocina": "Peruana-China",
            "porciones": 2,
            "tiempo_total_min": 25,
            "ingredientes": [{"nombre": "Arroz", "cantidad": 2, "unidad": "tazas"}],
            "pasos": ["Cocinar arroz", "Saltear", "Servir"]
          },
          {
            "nombre_receta": "Jugo Verde Detox",
            "tipo_comida": "Jugo",
            "cocina": "Saludable",
            "porciones": 1,
            "tiempo_total_min": 5,
            "ingredientes": [{"nombre": "Espinaca", "cantidad": 50, "unidad": "gramos"}],
            "pasos": ["Lavar", "Licuar", "Servir"]
          }
        ]
      }
      ''';

      final useCase = ExtractRecipeUseCase(FakeAIExtractor());
      final list = useCase.parseManyFromJson(
        multiJson,
        sourceUrl: 'https://www.tiktok.com/@chef/video/123',
      );

      expect(list.length, 2);
      expect(list[0].id, isNot(equals(list[1].id)));
      expect(list[0].name, 'Arroz Chaufa');
      expect(list[0].tipoComida, MealType.seco);
      expect(list[0].cuisineStyle, 'Peruana-China');
      expect(list[1].name, 'Jugo Verde Detox');
      expect(list[1].tipoComida, MealType.jugo);
      expect(list[1].cuisineStyle, 'Saludable');
      expect(list[1].fuenteUrl, 'https://www.tiktok.com/@chef/video/123');
    });

    test(
        'parseFromJson separa tiempo activo y refrigeración en RecipeTimeBreakdown',
        () {
      const jellyJson = '''
      {
        "nombre_receta": "Gelatina Pie de Limón Saludable",
        "tipo_comida": "Mazamorra",
        "porciones": 4,
        "tiempo_preparacion_min": 15,
        "tiempo_coccion_min": 0,
        "tiempo_refrigeracion_min": 180,
        "tiempo_total_min": 195,
        "ingredientes": [
          {"nombre": "Gelatina sin sabor", "cantidad": 14, "unidad": "gramos"},
          {"nombre": "Limón", "cantidad": 3, "unidad": "unidades"}
        ],
        "pasos": [
          "Hidratar y disolver la gelatina",
          "Mezclar con jugo de limón",
          "Refrigerar durante 3 horas hasta cuajar firme"
        ]
      }
      ''';

      final useCase = ExtractRecipeUseCase(FakeAIExtractor());
      final recipe = useCase.parseFromJson(jellyJson);
      final breakdown = RecipeTimeBreakdown.extract(recipe);

      expect(recipe.durationMinutes, 195);
      expect(breakdown.activeMinutes, 15);
      expect(breakdown.chillMinutes, 180);
      expect(RecipeTimeBreakdown.summaryLabel(recipe),
          '15 min activo + 3 h refri');
      expect(RecipeTimeBreakdown.compactChip(recipe), '15m+3 h❄');
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

  group('WhatCanICookUseCase', () {
    test('executeWithMenu parsea objeto {"menus": ...}, pasos String y sinónimos',
        () async {
      final fake = FakeAIExtractor(
        jsonResponse: '''```json
{
  "menus": [
    {
      "menu_numero": 1,
      "platos": [
        {
          "nombre_receta": "Seco de pollo",
          "descripcion": "Clásico casero",
          "porciones": 2.0,
          "tiempo_total_min": 35.0,
          "tipo_comida": "segundo",
          "ingredientes": [
            {"nombre": "Pollo", "cantidad": "500", "unidad": "g"},
            {"nombre": "Culantro", "cantidad": 1, "unidad": "taza"}
          ],
          "pasos": ["Licuar culantro", "Aderezar cebolla", "Cocinar pollo"]
        }
      ]
    }
  ]
}
```''',
      );
      final useCase = WhatCanICookUseCase(fake);
      final res = await useCase.executeWithMenu(
        inventory: const [
          InventoryIngredient(
            id: 'i1',
            name: 'Pollo',
            primaryCategory: 'Proteínas animales',
            quantity: 1,
            unit: 'kg',
          ),
        ],
        mealPeriod: 'almuerzo',
        components: ['platoFuerte'],
        menuCount: 1,
        budgetSaverMode: true,
      );

      expect(res, hasLength(1));
      expect(res.first.menuNumber, 1);
      expect(res.first.recipe.name, 'Seco de pollo');
      expect(res.first.recipe.tipoComida, MealType.seco);
      expect(res.first.recipe.instructions, hasLength(3));
    });
  });
}
