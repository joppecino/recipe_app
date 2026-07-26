import 'dart:convert';

import 'package:flutter/material.dart';

import '../../database/database.dart';

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

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingredients = _parseList(recipe.ingredients);
    final instructions = _parseList(recipe.instructions);
    final tags = _parseTags(recipe.tags);

    return Scaffold(
      appBar: AppBar(title: Text(recipe.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            if (recipe.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  recipe.imageUrl!,
                  width: double.infinity,
                  height: 200,
                  fit: .cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 200,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            if (recipe.imageUrl != null) const SizedBox(height: 16),
            if (tags.isNotEmpty) ...[
              Wrap(
                spacing: 4,
                children: tags.map((tag) => Chip(
                  label: Text(tag),
                  materialTapTargetSize: .shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 16),
            ],
            Text('Ingredients', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: .start,
                  children: ingredients
                      .map((ing) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: .start,
                              children: [
                                const Text('\u2022  '),
                                Expanded(child: Text(ing)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Instructions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: .start,
                  children: instructions
                      .asMap()
                      .entries
                      .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              crossAxisAlignment: .start,
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
              SelectableText(recipe.sourceUrl!,
                  style: TextStyle(color: theme.colorScheme.primary)),
            ],
          ],
        ),
      ),
    );
  }
}
