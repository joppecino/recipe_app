import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/database.dart';
import '../../providers/providers.dart';
import '../import/import_recipe.dart';
import 'image_viewer.dart';

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

double _parseQuantity(String ingredient) {
  final trimmed = ingredient.trim();
  final match = RegExp(r'^([\d]+(?:\s*[\d]+\/\s*[\d]+)?(?:\s*[\/\d.])*|[\d.]+|\u00BC|\u00BD|\u00BE|[0-9])')
      .matchAsPrefix(trimmed);
  if (match == null) return 0;
  final str = match.group(0)!.trim();
  if (str.isEmpty) return 0;

  const unicodeFractions = {
    '\u00BC': 0.25,
    '\u00BD': 0.5,
    '\u00BE': 0.75,
  };
  if (unicodeFractions.containsKey(str)) return unicodeFractions[str]!;

  final parts = str.split(RegExp(r'\s+'));
  double value = 0;
  for (final part in parts) {
    if (part.contains('/')) {
      final fracParts = part.split('/');
      value += double.tryParse(fracParts[0])! / double.tryParse(fracParts[1])!;
    } else {
      value += double.tryParse(part) ?? 0;
    }
  }
  return value;
}

String _scaleIngredient(String ingredient, double factor) {
  final trimmed = ingredient.trim();
  final match = RegExp(r'^([\d]+(?:\s*[\d]+\/\s*[\d]+)?(?:\s*[\/\d.])*|[\d.]+|\u00BC|\u00BD|\u00BE|[0-9])\s*')
      .matchAsPrefix(trimmed);
  if (match == null) return ingredient;
  final original = _parseQuantity(ingredient);
  if (original == 0) return ingredient;
  final scaled = original * factor;

  String scaledStr;
  if (scaled == scaled.roundToDouble()) {
    scaledStr = scaled.toInt().toString();
  } else {
    scaledStr = scaled.toStringAsFixed(1);
  }

  return '$scaledStr${ingredient.substring(match.end)}';
}

String _formatYield(String raw) {
  final num = double.tryParse(raw.trim());
  if (num != null && num == num.roundToDouble()) {
    return '${num.toInt()} portions';
  }
  return '$raw portions';
}

class RecipeDetailScreen extends ConsumerStatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  ConsumerState<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends ConsumerState<RecipeDetailScreen> {
  late int _baseYield;
  late int _currentYield;

  @override
  void initState() {
    super.initState();
    final raw = widget.recipe.recipeYield;
    _baseYield = (double.tryParse(raw ?? '') ?? 0).round();
    if (_baseYield < 1) _baseYield = 1;
    _currentYield = _baseYield;
  }

  double get _scaleFactor => _currentYield / _baseYield;

  Future<void> _handleEdit(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ImportRecipeScreen(existingRecipe: widget.recipe),
      ),
    );
    if (saved == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Are you sure you want to delete "${widget.recipe.title}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(databaseProvider).deleteRecipe(widget.recipe.id);
      if (context.mounted) Navigator.of(context).pop(true);
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleEdit(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleDelete(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recipe = widget.recipe;
    final ingredients = _parseList(recipe.ingredients);
    final instructions = _parseList(recipe.instructions);
    final tags = _parseTags(recipe.tags);

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.imageUrl != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        FullScreenImage(imageUrl: recipe.imageUrl!),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                        height: 200,
                        color: theme
                            .colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      Image.network(
                        recipe.imageUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 200,
                          color:
                              theme.colorScheme.surfaceContainerHighest,
                          child:
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (recipe.imageUrl != null) const SizedBox(height: 16),
            if (tags.isNotEmpty) ...[
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: tags.map((tag) => Chip(
                  label: Text(tag),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (recipe.description != null && recipe.description!.isNotEmpty) ...[
              Text(recipe.description!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Text('Ingredients', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (recipe.recipeYield != null &&
                    recipe.recipeYield!.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _currentYield > 1
                        ? () => setState(() => _currentYield--)
                        : null,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    _formatYield('$_currentYield'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _currentYield++),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: ingredients
                      .map((ing) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('\u2022  '),
                                Expanded(
                                  child: Text(
                                    _scaleFactor != 1
                                        ? _scaleIngredient(ing, _scaleFactor)
                                        : ing,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Instructions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: instructions
                      .asMap()
                      .entries
                      .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '${entry.key + 1}.',
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                                Expanded(child: Text(entry.value)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            if (recipe.sourceUrl != null) ...[
              const SizedBox(height: 16),
              Text('Source', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => launchUrl(Uri.parse(recipe.sourceUrl!),
                    mode: LaunchMode.externalApplication),
                child: Text(recipe.sourceUrl!,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    )),
              ),
              const SizedBox(height: 32),
            ],
          ],
        ),
      ),
      ),
    );
  }
}
