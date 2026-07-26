import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/providers.dart';
import '../../services/parser_service.dart';

String normalizeTag(String tag) {
  if (tag.isEmpty) return tag;
  return tag[0].toUpperCase() + tag.substring(1).toLowerCase();
}

List<String> _parseList(String json) {
  final decoded = jsonDecode(json);
  return (decoded as List).cast<String>();
}

List<String> _parseTags(String? json) {
  if (json == null) return [];
  try {
    return _parseList(json);
  } catch (_) {
    return [];
  }
}

class ImportRecipeScreen extends ConsumerStatefulWidget {
  final Recipe? existingRecipe;

  const ImportRecipeScreen({super.key, this.existingRecipe});

  @override
  ConsumerState<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

class _ImportRecipeScreenState extends ConsumerState<ImportRecipeScreen> {
  final _urlController = TextEditingController();
  final _scraper = ScraperService();
  final _titleController = TextEditingController();
  final _ingredientControllers = <TextEditingController>[];
  final _instructionControllers = <TextEditingController>[];
  final _tagControllers = <TextEditingController>[];

  bool _loading = false;
  bool _dirtyAfterFetch = false;
  String? _error;
  ParsedRecipe? _original;
  bool get _isEditing => widget.existingRecipe != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingRecipe;
    if (existing != null) {
      _titleController.text = existing.title;
      if (existing.sourceUrl != null) {
        _urlController.text = existing.sourceUrl!;
      }
      _ingredientControllers.addAll(
        _parseList(
          existing.ingredients,
        ).map((e) => TextEditingController(text: e)),
      );
      _instructionControllers.addAll(
        _parseList(
          existing.instructions,
        ).map((e) => TextEditingController(text: e)),
      );
      final existingTags = _parseTags(existing.tags);
      _tagControllers.addAll(
        existingTags.map((e) => TextEditingController(text: normalizeTag(e))),
      );
      _original = ParsedRecipe(
        title: existing.title,
        ingredients: _parseList(existing.ingredients),
        instructions: _parseList(existing.instructions),
        imageUrl: existing.imageUrl,
        tags: existingTags.map(normalizeTag).toList(),
      );
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    for (final c in _ingredientControllers) {
      c.dispose();
    }
    for (final c in _instructionControllers) {
      c.dispose();
    }
    for (final c in _tagControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _scraper.scrape(_urlController.text);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _error = "Sorry, unable to find a recipe.";
          _loading = false;
        });
        return;
      }

      setState(() {
        _original = result;
        _dirtyAfterFetch = true;
        _titleController.text = result.title;
        for (final c in _ingredientControllers) {
          c.dispose();
        }
        _ingredientControllers
          ..clear()
          ..addAll(
            result.ingredients.map((e) => TextEditingController(text: e)),
          );
        for (final c in _instructionControllers) {
          c.dispose();
        }
        _instructionControllers
          ..clear()
          ..addAll(
            result.instructions.map((e) => TextEditingController(text: e)),
          );
        for (final c in _tagControllers) {
          c.dispose();
        }
        _tagControllers
          ..clear()
          ..addAll(
            result.tags.map((e) => TextEditingController(text: normalizeTag(e))),
          );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to fetch: $e';
        _loading = false;
      });
    }
  }

  void _addIngredient() {
    setState(() {
      _ingredientControllers.add(TextEditingController());
    });
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredientControllers[index].dispose();
      _ingredientControllers.removeAt(index);
    });
  }

  void _addInstruction() {
    setState(() {
      _instructionControllers.add(TextEditingController());
    });
  }

  void _removeInstruction(int index) {
    setState(() {
      _instructionControllers[index].dispose();
      _instructionControllers.removeAt(index);
    });
  }

  void _addTag() {
    setState(() {
      _tagControllers.add(TextEditingController());
    });
  }

  void _removeTag(int index) {
    setState(() {
      _tagControllers[index].dispose();
      _tagControllers.removeAt(index);
    });
  }

  bool get _isClean {
    if (_dirtyAfterFetch) return false;
    if (_original == null) return true;
    if (_titleController.text != _original!.title) return false;
    if (_ingredientControllers.length != _original!.ingredients.length) {
      return false;
    }
    for (var i = 0; i < _ingredientControllers.length; i++) {
      if (_ingredientControllers[i].text != _original!.ingredients[i]) {
        return false;
      }
    }
    if (_instructionControllers.length != _original!.instructions.length) {
      return false;
    }
    for (var i = 0; i < _instructionControllers.length; i++) {
      if (_instructionControllers[i].text != _original!.instructions[i]) {
        return false;
      }
    }
    if (_tagControllers.length != _original!.tags.length) {
      return false;
    }
    for (var i = 0; i < _tagControllers.length; i++) {
      if (_tagControllers[i].text != _original!.tags[i]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final ingredients = jsonEncode(
      _ingredientControllers.map((c) => c.text).toList(),
    );
    final instructions = jsonEncode(
      _instructionControllers.map((c) => c.text).toList(),
    );

    final tags = jsonEncode(
      _tagControllers
          .map((c) => normalizeTag(c.text))
          .where((t) => t.isNotEmpty)
          .toList()
          .toSet()
          .toList(),
    );

    if (_isEditing) {
      final existing = widget.existingRecipe!;
      db.updateRecipe(
        existing.copyWith(
          title: _titleController.text,
          ingredients: ingredients,
          instructions: instructions,
          tags: Value<String?>(tags),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } else {
      final recipe = RecipesCompanion.insert(
        title: _titleController.text,
        ingredients: ingredients,
        instructions: instructions,
        tags: Value<String?>(tags),
        imageUrl: _original?.imageUrl != null
            ? Value(_original!.imageUrl)
            : const Value.absent(),
        sourceUrl: _urlController.text.isNotEmpty
            ? Value(_urlController.text)
            : const Value.absent(),
        createdAt: DateTime.now(),
      );

      await db.insertRecipe(recipe);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (_isClean) return true;
    if (!mounted) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes. Do you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final hasRecipe = _original != null;
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Recipe' : 'Import Recipe'),
          leading: BackButton(
            onPressed: () async {
              final shouldPop = await _confirmDiscard();
              if (shouldPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.25, 0),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: hasRecipe || _isEditing
              ? Column(
                  key: const ValueKey('form'),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_original?.imageUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  _original!.imageUrl!,
                                  width: double.infinity,
                                  height: 200,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    height: 200,
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: const Center(
                                      child: Icon(Icons.broken_image),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Title',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _titleController,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Tags',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        IconButton(
                                          onPressed: _addTag,
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ..._tagControllers.asMap().entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: entry.value,
                                                decoration: InputDecoration(
                                                  border:
                                                      const OutlineInputBorder(),
                                                  hintText:
                                                      'Tag ${entry.key + 1}',
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _removeTag(entry.key),
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (_tagControllers.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          'No tags added.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.outline,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Ingredients',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        IconButton(
                                          onPressed: _addIngredient,
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ..._ingredientControllers.asMap().entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: entry.value,
                                                decoration: InputDecoration(
                                                  border:
                                                      const OutlineInputBorder(),
                                                  hintText:
                                                      'Ingredient ${entry.key + 1}',
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _removeIngredient(entry.key),
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Instructions',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                        IconButton(
                                          onPressed: _addInstruction,
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                        ),
                                      ],
                                    ),
                                    ..._instructionControllers.asMap().entries.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              child: Text(
                                                '${entry.key + 1}.',
                                                style:
                                                    theme.textTheme.bodyLarge,
                                              ),
                                            ),
                                            Expanded(
                                              child: TextField(
                                                controller: entry.value,
                                                decoration: InputDecoration(
                                                  border:
                                                      const OutlineInputBorder(),
                                                  hintText:
                                                      'Step ${entry.key + 1}',
                                                ),
                                                maxLines: 3,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  _removeInstruction(entry.key),
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Center(
                  key: const ValueKey('url'),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'Paste recipe URL...',
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _fetch,
                            icon: _loading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download),
                            label: Text(
                              _loading ? 'Fetching...' : 'Fetch Recipe',
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        bottomNavigationBar: hasRecipe
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save Recipe'),
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
