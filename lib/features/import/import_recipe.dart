import 'dart:convert';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/providers.dart';
import '../../services/parser_service.dart';
import '../recipes/image_viewer.dart';

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
  final _descriptionController = TextEditingController();
  final _yieldController = TextEditingController();
  final _ingredientControllers = <TextEditingController>[];
  final _instructionControllers = <TextEditingController>[];
  final _tagControllers = <TextEditingController>[];
  final _tagBump = ValueNotifier<int>(0);
  final _ingredientBump = ValueNotifier<int>(0);
  final _instructionBump = ValueNotifier<int>(0);

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
      if (existing.description != null) {
        _descriptionController.text = existing.description!;
      }
      if (existing.recipeYield != null) {
        _yieldController.text = existing.recipeYield!;
      }
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
        description: existing.description,
        yield: existing.recipeYield,
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
    _descriptionController.dispose();
    _yieldController.dispose();
    for (final c in _ingredientControllers) {
      c.dispose();
    }
    for (final c in _instructionControllers) {
      c.dispose();
    }
    for (final c in _tagControllers) {
      c.dispose();
    }
    _tagBump.dispose();
    _ingredientBump.dispose();
    _instructionBump.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Url missing.');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = 'URL is invalid');
      return;
    }

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
        _descriptionController.text = result.description ?? '';
        _yieldController.text = result.yield ?? '';
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
    _ingredientControllers.add(TextEditingController());
    _ingredientBump.value++;
  }

  void _removeIngredient(int index) {
    _ingredientControllers[index].dispose();
    _ingredientControllers.removeAt(index);
    _ingredientBump.value++;
  }

  void _addInstruction() {
    _instructionControllers.add(TextEditingController());
    _instructionBump.value++;
  }

  void _removeInstruction(int index) {
    _instructionControllers[index].dispose();
    _instructionControllers.removeAt(index);
    _instructionBump.value++;
  }

  void _addTag() {
    _tagControllers.add(TextEditingController());
    _tagBump.value++;
  }

  void _removeTag(int index) {
    _tagControllers[index].dispose();
    _tagControllers.removeAt(index);
    _tagBump.value++;
  }

  void _reorderTag(int oldIndex, int newIndex) {
    final item = _tagControllers.removeAt(oldIndex);
    _tagControllers.insert(newIndex, item);
    _tagBump.value++;
  }

  void _reorderIngredient(int oldIndex, int newIndex) {
    final item = _ingredientControllers.removeAt(oldIndex);
    _ingredientControllers.insert(newIndex, item);
    _ingredientBump.value++;
  }

  void _reorderInstruction(int oldIndex, int newIndex) {
    final item = _instructionControllers.removeAt(oldIndex);
    _instructionControllers.insert(newIndex, item);
    _instructionBump.value++;
  }

  Future<void> _editYield() async {
    final controller = TextEditingController(text: _yieldController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yield / Servings'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'e.g. 4 servings',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && mounted) {
      setState(() => _yieldController.text = result);
    }
  }

  bool get _isClean {
    if (_dirtyAfterFetch) return false;
    if (_original == null) return true;
    if (_titleController.text != _original!.title) return false;
    if (_descriptionController.text != (_original!.description ?? '')) return false;
    if (_yieldController.text != (_original!.yield ?? '')) return false;
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
          description: Value<String?>(_descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : null),
          recipeYield: Value<String?>(_yieldController.text.isNotEmpty
              ? _yieldController.text
              : null),
          ingredients: ingredients,
          instructions: instructions,
          tags: Value<String?>(tags),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } else {
      final recipe = RecipesCompanion.insert(
        title: _titleController.text,
        description: Value<String?>(_descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null),
        recipeYield: Value<String?>(_yieldController.text.isNotEmpty
            ? _yieldController.text
            : null),
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
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: AnimatedSwitcher(
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
                              GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImage(
                                        imageUrl: _original!.imageUrl!),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 200,
                                        color: theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                        child: const Center(
                                          child:
                                              CircularProgressIndicator(),
                                        ),
                                      ),
                                      Image.network(
                                        _original!.imageUrl!,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            Container(
                                          height: 200,
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Center(
                                            child:
                                                Icon(Icons.broken_image),
                                          ),
                                        ),
                                      ),
                                    ],
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
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: _titleController,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Description',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _descriptionController,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: 'Description',
                                      ),
                                      minLines: 3,
                                      maxLines: 6,
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
                                    Text(
                                      'Tags',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 12),
                                    ValueListenableBuilder<int>(
                                      valueListenable: _tagBump,
                                      builder: (context, _, _) => Column(
                                        children: [
                                          ReorderableListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            buildDefaultDragHandles: false,
                                            itemCount:
                                                _tagControllers.length,
                                            onReorderItem: _reorderTag,
                                            proxyDecorator:
                                                (child, index, animation) =>
                                                    Material(
                                              elevation: 2,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: child,
                                            ),
                                            itemBuilder: (context, index) {
                                              final controller =
                                                  _tagControllers[index];
                                              return RepaintBoundary(
                                                key: ValueKey(controller),
                                                child: Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Row(
                                                  children: [
                                                    ReorderableDragStartListener(
                                                      index: index,
                                                      child: const Icon(
                                                        Icons.drag_handle,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller:
                                                            controller,
                                                        decoration:
                                                            InputDecoration(
                                                          border:
                                                              const OutlineInputBorder(),
                                                          hintText:
                                                              'Tag ${index + 1}',
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () =>
                                                          _removeTag(
                                                              index),
                                                      icon: const Icon(
                                                        Icons
                                                            .remove_circle_outline,
                                                        color:
                                                            Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                ),
                                              );
                                            },
                                          ),
                                          if (_tagControllers.isEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: Text(
                                                'No tags added.',
                                                style: theme
                                                    .textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: theme
                                                      .colorScheme.outline,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: _addTag,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          highlightColor: theme
                                              .colorScheme.primary
                                              .withValues(alpha: 0.08),
                                          splashColor: theme
                                              .colorScheme.primary
                                              .withValues(alpha: 0.12),
                                          child: const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.add_circle_outline,
                                            ),
                                          ),
                                        ),
                                      ],
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
                                    GestureDetector(
                                      onTap: () => _editYield(),
                                      child: Row(
                                        children: [
                                          Text(
                                            'Ingredients',
                                            style:
                                                theme.textTheme.titleSmall,
                                          ),
                                          if (_yieldController
                                              .text.isNotEmpty) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${_yieldController.text})',
                                              style: theme
                                                  .textTheme.titleSmall
                                                  ?.copyWith(
                                                color: theme
                                                    .colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.edit,
                                            size: 14,
                                            color: theme
                                                .colorScheme.outline,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ValueListenableBuilder<int>(
                                      valueListenable: _ingredientBump,
                                      builder: (context, _, _) => Column(
                                        children: [
                                          ReorderableListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            buildDefaultDragHandles: false,
                                            itemCount:
                                                _ingredientControllers.length,
                                            onReorderItem:
                                                _reorderIngredient,
                                            proxyDecorator:
                                                (child, index, animation) =>
                                                    Material(
                                              elevation: 2,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: child,
                                            ),
                                            itemBuilder:
                                                (context, index) {
                                              final controller =
                                                  _ingredientControllers[
                                                      index];
                                              return RepaintBoundary(
                                                key:
                                                    ValueKey(controller),
                                                child: Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Row(
                                                  children: [
                                                    ReorderableDragStartListener(
                                                      index: index,
                                                      child:
                                                          const Icon(
                                                        Icons
                                                            .drag_handle,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        width: 8),
                                                    Expanded(
                                                      child: TextField(
                                                        controller:
                                                            controller,
                                                        decoration:
                                                            InputDecoration(
                                                          border:
                                                              const OutlineInputBorder(),
                                                          hintText:
                                                              'Ingredient ${index + 1}',
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () =>
                                                          _removeIngredient(
                                                              index),
                                                      icon: const Icon(
                                                        Icons
                                                            .remove_circle_outline,
                                                        color:
                                                            Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: _addIngredient,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          highlightColor: theme
                                              .colorScheme.primary
                                              .withValues(alpha: 0.08),
                                          splashColor: theme
                                              .colorScheme.primary
                                              .withValues(alpha: 0.12),
                                          child: const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.add_circle_outline,
                                            ),
                                          ),
                                        ),
                                      ],
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
                                    Text(
                                      'Instructions',
                                      style: theme.textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 12),
                                    ValueListenableBuilder<int>(
                                      valueListenable: _instructionBump,
                                      builder: (context, _, _) => Column(
                                        children: [
                                          ReorderableListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            buildDefaultDragHandles: false,
                                            itemCount:
                                                _instructionControllers
                                                    .length,
                                            onReorderItem:
                                                _reorderInstruction,
                                            proxyDecorator:
                                                (child, index, animation) =>
                                                    Material(
                                              elevation: 2,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: child,
                                            ),
                                            itemBuilder:
                                                (context, index) {
                                              final controller =
                                                  _instructionControllers[
                                                      index];
                                              return RepaintBoundary(
                                                key:
                                                    ValueKey(controller),
                                                child: Padding(
                                                padding:
                                                    const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .center,
                                                  children: [
                                                    ReorderableDragStartListener(
                                                      index: index,
                                                      child:
                                                          const Icon(
                                                        Icons
                                                            .drag_handle,
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                        width: 8),
                                                    SizedBox(
                                                      width: 28,
                                                      child: Text(
                                                        '${index + 1}.',
                                                        style: theme
                                                            .textTheme
                                                            .bodyLarge,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: TextField(
                                                        controller:
                                                            controller,
                                                        decoration:
                                                            InputDecoration(
                                                          border:
                                                              const OutlineInputBorder(),
                                                          hintText:
                                                              'Step ${index + 1}',
                                                        ),
                                                        maxLines: 3,
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () =>
                                                          _removeInstruction(
                                                              index),
                                                      icon: const Icon(
                                                        Icons
                                                            .remove_circle_outline,
                                                        color:
                                                            Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: _addInstruction,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          highlightColor: theme
                                              .colorScheme.primary
                                              .withValues(alpha: 0.08),
                                          splashColor: theme
                                              .colorScheme.primary
                                              .withValues(alpha: 0.12),
                                          child: const Padding(
                                            padding: EdgeInsets.all(8),
                                            child: Icon(
                                              Icons.add_circle_outline,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
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
                            hintText: 'Paste your Recipe URL',
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
                              _loading ? 'Fetching' : 'Fetch Recipe',
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
