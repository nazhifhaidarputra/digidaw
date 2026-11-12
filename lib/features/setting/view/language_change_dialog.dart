import 'package:flutter/material.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/setting/view/language_flag.dart';
import 'package:karbeat/src/rust/api/l10n.dart';

/// Warns that the app language is about to change, in the [current] language
/// and, when it differs, in the [target] language too. Completes with whether
/// the change was confirmed.
Future<bool> showLanguageChangeDialog(
  BuildContext context, {
  required UiLanguage? current,
  required UiLanguage target,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) =>
        _LanguageChangeDialog(current: current, target: target),
  );
  return confirmed ?? false;
}

class _LanguageChangeDialog extends StatelessWidget {
  const _LanguageChangeDialog({required this.current, required this.target});

  final UiLanguage? current;
  final UiLanguage target;

  @override
  Widget build(BuildContext context) {
    final current = this.current;
    final showsTarget = current == null || current.code != target.code;
    return AlertDialog(
      key: const ValueKey('language-change-dialog'),
      title: Text(tr('settings-language-change-title')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (current != null)
              _Warning(
                key: const ValueKey('language-change-current-message'),
                language: current,
                message: tr('settings-language-change-warning'),
              ),
            if (current != null && showsTarget) const Divider(height: 32),
            if (showsTarget)
              _Warning(
                key: const ValueKey('language-change-target-message'),
                language: target,
                message: trIn(target.code, 'settings-language-change-warning'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('language-change-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('common-cancel')),
        ),
        FilledButton(
          key: const ValueKey('language-change-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr('settings-language-change-confirm')),
        ),
      ],
    );
  }
}

/// The warning in one language, under that language's flag and name.
class _Warning extends StatelessWidget {
  const _Warning({super.key, required this.language, required this.message});

  final UiLanguage language;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LanguageFlag(language: language, width: 20),
            const SizedBox(width: 8),
            Text(language.nativeName, style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 8),
        Text(message),
      ],
    );
  }
}
