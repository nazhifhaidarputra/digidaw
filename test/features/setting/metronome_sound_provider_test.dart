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
  Set<String> existingFiles = {};
  Exception? applyError;

  /// Every sound handed to the engine, in order; null is the built-in click.
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

  @override
  Future<Result<bool>> fileExists(String path) async =>
      Result.ok(existingFiles.contains(path));

  @override
  Future<Result<void>> apply(DawContext context, String? path) async {
    final error = applyError;
    if (error != null) return Result.error(error);
    applied.add(path);
    return Result.ok(null);
  }
}

ProviderContainer _container(_FakeMetronomeSoundService service) {
  final container = ProviderContainer(
    overrides: [metronomeSoundServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('restores and applies the saved sound', () async {
    final service = _FakeMetronomeSoundService()
      ..savedPath = '/sounds/click.wav'
      ..existingFiles = {'/sounds/click.wav'};
    final container = _container(service);

    final result = await container
        .read(metronomeSoundProvider.notifier)
        .initialize(_MockDawContext());

    expect(result.isOk(), isTrue);
    expect(service.applied, ['/sounds/click.wav']);
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

  test('a missing saved sound falls back to the default click', () async {
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
    'choosing a sound applies and saves it, and default clears it',
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
