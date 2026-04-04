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
}
