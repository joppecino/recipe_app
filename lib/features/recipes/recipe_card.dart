import 'dart:convert';

import 'package:flutter/material.dart';

import '../../database/database.dart';
import 'recipe_detail.dart';

List<String> _parseList(String json) {
  final decoded = jsonDecode(json);
  return (decoded as List).cast<String>();
}

int _count(String json) {
  try {
    return _parseList(json).length;
  } catch (_) {
    return 0;
  }
}

List<String> _parseTags(String? json) {
  if (json == null) return [];
  try {
    return _parseList(json);
  } catch (_) {
    return [];
  }
}

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback? onChanged;

  const RecipeCard({super.key, required this.recipe, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ingredientCount = _count(recipe.ingredients);
    final instructionCount = _count(recipe.instructions);
    final tags = _parseTags(recipe.tags);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: () async {
          FocusScope.of(context).unfocus();
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(recipe: recipe)),
          );
          if (changed == true) onChanged?.call();
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(recipe.title, style: theme.textTheme.titleMedium),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$ingredientCount ingredients · $instructionCount steps'),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: tags.map((tag) => Chip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                )).toList(),
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
