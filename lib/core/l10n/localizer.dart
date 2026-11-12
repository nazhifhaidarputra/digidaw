/// Formats the translated messages of the user interface.
///
/// The messages live in Fluent files under `rust/karbeat-l10n/locales/`; see
/// the README there. Widgets and notifiers call [tr], which works without a
/// `BuildContext`. When the language changes, the app rebuilds every widget
/// once, so a [tr] call in a `build` method always shows the active language.
abstract interface class Localizer {
  /// Message [id] in the active language, with [args] placed into it.
  String format(String id, Map<String, Object> args);

  /// Message [id] in the language [languageCode].
  String formatIn(String languageCode, String id, Map<String, Object> args);

  /// Forgets cached messages after the active language changed.
  void languageChanged();
}

/// Gives every message's id: used before the Rust library is loaded.
final class _IdLocalizer implements Localizer {
  const _IdLocalizer();

  @override
  String format(String id, Map<String, Object> args) => id;

  @override
  String formatIn(String languageCode, String id, Map<String, Object> args) =>
      id;

  @override
  void languageChanged() {}
}

/// The process's [Localizer].
///
/// The app installs the Fluent localizer once the Rust library is loaded;
/// tests install one that reads the English Fluent files.
abstract final class L10n {
  static Localizer localizer = const _IdLocalizer();
}

/// Message [id] in the active language. Numbers in [args] pick plural
/// variants; any other value is shown as text.
String tr(String id, [Map<String, Object> args = const {}]) =>
    L10n.localizer.format(id, args);

/// Message [id] in the language [languageCode], such as `ja-JP`.
String trIn(
  String languageCode,
  String id, [
  Map<String, Object> args = const {},
]) => L10n.localizer.formatIn(languageCode, id, args);
