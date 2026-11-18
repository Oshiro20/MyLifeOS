import 'package:test/test.dart';
import 'package:domain/domain.dart';

void main() {
  group('CalculateRecipeViabilityUseCase', () {
    late CalculateRecipeViabilityUseCase useCase;

    setUp(() {
      useCase = CalculateRecipeViabilityUseCase();
    });

    test(
        'debería retornar 1.0 (100%) cuando todos los ingredientes están en el inventario con misma unidad',
        () {
      final req = [
        const RecipeIngredient(
            id: '1',
            recipeId: 'r1',
            ingredientName: 'Tomate',
            quantity: 2.0,
            unit: 'unidades'),
        const RecipeIngredient(
            id: '2',
            recipeId: 'r1',
            ingredientName: 'Cebolla',
            quantity: 1.0,
            unit: 'unidades'),
      ];
      final inv = [
        const InventoryIngredient(
            id: 'i1',
            name: 'Tomate',
            primaryCategory: 'Verduras',
            quantity: 5.0,
            unit: 'unidades'),
        const InventoryIngredient(
            id: 'i2',
            name: 'Cebolla',
            primaryCategory: 'Verduras',
            quantity: 2.0,
            unit: 'unidades'),
      ];

      final result = useCase.execute(recipeIngredients: req, inventory: inv);
      expect(result, 1.0);
    });

    test('debería retornar 0.5 (50%) cuando falta un ingrediente por completo',
        () {
      final req = [
        const RecipeIngredient(
            id: '1',
            recipeId: 'r1',
            ingredientName: 'Tomate',
            quantity: 2.0,
            unit: 'unidades'),
        const RecipeIngredient(
            id: '2',
            recipeId: 'r1',
            ingredientName: 'Cebolla',
            quantity: 1.0,
            unit: 'unidades'),
      ];
      final inv = [
        const InventoryIngredient(
            id: 'i1',
            name: 'Tomate',
            primaryCategory: 'Verduras',
            quantity: 5.0,
            unit: 'unidades'),
      ]; // Falta cebolla

      final result = useCase.execute(recipeIngredients: req, inventory: inv);
      expect(result, 0.5);
    });

    test(
        'debería calcular viabilidad con decimales para unidades de volumen con conversión',
        () {
      final req = [
        const RecipeIngredient(
            id: '1',
            recipeId: 'r1',
            ingredientName: 'Avena',
            quantity: 500.0,
            unit: 'g'),
        const RecipeIngredient(
            id: '2',
            recipeId: 'r1',
            ingredientName: 'Leche',
            quantity: 1.0,
            unit: 'litro'),
      ];
      final inv = [
        const InventoryIngredient(
            id: 'i1',
            name: 'Avena',
            primaryCategory: 'Cereales',
            quantity: 1.0,
            unit: 'kg'), // 1kg > 500g -> OK
        const InventoryIngredient(
            id: 'i2',
            name: 'Leche',
            primaryCategory: 'Lacteos',
            quantity: 500.0,
            unit: 'ml'), // 500ml de 1L -> 50%
      ];

      final result = useCase.execute(recipeIngredients: req, inventory: inv);
      // Avena aporta 1.0/2 (50% de la receta)
      // Leche aporta 0.5/2 (25% de la receta)
      // Total = 0.75
      expect(result, 0.75);
    });

    test('debería retornar 0.0 (0%) cuando no hay inventario', () {
      final req = [
        const RecipeIngredient(
            id: '1',
            recipeId: 'r1',
            ingredientName: 'Tomate',
            quantity: 2.0,
            unit: 'unidades'),
      ];
      final inv = <InventoryIngredient>[];

      final result = useCase.execute(recipeIngredients: req, inventory: inv);
      expect(result, 0.0);
    });
  });

  group('GenerateShoppingListUseCase', () {
    late GenerateShoppingListUseCase useCase;

    setUp(() {
      useCase = GenerateShoppingListUseCase();
    });

    test(
        'debería retornar lista vacía si el inventario cubre todo (con conversión de volumenes)',
        () {
      final req = [
        const RecipeIngredient(
            id: '1',
            recipeId: 'r1',
            ingredientName: 'Leche',
            quantity: 1.0,
            unit: 'litro'),
      ];
      final inv = [
        const InventoryIngredient(
            id: 'i1',
            name: 'Leche',
            primaryCategory: 'Lacteos',
            quantity: 1000.0,
            unit: 'ml'),
      ];

      final result = useCase.execute(recipeIngredients: req, inventory: inv);
      expect(result.isEmpty, true);
    });

    test(
        'debería retornar la diferencia exacta de los faltantes con unidades estandarizadas',
        () {
      final req = [
        const RecipeIngredient(
            id: '1',
            recipeId: 'r1',
            ingredientName: 'Harina',
            quantity: 1.0,
            unit: 'kg'),
        const RecipeIngredient(
            id: '2',
            recipeId: 'r1',
            ingredientName: 'Huevos',
            quantity: 6.0,
            unit: 'unidades'),
      ];
      final inv = [
        const InventoryIngredient(
            id: 'i1',
            name: 'Harina',
            primaryCategory: 'Secos',
            quantity: 800.0,
            unit: 'g'),
        const InventoryIngredient(
            id: 'i2',
            name: 'Huevos',
            primaryCategory: 'Frescos',
            quantity: 2.0,
            unit: 'unidades'),
      ];
      // Faltan 200g (la receta pide kg, así que devolverá faltante en kg = 0.2kg)
      // Faltan 4 huevos

      final result = useCase.execute(recipeIngredients: req, inventory: inv);

      expect(result.length, 2);

      final harinaMissing = result.firstWhere((e) => e.name == 'Harina');
      expect(harinaMissing.quantity, closeTo(0.2, 0.001));
      expect(harinaMissing.unit, 'kg');

      final huevosMissing = result.firstWhere((e) => e.name == 'Huevos');
      expect(huevosMissing.quantity, 4.0);
      expect(huevosMissing.unit, 'unidades');
    });
  });

  group('GenerateWeeklyMenuUseCase', () {
    test('no borra el menú existente si no hay recetas guardadas', () async {
      final repo = _FakeWeeklyMenuRepo(recipes: const []);
      final useCase = GenerateWeeklyMenuUseCase(repository: repo);

      await expectLater(useCase.execute(), throwsException);
      expect(repo.clearCalls, 0);
    });

    test('prioriza recetas por MealType en desayuno, almuerzo y cena',
        () async {
      final repo = _FakeWeeklyMenuRepo(recipes: [
        Recipe(
          id: 'r_b',
          name: 'Avena',
          durationMinutes: 10,
          servings: 1,
          tipoComida: MealType.desayuno,
          createdAt: DateTime(2026),
        ),
        Recipe(
          id: 'r_l',
          name: 'Seco de pollo',
          durationMinutes: 30,
          servings: 2,
          tipoComida: MealType.seco,
          createdAt: DateTime(2026),
        ),
        Recipe(
          id: 'r_d',
          name: 'Crema de verduras',
          durationMinutes: 20,
          servings: 2,
          tipoComida: MealType.cena,
          createdAt: DateTime(2026),
        ),
      ]);
      final useCase = GenerateWeeklyMenuUseCase(repository: repo);

      await useCase.execute();
      expect(repo.clearCalls, 1);
      expect(repo.savedEntries.length, 21);
      expect(
        repo.savedEntries.where((e) => e.mealType == 0).every((e) => e.recipeId == 'r_b'),
        isTrue,
      );
    });
  });

  group('IngredientMatcher', () {
    test('empareja frasco de Ajos molidos 300 ml con 2 cucharadas de ajos y descuenta 30 ml', () {
      const pantry = [
        InventoryIngredient(
          id: 'p_ajos',
          name: 'Ajos molidos',
          primaryCategory: 'Condimentos',
          quantity: 300.0,
          unit: 'ml',
        ),
      ];
      const recipe = [
        RecipeIngredient(
          id: 'r_ajos',
          recipeId: 'r1',
          ingredientName: 'ajos',
          quantity: 2.0,
          unit: 'cucharadas',
        ),
      ];

      final checks = IngredientMatcher.evaluateRecipe(
        recipeIngredients: recipe,
        inventory: pantry,
      );

      expect(checks.length, 1);
      final c = checks.first;
      expect(c.pantryMatch?.id, 'p_ajos');
      expect(c.availability, IngredientAvailability.available);
      expect(c.deductedInPantryUnit, closeTo(30.0, 0.001));
      expect(c.remainingAfterCook, closeTo(270.0, 0.001));
    });

    test('tolera tildes, plurales y variantes sin falsos positivos como salsa de tomate', () {
      const pantry = [
        InventoryIngredient(
          id: 'p_platano',
          name: 'Plátano Seda',
          primaryCategory: 'Frutas',
          quantity: 4.0,
          unit: 'unidades',
        ),
        InventoryIngredient(
          id: 'p_salsa',
          name: 'Salsa de tomate',
          primaryCategory: 'Despensa',
          quantity: 200.0,
          unit: 'g',
        ),
        InventoryIngredient(
          id: 'p_sillao',
          name: 'Sillao',
          primaryCategory: 'Condimentos',
          quantity: 500.0,
          unit: 'ml',
        ),
      ];

      expect(
        IngredientMatcher.findBestMatch(pantry, 'platano')?.id,
        'p_platano',
      );
      expect(
        IngredientMatcher.findBestMatch(pantry, 'tomate'),
        isNull,
      );
      expect(
        IngredientMatcher.findBestMatch(pantry, 'salsa de soya')?.id,
        'p_sillao',
      );
    });

    test('clasifica faltantes, insuficientes, unidades incompatibles y agotamientos', () {
      const pantry = [
        InventoryIngredient(
          id: 'p_huevo',
          name: 'Huevos',
          primaryCategory: 'Frescos',
          quantity: 2.0,
          unit: 'unidades',
        ),
        InventoryIngredient(
          id: 'p_pollo',
          name: 'Pollo',
          primaryCategory: 'Carnes',
          quantity: 1.0,
          unit: 'unidades',
        ),
      ];
      const recipe = [
        RecipeIngredient(
          id: 'r_huevo',
          recipeId: 'r1',
          ingredientName: 'huevo',
          quantity: 2.0,
          unit: 'unidades',
        ),
        RecipeIngredient(
          id: 'r_pollo',
          recipeId: 'r1',
          ingredientName: 'pollo',
          quantity: 500.0,
          unit: 'g',
        ),
        RecipeIngredient(
          id: 'r_sal',
          recipeId: 'r1',
          ingredientName: 'sal',
          quantity: 1.0,
          unit: 'cdta',
        ),
      ];

      final checks = IngredientMatcher.evaluateRecipe(
        recipeIngredients: recipe,
        inventory: pantry,
      );

      expect(checks[0].availability, IngredientAvailability.available);
      expect(checks[0].willDeplete, isTrue);
      expect(checks[1].availability, IngredientAvailability.incompatibleUnit);
      expect(checks[2].availability, IngredientAvailability.missing);
    });
  });
}

class _FakeWeeklyMenuRepo implements ICocinaRepository {
  final List<Recipe> recipes;
  int clearCalls = 0;
  final List<WeeklyMenuEntry> savedEntries = [];

  _FakeWeeklyMenuRepo({required this.recipes});

  @override
  Future<void> clearWeeklyMenu() async {
    clearCalls++;
    savedEntries.clear();
  }

  @override
  Future<List<Recipe>> getAllRecipes() async => recipes;

  @override
  Future<void> saveWeeklyMenuEntry(WeeklyMenuEntry entry) async {
    savedEntries.add(entry);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
