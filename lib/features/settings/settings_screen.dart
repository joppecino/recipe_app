import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        ],
      ),
    );
  }
}
