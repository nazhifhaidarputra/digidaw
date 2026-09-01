import 'dart:async';
import 'dart:io';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/utils/result_type.dart';
import 'package:karbeat/features/workspace/models/browser_panel_state.dart';
import 'package:karbeat/features/workspace/services/sample_browser_service.dart';
import 'package:karbeat/features/track/view/track_list_screen.dart';
import 'package:karbeat/shared/enums/global.dart';

class _FakeSampleBrowserService extends SampleBrowserService {
  _FakeSampleBrowserService(this.tree, {List<String> persistedPaths = const []})
    : persistedPaths = List.of(persistedPaths);

  final FileTree tree;
  List<String> persistedPaths;
  int scanCount = 0;

  @override
  Future<Result<String?>> pickDirectory() async => Result.ok(tree.path);

  @override
  Future<Result<FileTree>> scanDirectory(String path) async {
    scanCount++;
    return Result.ok(tree);
  }

  @override
  Future<Result<List<String>>> loadPersistedDirectoryPaths() async =>
      Result.ok(List.of(persistedPaths));

  @override
  Future<Result<void>> savePersistedDirectoryPaths(
    Iterable<String> paths,
  ) async {
    persistedPaths = paths.toList();
    return Result.ok(null);
  }
}

class _DelayedRestoreSampleBrowserService extends SampleBrowserService {
  final Completer<Result<List<String>>> loadCompleter = Completer();

  @override
  Future<Result<List<String>>> loadPersistedDirectoryPaths() =>
      loadCompleter.future;
}

void main() {
  test('piano roll navigation can clear a previously edited pattern', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(workspaceStateProvider.notifier);

    notifier.openPattern(12);
    expect(container.read(workspaceStateProvider).editingPatternId, 12);

    notifier.openPianoRoll();

    final state = container.read(workspaceStateProvider);
    expect(state.currentView, WorkspaceView.pianoRoll);
    expect(state.editingPatternId, isNull);
  });

  test('browser panel uses immutable empty defaults', () {
    const state = BrowserPanelState();

    expect(state.isExpanded, isFalse);
    expect(state.isLoadingDirectory, isFalse);
    expect(state.directories, isEmpty);
    expect(state.expandedDirectoryPaths, isEmpty);
    expect(state.selectedSamplePath, isNull);
  });

  test('scanner builds a sorted recursive audio-only tree', () async {
    final root = await Directory.systemTemp.createTemp('karbeat_browser_test_');
    addTearDown(() => root.delete(recursive: true));

    final drums = await Directory(
      '${root.path}${Platform.pathSeparator}Drums',
    ).create();
    await File(
      '${root.path}${Platform.pathSeparator}zeta.WAV',
    ).writeAsBytes([0]);
    await File(
      '${root.path}${Platform.pathSeparator}alpha.mp3',
    ).writeAsBytes([0]);
    await File(
      '${root.path}${Platform.pathSeparator}notes.txt',
    ).writeAsString('skip');
    await File(
      '${root.path}${Platform.pathSeparator}.hidden.wav',
    ).writeAsBytes([0]);
    await File(
      '${drums.path}${Platform.pathSeparator}kick.flac',
    ).writeAsBytes([0]);

    final result = await SampleBrowserService().scanDirectory(root.path);

    expect(result.isOk(), isTrue);
    final tree = result.ok();
    expect(tree.samples.map((sample) => sample.name), [
      'alpha.mp3',
      'zeta.WAV',
    ]);
    expect(tree.directories.map((directory) => directory.name), ['Drums']);
    expect(tree.directories.single.samples.single.name, 'kick.flac');
  });

  test('workspace notifier adds and deduplicates a source directory', () async {
    const tree = FileTree(name: 'Samples', path: '/samples');
    final service = _FakeSampleBrowserService(tree);
    final container = ProviderContainer(
      overrides: [sampleBrowserServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(workspaceStateProvider.notifier);
    await notifier.addSampleDirectory();
    await notifier.addSampleDirectory();

    final browser = container.read(workspaceStateProvider).browserPanelState;
    expect(browser.directories.length, 1);
    expect(browser.directories['/samples'], tree);
    expect(browser.expandedDirectoryPaths, contains('/samples'));
    expect(service.persistedPaths, ['/samples']);

    notifier.selectBrowserSample('/samples/kick.wav');
    notifier.toggleBrowserDirectory('/samples');
    expect(
      container
          .read(workspaceStateProvider)
          .browserPanelState
          .selectedSamplePath,
      '/samples/kick.wav',
    );
    expect(
      container
          .read(workspaceStateProvider)
          .browserPanelState
          .expandedDirectoryPaths,
      isNot(contains('/samples')),
    );
  });

  test('restores persisted directories once in a new session', () async {
    const tree = FileTree(name: 'Samples', path: '/samples');
    final service = _FakeSampleBrowserService(
      tree,
      persistedPaths: const ['/samples'],
    );
    final firstSession = ProviderContainer(
      overrides: [sampleBrowserServiceProvider.overrideWithValue(service)],
    );

    final firstNotifier = firstSession.read(workspaceStateProvider.notifier);
    await firstNotifier.restoreSampleDirectories();
    await firstNotifier.restoreSampleDirectories();

    expect(
      firstSession
          .read(workspaceStateProvider)
          .browserPanelState
          .directories['/samples'],
      tree,
    );
    expect(service.scanCount, 1);
    firstSession.dispose();

    final secondSession = ProviderContainer(
      overrides: [sampleBrowserServiceProvider.overrideWithValue(service)],
    );
    await secondSession
        .read(workspaceStateProvider.notifier)
        .restoreSampleDirectories();

    expect(
      secondSession
          .read(workspaceStateProvider)
          .browserPanelState
          .directories['/samples'],
      tree,
    );
    expect(service.scanCount, 2);
    secondSession.dispose();
  });

  test('stops restoring when its provider container is disposed', () async {
    final service = _DelayedRestoreSampleBrowserService();
    final container = ProviderContainer(
      overrides: [sampleBrowserServiceProvider.overrideWithValue(service)],
    );

    final restore = container
        .read(workspaceStateProvider.notifier)
        .restoreSampleDirectories();
    container.dispose();
    service.loadCompleter.complete(Result.ok(const ['/samples']));

    expect(await restore, isA<Ok<void>>());
  });

  testWidgets('panel renders browser samples as draggable rows', (
    tester,
  ) async {
    const sample = BrowserSample(name: 'kick.wav', path: '/samples/kick.wav');
    const tree = FileTree(
      name: 'Samples',
      path: '/samples',
      samples: IListConst<BrowserSample>([sample]),
    );
    final container = ProviderContainer(
      overrides: [
        sampleBrowserServiceProvider.overrideWithValue(
          _FakeSampleBrowserService(tree),
        ),
      ],
    );
    await container.read(workspaceStateProvider.notifier).addSampleDirectory();
    final scrollController = ScrollController();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SampleBrowserPanel(scrollController: scrollController),
          ),
        ),
      ),
    );

    expect(find.text('Sample Browser'), findsOneWidget);
    expect(find.text('Samples'), findsOneWidget);
    expect(find.text('kick.wav'), findsOneWidget);
    expect(find.byType(Draggable<BrowserSample>), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    scrollController.dispose();
    container.dispose();
  });
}
