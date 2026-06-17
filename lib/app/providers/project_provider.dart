import 'dart:async';

import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:karbeat/core/services/serializer_service.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/core/utils/result_type.dart';

// Rust FFI Imports
import 'package:karbeat/src/rust/api/project.dart';
import 'package:karbeat/src/rust/api/pattern.dart';
import 'package:karbeat/src/rust/api/mixer.dart' as mixer_api;
import 'package:karbeat/src/rust/api/automation.dart';
import 'package:karbeat/src/rust/api/serialization.dart' as serialization_api;

part 'project_provider.freezed.dart';

// ============================================================
// Dependency Injection
// ============================================================

/// Provider for the SerializerService so ProjectNotifier can depend on it
/// to save and load the project files without coupling directly to disk I/O.
final serializerServiceProvider = Provider<SerializerService>((ref) {
  return SerializerService();
});

// ============================================================
// Single Optimized Data Store (The Absolute Truth)
// ============================================================

/// The singular optimized data store representing the fully serialized
/// ApplicationState document. It leverages `fast_immutable_collections` to ensure
/// immutability, safety, and performance across the UI layer.
@freezed
abstract class ApplicationDataStore with _$ApplicationDataStore {
  const factory ApplicationDataStore({
    String? currentFilePath,
    required UiProjectMetadata metadata,
    required UiTransportState transport,
    required UiAudioHardwareConfig hardwareConfig,
    required IMap<int, UiTrack> tracks,
    required IMap<int, UiGeneratorInstance> generators,
    required IMap<int, UiPattern> patterns,
    required mixer_api.UiMixerState mixer,
    required IMap<int, ModulationLinkDto> modulationLinks,
    required IMap<int, AutomationLaneDto> automationPool,
    required IMap<int, ModulationSourceDto> modulationSources,
  }) = _ApplicationDataStore;
}

// ============================================================
// Core Async Notifier
// ============================================================

/// The top-level provider responsible for owning the optimized data store.
/// It coordinates the initialization, saving, and loading of projects.
class ProjectNotifier extends AsyncNotifier<ApplicationDataStore> {
  @override
  Future<ApplicationDataStore> build() async {
    // 1. Initialize a blank project from the Rust backend on boot
    final uiState = await serialization_api.newBlankProject();
    return await _fetchFullState(uiState, null);
  }

  /// Converts the raw mutable Rust FFI structs into our optimized ICollection store.
  Future<ApplicationDataStore> _fetchFullState(UiApplicationState state, String? path) async {
    // Modulations might not be deeply nested in UiApplicationState,
    // so we fetch them alongside the main state load to ensure consistency.
    final (links, lanes, sources) = await (
      getAllLinkedModulationParams(),
      getAutomationsLanesAll(),
      getAllModulationSources(),
    ).wait;

    return ApplicationDataStore(
      currentFilePath: path,
      metadata: state.metadata,
      transport: state.transport,
      hardwareConfig: state.hardwareConfig,
      tracks: state.tracks.lock,
      generators: state.generators.lock,
      patterns: state.patterns.lock,
      mixer: state.mixer,
      modulationLinks: links.lock,
      automationPool: lanes.lock,
      modulationSources: sources.lock,
    );
  }

  /// Load a project from disk relying on the injected `SerializerService`.
  Future<Result<void>> loadProject(String path) async {
    final result = await AsyncValue.guard(() async {
      final serializer = ref.read(serializerServiceProvider);
      final uiState = await serializer.loadProject(pathName: path);
      return _fetchFullState(uiState, path);
    });
    state = result;
    return result.hasError ? Result.error(Exception(result.error.toString())) : Result.ok(null);
  }

  /// Save the current project to disk relying on the injected `SerializerService`.
  Future<Result<void>> saveProject(String path) async {
    try {
      final serializer = ref.read(serializerServiceProvider);
      await serializer.saveProject(pathName: path);

      // Softly update the current path immediately
      if (state.hasValue) {
        state = AsyncValue.data(state.requireValue.copyWith(currentFilePath: path));
      }

      AppLogger.info("Project saved successfully to $path");
      return Result.ok(null);
    } catch (e) {
      AppLogger.error("Failed to save project: $e");
      return Result.error(Exception(e.toString()));
    }
  }

  // ====================================================================
  // Granular State Merging (For Feature Notifiers)
  // ====================================================================
  // Rather than making `TrackListNotifier` duplicate large maps,
  // it can push updates into this central truth repository.

  /// Adds or updates a single track in O(1) time
  void upsertTrack(int trackId, UiTrack updatedTrack) {
    if (state.hasValue) {
      final current = state.requireValue;
      state = AsyncValue.data(current.copyWith(tracks: current.tracks.add(trackId, updatedTrack)));
    }
  }

  /// Removes a track in O(1) time
  void removeTrack(int trackId) {
    if (state.hasValue) {
      final current = state.requireValue;
      state = AsyncValue.data(current.copyWith(tracks: current.tracks.remove(trackId)));
    }
  }

  /// Updates multiple tracks at once (e.g., during a bulk move)
  void upsertTracksBulk(Map<int, UiTrack> updatedTracks) {
    if (state.hasValue) {
      final current = state.requireValue;
      state = AsyncValue.data(current.copyWith(tracks: current.tracks.addAll(updatedTracks.lock)));
    }
  }

  /// insert or update if exists of generator
  void upsertGenerator(int genId, UiGeneratorInstance updatedGen) {
    if (state.hasValue) {
      final current = state.requireValue;
      state = AsyncValue.data(current.copyWith(generators: current.generators.add(genId, updatedGen)));
    }
  }

  void removeGenerator(int genId) {
    if (state.hasValue) {
      final current = state.requireValue;
      state = AsyncValue.data(current.copyWith(generators: current.generators.remove(genId)));
    }
  }

  void updateMixer(mixer_api.UiMixerState newMixer) {
    if (state.hasValue) {
      state = AsyncValue.data(state.requireValue.copyWith(mixer: newMixer));
    }
  }

  void updatePatterns(Map<int, UiPattern> newPatterns) {
    if (state.hasValue) {
      state = AsyncValue.data(state.requireValue.copyWith(patterns: newPatterns.lock));
    }
  }

  void updateTransport(UiTransportState transport) {
    if (state.hasValue) {
      state = AsyncValue.data(state.requireValue.copyWith(transport: transport));
    }
  }

  void updateAutomations({
    Map<int, ModulationLinkDto>? links,
    Map<int, AutomationLaneDto>? pool,
    Map<int, ModulationSourceDto>? sources,
  }) {
    if (state.hasValue) {
      state = AsyncValue.data(
        state.requireValue.copyWith(
          modulationLinks: links?.lock ?? state.requireValue.modulationLinks,
          automationPool: pool?.lock ?? state.requireValue.automationPool,
          modulationSources: sources?.lock ?? state.requireValue.modulationSources,
        ),
      );
    }
  }
}

// ============================================================
// Global Provider Export
// ============================================================

final projectProvider = AsyncNotifierProvider<ProjectNotifier, ApplicationDataStore>(ProjectNotifier.new);
