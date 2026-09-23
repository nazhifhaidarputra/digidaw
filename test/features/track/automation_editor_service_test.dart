import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/models/automation_lane_clipboard.dart';
import 'package:karbeat/features/track/services/automation_editor_service.dart';

void main() {
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
