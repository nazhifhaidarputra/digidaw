import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/src/rust/api/l10n.dart' as l10n_api;

/// Lists, activates and saves the user interface language. Rust keeps the
/// choice with the other settings and formats every message.
class LanguageService {
  Result<IList<l10n_api.UiLanguage>> availableLanguages() {
    return attempt(() => l10n_api.availableLanguages().lock);
  }

  /// Activates the saved language, or the system language when none is saved.
  Future<Result<l10n_api.UiLanguageState>> applyLanguage() {
    return attemptAsync(
      () => l10n_api.applyLanguage(systemLocales: _systemLocales()),
    );
  }

  /// Saves and activates [code]; null follows the system language.
  Future<Result<l10n_api.UiLanguageState>> saveLanguage(String? code) {
    return attemptAsync(
      () => l10n_api.saveLanguage(code: code, systemLocales: _systemLocales()),
    );
  }

  List<String> _systemLocales() => [
    for (final locale in PlatformDispatcher.instance.locales)
      locale.toLanguageTag(),
  ];
}
