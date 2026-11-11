import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/source/services/audio_waveform_services.dart';
import 'package:karbeat/features/source/view/audio_properties_screen.dart';
import 'package:karbeat/features/track/services/curve_sampler.dart';
import 'package:karbeat/src/rust/api/audio_analysis.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';

import '../track/fake_curve_sampler.dart';

const _sourceId = 7;
const _frames = 48000;

class _Props extends Fake implements AudioWaveformUiForAudioProperties {
  _Props({this.trimStart = 0, this.trimEnd = _frames});

  @override
  final int trimStart;
  @override
  final int trimEnd;
  @override
  int get originalFrames => _frames;
  @override
  int? get id => _sourceId;
  @override
  int get sampleRate => 48000;
  @override
  int get channels => 2;
  @override
  double get duration => 1;
  @override
  String get filePath => 'a.wav';
  @override
  bool get normalized => false;
  @override
  bool get invert => false;
  @override
  bool get reverse => false;
  @override
  double get pitchCents => 0;
  @override
  bool get preserveFormants => false;
  @override
  bool get realtime => false;
  @override
  UiAudioSampleMode get sampleMode => UiAudioSampleMode.default_;
  @override
  UiBeatGrid? get beatGrid => null;
  @override
  double? get originalBpm => null;
  @override
  bool get fitted => false;
  @override
  bool get renderReady => false;
  @override
  bool get warp => false;
}

class _Context extends Fake implements DawContext {}

class _ProjectNotifier extends ProjectNotifier {
  final List<(int, int)> trims = [];

  @override
  DawContext get dawContext => _Context();

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
    tracks: const IMapConst({}),
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: const {},
      masterBus: const UiMixerChannel(
        volume: 0,
        pan: 0,
        mute: false,
        solo: false,
        invertedPhase: false,
        effects: [],
      ),
      buses: const {},
      routing: const [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );

  @override
  Future<void> setSourceTrim(int sourceId, int trimStart, int trimEnd) async {
    trims.add((trimStart, trimEnd));
  }
}

class _Jobs extends BackgroundJobsNotifier {
  @override
  BackgroundJobsState build() => const BackgroundJobsState();
}

Future<_ProjectNotifier> _pump(WidgetTester tester, _Props props) async {
  tester.view.physicalSize = const Size(1032, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final project = _ProjectNotifier();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectProvider.overrideWith(() => project),
        backgroundJobsProvider.overrideWith(_Jobs.new),
        curveSamplerProvider.overrideWithValue(FakeCurveSampler()),
        audioWaveformHandleProvider.overrideWith((ref, sourceId) => null),
        audioPropertiesProvider.overrideWith((ref, sourceId) async => props),
      ],
      child: const MaterialApp(
        home: AudioPropertiesScreen(sourceId: _sourceId, sourceName: 'a'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return project;
}

/// Drags like a pointer does, with a frame between moves. A drag that outlives
/// the first rebuild has to survive the overlay's layout changing under it.
Future<void> _drag(WidgetTester tester, Finder grip, double dx) async {
  final gesture = await tester.startGesture(tester.getCenter(grip));
  await tester.pump();
  for (var step = 0; step < 5; step++) {
    await gesture.moveBy(Offset(dx / 5, 0));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('dragging the left grip moves only the trim start', (
    tester,
  ) async {
    final project = await _pump(tester, _Props());
    final grip = find.byTooltip('Trim start');
    expect(grip, findsOneWidget);
    await _drag(tester, grip, 250);

    expect(project.trims, hasLength(1));
    final (start, end) = project.trims.single;
    // A fifth of the waveform: the first move only starts the drag.
    expect(start, inInclusiveRange(9000, 13000));
    expect(end, 0, reason: 'zero still plays to the end');
  });

  testWidgets('dragging the right grip moves only the trim end', (
    tester,
  ) async {
    final project = await _pump(tester, _Props());
    await _drag(tester, find.byTooltip('Trim end'), -250);

    final (start, end) = project.trims.single;
    expect(start, 0);
    expect(end, inExclusiveRange(1, _frames));
  });

  testWidgets('a grip dragged from a trimmed source keeps the other point', (
    tester,
  ) async {
    final project = await _pump(
      tester,
      _Props(trimStart: 12000, trimEnd: 36000),
    );
    await _drag(tester, find.byTooltip('Trim start'), 100);

    final (start, end) = project.trims.single;
    expect(start, greaterThan(12000));
    expect(end, 36000);
  });
}
