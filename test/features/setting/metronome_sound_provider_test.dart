import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/services/metronome_sound_provider.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _FakeMetronomeSoundService extends MetronomeSoundService {
  String? savedPath;
  String? pickedPath;
  bool hasSavedClicks = false;
  Exception? applyError;

  /// Every sound handed to the engine, in order: an imported path, 'restored'
  /// for the clicks saved on disk, or null for the built-in click.
  final List<String?> applied = [];

  @override
  Future<Result<String?>> loadPath() async => Result.ok(savedPath);

  @override
  Future<Result<void>> savePath(String? path) async {
    savedPath = path;
    return Result.ok(null);
  }

  @override
  Future<Result<String?>> pickSound() async => Result.ok(pickedPath);

  Result<void> _apply(String? sound) {
    final error = applyError;
    if (error != null) return Result.error(error);
    applied.add(sound);
    return Result.ok(null);
  }

  @override
  Future<Result<void>> importSound(DawContext context, String path) async {
    final result = _apply(path);
    if (result.isOk()) hasSavedClicks = true;
    return result;
  }

  @override
  Future<Result<void>> restoreSound(DawContext context) async {
    if (!hasSavedClicks) return Result.error(Exception('No saved clicks'));
    return _apply('restored');
  }

  @override
  Future<Result<void>> useDefaultSound(DawContext context) async =>
      _apply(null);
}

ProviderContainer _container(_FakeMetronomeSoundService service) {
  final container = ProviderContainer(
    overrides: [metronomeSoundServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('restores the saved clicks from disk', () async {
    final service = _FakeMetronomeSoundService()
      ..savedPath = '/sounds/click.wav'
      ..hasSavedClicks = true;
    final container = _container(service);

    final result = await container
        .read(metronomeSoundProvider.notifier)
        .initialize(_MockDawContext());

    expect(result.isOk(), isTrue);
    expect(service.applied, ['restored']);
    expect(container.read(metronomeSoundProvider), '/sounds/click.wav');
  });

  test('nothing is applied when no sound was saved', () async {
    final service = _FakeMetronomeSoundService();
    final container = _container(service);

    await container
        .read(metronomeSoundProvider.notifier)
        .initialize(_MockDawContext());

    expect(service.applied, isEmpty);
    expect(container.read(metronomeSoundProvider), isNull);
  });

  test('missing saved clicks fall back to the default click', () async {
    final service = _FakeMetronomeSoundService()
      ..savedPath = '/sounds/gone.wav';
    final container = _container(service);

    await container
        .read(metronomeSoundProvider.notifier)
        .initialize(_MockDawContext());

    expect(service.applied, isEmpty);
    expect(service.savedPath, isNull);
    expect(container.read(metronomeSoundProvider), isNull);
    expect(
      container.read(notificationProvider).current?.title,
      'Metronome sound unavailable',
    );
  });

  test(
    'choosing a sound imports and saves it, and default clears it',
    () async {
      final service = _FakeMetronomeSoundService();
      final container = _container(service);
      final notifier = container.read(metronomeSoundProvider.notifier);
      await notifier.initialize(_MockDawContext());

      service.pickedPath = '/sounds/cowbell.wav';
      expect((await notifier.chooseSound()).isOk(), isTrue);
      expect(service.applied, ['/sounds/cowbell.wav']);
      expect(service.savedPath, '/sounds/cowbell.wav');
      expect(container.read(metronomeSoundProvider), '/sounds/cowbell.wav');

      expect((await notifier.useDefaultSound()).isOk(), isTrue);
      expect(service.applied, ['/sounds/cowbell.wav', null]);
      expect(service.savedPath, isNull);
      expect(container.read(metronomeSoundProvider), isNull);
    },
  );

  test('a cancelled pick changes nothing', () async {
    final service = _FakeMetronomeSoundService();
    final container = _container(service);
    final notifier = container.read(metronomeSoundProvider.notifier);
    await notifier.initialize(_MockDawContext());

    expect((await notifier.chooseSound()).isOk(), isTrue);

    expect(service.applied, isEmpty);
    expect(container.read(metronomeSoundProvider), isNull);
  });

  test('a sound the engine rejects keeps the current one', () async {
    final service = _FakeMetronomeSoundService()
      ..pickedPath = '/sounds/broken.wav'
      ..applyError = Exception('unsupported format');
    final container = _container(service);
    final notifier = container.read(metronomeSoundProvider.notifier);
    await notifier.initialize(_MockDawContext());

    expect((await notifier.chooseSound()).isErr(), isTrue);

    expect(service.savedPath, isNull);
    expect(container.read(metronomeSoundProvider), isNull);
  });
}
