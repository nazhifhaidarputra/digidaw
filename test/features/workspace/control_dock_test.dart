import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/app/providers/transport_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/core/l10n/localizer.dart';
import 'package:karbeat/features/workspace/view/control_panel.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/project.dart';

class _TransportNotifier extends TransportNotifier {
  @override
  Future<TransportStateData> build() async => const TransportStateData(
    state: UiTransportState(bpm: 120, timeSignature: (4, 4)),
    sampleRate: 48000,
  );
}

class _BackgroundJobsNotifier extends BackgroundJobsNotifier {
  @override
  BackgroundJobsState build() => const BackgroundJobsState();
}

void main() {
  late ProviderContainer container;

  /// Pumps the dock at [width] logical pixels, as wide as the workspace.
  Future<void> pumpDock(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer(
      overrides: [
        transportProvider.overrideWith(_TransportNotifier.new),
        transportPositionStreamProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        backgroundJobsProvider.overrideWith(_BackgroundJobsNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: WorkspaceControlDock(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a large screen shows every view, readout field and toggle', (
    tester,
  ) async {
    await pumpDock(tester, 1400);

    expect(tester.takeException(), isNull);
    for (final label in [
      tr('workspace-view-tracks'),
      tr('workspace-view-piano-roll'),
      tr('workspace-view-mixer'),
      tr('workspace-view-source'),
      tr('workspace-readout-bar'),
      tr('workspace-readout-signature'),
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byTooltip(tr('workspace-metronome')), findsOneWidget);
    expect(find.byTooltip(tr('workspace-dock-more')), findsNothing);
  });

  testWidgets('a phone keeps one-tap segments and moves toggles behind more', (
    tester,
  ) async {
    // An 844 px phone, less the 60 px sidebar.
    await pumpDock(tester, 784);

    expect(tester.takeException(), isNull);
    // Only the selected view keeps its label.
    expect(find.text(tr('workspace-view-tracks')), findsOneWidget);
    expect(find.text(tr('workspace-view-mixer')), findsNothing);
    expect(find.text(tr('workspace-readout-bar')), findsNothing);
    expect(find.byTooltip(tr('workspace-dock-more')), findsOneWidget);

    await tester.tap(find.byTooltip(tr('workspace-tool-draw')));
    await tester.pump();
    expect(
      container.read(workspaceStateProvider).selectedTool,
      ToolSelection.draw,
    );
  });

  testWidgets('a small phone collapses views and tools into popovers', (
    tester,
  ) async {
    await pumpDock(tester, 600);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip(tr('workspace-dock-switch-view')), findsOneWidget);
    expect(find.byTooltip(tr('workspace-dock-pick-tool')), findsOneWidget);

    await tester.tap(find.byTooltip(tr('workspace-dock-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('workspace-snap-to-grid')));
    await tester.pumpAndSettle();
    expect(container.read(workspaceStateProvider).snapToGrid, isTrue);
  });
}
