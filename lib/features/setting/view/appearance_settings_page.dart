import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/app_theme.dart';
import 'package:karbeat/features/setting/models/app_color_theme.dart';
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
          customColorThemePaths: state.customColorThemePaths,
        ),
      ),
    );
    final notifier = ref.read(appearanceSettingsProvider.notifier);
    final colorThemeSources = [
      ...AppearanceAssetService.bundledColorThemes,
      ...appearance.customColorThemePaths,
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
              Row(
                children: [
                  Expanded(
                    child: _ColorThemeMenu(
                      themes: [
                        for (final source in colorThemeSources)
                          if (appearance.colorThemes[source] case final theme?)
                            (
                              source: source,
                              theme: theme,
                              removable: appearance.customColorThemePaths
                                  .contains(source),
                            ),
                      ],
                      selected: appearance.colorThemeSource,
                      onSelected: (source) =>
                          unawaited(notifier.setColorTheme(source)),
                      onRemove: (source) =>
                          unawaited(_removeColorTheme(context, ref, source)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    key: const ValueKey('choose-color-theme'),
                    onPressed: () => unawaited(notifier.chooseColorThemeFile()),
                    icon: const Icon(Icons.palette_outlined),
                    label: const Text('Load JSON theme'),
                  ),
                ],
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

typedef _ColorThemeEntry = ({
  String source,
  AppColorTheme theme,
  bool removable,
});

/// Picks the colour theme. Themes loaded from a file have a remove button in
/// the open menu.
class _ColorThemeMenu extends StatelessWidget {
  const _ColorThemeMenu({
    required this.themes,
    required this.selected,
    required this.onSelected,
    required this.onRemove,
  });

  final List<_ColorThemeEntry> themes;

  /// Source of the active theme; null is Default.
  final String? selected;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      key: const ValueKey('color-theme-menu'),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Theme'),
      items: [
        const DropdownMenuItem(
          key: ValueKey('color-theme-default'),
          value: null,
          child: _ColorThemeLabel(name: 'Default'),
        ),
        for (final entry in themes)
          DropdownMenuItem(
            key: ValueKey('color-theme-${entry.source}'),
            value: entry.source,
            child: _ColorThemeLabel(
              name: entry.theme.name,
              color: entry.theme.primary,
              tooltip: entry.removable ? entry.source : null,
              trailing: entry.removable
                  ? Builder(
                      builder: (menuContext) => IconButton(
                        key: ValueKey('remove-color-theme-${entry.source}'),
                        tooltip: 'Remove theme',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          // Close the menu first so the warning is not
                          // shown behind it.
                          Navigator.of(menuContext).pop();
                          onRemove(entry.source);
                        },
                      ),
                    )
                  : null,
            ),
          ),
      ],
      // The closed menu shows the active theme without its remove button.
      selectedItemBuilder: (context) => [
        const _ColorThemeLabel(name: 'Default'),
        for (final entry in themes)
          _ColorThemeLabel(name: entry.theme.name, color: entry.theme.primary),
      ],
      onChanged: onSelected,
    );
  }
}

class _ColorThemeLabel extends StatelessWidget {
  const _ColorThemeLabel({
    required this.name,
    this.color,
    this.tooltip,
    this.trailing,
  });

  final String name;

  /// Swatch of the theme's primary colour; Default has none.
  final Color? color;
  final String? tooltip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final swatch = color;
    final label = Text(name, overflow: TextOverflow.ellipsis);
    return Row(
      children: [
        if (swatch == null)
          const Icon(Icons.palette_outlined, size: 18)
        else
          CircleAvatar(radius: 9, backgroundColor: swatch),
        const SizedBox(width: 12),
        Expanded(
          child: tooltip == null
              ? label
              : Tooltip(message: tooltip, child: label),
        ),
        ?trailing,
      ],
    );
  }
}

/// Asks before removing a loaded theme file from the theme menu.
Future<void> _removeColorTheme(
  BuildContext context,
  WidgetRef ref,
  String source,
) async {
  final appearance = ref.read(appearanceSettingsProvider);
  final name = appearance.colorThemes[source]?.name ?? _fileName(source);
  final active = appearance.colorThemeSource == source;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('remove-color-theme-dialog'),
      title: const Text('Remove color theme?'),
      content: Text(
        '“$name” will be removed from the theme menu.'
        '${active ? ' It is the active theme, so DigiDAW switches back to the Default theme.' : ''}\n\n'
        'The file ${_fileName(source)} is not deleted. You can load it again with Load JSON theme.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('confirm-remove-color-theme'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(appearanceSettingsProvider.notifier).removeColorTheme(source);
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
