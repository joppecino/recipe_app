import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

final searchBottomProvider = StateNotifierProvider<SearchBottomNotifier, bool>((ref) => SearchBottomNotifier());

class SearchBottomNotifier extends StateNotifier<bool> {
  SearchBottomNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('search_bottom') ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('search_bottom', value);
  }
}
