import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/core/widgets/channel_toggle_button.dart';
import 'package:karbeat/features/plugins/services/plugin_ui_launcher.dart';
import 'package:karbeat/features/setting/services/external_plugin_service.dart';
import 'package:karbeat/features/track/view/track_header.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/external_plugins.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:mocktail/mocktail.dart';

class _MockDawContext extends Mock implements DawContext {}

class _ProjectNotifier extends ProjectNotifier {
  _ProjectNotifier(this.project);

  final ApplicationDataStore project;
  final DawContext context = _MockDawContext();

  @override
  DawContext get dawContext => context;

  @override
  Future<ApplicationDataStore> build() async => project;
}

class _ExternalPluginService extends ExternalPluginService {
  _ExternalPluginService({required this.isExternal});

  final bool isExternal;
  int openCount = 0;
  UiPluginTarget? openedTarget;

  @override
  Future<Result<UiExternalPluginDescriptor?>> descriptor(
    DawContext context,
    UiPluginTarget target,
  ) async => Result.ok(isExternal ? _externalDescriptor : null);

  @override
  Future<Result<UiExternalPluginCapabilities>> capabilities(
    DawContext context,
    UiPluginTarget target,
  ) async => Result.ok(
    const UiExternalPluginCapabilities(
      controller: true,
      editor: true,
      sidechain: false,
    ),
  );

  @override
  Future<Result<void>> openEditor(
    DawContext context,
    UiPluginTarget target,
  ) async {
    openCount++;
    openedTarget = target;
    return Result.ok(null);
  }
}

class _FlutterPluginLauncher extends PluginFlutterUiLauncher {
  int openCount = 0;
  UiPluginTarget? openedTarget;
  int? openedRegistryId;
  int? openedInstanceId;
  String? openedPluginName;

  @override
  void open(
    BuildContext context, {
    required UiPluginTarget target,
    required int registryId,
    required int instanceId,
    required String pluginName,
    bool forceDynamic = false,
  }) {
    openCount++;
    openedTarget = target;
    openedRegistryId = registryId;
    openedInstanceId = instanceId;
    openedPluginName = pluginName;
  }
}

const _externalDescriptor = UiExternalPluginDescriptor(
  format: UiExternalPluginFormat.vst3,
  nativeId: 'external-synth',
  path: '/plugins/ExternalSynth.vst3',
  name: 'External Synth',
  vendor: 'Vendor',
  version: '1',
  instrument: true,
);

void main() {
  testWidgets('long press opens the embedded generator plugin screen', (
    tester,
  ) async {
    final service = _ExternalPluginService(isExternal: false);
    final launcher = _FlutterPluginLauncher();
    await _pumpTrackHeader(tester, service: service, launcher: launcher);

    await tester.longPress(find.text('MIDI Track'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to plugin screen'));
    await tester.pumpAndSettle();

    expect(launcher.openCount, 1);
    expect(launcher.openedTarget, const UiPluginTarget.generator(7));
    expect(launcher.openedRegistryId, 42);
    expect(launcher.openedInstanceId, 7);
    expect(launcher.openedPluginName, 'Test Synth');
    expect(service.openCount, 0);
  });

  testWidgets('right click opens the external generator native editor', (
    tester,
  ) async {
    final service = _ExternalPluginService(isExternal: true);
    final launcher = _FlutterPluginLauncher();
    await _pumpTrackHeader(tester, service: service, launcher: launcher);

    final position = tester.getCenter(find.text('MIDI Track'));
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.down(position);
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to plugin screen'));
    await tester.pumpAndSettle();

    expect(service.openCount, 1);
    expect(service.openedTarget, const UiPluginTarget.generator(7));
    expect(launcher.openCount, 0);
  });

  testWidgets('mute and solo buttons reflect the track mixer channel', (
    tester,
  ) async {
    await _pumpTrackHeader(
      tester,
      service: _ExternalPluginService(isExternal: false),
      launcher: _FlutterPluginLauncher(),
      channel: const UiMixerChannel(
        volume: 1,
        pan: 0,
        mute: true,
        solo: false,
        invertedPhase: false,
        effects: [],
      ),
    );

    expect(find.byIcon(Icons.mic_off), findsNothing);
    expect(find.byIcon(Icons.volume_up), findsNothing);
    final mute = tester.widget<ChannelToggleButton>(
      find.widgetWithText(ChannelToggleButton, 'M'),
    );
    final solo = tester.widget<ChannelToggleButton>(
      find.widgetWithText(ChannelToggleButton, 'S'),
    );
    expect(mute.isActive, isTrue);
    expect(solo.isActive, isFalse);
  });

  testWidgets('shrinking a track leaves only its title', (tester) async {
    await _pumpTrackHeader(
      tester,
      service: _ExternalPluginService(isExternal: false),
      launcher: _FlutterPluginLauncher(),
    );
    expect(find.text('MIDI'), findsOneWidget);

    await tester.tap(find.byTooltip('Shrink lane'));
    await tester.pumpAndSettle();

    expect(find.text('MIDI Track'), findsOneWidget);
    expect(find.text('MIDI'), findsNothing);
    expect(find.byType(ChannelToggleButton), findsNothing);
    expect(find.byTooltip('Expand lane'), findsOneWidget);
  });
}

Future<void> _pumpTrackHeader(
  WidgetTester tester, {
  required ExternalPluginService service,
  required PluginFlutterUiLauncher launcher,
  UiMixerChannel? channel,
}) async {
  final project = _projectData(channel: channel);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectProvider.overrideWith(() => _ProjectNotifier(project)),
        externalPluginServiceProvider.overrideWithValue(service),
        pluginFlutterUiLauncherProvider.overrideWithValue(launcher),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TrackHeader(
              trackId: 1,
              itemHeight: 90,
              onDragStarted: () {},
              onDragEnded: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ApplicationDataStore _projectData({UiMixerChannel? channel}) {
  const master = UiMixerChannel(
    volume: 1,
    pan: 0,
    mute: false,
    solo: false,
    invertedPhase: false,
    effects: [],
  );
  return ApplicationDataStore(
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
    tracks: IMap({
      1: const UiTrack(
        id: 1,
        name: 'MIDI Track',
        color: '#345678',
        trackType: UiTrackType.midi,
        clips: [],
        generatorId: 7,
        orderIdx: 0,
      ),
    }),
    generators: IMap({
      7: const UiGeneratorInstance(
        id: 7,
        instanceType: UiGeneratorInstanceType.plugin(
          UiPluginInstance(registryId: 42, name: 'Test Synth', bypass: false),
        ),
      ),
    }),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: UiMixerState.raw(
      channels: {1: ?channel},
      masterBus: master,
      buses: {},
      routing: [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}
