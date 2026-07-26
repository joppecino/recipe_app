import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/providers.dart';
import '../import/import_recipe.dart';
import '../settings/settings_screen.dart';
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
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Set<String> _selectedTags = {};
  Timer? _debounceTimer;
  List<Recipe> _allRecipes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final db = ref.read(databaseProvider);
    final recipes = await db.getAllRecipes();
    if (mounted) {
      setState(() {
        _allRecipes = recipes;
        _loading = false;
      });
    }
  }

  Future<void> _refreshRecipes() async {
    final db = ref.read(databaseProvider);
    final recipes = await db.getAllRecipes();
    if (mounted) {
      setState(() => _allRecipes = recipes);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _unfocusSearch() => _searchFocusNode.unfocus();

  Widget _buildRecipeList() {
    final filtered = _allRecipes.where(
        (r) => _matchesSearch(r) && _matchesTags(r));

    if (_allRecipes.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshRecipes,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
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
            ),
          ),
        ),
      );
    }

    final hasActiveFilter = _searchQuery.isNotEmpty || _selectedTags.isNotEmpty;

    if (filtered.isEmpty && hasActiveFilter) {
      return RefreshIndicator(
        onRefresh: _refreshRecipes,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.5,
            child: Center(
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
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshRecipes,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final recipe = filtered.elementAt(index);
          return TweenAnimationBuilder<double>(
            key: ValueKey(recipe.id),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(30 * (1 - value), 0),
                child: child,
              ),
            ),
            child: RecipeCard(
              recipe: recipe,
              onChanged: _refreshRecipes,
            ),
          );
        },
      ),
    );
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
    var localSelection = Set<String>.from(_selectedTags);
    var didClear = false;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: allTags.map((tag) => CheckboxListTile(
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
                              )).toList(),
                        ),
                      ),
                    ),
                  if (_selectedTags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          didClear = true;
                          setState(() => _selectedTags = {});
                          Navigator.of(ctx).pop();
                        },
                        child: const Text('Clear filters'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted && !didClear) {
        setState(() => _selectedTags = localSelection);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
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
                      onPressed: () {
                      _unfocusSearch();
                      _openFilterSheet(_allRecipes);
                    },
                      icon: Badge(
                        isLabelVisible: _selectedTags.isNotEmpty,
                        smallSize: 8,
                        child: Icon(
                          Icons.filter_list,
                          color: _selectedTags.isNotEmpty
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildRecipeList(),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          _unfocusSearch();
          final saved = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
                builder: (_) => const ImportRecipeScreen()),
          );
          if (saved == true) _loadRecipes();
        },
        icon: const Icon(Icons.add),
        label: const Text('Import Recipe'),
      ),
    );
  }
}
