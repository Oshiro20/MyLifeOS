import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for shopping list UI state (not data - data comes from recipesProvider)
/// This provider is used for UI-only state like filtering, search, etc.
class ShoppingListState {
  final String searchQuery;
  final String? filterCategory;

  const ShoppingListState({
    this.searchQuery = '',
    this.filterCategory,
  });

  ShoppingListState copyWith({
    String? searchQuery,
    String? filterCategory,
  }) =>
      ShoppingListState(
        searchQuery: searchQuery ?? this.searchQuery,
        filterCategory: filterCategory ?? this.filterCategory,
      );
}

class ShoppingListNotifier extends Notifier<ShoppingListState> {
  @override
  ShoppingListState build() {
    return const ShoppingListState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterCategory(String? category) {
    state = state.copyWith(filterCategory: category);
  }

  void clearFilters() {
    state = const ShoppingListState();
  }
}

final shoppingListProvider =
    NotifierProvider<ShoppingListNotifier, ShoppingListState>(
        ShoppingListNotifier.new);
