import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Recipes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(recipes, recipes.description);
        await m.addColumn(recipes, recipes.recipeYield);
      }
    },
  );

  Future<int> insertRecipe(RecipesCompanion recipe) =>
      into(recipes).insert(recipe);

  Future<List<Recipe>> getAllRecipes() => select(recipes).get();

  Future<Recipe?> getRecipeById(int id) =>
      (select(recipes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<bool> updateRecipe(Recipe recipe) => update(recipes).replace(recipe);

  Future<int> deleteRecipe(int id) =>
      (delete(recipes)..where((t) => t.id.equals(id))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'recipes.db'));
    return NativeDatabase(file);
  });
}
