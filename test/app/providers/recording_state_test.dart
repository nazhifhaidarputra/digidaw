import 'dart:async';
import 'dart:typed_data';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/recording_state.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/recording.dart';
import 'package:karbeat/src/rust/frb_generated.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _MockRustLibApi extends Mock implements RustLibApi {}

const _channel = UiMixerChannel(
  volume: 0,
  pan: 0,
  mute: false,
  solo: false,
  invertedPhase: false,
  effects: [],
);

const _input = UiTrackInput(firstChannel: 0, channels: 2, monitor: false);

UiTrack _track({List<UiClip> clips = const []}) => UiTrack(
  id: 1,
  name: 'Vocals',
  color: '#345678',
  trackType: UiTrackType.audio,
  clips: clips,
  orderIdx: 0,
  input: _input,
);

class _ProjectNotifier extends ProjectNotifier {
  final DawContext context = _MockDawContext();

  @override
  DawContext get dawContext => context;

  @override
  Future<ApplicationDataStore> build() async => ApplicationDataStore(
    metadata: const UiProjectMetadata(
      name: '',
      author: '',
      description: '',
      genre: '',
      version: '',
      createdAt: '',
    ),
    transport: const UiTransportState(bpm: 120, timeSignature: (4, 4)),
    hardwareConfig: const UiAudioHardwareConfig(
      selectedInputDevice: '',
      selectedOutputDevice: '',
      sampleRate: 48000,
      bufferSize: 1024,
      cpuLoad: 0,
    ),
    tracks: IMap({1: _track()}),
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {1: _channel},
      masterBus: _channel,
      buses: {},
      routing: [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

UiRecordingProgress _progress({
  required int frames,
  required int peakOffset,
  required List<double> peaks,
  bool ended = false,
}) => UiRecordingProgress(
  trackId: 1,
  startSamples: 48000,
  frames: frames,
  sampleRate: 48000,
  peakOffset: peakOffset,
  peaks: Float32List.fromList(peaks),
  ended: ended,
);

void main() {
  final api = _MockRustLibApi();
  late StreamController<UiRecordingProgress> progress;

  setUpAll(() {
    registerFallbackValue(_MockDawContext());
    RustLib.initMock(api: api);
  });

  setUp(() {
    reset(api);
    progress = StreamController<UiRecordingProgress>.broadcast();
    when(
      () => api.crateApiRecordingStartTrackRecording(
        ctx: any(named: 'ctx'),
        trackId: any(named: 'trackId'),
      ),
    ).thenAnswer((_) async => const UiStartedTake(enabledInput: false));
  });

  Future<ProviderContainer> makeContainer() async {
    final container = ProviderContainer(
      overrides: [
        projectProvider.overrideWith(_ProjectNotifier.new),
        recordingProgressStreamProvider.overrideWith((ref) => progress.stream),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(progress.close);
    await container.read(projectProvider.future);
    // Track headers keep the notifier listened to, which keeps its progress
    // listener running.
    container.listen(recordingProvider, (_, _) {});
    return container;
  }

  test('an armed take grows with its progress and becomes a clip when the '
      'engine ends it', () async {
    final recorded = UiClip(
      name: 'Recording_2026-10-30T14:05:33+07:00',
      id: 9,
      startTime: 1920,
      source: const UiClipSource.audio(sourceId: 3),
      offsetStart: 0,
      loopLength: 512,
      isSampleBased: true,
    );
    final stopped = Completer<UiTrack?>();
    when(
      () => api.crateApiRecordingStopTrackRecording(
        ctx: any(named: 'ctx'),
        trackId: 1,
      ),
    ).thenAnswer((_) => stopped.future);

    final container = await makeContainer();
    final notifier = container.read(recordingProvider.notifier);
    expect((await notifier.toggleTrack(1)).isOk(), isTrue);
    expect(container.read(recordingProvider).takes[1], const TrackTake());

    progress.add(_progress(frames: 256, peakOffset: 0, peaks: [-0.5, 0.5]));
    await Future<void>.delayed(Duration.zero);
    // A report repeating a known pair adds only the new one.
    progress.add(
      _progress(frames: 512, peakOffset: 0, peaks: [-0.5, 0.5, -0.25, 0.25]),
    );
    await Future<void>.delayed(Duration.zero);
    final take = container.read(recordingProvider).takes[1]!;
    expect(take.startSamples, 48000);
    expect(take.frames, 512);
    expect(take.peaks, [-0.5, 0.5, -0.25, 0.25].lock);

    progress.add(
      _progress(frames: 512, peakOffset: 2, peaks: const [], ended: true),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(recordingProvider).takes[1]?.isStopping, isTrue);

    stopped.complete(_track(clips: [recorded]));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(recordingProvider).takes, isEmpty);
    expect(
      container.read(projectProvider).value!.tracks[1]!.clips.single,
      recorded,
    );
  });

  test(
    'recording without a selected audio track warns and arms nothing',
    () async {
      final container = await makeContainer();
      await container.read(recordingProvider.notifier).recordSelectedTrack();

      expect(container.read(recordingProvider).takes, isEmpty);
      expect(container.read(notificationProvider).current, isNotNull);
      verifyNever(
        () => api.crateApiRecordingStartTrackRecording(
          ctx: any(named: 'ctx'),
          trackId: any(named: 'trackId'),
        ),
      );
    },
  );
}
