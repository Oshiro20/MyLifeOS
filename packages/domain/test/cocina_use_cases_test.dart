import 'package:test/test.dart';
import 'package:domain/src/cocina/usecases/calculate_recipe_viability_use_case.dart';
import 'package:domain/src/cocina/usecases/generate_shopping_list_use_case.dart';

void main() {
  group('CalculateRecipeViabilityUseCase', () {
    late CalculateRecipeViabilityUseCase useCase;

    setUp(() {
      useCase = CalculateRecipeViabilityUseCase();
    });

    test('debería retornar 1.0 (100%) cuando todos los ingredientes están el inventario', () {
      final req = {'Tomate': 2.0, 'Cebolla': 1.0};
      final inv = {'Tomate': 5.0, 'Cebolla': 2.0};

      final result = useCase.execute(recipeRequirements: req, inventory: inv);
      expect(result, 1.0);
    });

    test('debería retornar 0.5 (50%) cuando falta la mitad de ingredientes', () {
      final req = {'Tomate': 2.0, 'Cebolla': 1.0};
      final inv = {'Tomate': 5.0}; // Falta cebolla

      final result = useCase.execute(recipeRequirements: req, inventory: inv);
      expect(result, 0.5);
    });

    test('debería retornar 0.0 (0%) cuando no hay inventario', () {
      final req = {'Tomate': 2.0, 'Cebolla': 1.0};
      final inv = <String, double>{};

      final result = useCase.execute(recipeRequirements: req, inventory: inv);
      expect(result, 0.0);
    });

    test('debería ser case-insensitive y tolerar espacios', () {
      final req = {'  ToMaTe ': 2.0};
      final inv = {'tomate': 2.0};

      final result = useCase.execute(recipeRequirements: req, inventory: inv);
      expect(result, 1.0);
    });
  });

  group('GenerateShoppingListUseCase', () {
    late GenerateShoppingListUseCase useCase;

    setUp(() {
      useCase = GenerateShoppingListUseCase();
    });

    test('debería retornar lista vacía si el inventario cubre todo', () {
      final req = {'Tomate': 2.0};
      final inv = {'Tomate': 5.0};

      final result = useCase.execute(recipeRequirements: req, inventory: inv);
      expect(result.isEmpty, true);
    });

    test('debería retornar la diferencia exacta de los faltantes', () {
      final req = {'Tomate': 5.0, 'Cebolla': 3.0, 'Ajo': 1.0};
      final inv = {'Tomate': 2.0, 'Cebolla': 3.0}; // Falta 3 tomates y 1 ajo

      final result = useCase.execute(recipeRequirements: req, inventory: inv);
      
      expect(result.length, 2);
      expect(result['Tomate'], 3.0);
      expect(result['Ajo'], 1.0);
    });
  });
}
