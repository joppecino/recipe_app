import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
