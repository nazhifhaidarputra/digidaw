import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/models/language_state.dart';
import 'package:karbeat/features/setting/services/language_service.dart';
import 'package:karbeat/src/rust/api/l10n.dart';

final languageServiceProvider = Provider<LanguageService>((ref) {
  return LanguageService();
});

/// The user interface language: the saved choice and the one in use.
class LanguageNotifier extends Notifier<LanguageState> {
  @override
  LanguageState build() => const LanguageState();

  /// Lists the languages and activates the saved or system language.
  Future<Result<void>> initialize() async {
    final service = ref.read(languageServiceProvider);
    final languages = service.availableLanguages();
    if (languages case Error(:final error)) {
      return ref.notifyErrorResult(
        error,
        title: tr('settings-language-load-failed'),
      );
    }
    state = state.copyWith(languages: languages.ok(), isApplying: true);
    final applied = await service.applyLanguage();
    return _publish(applied, failureTitle: 'settings-language-load-failed');
  }

  /// Saves and activates [code]; null follows the system language.
  Future<Result<void>> setLanguage(String? code) async {
    if (state.isApplying) {
      return Result.error(Exception('A language change is already running'));
    }
    state = state.copyWith(isApplying: true);
    final saved = await ref.read(languageServiceProvider).saveLanguage(code);
    return _publish(saved, failureTitle: 'settings-language-change-failed');
  }

  Result<void> _publish(
    Result<UiLanguageState> result, {
    required String failureTitle,
  }) {
    switch (result) {
      case Ok(value: final language):
        // Rust already formats in the new language; drop the cached old one
        // before anything rebuilds.
        L10n.localizer.languageChanged();
        state = state.copyWith(
          selected: language.selected,
          active: language.active,
          system: language.system,
          isApplying: false,
        );
        return Result.ok(null);
      case Error(:final error):
        state = state.copyWith(isApplying: false);
        return ref.notifyErrorResult(error, title: tr(failureTitle));
    }
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, LanguageState>(
  LanguageNotifier.new,
);
