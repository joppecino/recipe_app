import 'dart:convert';

import 'package:http/http.dart' as http;

class ParsedRecipe {
  final String title;
  final String? description;
  final String? yield;
  final List<String> ingredients;
  final List<String> instructions;
  final String? imageUrl;
  final List<String> tags;

  ParsedRecipe({
    required this.title,
    this.description,
    this.yield,
    required this.ingredients,
    required this.instructions,
    this.imageUrl,
    this.tags = const [],
  });
}

class ScraperService {
  Future<ParsedRecipe?> scrape(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      url = 'https://$url';
    }

    final response = await http.get(Uri.parse(url));
    final body = response.body;

    final regex = RegExp(
      r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>',
      dotAll: true,
      caseSensitive: false,
    );

    for (final match in regex.allMatches(body)) {
      final jsonStr = match.group(1)!;
      final decoded = jsonDecode(jsonStr);
      final recipes = _extractRecipes(decoded);

      if (recipes.isNotEmpty) {
        return _parseRecipe(recipes.first);
      }
    }

    return null;
  }

  List<Map<String, dynamic>> _extractRecipes(dynamic json) {
    final recipes = <Map<String, dynamic>>[];

    void tryAdd(Map<String, dynamic> item) {
      final type = item['@type'];
      if (type == 'Recipe' || (type is List && type.contains('Recipe'))) {
        recipes.add(item);
      }
    }

    if (json is Map<String, dynamic>) {
      tryAdd(json);
      if (json['@graph'] is List) {
        for (final item in json['@graph']) {
          if (item is Map<String, dynamic>) {
            tryAdd(item);
          }
        }
      }
    } 
    else if (json is List) {
      for (final item in json) {
        if (item is Map<String, dynamic>) {
          tryAdd(item);
        }
      }
    }

    return recipes;
  }

  ParsedRecipe _parseRecipe(Map<String, dynamic> json) {
    final title = json['name'] as String? ?? 'Untitled';

    List<String> ingredients = [];
    final rawIngredients = json['recipeIngredient'];
    if (rawIngredients is List) {
      ingredients = rawIngredients.map((e) => e.toString()).toList();
    } else if (rawIngredients is String) {
      ingredients = [rawIngredients];
    }

    List<String> instructions = [];
    final rawInstructions = json['recipeInstructions'];
    if (rawInstructions is List) {
      for (final item in rawInstructions) {
        if (item is String) {
          instructions.add(item);
        } else if (item is Map<String, dynamic>) {
          instructions
              .add((item['text'] ?? item['name'] ?? '').toString());
        }
      }
    } else if (rawInstructions is String) {
      instructions = [rawInstructions];
    } else if (rawInstructions is Map<String, dynamic>) {
      instructions.add((rawInstructions['text'] ?? '').toString());
    }

    String? imageUrl;
    final rawImage = json['image'];
    if (rawImage is String) {
      imageUrl = rawImage;
    } else if (rawImage is List && rawImage.isNotEmpty) {
      final first = rawImage.first;
      if (first is String) {
        imageUrl = first;
      } else if (first is Map<String, dynamic>) {
        imageUrl = first['url'] as String?;
      }
    } else if (rawImage is Map<String, dynamic>) {
      imageUrl = rawImage['url'] as String?;
    }

    final tags = <String>[];
    final rawCuisine = json['recipeCuisine'];
    if (rawCuisine is String) {
      tags.addAll(rawCuisine.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    } else if (rawCuisine is List) {
      tags.addAll(rawCuisine.map((e) => e.toString()));
    }
    final rawKeywords = json['keywords'];
    if (rawKeywords is String) {
      tags.addAll(rawKeywords.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty));
    } else if (rawKeywords is List) {
      tags.addAll(rawKeywords.map((e) => e.toString()));
    }

    final description = json['description'] as String?;
    String? yield;
    final rawYield = json['recipeYield'];
    if (rawYield is String) {
      yield = rawYield;
    } else if (rawYield is List && rawYield.isNotEmpty) {
      yield = rawYield.first.toString();
    }

    return ParsedRecipe(
      title: title,
      description: description,
      yield: yield,
      ingredients: ingredients,
      instructions: instructions,
      imageUrl: imageUrl,
      tags: tags.toSet().toList(),
    );
  }
}
