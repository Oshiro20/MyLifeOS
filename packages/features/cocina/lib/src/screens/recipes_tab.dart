import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:domain/src/cocina/entities/recipe.dart';
import 'package:core/core.dart';
import 'package:uuid/uuid.dart';
import '../providers/cocina_providers.dart';

class RecipesTab extends ConsumerWidget with AppFeedback {
  const RecipesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipesProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00C896)));
    }

    if (state.recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 64, color: Colors.white12),
            const SizedBox(height: 12),
            const Text('Sin recetas guardadas',
                style: TextStyle(color: Colors.white38, fontSize: 17)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _showAddRecipeSheet(context, ref),
              icon: const Icon(Icons.add, color: Color(0xFF00C896)),
              label: const Text('Agregar receta',
                  style: TextStyle(color: Color(0xFF00C896))),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: state.recipes.length,
          itemBuilder: (ctx, i) {
            final recipe = state.recipes[i];
            return _RecipeTile(
              recipe: recipe,
              onFavorite: () {
                ref.read(recipesProvider.notifier).toggleFavorite(recipe.id);
                final label = recipe.isFavorite ? 'quitado de' : 'añadido a';
                showInfo(context, '"${recipe.name}" $label favoritos');
              },
              onDelete: () => _confirmDelete(context, ref, recipe),
              onTap: () => _showRecipeDetail(context, recipe),
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'add_recipe',
            backgroundColor: const Color(0xFF00C896),
            onPressed: () => _showAddRecipeSheet(context, ref),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Recipe recipe) async {
    final confirmed = await showConfirmDelete(context,
        itemName: recipe.name,
        subtitle: '${recipe.durationMinutes} min · ${recipe.ingredients.length} ingredientes');
    if (!confirmed) return;
    await ref.read(recipesProvider.notifier).deleteRecipe(recipe.id);
    if (context.mounted) showSuccess(context, '"${recipe.name}" eliminada.');
  }

  void _showAddRecipeSheet(BuildContext ctx, WidgetRef ref) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRecipeSheet(
        onSave: (r) async {
          await ref.read(recipesProvider.notifier).saveRecipe(r);
          if (ctx.mounted) showSuccess(ctx, '"${r.name}" guardada ✓');
        },
      ),
    );
  }

  void _showRecipeDetail(BuildContext ctx, Recipe recipe) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _RecipeDetailSheet(recipe: recipe),
    );
  }
}

// ── Tile de receta ───────────────────────────────────────────────────────────

class _RecipeTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onFavorite;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _RecipeTile({
    required this.recipe,
    required this.onFavorite,
    required this.onDelete,
    required this.onTap,
  });

  static const _goalEmoji = {
    NutritionGoal.loseWeight: '🥗', NutritionGoal.maintain: '⚖️',
    NutritionGoal.gainMuscle: '💪', NutritionGoal.other: '🍽️',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF2A2A40),
            child: Text(_goalEmoji[recipe.goal] ?? '🍽️', style: const TextStyle(fontSize: 22)),
          ),
          title: Text(recipe.name,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${recipe.durationMinutes} min · ${recipe.servings} porciones · ${recipe.ingredients.length} ingredientes',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: recipe.isFavorite ? const Color(0xFFFF4D4D) : Colors.white24, size: 20),
                onPressed: onFavorite,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Detalle de receta ────────────────────────────────────────────────────────

class _RecipeDetailSheet extends StatelessWidget {
  final Recipe recipe;
  const _RecipeDetailSheet({required this.recipe});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        children: [
          Center(child: Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          Text(recipe.name,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.w700)),
          if (recipe.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(recipe.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 14)),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 8, children: [
            _chip(context, '⏱ ${recipe.durationMinutes} min'),
            _chip(context, '👥 ${recipe.servings} porciones'),
            _chip(context, '🍳 ${recipe.ingredients.length} ingredientes'),
          ]),
          if (recipe.ingredients.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('INGREDIENTES',
                style: TextStyle(color: Colors.white38, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            ...recipe.ingredients.map((ing) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF00C896)),
                const SizedBox(width: 10),
                Text('${ing.ingredientName}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
                const Spacer(),
                Text('${ing.quantity} ${ing.unit}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38), fontSize: 12)),
              ]),
            )),
          ],
          if (recipe.instructions.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('INSTRUCCIONES',
                style: TextStyle(color: Colors.white38, fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            ...recipe.instructions.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 24, height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C896).withAlpha(40),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('${e.key + 1}',
                      style: const TextStyle(color: Color(0xFF00C896), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14))),
              ]),
            )),
          ],
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF2A2A40), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54), fontSize: 12)),
  );
}

// ── Formulario de receta con ingredientes ────────────────────────────────────

class _AddRecipeSheet extends StatefulWidget {
  final Future<void> Function(Recipe) onSave;
  const _AddRecipeSheet({required this.onSave});
  @override
  State<_AddRecipeSheet> createState() => _AddRecipeSheetState();
}

class _AddRecipeSheetState extends State<_AddRecipeSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durCtrl = TextEditingController(text: '30');
  final _srvCtrl = TextEditingController(text: '2');
  NutritionGoal _goal = NutritionGoal.maintain;
  String? _nameError;
  String? _durError;
  bool _saving = false;

  // Ingredientes dinámicos
  final List<_IngEntry> _ingredients = [];
  // Instrucciones dinámicas
  final List<TextEditingController> _instructions = [];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, controller) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ListView(
          controller: controller,
          children: [
            Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const Text('Nueva receta',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _field(_nameCtrl, 'Nombre de la receta', Icons.edit_outlined,
                errorText: _nameError, onChanged: (_) => setState(() => _nameError = null)),
            const SizedBox(height: 8),
            _field(_descCtrl, 'Descripción (opcional)', Icons.notes_outlined),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(_durCtrl, 'Minutos', Icons.timer_outlined,
                  keyboardType: TextInputType.number, errorText: _durError,
                  onChanged: (_) => setState(() => _durError = null))),
              const SizedBox(width: 8),
              Expanded(child: _field(_srvCtrl, 'Porciones', Icons.people_outline,
                  keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 8),
            DropdownButtonFormField<NutritionGoal>(
              value: _goal,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: _deco('Objetivo nutricional', Icons.flag_outlined),
              items: const [
                DropdownMenuItem(value: NutritionGoal.loseWeight,
                    child: Text('🥗 Adelgazar', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: NutritionGoal.maintain,
                    child: Text('⚖️ Mantener', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: NutritionGoal.gainMuscle,
                    child: Text('💪 Ganar músculo', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: NutritionGoal.other,
                    child: Text('🍽️ Otro', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _goal = v!),
            ),

            // ── Sección Ingredientes ────────────────────────────────────────
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.restaurant_outlined, color: Color(0xFF00C896), size: 18),
              const SizedBox(width: 8),
              const Text('Ingredientes',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF00C896)),
                label: const Text('Agregar', style: TextStyle(color: Color(0xFF00C896), fontSize: 12)),
              ),
            ]),
            if (_ingredients.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Agrega ingredientes para mejorar las sugerencias',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            ..._ingredients.asMap().entries.map((e) => _IngredientRow(
              entry: e.value,
              onRemove: () => setState(() => _ingredients.removeAt(e.key)),
            )),

            // ── Sección Instrucciones ───────────────────────────────────────
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.format_list_numbered, color: Color(0xFF00C896), size: 18),
              const SizedBox(width: 8),
              const Text('Instrucciones',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _instructions.add(TextEditingController())),
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF00C896)),
                label: const Text('Agregar', style: TextStyle(color: Color(0xFF00C896), fontSize: 12)),
              ),
            ]),
            if (_instructions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Opcional: añade los pasos de preparación',
                    style: TextStyle(color: Colors.white24, fontSize: 12)),
              ),
            ..._instructions.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Container(
                  width: 24, height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C896).withAlpha(40),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text('${e.key + 1}',
                      style: const TextStyle(color: Color(0xFF00C896), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: e.value,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Paso ${e.key + 1}...',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                )),
                GestureDetector(
                  onTap: () => setState(() => _instructions.removeAt(e.key)),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.close, color: Colors.white24, size: 16),
                  ),
                ),
              ]),
            )),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C896),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar receta',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addIngredient() {
    setState(() {
      _ingredients.add(_IngEntry(
        nameCtrl: TextEditingController(),
        qtyCtrl: TextEditingController(text: '1'),
        unit: 'unidad',
      ));
    });
  }

  Future<void> _save() async {
    final nameVal = Validator.recipeName(_nameCtrl.text);
    final durVal = Validator.recipeDuration(int.tryParse(_durCtrl.text));
    final combined = Validator.combine([nameVal, durVal]);

    if (!combined.isValid) {
      setState(() {
        _nameError = nameVal.errorMessage;
        _durError = durVal.errorMessage;
      });
      return;
    }

    // Build ingredient list
    final uuid = const Uuid();
    final ings = _ingredients
        .where((e) => e.nameCtrl.text.trim().isNotEmpty)
        .map((e) => RecipeIngredient(
              id: uuid.v4(),
              recipeId: '',
              ingredientName: e.nameCtrl.text.trim(),
              quantity: double.tryParse(e.qtyCtrl.text) ?? 1,
              unit: e.unit,
            ))
        .toList();

    // Build instructions list
    final steps = _instructions
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _saving = true);
    try {
      await widget.onSave(Recipe(
        id: '', name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        durationMinutes: int.tryParse(_durCtrl.text) ?? 30,
        servings: int.tryParse(_srvCtrl.text) ?? 2,
        goal: _goal,
        ingredients: ings,
        instructions: steps,
        createdAt: DateTime.now(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: const Color(0xFFFF5252)),
        );
      }
    }
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? errorText, void Function(String)? onChanged,
  }) =>
      TextField(
        controller: c, keyboardType: keyboardType, style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        onChanged: onChanged,
        decoration: _deco(hint, icon).copyWith(
          errorText: errorText,
          errorStyle: const TextStyle(color: Color(0xFFFF5252), fontSize: 11),
        ),
      );

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF00C896), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5)),
      );
}

// ── Helpers para ingredientes dinámicos ──────────────────────────────────────

class _IngEntry {
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  String unit;
  _IngEntry({required this.nameCtrl, required this.qtyCtrl, required this.unit});
}

class _IngredientRow extends StatefulWidget {
  final _IngEntry entry;
  final VoidCallback onRemove;
  const _IngredientRow({required this.entry, required this.onRemove});
  @override
  State<_IngredientRow> createState() => _IngredientRowState();
}

class _IngredientRowState extends State<_IngredientRow> {
  static const _units = ['unidad', 'g', 'kg', 'ml', 'L', 'taza', 'cda', 'cdta', 'pizca'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        // Nombre
        Expanded(
          flex: 4,
          child: TextField(
            controller: widget.entry.nameCtrl,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ingrediente',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Cantidad
        Expanded(
          flex: 2,
          child: TextField(
            controller: widget.entry.qtyCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Cant.',
              hintStyle: const TextStyle(color: Colors.white24),
              filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Unidad
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            value: widget.entry.unit,
            dropdownColor: Theme.of(context).cardColor,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
            decoration: InputDecoration(
              filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
            items: _units.map((u) => DropdownMenuItem(value: u,
                child: Text(u, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)))).toList(),
            onChanged: (v) => setState(() => widget.entry.unit = v!),
          ),
        ),
        // Eliminar
        GestureDetector(
          onTap: widget.onRemove,
          child: const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(Icons.close, color: Colors.white24, size: 16),
          ),
        ),
      ]),
    );
  }
}
