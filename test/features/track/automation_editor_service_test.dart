import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';
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
      channels: {},
      masterBus: _channel,
      buses: {},
      routing: [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: IMap({
      1: const AutomationLaneDto(
        id: 1,
        label: 'Volume',
        points: [
          AutomationPointDto(
            id: 10,
            timeTicks: 0,
            value: 0.25,
            curveType: AutomationCurveTypeDto.linear,
            tension: 0,
          ),
        ],
        enabled: true,
        min: 0,
        max: 1,
        defaultValue: 0,
      ),
    }),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

void main() {
  final api = _MockRustLibApi();

  setUpAll(() {
    registerFallbackValue(_MockDawContext());
    RustLib.initMock(api: api);
  });

  setUp(() {
    reset(api);
    when(
      () => api.crateApiAutomationUpdateAutomationPoint(
        ctx: any(named: 'ctx'),
        automationId: any(named: 'automationId'),
        id: any(named: 'id'),
        timeTicks: any(named: 'timeTicks'),
        value: any(named: 'value'),
        tension: any(named: 'tension'),
        curveType: any(named: 'curveType'),
      ),
    ).thenAnswer((_) async => 0);
  });

  Future<ProviderContainer> createProjectContainer() async {
    final container = ProviderContainer.test(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    await container.read(projectProvider.future);
    return container;
  }

  double pointValue(ProviderContainer container) => container
      .read(projectProvider)
      .requireValue
      .automationPool[1]!
      .points
      .single
      .value;

  test('setting a point value clamps it to the normalized range', () async {
    final container = await createProjectContainer();

    await container
        .read(automationEditorProvider.notifier)
        .setPointValue(laneId: 1, pointId: 10, normalizedValue: 1.5);

    expect(pointValue(container), 1.0);
    verify(
      () => api.crateApiAutomationUpdateAutomationPoint(
        ctx: any(named: 'ctx'),
        automationId: 1,
        id: 10,
        value: 1.0,
      ),
    ).called(1);
  });

  test('setting the current value does not call the backend', () async {
    final container = await createProjectContainer();

    await container
        .read(automationEditorProvider.notifier)
        .setPointValue(laneId: 1, pointId: 10, normalizedValue: 0.25);

    verifyNever(
      () => api.crateApiAutomationUpdateAutomationPoint(
        ctx: any(named: 'ctx'),
        automationId: any(named: 'automationId'),
        id: any(named: 'id'),
        value: any(named: 'value'),
      ),
    );
  });

  test('clearing hover of a stale point keeps the newer hover', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final editor = container.read(automationEditorProvider.notifier);

    editor.hoverPoint(laneId: 1, pointId: 10);
    editor.hoverPoint(laneId: 1, pointId: 11);
    editor.clearHoveredPoint(laneId: 1, pointId: 10);

    final state = container.read(automationEditorProvider);
    expect(state.hoveredLaneId, 1);
    expect(state.hoveredPointId, 11);

    editor.clearHoveredPoint(laneId: 1, pointId: 11);
    final cleared = container.read(automationEditorProvider);
    expect(cleared.hoveredLaneId, isNull);
    expect(cleared.hoveredPointId, isNull);
  });

  test('closing the context menu only clears its own target', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final editor = container.read(automationEditorProvider.notifier);

    editor.openPointContext(laneId: 2, pointId: 20);
    editor.closePointContext(laneId: 3, pointId: 20);
    expect(container.read(automationEditorProvider).contextPointId, 20);

    editor.closePointContext(laneId: 2, pointId: 20);
    final state = container.read(automationEditorProvider);
    expect(state.contextLaneId, isNull);
    expect(state.contextPointId, isNull);
  });

  test('pasting with an empty clipboard is a no-op', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final editor = container.read(automationEditorProvider.notifier);

    await editor.pastePointValue(laneId: 1, pointId: 1);

    expect(
      container.read(automationEditorProvider).clipboard,
      const AutomationLanePointClipboard.empty(),
    );
  });
}
