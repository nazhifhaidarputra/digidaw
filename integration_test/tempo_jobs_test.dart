import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:karbeat/app/app.dart';
import 'package:karbeat/app/providers/background_jobs_provider.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/features/source/view/audio_properties_screen.dart';
import 'package:karbeat/src/rust/api/audio.dart' as audio_api;
import 'package:karbeat/src/rust/api/audio_analysis.dart' as analysis_api;
import 'package:karbeat/src/rust/api/jobs.dart' show UiJobState_Progress;
import 'package:karbeat/src/rust/api/project.dart' as project_api;
import 'package:karbeat/src/rust/api/track.dart' as track_api;
import 'package:karbeat/src/rust/api/transport.dart' as transport_api;

/// 16-bit stereo WAV of a drum loop at [bpm]: kick on 1 and 3, snare on 2
/// and 4, noisy hats on eighths.
Uint8List drumLoopWav({required double seconds, required double bpm}) {
  const rate = 44100;
  final frames = (seconds * rate).round();
  final eighth = 30 / bpm * rate;
  var seed = 0x2545f491;
  double noise() {
    seed ^= (seed << 13) & 0xffffffff;
    seed ^= seed >> 17;
    seed ^= (seed << 5) & 0xffffffff;
    return seed / 0xffffffff * 2 - 1;
  }

  final mono = Float64List(frames);
  for (var step = 0; ; step++) {
    final start = (step * eighth).floor();
    if (start >= frames) break;
    for (
      var offset = 0;
      offset < rate ~/ 4 && start + offset < frames;
      offset++
    ) {
      final t = offset / rate;
      var value = 0.15 * math.exp(-t * 120) * noise();
      if (step % 4 == 0) {
        final pitch = 50 + 90 * math.exp(-t * 30);
        value += 0.9 * math.exp(-t * 25) * math.sin(2 * math.pi * pitch * t);
      }
      if (step % 4 == 2) {
        value +=
            0.5 * math.exp(-t * 30) * noise() +
            0.3 * math.exp(-t * 20) * math.sin(2 * math.pi * 190 * t);
      }
      mono[start + offset] += value;
    }
  }
  final data = ByteData(frames * 4);
  for (var frame = 0; frame < frames; frame++) {
    final sample = (mono[frame].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(frame * 4, sample, Endian.little);
    data.setInt16(frame * 4 + 2, sample, Endian.little);
  }
  final header = ByteData(44)
    ..setUint32(0, 0x46464952, Endian.little)
    ..setUint32(4, 36 + frames * 4, Endian.little)
    ..setUint32(8, 0x45564157, Endian.little)
    ..setUint32(12, 0x20746d66, Endian.little)
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, 2, Endian.little)
    ..setUint32(24, rate, Endian.little)
    ..setUint32(28, rate * 4, Endian.little)
    ..setUint16(32, 4, Endian.little)
    ..setUint16(34, 16, Endian.little)
    ..setUint32(36, 0x61746164, Endian.little)
    ..setUint32(40, frames * 4, Endian.little);
  return Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...data.buffer.asUint8List(),
  ]);
}

/// RMS of a 16-bit PCM WAV's samples.
double wavRms(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (id == 'data') {
      var sum = 0.0;
      final count = size ~/ 2;
      for (var i = 0; i < count; i++) {
        final sample = data.getInt16(offset + 8 + i * 2, Endian.little) / 32768;
        sum += sample * sample;
      }
      return count == 0 ? 0 : math.sqrt(sum / count);
    }
    offset += 8 + size + (size & 1);
  }
  return 0;
}

/// Polls the source until [done] holds for its properties.
Future<project_api.AudioWaveformUiForAudioProperties> waitForSource(
  WidgetTester tester,
  project_api.DawContext ctx,
  int sourceId,
  bool Function(project_api.AudioWaveformUiForAudioProperties) done,
) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    final props = await tester.runAsync(
      () => audio_api.getAudioProperties(ctx: ctx, id: sourceId),
    );
    if (props != null && done(props)) return props;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
  throw StateError('source $sourceId never reached the expected state');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('detects tempo and fits a source through background jobs', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        observers: [NotificationProviderObserver()],
        child: KarbeatApp(),
      ),
    );
    for (var attempt = 0; attempt < 60; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
      if (find.text('Tracks').evaluate().isNotEmpty) break;
    }
    expect(find.text('Tracks'), findsWidgets);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp).first),
    );
    final jobs = container.read(backgroundJobsProvider.notifier);
    final ctx = container.read(projectProvider.notifier).dawContext;

    final wav = File('${Directory.systemTemp.path}/karbeat_drums_120.wav');
    await tester.runAsync(
      () => wav.writeAsBytes(drumLoopWav(seconds: 20, bpm: 120)),
    );
    final sourceId = (await tester.runAsync(
      () => project_api.addAudioSource(ctx: ctx, filePath: wav.path),
    ))!;
    debugPrint('[tempo-e2e] imported source $sourceId');

    // Models configure asynchronously at startup; retry until they are ready.
    int? detection;
    for (var attempt = 0; attempt < 40 && detection == null; attempt++) {
      try {
        final id = await tester.runAsync(
          () => analysis_api.startTempoDetection(ctx: ctx, sourceId: sourceId),
        );
        final outcome = await tester.runAsync(() => jobs.awaitJob(id!));
        if (outcome!.isOk()) {
          detection = id;
        } else {
          debugPrint('[tempo-e2e] detection attempt failed: ${outcome.err()}');
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 500)),
          );
        }
      } catch (error) {
        debugPrint('[tempo-e2e] detection not started: $error');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
      }
    }
    expect(detection, isNotNull, reason: 'tempo detection never succeeded');

    var props = (await tester.runAsync(
      () => audio_api.getAudioProperties(ctx: ctx, id: sourceId),
    ))!;
    debugPrint(
      '[tempo-e2e] detected ${props.beatGrid?.bpm} BPM, '
      '${props.beatGrid?.beats.length} beats, '
      'confidence ${props.beatGrid?.confidence}',
    );
    expect(props.beatGrid, isNotNull);
    expect((props.beatGrid!.bpm - 120).abs(), lessThan(1.0));

    await tester.runAsync(() => transport_api.setBpm(ctx: ctx, val: 100));
    final fit = (await tester.runAsync(
      () => analysis_api.startFitToTempo(
        ctx: ctx,
        sourceId: sourceId,
        warp: true,
      ),
    ))!;
    final fitted = await tester.runAsync(() => jobs.awaitJob(fit));
    expect(
      fitted!.isOk(),
      isTrue,
      reason: '${fitted.isErr() ? fitted.err() : ''}',
    );

    props = (await tester
        .runAsync<project_api.AudioWaveformUiForAudioProperties?>(
          () => audio_api.getAudioProperties(ctx: ctx, id: sourceId),
        ))!;
    debugPrint(
      '[tempo-e2e] fitted=${props.fitted} warp=${props.warp} '
      'renderReady=${props.renderReady} mode=${props.sampleMode}',
    );
    expect(props.fitted, isTrue);
    expect(props.warp, isTrue);
    expect(props.renderReady, isTrue);

    // The fitted source is audible, also while the realtime stretch follows a
    // tempo change before the high-quality re-render lands.
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
    await tester.runAsync(() => transport_api.setBpm(ctx: ctx, val: 110));
    final export = File('${Directory.systemTemp.path}/karbeat_fit_export.wav');
    await tester.runAsync(
      () => project_api
          .exportProjectFlutter(
            ctx: ctx,
            outputPath: export.path,
            config: const project_api.AudioExportConfigDTO.wav(
              project_api.WavExportConfigDTO(
                sampleRate: 44100,
                channels: 2,
                bitDepth: project_api.BitDepthDTO.bitPerSample(16),
              ),
            ),
            tailHandling: project_api.TailHandlingDTO.cutRemaining,
            range: const project_api.ExportRangeDTO.song(),
          )
          .drain<void>(),
    );
    final rms = wavRms((await tester.runAsync(export.readAsBytes))!);
    debugPrint('[tempo-e2e] exported fitted clip at 110 BPM, rms $rms');
    expect(rms, greaterThan(0.02));

    // Offline edits render in the background.
    await tester.runAsync(
      () => analysis_api.setWaveformEdits(
        ctx: ctx,
        sourceId: sourceId,
        normalize: true,
        invert: false,
        reverse: true,
      ),
    );
    props = await waitForSource(
      tester,
      ctx,
      sourceId,
      (p) => p.reverse && p.normalized && p.renderReady,
    );
    debugPrint(
      '[tempo-e2e] reverse + normalize rendered, fitted=${props.fitted}',
    );

    await tester.runAsync(
      () => analysis_api.setAudioSourceSampleMode(
        ctx: ctx,
        sourceId: sourceId,
        mode: project_api.UiAudioSampleMode.resampled,
      ),
    );
    props = await waitForSource(
      tester,
      ctx,
      sourceId,
      (p) =>
          p.sampleMode == project_api.UiAudioSampleMode.resampled &&
          !p.fitted &&
          p.renderReady,
    );
    debugPrint(
      '[tempo-e2e] switched to Resampled, reverse kept=${props.reverse}',
    );

    // A long source is analyzed in parallel segments and rendered in parallel
    // chunks; a tempo change mid-render cancels the stale render at once.
    final longWav = File('${Directory.systemTemp.path}/karbeat_drums_long.wav');
    await tester.runAsync(
      () => longWav.writeAsBytes(drumLoopWav(seconds: 90, bpm: 120)),
    );
    final longId = (await tester.runAsync(
      () => project_api.addAudioSource(ctx: ctx, filePath: longWav.path),
    ))!;
    final watch = Stopwatch()..start();
    final longDetection = (await tester.runAsync(
      () => analysis_api.startTempoDetection(ctx: ctx, sourceId: longId),
    ))!;
    final detected = await tester.runAsync(() => jobs.awaitJob(longDetection));
    expect(
      detected!.isOk(),
      isTrue,
      reason: '${detected.isErr() ? detected.err() : ''}',
    );
    debugPrint('[tempo-e2e] detected 90 s source in ${watch.elapsed}');

    await tester.runAsync(() => transport_api.setBpm(ctx: ctx, val: 100));
    final staleFit = (await tester.runAsync(
      () =>
          analysis_api.startFitToTempo(ctx: ctx, sourceId: longId, warp: false),
    ))!;
    for (var attempt = 0; attempt < 200; attempt++) {
      final job = container.read(backgroundJobsProvider).active[staleFit];
      if (job?.state is UiJobState_Progress) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    watch.reset();
    await tester.runAsync(() => transport_api.setBpm(ctx: ctx, val: 105));
    final stale = await tester.runAsync(() => jobs.awaitJob(staleFit));
    debugPrint(
      '[tempo-e2e] stale fit stopped ${watch.elapsed} after the change',
    );
    expect(stale!.isErr(), isTrue);
    expect(stale.err(), isA<BackgroundJobCancelledException>());

    watch.reset();
    final freshFit = (await tester.runAsync(
      () =>
          analysis_api.startFitToTempo(ctx: ctx, sourceId: longId, warp: true),
    ))!;
    final fresh = await tester.runAsync(() => jobs.awaitJob(freshFit));
    expect(
      fresh!.isOk(),
      isTrue,
      reason: '${fresh.isErr() ? fresh.err() : ''}',
    );
    debugPrint('[tempo-e2e] fitted 90 s source in ${watch.elapsed}');
    final longProps = await waitForSource(
      tester,
      ctx,
      longId,
      (p) => p.fitted && p.renderReady,
    );
    expect(longProps.warp, isTrue);

    // The properties screen shows the tempo controls for the fitted source.
    final navigator = Navigator.of(tester.element(find.text('Tracks').first));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AudioPropertiesScreen(sourceId: sourceId, sourceName: 'clicks'),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find.text('Detect tempo').evaluate().isNotEmpty) break;
    }
    expect(find.text('Detect tempo'), findsOneWidget);
    expect(find.text('Fit to tempo'), findsOneWidget);
    expect(find.textContaining('120.0 BPM'), findsOneWidget);
    expect(find.text('Resampled'), findsOneWidget);
    debugPrint('[tempo-e2e] properties screen shows tempo controls');

    expect(tester.takeException(), isNull);
  });
}
