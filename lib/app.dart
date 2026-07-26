import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/recipes/recipe_list.dart';
import 'providers/providers.dart';

class RecipeApp extends ConsumerWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Recipe App',
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const RecipeListScreen(),
    );
  }
}
