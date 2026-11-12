import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/setting/models/general_settings_state.dart';
import 'package:karbeat/features/setting/services/general_settings_provider.dart';
import 'package:karbeat/features/setting/services/language_provider.dart';
import 'package:karbeat/features/setting/view/language_change_dialog.dart';
import 'package:karbeat/features/setting/view/language_flag.dart';
import 'package:karbeat/src/rust/api/l10n.dart';

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  static const historyOptions = <int>[0, 25, 50, 100, 250, 500, 1000];
  static const autoSaveIntervalMinutes = <int>[1, 2, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(
      generalSettingsProvider.select(
        (state) => (
          limit: state.maxHistoryEntries,
          busy: state.isApplyingHistoryLimit,
        ),
      ),
    );
    final autoSave = ref.watch(
      generalSettingsProvider.select(
        (state) => (
          enabled: state.autoSaveEnabled,
          intervalSeconds: state.autoSaveIntervalSeconds,
          busy: state.isApplyingAutoSave,
        ),
      ),
    );
    final showRecentProjects = ref.watch(
      generalSettingsProvider.select((state) => state.showRecentProjects),
    );
    final intervalOptions = {
      for (final minutes in autoSaveIntervalMinutes) minutes * 60,
      autoSave.intervalSeconds,
    }.toList(growable: false)..sort();

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
                tr('settings-menu-general'),
                key: const ValueKey('settings-page-general'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              const _LanguageSection(),
              const SizedBox(height: 32),
              DropdownButtonFormField<int>(
                key: ValueKey('history-limit-field-${selection.limit}'),
                initialValue: selection.limit,
                decoration: InputDecoration(
                  labelText: tr('settings-general-history-limit'),
                  border: OutlineInputBorder(),
                ),
                items: historyOptions
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(
                          value == 0
                              ? tr('common-disabled')
                              : tr('settings-general-history-entries', {
                                  'count': value,
                                }),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: selection.busy
                    ? null
                    : (value) {
                        if (value != null) {
                          unawaited(
                            ref
                                .read(generalSettingsProvider.notifier)
                                .setHistoryLimit(value),
                          );
                        }
                      },
              ),
              const SizedBox(height: 12),
              Text(tr('settings-general-history-help')),
              if (selection.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 32),
              Text(
                tr('settings-general-auto-save'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('auto-save-enabled-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('settings-general-auto-save-enable')),
                value: autoSave.enabled,
                onChanged: autoSave.busy
                    ? null
                    : (value) => unawaited(
                        ref
                            .read(generalSettingsProvider.notifier)
                            .setAutoSaveEnabled(value),
                      ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(
                  'auto-save-interval-field-${autoSave.intervalSeconds}',
                ),
                initialValue: autoSave.intervalSeconds,
                decoration: InputDecoration(
                  labelText: tr('settings-general-auto-save-interval'),
                  border: OutlineInputBorder(),
                ),
                items: intervalOptions
                    .map(
                      (seconds) => DropdownMenuItem(
                        value: seconds,
                        child: Text(_formatInterval(seconds)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: autoSave.busy || !autoSave.enabled
                    ? null
                    : (value) {
                        if (value != null) {
                          unawaited(
                            ref
                                .read(generalSettingsProvider.notifier)
                                .setAutoSaveInterval(value),
                          );
                        }
                      },
              ),
              const SizedBox(height: 12),
              Text(tr('settings-general-auto-save-help')),
              if (autoSave.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: 32),
              Text(
                tr('settings-general-folders'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _DefaultFolderTile(
                kind: DefaultFolder.project,
                title: tr('settings-general-project-folder'),
                unsetText: tr('settings-general-project-folder-unset'),
              ),
              _DefaultFolderTile(
                kind: DefaultFolder.export,
                title: tr('settings-general-export-folder'),
                unsetText: tr('settings-general-export-folder-unset'),
              ),
              const SizedBox(height: 32),
              Text(
                tr('settings-general-recent-projects'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('show-recent-projects-switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(tr('settings-general-recent-projects-show')),
                subtitle: Text(tr('settings-general-recent-projects-help')),
                value: showRecentProjects,
                onChanged: (value) => unawaited(
                  ref
                      .read(generalSettingsProvider.notifier)
                      .setShowRecentProjects(value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatInterval(int seconds) {
    if (seconds % 60 != 0) {
      return tr('settings-general-interval-seconds', {'count': seconds});
    }
    return tr('settings-general-interval-minutes', {'count': seconds ~/ 60});
  }
}

/// One default folder: its path, a warning when it is gone, and buttons to
/// choose or clear it.
class _DefaultFolderTile extends ConsumerWidget {
  const _DefaultFolderTile({
    required this.kind,
    required this.title,
    required this.unsetText,
  });

  final DefaultFolder kind;
  final String title;
  final String unsetText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folder = ref.watch(
      generalSettingsProvider.select(
        (state) => (
          path: state.folder(kind),
          missing: state.missingFolders.contains(kind),
          busy: state.isSavingFolder,
        ),
      ),
    );
    final notifier = ref.read(generalSettingsProvider.notifier);
    final path = folder.path;
    final theme = Theme.of(context);

    return ListTile(
      key: ValueKey('default-folder-${kind.name}'),
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(path ?? unsetText),
          if (folder.missing)
            Text(
              tr('settings-general-folder-missing'),
              key: ValueKey('default-folder-${kind.name}-missing'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            key: ValueKey('default-folder-${kind.name}-choose'),
            onPressed: folder.busy
                ? null
                : () => unawaited(notifier.chooseDefaultFolder(kind)),
            child: Text(tr('common-choose')),
          ),
          if (path != null)
            TextButton(
              key: ValueKey('default-folder-${kind.name}-reset'),
              onPressed: folder.busy
                  ? null
                  : () => unawaited(notifier.setDefaultFolder(kind, null)),
              child: Text(tr('common-reset')),
            ),
        ],
      ),
    );
  }
}

/// The value of the "System default" choice in the language selector.
const _systemLanguage = '';

/// Picks the app language, after a warning in the current and the new
/// language.
class _LanguageSection extends ConsumerStatefulWidget {
  const _LanguageSection();

  @override
  ConsumerState<_LanguageSection> createState() => _LanguageSectionState();
}

class _LanguageSectionState extends ConsumerState<_LanguageSection> {
  /// Bumped to rebuild the selector on its saved value after a choice.
  int _resets = 0;

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageProvider);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('settings-language-title'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(
            'language-field-${language.selected ?? 'system'}-$_resets',
          ),
          initialValue: language.selected ?? _systemLanguage,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr('settings-language-field'),
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem(
              key: const ValueKey('language-option-system'),
              value: _systemLanguage,
              child: Row(
                children: [
                  const Icon(Icons.computer, size: 18),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      tr('settings-language-system', {
                        'language': language.system?.nativeName ?? '',
                      }),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            for (final option in language.languages)
              DropdownMenuItem(
                key: ValueKey('language-option-${option.code}'),
                value: option.code,
                child: _LanguageLabel(language: option),
              ),
          ],
          onChanged: language.isApplying || language.languages.isEmpty
              ? null
              : (value) {
                  if (value != null) unawaited(_choose(value));
                },
        ),
        const SizedBox(height: 12),
        Text(tr('settings-language-help')),
        if (language.isApplying) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }

  Future<void> _choose(String value) async {
    final state = ref.read(languageProvider);
    final code = value == _systemLanguage ? null : value;
    final target = code == null ? state.system : state.language(code);
    if (code != state.selected && target != null) {
      final confirmed = await showLanguageChangeDialog(
        context,
        current: state.active,
        target: target,
      );
      if (confirmed) {
        await ref.read(languageProvider.notifier).setLanguage(code);
      }
    }
    // Show the saved choice again, whether the change happened or not.
    if (mounted) setState(() => _resets++);
  }
}

/// A language's flag and its name in itself, with its English name when that
/// differs.
class _LanguageLabel extends StatelessWidget {
  const _LanguageLabel({required this.language});

  final UiLanguage language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        LanguageFlag(language: language),
        const SizedBox(width: 12),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: language.nativeName,
              children: [
                if (language.englishName != language.nativeName)
                  TextSpan(
                    text: '  ${language.englishName}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
