import 'dart:async';
import 'dart:ui';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/project_provider.dart';
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

const _busId = 5;

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
      buses: {
        _busId: const UiBus(
          id: _busId,
          name: 'Drums',
          channel: _channel,
          color: '#9E9E9EFF',
        ),
      },
      routing: [],
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
  });

  setUp(() => reset(api));

  Future<ProviderContainer> createContainer() async {
    final container = ProviderContainer.test(
      overrides: [projectProvider.overrideWith(_ProjectNotifier.new)],
    );
    await container.read(projectProvider.future);
    return container;
  }

  UiBus busIn(ProviderContainer container) =>
      container.read(projectProvider).requireValue.mixer.buses[_busId]!;

  test('changes the bus color and commits it as a hex string', () async {
    when(
      () => api.crateApiMixerChangeBusColor(
        ctx: any(named: 'ctx'),
        busId: _busId,
        newColor: any(named: 'newColor'),
      ),
    ).thenAnswer((_) async {});
    final container = await createContainer();

    final result = await container
        .read(mixerStateProvider.notifier)
        .changeBusColor(busId: _busId, color: const Color(0xFFFF8A65));

    expect(result.isOk(), isTrue);
    expect(busIn(container).color, 'FF8A65FF');
    verify(
      () => api.crateApiMixerChangeBusColor(
        ctx: any(named: 'ctx'),
        busId: _busId,
        newColor: 'FF8A65FF',
      ),
    ).called(1);
  });

  test('restores only the name when the backend rejects a rename', () async {
    final rename = Completer<void>();
    when(
      () => api.crateApiMixerRenameBus(
        ctx: any(named: 'ctx'),
        busId: _busId,
        newName: 'Vocals',
      ),
    ).thenAnswer((_) => rename.future);
    final container = await createContainer();
    final project = container.read(projectProvider.notifier);

    final renaming = container
        .read(mixerStateProvider.notifier)
        .renameBus(busId: _busId, name: 'Vocals');
    expect(busIn(container).name, 'Vocals');

    // A fader move lands while the rename is still in flight.
    project.upsertBusMixerChannel(
      _busId,
      busIn(container).copyWith(
        channel: const UiMixerChannel(
          volume: -6,
          pan: 0,
          mute: false,
          solo: false,
          invertedPhase: false,
          effects: [],
        ),
      ),
    );
    rename.completeError('bus is gone');

    expect((await renaming).isErr(), isTrue);
    expect(busIn(container).name, 'Drums');
    expect(busIn(container).channel.volume, -6);
  });
}
