import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/src/rust/api/l10n.dart';

part 'language_state.freezed.dart';

@freezed
abstract class LanguageState with _$LanguageState {
  const LanguageState._();

  const factory LanguageState({
    /// Every language, in the order the selector lists them.
    @Default(IListConst<UiLanguage>([])) IList<UiLanguage> languages,

    /// The saved choice; null follows the system language.
    String? selected,

    /// The language messages are shown in; null until loaded.
    UiLanguage? active,

    /// The language the system locales resolve to.
    UiLanguage? system,
    @Default(false) bool isApplying,
  }) = _LanguageState;

  /// The language [code] names, if it is one of [languages].
  UiLanguage? language(String code) =>
      languages.where((language) => language.code == code).firstOrNull;
}
