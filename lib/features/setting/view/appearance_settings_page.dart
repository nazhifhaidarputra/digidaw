import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/app_theme.dart';
import 'package:karbeat/features/setting/models/appearance_settings_state.dart';
import 'package:karbeat/features/setting/services/appearance_asset_service.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(
      appearanceSettingsProvider.select(
        (state) => (
          themeMode: state.themeMode,
          palette: state.colorPalette,
          backgroundPath: state.backgroundImagePath,
          backgroundFit: state.backgroundFit,
          overlay: state.backgroundOverlayOpacity,
          fontPath: state.customFontPath,
          colorThemes: state.colorThemes,
          colorThemeSource: state.colorThemeSource,
          customColorThemePath: state.customColorThemePath,
        ),
      ),
    );
    final notifier = ref.read(appearanceSettingsProvider.notifier);
    final colorThemeSources = [
      ...AppearanceAssetService.bundledColorThemes,
      ?appearance.customColorThemePath,
    ];
    final usesColorTheme = appearance.colorThemeSource != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                key: const ValueKey('settings-page-appearance'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Text(
                'Color theme',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ChoiceChip(
                    key: const ValueKey('color-theme-default'),
                    selected: !usesColorTheme,
                    label: const Text('Default'),
                    onSelected: (_) => unawaited(notifier.setColorTheme(null)),
                  ),
                  for (final source in colorThemeSources)
                    if (appearance.colorThemes[source] case final theme?)
                      ChoiceChip(
                        key: ValueKey('color-theme-$source'),
                        selected: source == appearance.colorThemeSource,
                        avatar: CircleAvatar(backgroundColor: theme.primary),
                        label: Text(theme.name),
                        onSelected: (_) =>
                            unawaited(notifier.setColorTheme(source)),
                      ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                key: const ValueKey('choose-color-theme'),
                onPressed: () => unawaited(notifier.chooseColorThemeFile()),
                icon: const Icon(Icons.palette_outlined),
                label: const Text('Load JSON theme'),
              ),
              if (usesColorTheme) ...[
                const SizedBox(height: 12),
                const Text(
                  'The selected color theme sets its own brightness and colors. Choose Default to use the theme mode and accent palette.',
                ),
              ],
              const SizedBox(height: 28),
              Text(
                'Theme mode',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<AppThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: AppThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('System'),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.light,
                    icon: Icon(Icons.light_mode_outlined),
                    label: Text('Light'),
                  ),
                  ButtonSegment(
                    value: AppThemeMode.dark,
                    icon: Icon(Icons.dark_mode_outlined),
                    label: Text('Dark'),
                  ),
                ],
                selected: {appearance.themeMode},
                onSelectionChanged: usesColorTheme
                    ? null
                    : (selection) {
                        unawaited(notifier.setThemeMode(selection.single));
                      },
              ),
              const SizedBox(height: 28),
              Text(
                'Accent palette',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: AppColorPalette.values
                    .map((palette) {
                      final selected = palette == appearance.palette;
                      return ChoiceChip(
                        key: ValueKey('palette-${palette.name}'),
                        selected: selected,
                        avatar: CircleAvatar(
                          backgroundColor: AppTheme.seedColor(palette),
                        ),
                        label: Text(_paletteLabel(palette)),
                        onSelected: usesColorTheme
                            ? null
                            : (_) {
                                unawaited(notifier.setColorPalette(palette));
                              },
                      );
                    })
                    .toList(growable: false),
              ),
              const SizedBox(height: 32),
              Text(
                'Workspace background',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                appearance.backgroundPath == null
                    ? 'Default background'
                    : _fileName(appearance.backgroundPath!),
                key: const ValueKey('background-file-name'),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('choose-background'),
                    onPressed: () =>
                        unawaited(notifier.chooseBackgroundImage()),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Choose image'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('clear-background'),
                    onPressed: appearance.backgroundPath == null
                        ? null
                        : () => unawaited(notifier.clearBackgroundImage()),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Use default'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AppBackgroundFit>(
                key: const ValueKey('background-fit'),
                initialValue: appearance.backgroundFit,
                decoration: const InputDecoration(labelText: 'Image fit'),
                items: AppBackgroundFit.values
                    .map(
                      (fit) => DropdownMenuItem(
                        value: fit,
                        child: Text(_backgroundFitLabel(fit)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (fit) {
                  if (fit != null) unawaited(notifier.setBackgroundFit(fit));
                },
              ),
              const SizedBox(height: 16),
              Text('Dark overlay: ${(appearance.overlay * 100).round()}%'),
              Slider(
                key: const ValueKey('background-overlay'),
                value: appearance.overlay,
                min: 0,
                max: 0.9,
                divisions: 18,
                label: '${(appearance.overlay * 100).round()}%',
                onChanged: (value) {
                  unawaited(notifier.setBackgroundOverlayOpacity(value));
                },
              ),
              const SizedBox(height: 28),
              Text(
                'Application font',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                appearance.fontPath == null
                    ? 'System font'
                    : _fileName(appearance.fontPath!),
                key: const ValueKey('font-file-name'),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('choose-font'),
                    onPressed: () => unawaited(notifier.chooseCustomFont()),
                    icon: const Icon(Icons.font_download_outlined),
                    label: const Text('Choose TTF or OTF'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('clear-font'),
                    onPressed: appearance.fontPath == null
                        ? null
                        : () => unawaited(notifier.clearCustomFont()),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Use system font'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Custom assets stay at their original file location. If a file is moved or deleted, DigiDAW safely restores the default.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _paletteLabel(AppColorPalette palette) => switch (palette) {
  AppColorPalette.purple => 'Purple',
  AppColorPalette.blue => 'Blue',
  AppColorPalette.teal => 'Teal',
  AppColorPalette.orange => 'Orange',
  AppColorPalette.red => 'Red',
  AppColorPalette.green => 'Green',
  AppColorPalette.pink => 'Pink',
  AppColorPalette.cyan => 'Cyan',
  AppColorPalette.indigo => 'Indigo',
  AppColorPalette.amber => 'Amber',
  AppColorPalette.lime => 'Lime',
  AppColorPalette.magenta => 'Magenta',
  AppColorPalette.graphite => 'Graphite',
};

String _backgroundFitLabel(AppBackgroundFit fit) => switch (fit) {
  AppBackgroundFit.cover => 'Cover',
  AppBackgroundFit.contain => 'Contain',
  AppBackgroundFit.fill => 'Fill',
};

String _fileName(String path) {
  final segments = path.replaceAll('\\', '/').split('/');
  return segments.lastWhere(
    (segment) => segment.isNotEmpty,
    orElse: () => path,
  );
}
