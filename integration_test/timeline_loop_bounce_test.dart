import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karbeat/app/app.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/timeline_state.dart';
import 'package:karbeat/features/workspace/view/project_export.dart';
import 'package:karbeat/src/rust/api/project.dart' as project_api;
import 'package:karbeat/src/rust/api/track.dart' as track_api;

/// Two seconds of a 220 Hz stereo sine at half scale, as a 16-bit WAV.
Uint8List sineWav() {
  const rate = 48000;
  const frames = rate * 2;
  final data = ByteData(44 + frames * 4);
  void ascii(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      data.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + frames * 4, Endian.little);
  ascii(8, 'WAVEfmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 2, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 4, Endian.little);
  data.setUint16(32, 4, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 4, Endian.little);
  for (var frame = 0; frame < frames; frame++) {
    final value = (math.sin(2 * math.pi * 220 * frame / rate) * 16384).round();
    data.setInt16(44 + frame * 4, value, Endian.little);
    data.setInt16(46 + frame * 4, value, Endian.little);
  }
  return data.buffer.asUint8List();
}

Finder rulerBar() => find.byWidgetPredicate(
  (widget) => widget.runtimeType.toString() == '_TimelineRulerBar',
);

Future<void> settle(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }
}

Future<void> secondaryTapAt(WidgetTester tester, Offset position) async {
  final gesture = await tester.startGesture(
    position,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.up();
  await settle(tester, frames: 3);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loop region, cue markers, region export and bounce', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        observers: [NotificationProviderObserver()],
        child: KarbeatApp(),
      ),
    );
    for (var attempt = 0; attempt < 60; attempt++) {
      await settle(tester, frames: 1);
      if (find.text('Tracks').evaluate().isNotEmpty) break;
    }
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    final ctx = container.read(projectProvider.notifier).dawContext;

    // A sine clip on an audio track, so the bounce has audio in it
    final wav = File('${Directory.systemTemp.path}/digidaw_bounce_sine.wav');
    await tester.runAsync(() => wav.writeAsBytes(sineWav()));
    final sourceId = (await tester.runAsync(
      () => project_api.addAudioSource(ctx: ctx, filePath: wav.path),
    ))!;
    final track = (await tester.runAsync(
      () => project_api.addNewAudioTrack(ctx: ctx),
    ))!;
    await tester.runAsync(
      () => track_api.createClip(
        ctx: ctx,
        sourceId: sourceId,
        sourceType: track_api.UiSourceType.audio,
        trackId: track.id,
        startTime: 0,
      ),
    );
    container
        .read(projectProvider.notifier)
        .upsertTrack(
          track.id,
          (await tester.runAsync<project_api.UiTrack?>(
            () => track_api.getTrack(ctx: ctx, trackId: track.id),
          ))!,
        );

    // The track list is the default view. Earlier runs that ended with the
    // test may leave a crash report prompt open
    await settle(tester);
    final crashPrompt = find.byKey(const ValueKey('crash-recovery-dialog'));
    if (crashPrompt.evaluate().isNotEmpty) {
      await tester.tap(
        find.descendant(of: crashPrompt, matching: find.text('Close')),
      );
      await settle(tester);
    }
    expect(rulerBar(), findsOneWidget);
    final ruler = tester.getRect(rulerBar());

    // Shift-drag on the ruler draws the loop region
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    final drag = await tester.startGesture(
      ruler.centerLeft + const Offset(20, 0),
      kind: PointerDeviceKind.mouse,
    );
    for (var step = 0; step < 10; step++) {
      await drag.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await drag.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settle(tester);
    final region = container.read(loopRegionProvider);
    expect(region, isNotNull, reason: 'shift-drag should set a loop region');
    expect(region!.endTick, greaterThan(region.startTick));
    debugPrint(
      '[timeline-e2e] loop region ${region.startTick}..${region.endTick}',
    );

    // The ruler menu adds a cue marker where it was opened
    await secondaryTapAt(tester, ruler.centerLeft + const Offset(80, 0));
    expect(find.text('Add Cue Marker Here'), findsOneWidget);
    await tester.tap(find.text('Add Cue Marker Here'));
    await settle(tester);
    expect(container.read(cueMarkersProvider), hasLength(1));
    expect(find.text('Marker 1'), findsOneWidget);

    // Undo removes the marker and keeps the region
    await tester.runAsync(
      () => container.read(projectProvider.notifier).undoLastAction(),
    );
    await settle(tester);
    expect(container.read(cueMarkersProvider), isEmpty);
    expect(container.read(loopRegionProvider), isNotNull);
    await tester.runAsync(
      () => container.read(projectProvider.notifier).redoLastAction(),
    );
    await settle(tester);
    expect(container.read(cueMarkersProvider), hasLength(1));

    // Bounce from the ruler menu adds a source
    final before = (await tester
        .runAsync<Map<int, project_api.AudioWaveformUiForSourceList>?>(
          () => project_api.getAudioSourceList(ctx: ctx),
        ))!;
    await secondaryTapAt(tester, ruler.centerLeft + const Offset(120, 0));
    await tester.tap(find.text('Bounce Loop Region to New Source'));
    Map<int, project_api.AudioWaveformUiForSourceList>? after;
    for (var attempt = 0; attempt < 50; attempt++) {
      await settle(tester, frames: 2);
      after = await tester
          .runAsync<Map<int, project_api.AudioWaveformUiForSourceList>?>(
            () => project_api.getAudioSourceList(ctx: ctx),
          );
      if (after != null && after.length > before.length) break;
    }
    final bounced = after!.values.where(
      (source) => source.name.startsWith('Bounce'),
    );
    expect(bounced, hasLength(1), reason: 'bounce should add one source');
    debugPrint('[timeline-e2e] bounced source "${bounced.first.name}"');
    expect(find.text('Bounced to a new source'), findsOneWidget);

    // Export from the ruler menu opens the panel on the loop region
    await secondaryTapAt(tester, ruler.centerLeft + const Offset(120, 0));
    await tester.tap(find.text('Export Loop Region…'));
    await settle(tester);
    expect(find.text('Export Project'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Loop region'),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ProjectExportPanel),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Loop region'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
