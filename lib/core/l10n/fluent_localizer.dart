import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/src/rust/api/l10n.dart';

/// Formats messages with Fluent in Rust through synchronous bridge calls.
///
/// Messages without arguments are cached until the language changes, since
/// labels are formatted on every rebuild.
final class FluentLocalizer implements Localizer {
  final _plain = <String, String>{};

  @override
  String format(String id, Map<String, Object> args) {
    if (args.isEmpty) {
      return _plain.putIfAbsent(id, () => l10NFormat(id: id, args: const []));
    }
    return l10NFormat(id: id, args: _bridgeArgs(args));
  }

  @override
  String formatIn(String languageCode, String id, Map<String, Object> args) {
    return l10NFormatIn(code: languageCode, id: id, args: _bridgeArgs(args));
  }

  @override
  void languageChanged() => _plain.clear();
}

List<UiL10nArg> _bridgeArgs(Map<String, Object> args) => [
  for (final MapEntry(key: name, :value) in args.entries)
    UiL10nArg(
      name: name,
      value: switch (value) {
        num() => UiL10nValue.number(value.toDouble()),
        _ => UiL10nValue.text(value.toString()),
      },
    ),
];
