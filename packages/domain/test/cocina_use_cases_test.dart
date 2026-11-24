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
          id: 'p_fideo',
          name: 'Fideos',
          primaryCategory: 'Secos',
          quantity: 1.0,
          unit: 'paquete',
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
          id: 'r_fideo',
          recipeId: 'r1',
          ingredientName: 'fideos',
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

    test('convierte kg de papa <-> unidades usando peso promedio o equivalencia personalizada', () {
      const pantry = [
        InventoryIngredient(
          id: 'p_papa',
          name: 'Papa blanca',
          primaryCategory: 'Tubérculos y raíces',
          quantity: 1.0,
          unit: 'kg',
        ),
      ];
      const recipe = [
        RecipeIngredient(
          id: 'r_papa',
          recipeId: 'r1',
          ingredientName: 'papa',
          quantity: 3.0,
          unit: 'unidades',
        ),
      ];

      final defaultChecks = IngredientMatcher.evaluateRecipe(
        recipeIngredients: recipe,
        inventory: pantry,
      );
      expect(defaultChecks.single.availability, IngredientAvailability.available);
      expect(defaultChecks.single.isApproximateConversion, isTrue);
      expect(defaultChecks.single.deductedInPantryUnit, closeTo(0.51, 0.05));

      final customChecks = IngredientMatcher.evaluateRecipe(
        recipeIngredients: recipe,
        inventory: pantry,
        customGramsPerUnit: {'papa blanca': 125.0}, // 8 papas por kg
      );
      expect(customChecks.single.deductedInPantryUnit, closeTo(0.375, 0.001));
    });

    test('ExtractRecipeUseCase.parseNutritionGoal clasifica etiquetas de dieta/músculo/ligera', () {
      expect(
        ExtractRecipeUseCase.parseNutritionGoal('bajar_peso'),
        NutritionGoal.loseWeight,
      );
      expect(
        ExtractRecipeUseCase.parseNutritionGoal('ganar_musculo'),
        NutritionGoal.gainMuscle,
      );
      expect(
        ExtractRecipeUseCase.parseNutritionGoal('ligera'),
        NutritionGoal.light,
      );
      expect(
        ExtractRecipeUseCase.parseNutritionGoal('normal'),
        NutritionGoal.maintain,
      );
    });

    test('empareja Menestra lentejas baby cocida (1 u) con Lentejas baby (250 g), Pasta de ajos con Ajos molidos y Entrepierna con Encuentro', () {
      const pantry = [
        InventoryIngredient(
          id: 'p_lentejas',
          name: 'Menestra lentejas baby',
          primaryCategory: 'Legumbres',
          preparation: 'cocido / listo',
          quantity: 1.0,
          unit: 'unidades',
        ),
        InventoryIngredient(
          id: 'p_ajos',
          name: 'Ajos molidos',
          primaryCategory: 'Condimentos y especias',
          quantity: 300.0,
          unit: 'ml',
        ),
        InventoryIngredient(
          id: 'p_pollo',
          name: 'Entrepierna de pollo',
          primaryCategory: 'Proteínas animales',
          quantity: 2.0,
          unit: 'unidades',
        ),
      ];
      const recipe = [
        RecipeIngredient(
          id: 'r1',
          recipeId: 'rec1',
          ingredientName: 'Lentejas baby',
          quantity: 250.0,
          unit: 'gramos',
        ),
        RecipeIngredient(
          id: 'r2',
          recipeId: 'rec1',
          ingredientName: 'Pasta de ajos',
          quantity: 3.0,
          unit: 'cucharadas',
        ),
        RecipeIngredient(
          id: 'r3',
          recipeId: 'rec1',
          ingredientName: 'Encuentro de pollo',
          quantity: 2.0,
          unit: 'unidades',
        ),
      ];

      final checks = IngredientMatcher.evaluateRecipe(
        recipeIngredients: recipe,
        inventory: pantry,
      );

      expect(checks[0].availability, IngredientAvailability.available);
      expect(checks[0].pantryMatch?.id, 'p_lentejas');
      expect(checks[0].deductedInPantryUnit, closeTo(1.0, 0.001));

      expect(checks[1].availability, IngredientAvailability.available);
      expect(checks[1].pantryMatch?.id, 'p_ajos');
      expect(checks[1].deductedInPantryUnit, closeTo(45.0, 0.001));

      expect(checks[2].availability, IngredientAvailability.available);
      expect(checks[2].pantryMatch?.id, 'p_pollo');
      expect(checks[2].deductedInPantryUnit, closeTo(2.0, 0.001));
    });

    test('ignora porciones guardadas y extras listos antiguos para no confundir recetas', () {
      const pantry = [
        InventoryIngredient(
          id: 'p_leftover_main',
          name: 'Pollo frito con lentejas (preparado)',
          primaryCategory: 'Preparados / Listos',
          subCategory: 'Porción guardada',
          preparation: 'cocido / listo',
          quantity: 2.0,
          unit: 'unidades',
        ),
        InventoryIngredient(
          id: 'p_leftover_extra',
          name: 'Huevos (cocido)',
          primaryCategory: 'Preparados / Listos',
          subCategory: 'Extra listo',
          preparation: 'cocido / listo',
          quantity: 3.0,
          unit: 'unidades',
        ),
      ];

      expect(
        IngredientMatcher.findBestMatch(pantry, 'Huevos'),
        isNull,
      );
      expect(
        IngredientMatcher.findBestMatch(pantry, 'Lentejas'),
        isNull,
      );
    });
  });

  group('QuickMealSuggestionsUseCase', () {
    test('ordena sugerencias por periodo, disponibilidad y rescate de ingredientes por vencer', () {
      const useCase = QuickMealSuggestionsUseCase();
      final soon = DateTime.now().add(const Duration(days: 1));
      final pantry = [
        InventoryIngredient(
          id: 'p1',
          name: 'Avena',
          primaryCategory: 'Cereales',
          quantity: 500,
          unit: 'g',
        ),
        InventoryIngredient(
          id: 'p2',
          name: 'Plátano',
          primaryCategory: 'Frutas',
          quantity: 3,
          unit: 'unidades',
          expirationDate: soon,
        ),
        InventoryIngredient(
          id: 'p3',
          name: 'Pollo',
          primaryCategory: 'Proteínas',
          quantity: 4,
          unit: 'unidades',
        ),
        InventoryIngredient(
          id: 'p4',
          name: 'Arroz',
          primaryCategory: 'Cereales',
          quantity: 1,
          unit: 'kg',
        ),
      ];

      final breakfastRecipe = Recipe(
        id: 'rec_b',
        name: 'Avena con plátano',
        description: 'Desayuno rápido',
        durationMinutes: 10,
        servings: 1,
        instructions: const ['Cocinar avena', 'Agregar plátano'],
        ingredients: const [
          RecipeIngredient(
            id: 'i1',
            recipeId: 'rec_b',
            ingredientName: 'Avena',
            quantity: 60,
            unit: 'g',
          ),
          RecipeIngredient(
            id: 'i2',
            recipeId: 'rec_b',
            ingredientName: 'Plátano',
            quantity: 1,
            unit: 'unidades',
          ),
        ],
        goal: NutritionGoal.gainMuscle,
        tipoComida: MealType.desayuno,
        createdAt: DateTime(2026, 1, 1),
      );

      final lunchRecipe = Recipe(
        id: 'rec_l',
        name: 'Arroz con pollo',
        description: 'Clásico peruano',
        durationMinutes: 40,
        servings: 2,
        instructions: const ['Aderezar', 'Cocinar arroz con pollo'],
        ingredients: const [
          RecipeIngredient(
            id: 'i3',
            recipeId: 'rec_l',
            ingredientName: 'Pollo',
            quantity: 2,
            unit: 'unidades',
          ),
          RecipeIngredient(
            id: 'i4',
            recipeId: 'rec_l',
            ingredientName: 'Arroz',
            quantity: 250,
            unit: 'g',
          ),
        ],
        goal: NutritionGoal.maintain,
        tipoComida: MealType.seco,
        createdAt: DateTime(2026, 1, 1),
      );

      final breakfastResults = useCase(
        period: QuickMealPeriod.breakfast,
        recipes: [lunchRecipe, breakfastRecipe],
        inventory: pantry,
        activeGoal: NutritionGoal.gainMuscle,
      );
      expect(breakfastResults.first.recipe.id, 'rec_b');
      expect(breakfastResults.first.availabilityPercent, 100);
      expect(breakfastResults.first.rescuedExpiringNames, contains('Plátano'));
      expect(breakfastResults.first.matchesGoal, isTrue);

      final lunchResults = useCase(
        period: QuickMealPeriod.lunch,
        recipes: [breakfastRecipe, lunchRecipe],
        inventory: pantry,
      );
      expect(lunchResults.first.recipe.id, 'rec_l');
      expect(QuickMealPeriod.forHour(8), QuickMealPeriod.breakfast);
      expect(QuickMealPeriod.forHour(13), QuickMealPeriod.lunch);
      expect(QuickMealPeriod.forHour(19), QuickMealPeriod.dinner);
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
