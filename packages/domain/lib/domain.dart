// Barrel de exportación del paquete domain
library;

// Cocina
export 'src/cocina/entities/ingredient.dart';
export 'src/cocina/entities/ingredient_units.dart';
export 'src/cocina/entities/inventory_ingredient.dart';
export 'src/cocina/entities/recipe.dart';
export 'src/cocina/entities/user_food_preferences.dart';
export 'src/cocina/entities/chef_preferences.dart';
export 'src/cocina/usecases/extract_recipe_use_case.dart';
export 'src/cocina/usecases/calculate_recipe_viability_use_case.dart';
export 'src/cocina/usecases/generate_shopping_list_use_case.dart';
export 'src/cocina/usecases/ingredient_unit_normalizer.dart';
export 'src/cocina/usecases/what_can_i_cook_use_case.dart';
export 'src/cocina/usecases/generate_weekly_menu_use_case.dart';
export 'src/cocina/repositories/i_ai_recipe_extractor.dart';
export 'src/cocina/repositories/i_cocina_repository.dart';

// Armario
export 'src/armario/entities/wardrobe_garment.dart';
export 'src/armario/repositories/i_armario_repository.dart';

// FoodCoach
export 'src/foodcoach/entities/meal_evaluation.dart';
export 'src/foodcoach/repositories/i_foodcoach_repository.dart';

// Sync
export 'src/sync/i_sync_service.dart';
export 'src/sync/sync_data_use_case.dart';
