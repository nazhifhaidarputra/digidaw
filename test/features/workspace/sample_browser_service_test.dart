import 'dart:async';

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
import 'package:karbeat/src/rust/api/sample_browser.dart';

class _FakeSampleBrowserService extends SampleBrowserService {
  _FakeSampleBrowserService(this.tree);

  final FileTree tree;
  final events = StreamController<UiSampleFolderEvent>.broadcast();
  final addedPaths = <String>[];

  @override
  Future<Result<String?>> pickDirectory() async => Result.ok(tree.path);

  @override
  Stream<UiSampleFolderEvent> watchDirectories() => events.stream;

  @override
  Future<Result<FileTree>> addDirectory(String path) async {
    addedPaths.add(path);
    return Result.ok(tree);
  }
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

    expect(state.isLoadingDirectory, isFalse);
    expect(state.directories, isEmpty);
    expect(state.expandedDirectoryPaths, isEmpty);
    expect(state.selectedSamplePath, isNull);
  });

  test('right panel toggles and follows its selected tab', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(workspaceStateProvider.notifier);

    var state = container.read(workspaceStateProvider);
    expect(state.isRightPanelExpanded, isFalse);
    expect(state.rightPanelTab, RightPanelTab.browser);

    notifier.toggleRightPanel();
    state = container.read(workspaceStateProvider);
    expect(state.isRightPanelExpanded, isTrue);

    notifier.selectRightPanelTab(RightPanelTab.sources);
    state = container.read(workspaceStateProvider);
    expect(state.isRightPanelExpanded, isTrue);
    expect(state.rightPanelTab, RightPanelTab.sources);

    notifier.closeRightPanel();
    expect(
      container.read(workspaceStateProvider).isRightPanelExpanded,
      isFalse,
    );

    notifier.selectRightPanelTab(RightPanelTab.sources);
    expect(container.read(workspaceStateProvider).isRightPanelExpanded, isTrue);
  });

  test('converts Rust folder trees into immutable browser trees', () {
    const dto = UiSampleTree(
      name: 'Samples',
      path: '/samples',
      directories: [
        UiSampleTree(
          name: 'Drums',
          path: '/samples/Drums',
          directories: [],
          samples: [
            UiSampleFile(name: 'kick.flac', path: '/samples/Drums/kick.flac'),
          ],
        ),
      ],
      samples: [UiSampleFile(name: 'zeta.WAV', path: '/samples/zeta.WAV')],
    );

    expect(
      fileTreeFrom(dto),
      const FileTree(
        name: 'Samples',
        path: '/samples',
        directories: IListConst([
          FileTree(
            name: 'Drums',
            path: '/samples/Drums',
            samples: IListConst([
              BrowserSample(
                name: 'kick.flac',
                path: '/samples/Drums/kick.flac',
              ),
            ]),
          ),
        ]),
        samples: IListConst([
          BrowserSample(name: 'zeta.WAV', path: '/samples/zeta.WAV'),
        ]),
      ),
    );
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
    expect(service.addedPaths, ['/samples', '/samples']);

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

  test('renders folders streamed from Rust until it is disposed', () async {
    const tree = FileTree(name: 'Samples', path: '/samples');
    final service = _FakeSampleBrowserService(tree);
    final container = ProviderContainer(
      overrides: [sampleBrowserServiceProvider.overrideWithValue(service)],
    );
    final notifier = container.read(workspaceStateProvider.notifier);
    BrowserPanelState browser() =>
        container.read(workspaceStateProvider).browserPanelState;

    final restored = notifier.watchSampleDirectories();
    expect(identical(notifier.watchSampleDirectories(), restored), isTrue);
    expect(browser().isLoadingDirectory, isTrue);

    service.events
      ..add(
        const UiSampleFolderEvent.scanned(
          tree: UiSampleTree(
            name: 'Samples',
            path: '/samples',
            directories: [],
            samples: [],
          ),
        ),
      )
      ..add(const UiSampleFolderEvent.unavailable(path: '/missing'))
      ..add(const UiSampleFolderEvent.restored());
    expect(await restored, isA<Ok<void>>());
    expect(browser().isLoadingDirectory, isFalse);
    expect(browser().directories['/samples'], tree);
    expect(browser().expandedDirectoryPaths, contains('/samples'));

    // A rescan replaces the tree and keeps the folder collapsed.
    notifier.toggleBrowserDirectory('/samples');
    service.events.add(
      const UiSampleFolderEvent.scanned(
        tree: UiSampleTree(
          name: 'Samples',
          path: '/samples',
          directories: [],
          samples: [UiSampleFile(name: 'kick.wav', path: '/samples/kick.wav')],
        ),
      ),
    );
    await pumpEventQueue();
    expect(browser().directories['/samples']!.samples.single.name, 'kick.wav');
    expect(browser().expandedDirectoryPaths, isNot(contains('/samples')));

    service.events.add(const UiSampleFolderEvent.unavailable(path: '/samples'));
    await pumpEventQueue();
    expect(browser().directories, isEmpty);

    container.dispose();
    await pumpEventQueue();
    expect(service.events.hasListener, isFalse);
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
