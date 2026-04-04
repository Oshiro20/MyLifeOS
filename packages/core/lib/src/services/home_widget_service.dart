import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Servicio para gestionar el widget de home screen.
/// Muestra información resumen de los módulos principales.
class HomeWidgetService {
  static const String _groupId = 'group.com.mylifeos.personal.widget';
  
  /// IDs de las vistas del widget
  static const String outfitOfDay = 'widget_outfit_of_day';
  static const String suggestedRecipe = 'widget_suggested_recipe';
  static const String financeBalance = 'widget_finance_balance';
  static const String mealScore = 'widget_meal_score';

  /// Inicializa el widget de home screen.
  static Future<void> initialize() async {
    debugPrint('🏠 [HomeWidget] Inicializando widget...');
    // La configuración específica de plataforma se hace en Android/iOS nativo
  }

  /// Actualiza el widget con datos resumen.
  /// Llamar periódicamente o cuando cambien datos importantes.
  static Future<void> updateWidget({
    String? outfitOfDay,
    String? suggestedRecipe,
    String? financeBalance,
    String? mealScore,
  }) async {
    try {
      debugPrint('🔄 [HomeWidget] Actualizando widget...');

      if (outfitOfDay != null) {
        await HomeWidget.saveWidgetData<String>(outfitOfDay, _groupId);
      }

      if (suggestedRecipe != null) {
        await HomeWidget.saveWidgetData<String>(suggestedRecipe, _groupId);
      }

      if (financeBalance != null) {
        await HomeWidget.saveWidgetData<String>(financeBalance, _groupId);
      }

      if (mealScore != null) {
        await HomeWidget.saveWidgetData<String>(mealScore, _groupId);
      }

      // Actualizar el widget en pantalla
      await HomeWidget.updateWidget(
        name: 'MyLifeOSWidget',
        androidName: 'MyLifeOSWidget',
        iOSName: 'MyLifeOSWidget',
        qualifiedAndroidName: 'com.mylifeos.personal.MyLifeOSWidget',
      );

      debugPrint('✅ [HomeWidget] Widget actualizado exitosamente');
    } catch (e) {
      debugPrint('❌ [HomeWidget] Error al actualizar widget: $e');
    }
  }

  /// Establece el outfit del día en el widget.
  static Future<void> setOutfitOfDay(String outfitName) async {
    await HomeWidget.saveWidgetData<String>('outfit_of_day', outfitName);
    await _update();
  }

  /// Establece la receta sugerida en el widget.
  static Future<void> setSuggestedRecipe(String recipeName) async {
    await HomeWidget.saveWidgetData<String>('suggested_recipe', recipeName);
    await _update();
  }

  /// Establece el balance financiero en el widget.
  static Future<void> setFinanceBalance(String balance) async {
    await HomeWidget.saveWidgetData<String>('finance_balance', balance);
    await _update();
  }

  /// Establece el score de comida en el widget.
  static Future<void> setMealScore(String score) async {
    await HomeWidget.saveWidgetData<String>('meal_score', score);
    await _update();
  }

  /// Actualiza el widget con todos los datos guardados.
  static Future<void> _update() async {
    await HomeWidget.updateWidget(
      name: 'MyLifeOSWidget',
      androidName: 'MyLifeOSWidget',
      iOSName: 'MyLifeOSWidget',
      qualifiedAndroidName: 'com.mylifeos.personal.MyLifeOSWidget',
    );
  }

  /// Configura el callback para cuando el usuario toca el widget.
  static Future<void> setWidgetTapCallback() async {
    HomeWidget.widgetClicked.listen((uri) {
      debugPrint('👆 [HomeWidget] Widget tocado: $uri');
      // Aquí se puede navegar a una pantalla específica
      // Esto requiere integración con el router de la app
    });
  }
}
