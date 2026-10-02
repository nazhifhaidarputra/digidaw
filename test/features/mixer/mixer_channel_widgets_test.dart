import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/mixer/view/mixer_channel_context_menu.dart';
import 'package:karbeat/features/mixer/view/mixer_effect_rack.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

UiMixerChannel _channel({
  double volume = 0,
  bool mute = false,
  List<UiEffectSummary> effects = const [],
}) => UiMixerChannel(
  volume: volume,
  pan: 0,
  mute: mute,
  solo: false,
  invertedPhase: false,
  effects: effects,
);

const _compressor = UiEffectSummary(
  id: 7,
  registryId: 1,
  name: 'Compressor',
  bypass: false,
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
        2: _channel(volume: -3, mute: true, effects: const [_compressor]),
      },
      masterBus: _channel(),
      buses: {
        5: UiBus(id: 5, name: 'Drums', channel: _channel(), color: '#FF8800'),
      },
      routing: const [
        UiRoutingConnection(
          source: UiRoutingNode.track(2),
          destination: UiRoutingNode.bus(5),
          sendLevel: 1.0,
          isSend: false,
          tap: UiRoutingTap.postFader,
        ),
        UiRoutingConnection(
          source: UiRoutingNode.bus(5),
          destination: UiRoutingNode.master(),
          sendLevel: 1.0,
          isSend: false,
          tap: UiRoutingTap.postFader,
        ),
      ],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openMenu(WidgetTester tester, UiMixerChannelTarget target) async {
  await _pump(
    tester,
    MixerChannelContextMenu(
      target: target,
      child: const SizedBox(key: ValueKey('strip'), width: 80, height: 200),
    ),
  );
  await tester.tap(
    find.byKey(const ValueKey('strip')),
    buttons: kSecondaryMouseButton,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a track strip menu summarises the channel', (tester) async {
    await _openMenu(tester, const UiMixerChannelTarget.track(2));

    expect(find.text('Name: Lead'), findsOneWidget);
    expect(find.text('Type: Track'), findsOneWidget);
    expect(find.text('ID: 2'), findsOneWidget);
    expect(find.text('Volume: -3.0 dB'), findsOneWidget);
    expect(find.text('Pan: C'), findsOneWidget);
    expect(find.text('State: Muted'), findsOneWidget);
    expect(find.text('Output: Drums'), findsOneWidget);
    expect(find.text('Effects: 1'), findsOneWidget);
    expect(find.text('Unmute'), findsOneWidget);
    expect(find.text('Solo'), findsOneWidget);
    expect(find.text('Add effect…'), findsOneWidget);
    expect(find.text('Route to master'), findsOneWidget);
    expect(find.text('Delete Bus'), findsNothing);
  });

  testWidgets('a bus strip menu offers the bus actions', (tester) async {
    await _openMenu(tester, const UiMixerChannelTarget.bus(5));

    expect(find.text('Name: Drums'), findsOneWidget);
    expect(find.text('Type: Bus'), findsOneWidget);
    expect(find.text('Output: Master'), findsOneWidget);
    expect(find.text('Effects: None'), findsOneWidget);
    expect(find.text('Rename Bus'), findsOneWidget);
    expect(find.text('Unlink from master'), findsOneWidget);
    expect(find.text('Delete Bus'), findsOneWidget);
  });

  testWidgets('the master strip menu has no routing or ID', (tester) async {
    await _openMenu(tester, const UiMixerChannelTarget.master());

    expect(find.text('Name: Master'), findsOneWidget);
    expect(find.text('Type: Master'), findsOneWidget);
    expect(find.textContaining('ID:'), findsNothing);
    expect(find.textContaining('Output:'), findsNothing);
    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Routing…'), findsNothing);
  });

  testWidgets('the effect rack is titled with the channel name', (
    tester,
  ) async {
    await _pump(
      tester,
      const MixerEffectRack(target: UiMixerChannelTarget.track(2)),
    );
    expect(find.text('Lead Effects'), findsOneWidget);
    expect(find.text('Compressor'), findsOneWidget);

    await _pump(
      tester,
      const MixerEffectRack(target: UiMixerChannelTarget.bus(5)),
    );
    expect(find.text('Drums Effects'), findsOneWidget);
    expect(find.text('No effects'), findsOneWidget);

    await _pump(
      tester,
      const MixerEffectRack(target: UiMixerChannelTarget.master()),
    );
    expect(find.text('Master Effects'), findsOneWidget);
  });
}
