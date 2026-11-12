import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/language_provider.dart';
import 'package:karbeat/features/setting/services/language_service.dart';
import 'package:karbeat/src/rust/api/l10n.dart';

const _english = UiLanguage(
  code: 'en-US',
  nativeName: 'English (US)',
  englishName: 'English (US)',
  flag: 'us',
);
const _german = UiLanguage(
  code: 'de-DE',
  nativeName: 'Deutsch',
  englishName: 'German',
  flag: 'de',
);

/// Keeps the saved language in memory; the system resolves to English.
class _FakeLanguageService extends LanguageService {
  String? saved;
  Object? failure;
  final saveCalls = <String?>[];

  @override
  Result<IList<UiLanguage>> availableLanguages() =>
      Result.ok(const IListConst([_english, _german]));

  @override
  Future<Result<UiLanguageState>> applyLanguage() async => _state();

  @override
  Future<Result<UiLanguageState>> saveLanguage(String? code) async {
    saveCalls.add(code);
    if (failure case final failure?) return Result.error(Exception(failure));
    saved = code;
    return _state();
  }

  Result<UiLanguageState> _state() => Result.ok(
    UiLanguageState(
      selected: saved,
      active: saved == 'de-DE' ? _german : _english,
      system: _english,
    ),
  );
}

ProviderContainer _container(_FakeLanguageService service) {
  final container = ProviderContainer(
    overrides: [languageServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  container.listen(languageProvider, (_, _) {});
  container.listen(notificationProvider, (_, _) {});
  return container;
}

void main() {
  test('initialize lists languages and activates the saved one', () async {
    final service = _FakeLanguageService()..saved = 'de-DE';
    final container = _container(service);

    final result = await container.read(languageProvider.notifier).initialize();

    final state = container.read(languageProvider);
    expect(result.isOk(), isTrue);
    expect(state.languages, [_english, _german]);
    expect(state.selected, 'de-DE');
    expect(state.active, _german);
    expect(state.system, _english);
    expect(state.isApplying, isFalse);
  });

  test('setLanguage saves and activates the choice', () async {
    final service = _FakeLanguageService();
    final container = _container(service);
    final notifier = container.read(languageProvider.notifier);
    await notifier.initialize();

    await notifier.setLanguage('de-DE');
    expect(container.read(languageProvider).active, _german);

    await notifier.setLanguage(null);
    final state = container.read(languageProvider);
    expect(state.selected, isNull);
    expect(state.active, _english);
    expect(service.saveCalls, ['de-DE', null]);
  });

  test('a failed change keeps the language and notifies', () async {
    final service = _FakeLanguageService()..failure = 'disk full';
    final container = _container(service);
    final notifier = container.read(languageProvider.notifier);
    await notifier.initialize();

    final result = await notifier.setLanguage('de-DE');

    final state = container.read(languageProvider);
    expect(result.isErr(), isTrue);
    expect(state.active, _english);
    expect(state.isApplying, isFalse);
    expect(
      container.read(notificationProvider).current?.title,
      'Could not change the language',
    );
  });
}
