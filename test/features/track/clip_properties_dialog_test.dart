import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/features/track/view/clip_curve_editor.dart';
import 'package:karbeat/features/track/view/clip_properties_dialog.dart';
import 'package:karbeat/features/track/view/gain_envelope_editor.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';

import 'fake_curve_sampler.dart';

const _audioClip = UiClip(
  name: 'loop me',
  id: 10,
  startTime: 3840,
  source: UiClipSource.audio(sourceId: 7),
  offsetStart: 0,
  loopLength: 96000,
  isSampleBased: true,
);

const _midiClip = UiClip(
  name: 'pattern',
  id: 11,
  startTime: 0,
  source: UiClipSource.midi(patternId: 3),
  offsetStart: 0,
  loopLength: 960,
  isSampleBased: false,
);

const _channel = UiMixerChannel(
  volume: 0,
  pan: 0,
  mute: false,
  solo: false,
  invertedPhase: false,
  effects: [],
);

class _ProjectNotifier extends ProjectNotifier {
  _ProjectNotifier(this.clips);

  final List<UiClip> clips;

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
    transport: const UiTransportState(bpm: 100, timeSignature: (4, 4)),
    hardwareConfig: const UiAudioHardwareConfig(
      selectedInputDevice: '',
      selectedOutputDevice: '',
      sampleRate: 48000,
      bufferSize: 1024,
      cpuLoad: 0,
    ),
    tracks: {
      1: UiTrack(
        id: 1,
        name: 'Audio',
        color: '#000000',
        trackType: UiTrackType.audio,
        clips: clips,
        orderIdx: 0,
        input: const UiTrackInput(firstChannel: 0, channels: 2, monitor: false),
      ),
    }.lock,
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {},
      masterBus: _channel,
      buses: {},
      routing: [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

class _TransportNotifier extends TransportNotifier {
  @override
  Future<TransportStateData> build() async => const TransportStateData(
    state: UiTransportState(bpm: 100, timeSignature: (4, 4)),
    sampleRate: 48000,
  );
}

class _TrackListNotifier extends TrackListNotifier {
  final List<UiClipModulation> modulations = [];

  @override
  Future<Result<void>> setClipModulation({
    required int trackId,
    required int clipId,
    required UiClipModulation modulation,
  }) async {
    modulations.add(modulation);
    return Result.ok(null);
  }
}

/// Opens the dialog for [clip] from a button; returns the recording notifier.
Future<_TrackListNotifier> _open(
  WidgetTester tester,
  UiClip clip, {
  VoidCallback? onGoToParent,
  Size window = const Size(1280, 800),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final trackList = _TrackListNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectProvider.overrideWith(() => _ProjectNotifier([clip])),
        transportProvider.overrideWith(_TransportNotifier.new),
        trackListStateProvider.overrideWith(() => trackList),
        curveSamplerProvider.overrideWithValue(FakeCurveSampler()),
        audioWaveformHandleProvider.overrideWith((ref, sourceId) => null),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            ref.watch(projectProvider);
            ref.watch(transportProvider);
            return Scaffold(
              body: TextButton(
                onPressed: () => showClipPropertiesDialog(
                  context,
                  trackId: 1,
                  clipId: clip.id,
                  onGoToParent: onGoToParent ?? () {},
                ),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return trackList;
}

void main() {
  testWidgets('an audio clip shows its timing and a shortcut to its source', (
    tester,
  ) async {
    var wentToParent = false;
    await _open(tester, _audioClip, onGoToParent: () => wentToParent = true);

    expect(find.text('loop me'), findsOneWidget);
    expect(find.text('Audio clip'), findsOneWidget);
    // Tick 3840 is the first beat of bar 2 in 4/4.
    expect(find.text('2.1.00'), findsOneWidget);

    await tester.tap(find.text('Go to Audio Properties'));
    await tester.pumpAndSettle();
    expect(wentToParent, isTrue);
    expect(find.text('Go to Audio Properties'), findsNothing);
  });

  testWidgets('a MIDI clip points to the piano roll and has no clip curves', (
    tester,
  ) async {
    await _open(tester, _midiClip);
    expect(find.text('Go to Piano Roll'), findsOneWidget);
    expect(find.text('MIDI clip'), findsOneWidget);
    expect(find.textContaining('apply to audio clips'), findsOneWidget);
    expect(find.text('Volume'), findsNothing);
  });

  testWidgets('every parameter has its own editor', (tester) async {
    await _open(tester, _audioClip);
    expect(find.byType(GainEnvelopeEditor), findsOneWidget);
    for (final parameter in ['Pan', 'Pitch', 'Loop']) {
      await tester.tap(find.text(parameter));
      await tester.pumpAndSettle();
      expect(find.byType(ClipCurveEditor), findsOneWidget, reason: parameter);
    }
  });

  testWidgets('turning the loop on starts at an eighth note', (tester) async {
    final trackList = await _open(tester, _audioClip);
    await tester.tap(find.text('Loop'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    final looping = trackList.modulations.single.looping;
    expect(looping.enabled, isTrue);
    // At 100 BPM and 48 kHz a beat is 28800 samples.
    expect(looping.time, 14400);
    expect(looping.curve, isEmpty);
  });

  testWidgets('the stutter roll halves the loop time and turns looping on', (
    tester,
  ) async {
    final trackList = await _open(tester, _audioClip);
    await tester.tap(find.text('Loop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stutter roll'));
    await tester.pumpAndSettle();

    final looping = trackList.modulations.single.looping;
    expect(looping.enabled, isTrue);
    expect(looping.curve.map((point) => point.value), [
      28800,
      14400,
      7200,
      3600,
    ]);
    expect(looping.curve.map((point) => point.position), [
      0,
      48000,
      72000,
      84000,
    ]);
    expect(
      looping.curve.every(
        (point) => point.curveType == AutomationCurveTypeDto.step,
      ),
      isTrue,
    );
  });

  testWidgets('a pitch shape fits the clip length', (tester) async {
    final trackList = await _open(tester, _audioClip);
    await tester.tap(find.text('Pitch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rise an octave'));
    await tester.pumpAndSettle();

    final pitch = trackList.modulations.single.pitch;
    expect(pitch.first.position, 0);
    expect(pitch.first.value, 0);
    expect(pitch.last.position, 96000);
    expect(pitch.last.value, 1200);
  });

  testWidgets('a narrow window does not overflow', (tester) async {
    await _open(tester, _audioClip, window: const Size(720, 560));
    for (final parameter in ['Pan', 'Pitch', 'Loop']) {
      await tester.tap(find.text(parameter));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: parameter);
    }
  });
}
