import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final searchBottom = ref.watch(searchBottomProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: RadioGroup<ThemeMode>(
              groupValue: themeMode,
              onChanged: (v) {
                if (v != null) ref.read(themeModeProvider.notifier).state = v;
              },
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('System Mode'),
                    subtitle: const Text('Follow your device theme'),
                    value: ThemeMode.system,
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: theme.colorScheme.outlineVariant),
                  RadioListTile<ThemeMode>(
                    title: const Text('Light Mode'),
                    value: ThemeMode.light,
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16, color: theme.colorScheme.outlineVariant),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark Mode'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Layout', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('Search bar at bottom'),
              subtitle: const Text('Move search and filter to the bottom of the recipe list'),
              value: searchBottom,
              onChanged: (v) => ref.read(searchBottomProvider.notifier).toggle(v),
            ),
          ),
          const SizedBox(height: 24),
          Text('Data', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('Backup recipes'),
              subtitle: const Text('Export all recipes as a JSON file'),
              onTap: () => _backup(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _backup(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final recipes = await db.getAllRecipes();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'recipes': recipes.map((r) => {
        'title': r.title,
        'description': r.description,
        'recipeYield': r.recipeYield,
        'ingredients': _parseList(r.ingredients),
        'instructions': _parseList(r.instructions),
        'imageUrl': r.imageUrl,
        'tags': _parseTags(r.tags),
        'sourceUrl': r.sourceUrl,
        'createdAt': r.createdAt.toUtc().toIso8601String(),
      }).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);

    if (!context.mounted) return;

    final dir = await getDownloadsDirectory();
    final fileName = 'recipe_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${(dir ?? await getApplicationDocumentsDirectory()).path}/$fileName');

    await file.writeAsString(json);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Backup saved to ${file.path}')),
      );
  }
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
