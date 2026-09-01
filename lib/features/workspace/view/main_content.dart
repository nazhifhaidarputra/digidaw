import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/scheduler.dart';
import 'package:karbeat/app/providers/mixer_state.dart';
import 'package:karbeat/app/providers/notification_provider.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/app/providers/track_list_state.dart';
import 'package:karbeat/app/providers/workspace_state.dart';
import 'package:karbeat/features/workspace/view/control_panel.dart';
import 'package:karbeat/features/mixer/view/mixer_screen.dart';
import 'package:karbeat/features/piano_roll/view/piano_roll_screen.dart';
import 'package:karbeat/features/source/view/source_list_screen.dart';
import 'package:karbeat/features/setting/services/appearance_settings_provider.dart';
import 'package:karbeat/features/track/view/track_list_screen.dart';
import 'package:karbeat/shared/enums/global.dart';
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/mixer.dart';
import 'package:karbeat/core/utils/logger.dart';

class MainContent extends ConsumerStatefulWidget {
  const MainContent({super.key});

  @override
  ConsumerState<MainContent> createState() => _MainContentState();
}

class _MainContentState extends ConsumerState<MainContent>
    with SingleTickerProviderStateMixin {
  late final Ticker _mixerTelemetryTicker;
  late final DawContext _dawContext;
  late final ProviderSubscription<WorkspaceView> _workspaceSubscription;
  bool _telemetryActive = false;

  @override
  void initState() {
    super.initState();
    _dawContext = ref.read(projectProvider.notifier).dawContext;
    _mixerTelemetryTicker = createTicker((_) {
      ref.read(mixerStateProvider.notifier).pollTelemetry();
    });
    _workspaceSubscription = ref.listenManual(
      workspaceStateProvider.select((state) => state.currentView),
      (_, view) => _setTelemetryActive(_showsMixerMeters(view)),
    );
    _setTelemetryActive(
      _showsMixerMeters(ref.read(workspaceStateProvider).currentView),
    );
  }

  bool _showsMixerMeters(WorkspaceView view) {
    return view == WorkspaceView.trackList || view == WorkspaceView.mixer;
  }

  void _setTelemetryActive(bool active) {
    if (_telemetryActive == active) return;
    _telemetryActive = active;
    if (active) {
      _mixerTelemetryTicker.start();
    } else {
      _mixerTelemetryTicker.stop();
    }
    unawaited(_updateTelemetrySubscription(active));
  }

  Future<void> _updateTelemetrySubscription(bool active) async {
    try {
      await setMixerTelemetrySubs(ctx: _dawContext, active: active);
    } catch (error) {
      AppLogger.error('Could not update mixer telemetry subscription: $error');
      ref
          .read(notificationProvider.notifier)
          .error(error, title: 'Mixer telemetry unavailable');
    }
  }

  @override
  void dispose() {
    _workspaceSubscription.close();
    if (_telemetryActive) {
      unawaited(_updateTelemetrySubscription(false));
    }
    _mixerTelemetryTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentView = ref.watch(
      workspaceStateProvider.select((s) => s.currentView),
    );
    final hasBackground = ref.watch(
      appearanceSettingsProvider.select(
        (state) => state.backgroundImagePath != null,
      ),
    );

    return Container(
      color: hasBackground ? Colors.transparent : Colors.grey.shade800,
      child: Column(
        children: [
          SafeArea(
            top: true,
            bottom: false,
            child: Container(
              color: Colors.grey.shade50,
              child: const DefaultControlPanel(),
            ),
          ),
          Expanded(
            child: _buildMainContentNavigator(context, ref, currentView),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContentNavigator(
    BuildContext context,
    WidgetRef ref,
    WorkspaceView currentView,
  ) {
    final navigatorKey = _MainContentNavigatorKey(currentView);

    return NavigatorPopHandler<Object?>(
      onPopWithResult: (result) {
        navigatorKey.currentState?.pop(result);
      },
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (routeContext) =>
              _buildWorkspaceView(routeContext, ref, currentView),
        ),
      ),
    );
  }

  Widget _buildWorkspaceView(
    BuildContext context,
    WidgetRef ref,
    WorkspaceView currentView,
  ) {
    switch (currentView) {
      case WorkspaceView.trackList:
        return const TrackListScreen();
      case WorkspaceView.source:
        return SourceListScreen();
      case WorkspaceView.pianoRoll:
        return _buildPianoRoll(ref);
      case WorkspaceView.mixer:
        return const MixerScreen();
    }
  }

  Widget _buildPianoRoll(WidgetRef ref) {
    final trackState = ref.watch(trackListStateProvider);
    final projectState = ref.watch(projectProvider);

    // Try to get pattern from focused clip (most recently selected)
    final clipId = trackState.focusClipId;
    final trackId = trackState.selectedTrackId;
    int? resultPatternId;
    int? generatorId;

    if (clipId != null && trackId != null) {
      final track = projectState.value?.tracks[trackId];
      if (track != null) {
        for (final clip in track.clips) {
          if (clip.id == clipId) {
            if (clip.source case UiClipSource_Midi(:final patternId)) {
              resultPatternId = patternId;
              generatorId = track.generatorId;
            }
          }
        }
      }
    }

    // Fallback: Use editingPatternId (from source list)
    resultPatternId ??= ref.read(workspaceStateProvider).editingPatternId;

    return PianoRollScreen(
      patternId: resultPatternId,
      generatorId: generatorId,
    );
  }
}

/// Keeps detail routes scoped below the control panel. Changing the top-level
/// workspace view produces a different key, discarding that view's detail
/// stack and showing the new workspace root immediately.
class _MainContentNavigatorKey extends GlobalObjectKey<NavigatorState> {
  const _MainContentNavigatorKey(super.value);
}
