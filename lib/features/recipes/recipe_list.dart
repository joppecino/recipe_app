import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/providers.dart';
import '../import/import_recipe.dart';
import 'recipe_card.dart';

String normalizeTag(String tag) {
  if (tag.isEmpty) return tag;
  return tag[0].toUpperCase() + tag.substring(1).toLowerCase();
}

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  Set<String> _selectedTags = {};
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Set<String> _collectTags(List<Recipe> recipes) {
    final tags = <String>{};
    for (final recipe in recipes) {
      if (recipe.tags == null) continue;
      try {
        final decoded = jsonDecode(recipe.tags!);
        for (final tag in decoded as List) {
          tags.add(normalizeTag(tag.toString()));
        }
      } catch (_) {}
    }
    return tags;
  }

  bool _matchesSearch(Recipe recipe) {
    if (_searchQuery.isEmpty) return true;
    return recipe.title
        .toLowerCase()
        .contains(_searchQuery.toLowerCase());
  }

  bool _matchesTags(Recipe recipe) {
    if (_selectedTags.isEmpty) return true;
    if (recipe.tags == null) return false;
    try {
      final decoded = jsonDecode(recipe.tags!);
      final recipeTags = (decoded as List).map((e) => normalizeTag(e.toString())).toSet();
      return _selectedTags.intersection(recipeTags).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _openFilterSheet(List<Recipe> recipes) {
    final allTags = _collectTags(recipes).toList()..sort();

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        var localSelection = Set<String>.from(_selectedTags);

        return StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filter by tags',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (allTags.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No tags found. Add tags when importing recipes.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...allTags.map((tag) => CheckboxListTile(
                          title: Text(tag),
                          value: localSelection.contains(tag),
                          onChanged: (checked) {
                            setSheetState(() {
                              if (checked == true) {
                                localSelection.add(tag);
                              } else {
                                localSelection.remove(tag);
                              }
                            });
                          },
                        )),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _selectedTags = localSelection);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Apply Filter'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final hasActiveFilter = _searchQuery.isNotEmpty || _selectedTags.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _debounceTimer?.cancel();
                      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) setState(() => _searchQuery = value);
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search recipes...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _debounceTimer?.cancel();
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 48,
                    child: IconButton(
                      onPressed: () async {
                      final recipes = await db.getAllRecipes();
                      if (mounted) _openFilterSheet(recipes);
                    },
                      icon: Icon(
                        Icons.filter_list,
                        color: _selectedTags.isNotEmpty
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Recipe>>(
              future: db.getAllRecipes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final allRecipes = snapshot.data ?? [];
                final filtered = allRecipes.where(
                    (r) => _matchesSearch(r) && _matchesTags(r));

                if (allRecipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No recipes yet',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  );
                }

                if (filtered.isEmpty && hasActiveFilter) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No recipes match your search',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _selectedTags = {};
                            });
                          },
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) =>
                      RecipeCard(recipe: filtered.elementAt(index)),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
                builder: (_) => const ImportRecipeScreen()),
          );
          if (saved == true) setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('Import Recipe'),
      ),
    );
  }
}
