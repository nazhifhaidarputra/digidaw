import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/core/widgets/rainbow_sparkle.dart';
import 'package:karbeat/features/mixer/view/mixer_channel_strip.dart';
import 'package:karbeat/features/track/view/mixer_channel_side_panel.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/frb_generated.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _MockRustLibApi extends Mock implements RustLibApi {}

UiMixerChannel _channel({List<UiEffectSummary> effects = const []}) =>
    UiMixerChannel(
      volume: 0,
      pan: 0,
      mute: false,
      solo: false,
      invertedPhase: false,
      effects: effects,
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
    tracks: const IMapConst({
      2: UiTrack(
        id: 2,
        name: 'Lead',
        color: '#3366FF',
        trackType: UiTrackType.midi,
        clips: [],
        orderIdx: 0,
      ),
    }),
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {
        2: _channel(
          effects: const [
            UiEffectSummary(
              id: 7,
              registryId: 1,
              name: 'Compressor',
              bypass: false,
            ),
          ],
        ),
      },
      masterBus: _channel(),
      buses: {},
      routing: const [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

void main() {
  final api = _MockRustLibApi();

  setUpAll(() {
    registerFallbackValue(_MockDawContext());
    RustLib.initMock(api: api);
    when(
      () => api.crateApiMixerGetTrackMixerChannelSpecs(
        ctx: any(named: 'ctx'),
        trackId: any(named: 'trackId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => api.crateApiMixerGetMasterChannelSpecs(ctx: any(named: 'ctx')),
    ).thenAnswer((_) async => []);
  });

  Future<ProviderContainer> pumpPanel(WidgetTester tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return const SizedBox(
                  width: 350,
                  height: 500,
                  child: MixerChannelSidePanel(),
                );
              },
            ),
          ),
        ),
      ),
    );
    // Let the project finish loading before a channel is selected
    container.read(projectProvider);
    await tester.pump();
    await tester.pump();
    return container;
  }

  testWidgets('shows the strip and effect rack of the selected track', (
    tester,
  ) async {
    final container = await pumpPanel(tester);
    expect(find.byType(MixerChannelStrip), findsNothing);

    container
        .read(trackListStateProvider.notifier)
        .selectMixerChannel(const UiMixerChannelTarget.track(2));
    await tester.pump();

    expect(find.text('Track · Lead'), findsOneWidget);
    expect(find.byType(MixerChannelStrip), findsOneWidget);
    expect(find.text('Lead Effects'), findsOneWidget);
    expect(find.text('Compressor'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Close channel panel'));
    await tester.pump();
    expect(find.byType(MixerChannelStrip), findsNothing);
  });

  testWidgets('shows the master with its rainbow', (tester) async {
    final container = await pumpPanel(tester);

    container
        .read(trackListStateProvider.notifier)
        .selectMixerChannel(const UiMixerChannelTarget.master());
    // The rainbow animates for as long as it is shown, so nothing settles
    await tester.pump();

    expect(find.text('Master Effects'), findsOneWidget);
    expect(find.byType(RainbowSparkle), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
