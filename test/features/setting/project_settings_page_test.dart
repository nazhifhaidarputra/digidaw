import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/setting/view/project_settings_page.dart';
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/project.dart';

class _FakeProjectNotifier extends ProjectNotifier {
  UiProjectMetadata? lastSaved;

  @override
  Future<ApplicationDataStore> build() async => _projectData();

  @override
  Future<Result<void>> updateMetadata(UiProjectMetadata metadata) async {
    final canonical = metadata.copyWith(
      name: metadata.name.trim(),
      author: metadata.author.trim(),
      description: metadata.description.trim(),
      genre: metadata.genre.trim(),
      version: metadata.version.trim(),
    );
    lastSaved = canonical;
    state = AsyncData(state.requireValue.copyWith(metadata: canonical));
    return Result.ok(null);
  }

  void replaceMetadata(UiProjectMetadata metadata) {
    state = AsyncData(state.requireValue.copyWith(metadata: metadata));
  }
}

void main() {
  testWidgets('hydrates fields and saves edited metadata', (tester) async {
    late _FakeProjectNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectProvider.overrideWith(() {
            notifier = _FakeProjectNotifier();
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: ProjectSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Original title'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '  New title  ');
    await tester.pump();
    final saveButton = find.byKey(const ValueKey('save-project-metadata'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(notifier.lastSaved?.name, 'New title');
    expect(find.text('New title'), findsOneWidget);
  });

  testWidgets('rejects an empty title', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [projectProvider.overrideWith(_FakeProjectNotifier.new)],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: ProjectSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, '   ');
    await tester.pump();
    final saveButton = find.byKey(const ValueKey('save-project-metadata'));
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pump();

    expect(find.text('Title is required'), findsOneWidget);
  });

  testWidgets('does not overwrite dirty fields when project changes', (
    tester,
  ) async {
    late _FakeProjectNotifier notifier;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectProvider.overrideWith(() {
            notifier = _FakeProjectNotifier();
            return notifier;
          }),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(body: ProjectSettingsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Unsaved title');
    notifier.replaceMetadata(
      _metadata(name: 'Loaded project', description: 'New project'),
    );
    await tester.pump();

    expect(find.text('Unsaved title'), findsOneWidget);
    expect(
      find.text(
        'The current project changed while this form has unsaved edits.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Reload project'));
    await tester.pump();
    expect(find.text('Loaded project'), findsOneWidget);
  });
}

ApplicationDataStore _projectData() {
  const master = UiMixerChannel(
    volume: 1,
    pan: 0,
    mute: false,
    solo: false,
    invertedPhase: false,
    effects: [],
  );
  return ApplicationDataStore(
    metadata: _metadata(),
    transport: const UiTransportState(bpm: 120, timeSignature: (4, 4)),
    hardwareConfig: const UiAudioHardwareConfig(
      selectedInputDevice: '',
      selectedOutputDevice: '',
      sampleRate: 48000,
      bufferSize: 1024,
      cpuLoad: 0,
    ),
    tracks: const IMapConst<int, UiTrack>({}),
    generators: const IMapConst<int, UiGeneratorInstance>({}),
    patterns: const IMapConst<int, UiPattern>({}),
    mixer: const UiMixerState.raw(
      channels: {},
      masterBus: master,
      buses: {},
      routing: [],
    ),
    modulationLinks: const IMapConst<int, ModulationLinkDto>({}),
    automationPool: const IMapConst<int, AutomationLaneDto>({}),
    modulationSources: const IMapConst<int, ModulationSourceDto>({}),
  );
}

UiProjectMetadata _metadata({
  String name = 'Original title',
  String description = 'Original description',
}) {
  return UiProjectMetadata(
    name: name,
    author: 'Author',
    description: description,
    genre: 'Electronic',
    version: '1.0',
    createdAt: '2026-08-30T00:00:00Z',
  );
}
