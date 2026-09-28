import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/mixer/view/routing_dialog.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/frb_generated.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _MockRustLibApi extends Mock implements RustLibApi {}

const _kick = UiRoutingNode.track(1);
const _lead = UiRoutingNode.track(2);
const _drums = UiRoutingNode.bus(5);
const _master = UiRoutingNode.master();
const _leadCompressor = UiPluginTarget.trackEffect(trackId: 2, effectId: 7);

UiMixerChannel _channel({List<UiEffectSummary> effects = const []}) =>
    UiMixerChannel(
      volume: 0,
      pan: 0,
      mute: false,
      solo: false,
      invertedPhase: false,
      effects: effects,
    );

UiRoutingConnection _route(
  UiRoutingNode source,
  UiRoutingNode destination, {
  bool isSend = false,
}) => UiRoutingConnection(
  source: source,
  destination: destination,
  sendLevel: 1.0,
  isSend: isSend,
  tap: UiRoutingTap.postFader,
);

final _initialRouting = [
  _route(_kick, _master),
  _route(_lead, _master),
  _route(
    _kick,
    const UiRoutingNode.pluginSidechain(_leadCompressor),
    isSend: true,
  ),
];

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
    tracks: const IMapConst({}),
    generators: const IMapConst({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {
        1: _channel(),
        2: _channel(
          effects: const [
            UiEffectSummary(
              id: 7,
              registryId: 1,
              name: 'Sidechain Compressor Stereo',
              bypass: false,
            ),
          ],
        ),
      },
      masterBus: _channel(),
      buses: {5: UiBus(id: 5, name: 'Drums', channel: _channel(), color: '')},
      routing: _initialRouting,
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

void main() {
  final api = _MockRustLibApi();
  late List<UiRoutingConnection> backendRouting;

  setUpAll(() {
    registerFallbackValue(_MockDawContext());
    registerFallbackValue(_route(_kick, _master));
    registerFallbackValue(_master);
    registerFallbackValue(_leadCompressor);
    registerFallbackValue(UiRoutingTap.postFader);
    RustLib.initMock(api: api);
  });

  setUp(() {
    reset(api);
    backendRouting = List.of(_initialRouting);
    when(
      () => api.crateApiMixerGetRoutingMatrix(ctx: any(named: 'ctx')),
    ).thenAnswer((_) async => List.of(backendRouting));
    // The backend keeps one main output per source.
    when(
      () => api.crateApiMixerUpdateRouting(
        ctx: any(named: 'ctx'),
        conn: any(named: 'conn'),
      ),
    ).thenAnswer((invocation) async {
      final conn = invocation.namedArguments[#conn] as UiRoutingConnection;
      backendRouting
        ..removeWhere(
          (route) =>
              route.source == conn.source &&
              route.isSend == conn.isSend &&
              (!conn.isSend || route.destination == conn.destination),
        )
        ..add(conn);
    });
    when(
      () => api.crateApiMixerRemoveRouting(
        ctx: any(named: 'ctx'),
        source: any(named: 'source'),
        destination: any(named: 'destination'),
        isSend: any(named: 'isSend'),
      ),
    ).thenAnswer((invocation) async {
      backendRouting.removeWhere(
        (route) =>
            route.source == invocation.namedArguments[#source] &&
            route.destination == invocation.namedArguments[#destination] &&
            route.isSend == invocation.namedArguments[#isSend],
      );
    });
    when(
      () => api.crateApiMixerSetSidechainSource(
        ctx: any(named: 'ctx'),
        plugin: any(named: 'plugin'),
        from: any(named: 'from'),
        sendLevel: any(named: 'sendLevel'),
        tap: any(named: 'tap'),
      ),
    ).thenAnswer((invocation) async {
      if (invocation.namedArguments[#sendLevel] == null) {
        backendRouting.removeWhere(
          (route) =>
              route.source == invocation.namedArguments[#from] &&
              route.destination ==
                  UiRoutingNode.pluginSidechain(
                    invocation.namedArguments[#plugin] as UiPluginTarget,
                  ),
        );
      }
    });
  });

  Future<ProviderContainer> createContainer() async {
    final container = ProviderContainer.test(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    await container.read(projectProvider.future);
    return container;
  }

  List<UiRoutingNode> mainOutputsOf(
    ProviderContainer container,
    UiRoutingNode source,
  ) => container
      .read(projectProvider)
      .requireValue
      .mixer
      .routing
      .where((route) => route.source == source && !route.isSend)
      .map((route) => route.destination)
      .toList();

  test('changing the main output replaces the previous one', () async {
    final container = await createContainer();

    final result = await container
        .read(mixerStateProvider.notifier)
        .updateRoutingCall(
          src: _kick,
          dest: _drums,
          sendLvl: 1.0,
          isSend: false,
        );

    expect(result.isOk(), isTrue);
    expect(mainOutputsOf(container, _kick), [_drums]);
  });

  test('unlinking from master leaves the channel without an output', () async {
    final container = await createContainer();

    await container
        .read(mixerStateProvider.notifier)
        .removeRouting(source: _kick, destination: _master, isSend: false);

    expect(mainOutputsOf(container, _kick), isEmpty);
  });

  Future<ProviderContainer> pumpDialog(WidgetTester tester) async {
    final container = await createContainer();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showRoutingDialog(context: context, source: _kick),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('output dropdown follows a change to a bus', (tester) async {
    await pumpDialog(tester);
    expect(find.text('Master'), findsOneWidget);

    await tester.tap(find.text('Master'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drums').last);
    await tester.pumpAndSettle();

    final dropdown = tester.widget<DropdownButtonFormField<UiRoutingNode?>>(
      find.byType(DropdownButtonFormField<UiRoutingNode?>),
    );
    expect(dropdown.initialValue, _drums);
    expect(find.text('Master'), findsNothing);
  });

  testWidgets('lists and removes a sidechain into another track', (
    tester,
  ) async {
    await pumpDialog(tester);

    expect(find.text('Track 2 · Sidechain Compressor Stereo'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove'));
    await tester.pumpAndSettle();

    verify(
      () => api.crateApiMixerSetSidechainSource(
        ctx: any(named: 'ctx'),
        plugin: _leadCompressor,
        from: _kick,
        sendLevel: null,
        tap: any(named: 'tap'),
      ),
    ).called(1);
    expect(find.text('Track 2 · Sidechain Compressor Stereo'), findsNothing);
  });

  testWidgets('unlinking shows the channel as unlinked', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.byTooltip('Unlink from Master'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unlinked: this channel'), findsOneWidget);
    expect(find.byTooltip('Link to master'), findsOneWidget);
  });
}
