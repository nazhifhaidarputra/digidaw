import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:karbeat/app/providers/project_provider.dart';
import 'package:karbeat/core/utils/logger.dart';
import 'package:karbeat/src/rust/api/plugin.dart';
import 'package:karbeat/src/rust/api/project.dart';

part 'audio_plugins_service.freezed.dart';

@freezed
abstract class PluginRegistry with _$PluginRegistry {
  const factory PluginRegistry(
    {
      @Default(IListConst<UiPluginInfo>([])) IList<UiPluginInfo> availablePlugins,
    }
  ) = _PluginRegistry;
}

extension PluginRegistryExtension on PluginRegistry {
  PluginRegistry addPlugin(UiPluginInfo plugin) {
    return copyWith(
      availablePlugins: availablePlugins.add(plugin),
    );
  }

  PluginRegistry removePlugin(UiPluginInfo plugin) {
    return copyWith(
      availablePlugins: availablePlugins.remove(plugin),
    );
  }

  PluginRegistry addPlugins(Iterable<UiPluginInfo> plugins) {
    return copyWith(
      availablePlugins: availablePlugins.addAll(plugins),
    );
  }

  PluginRegistry removePlugins(Iterable<UiPluginInfo> plugins) {
    return copyWith(
      availablePlugins: availablePlugins.removeAll(plugins),
    );
  }

  PluginRegistry removeAllGenerators() {
    return copyWith(
      availablePlugins: availablePlugins.where((plugin) => plugin.pluginType != KarbeatPluginType.generator).toIList(),
    );
  }

  PluginRegistry removeAllEffects() {
    return copyWith(
      availablePlugins: availablePlugins.where((plugin) => plugin.pluginType != KarbeatPluginType.effect).toIList(),
    );
  }
}

@freezed
abstract class PluginState with _$PluginState {
  const factory PluginState(PluginRegistry registry) = _PluginState;
}

class PluginNotifier extends AsyncNotifier<PluginState> {
 DawContext get _ctx => ref.read(projectProvider.notifier).dawContext;

  @override
  Future<PluginState> build() async {
    // Await the Project Provider to ensure the DawContext is fully initialized first
    await ref.watch(projectProvider.future);
    
    final state = const PluginState(PluginRegistry());

    // 1. Replicate GlobalAppState constructor behavior: Fetch on boot
    try {
      final generators = await getAvailableGeneratorsWithIds(ctx: _ctx);
      final effects = await getAvailableEffectsWithIds(ctx: _ctx);

      return state.copyWith(
        registry: state.registry.addPlugins([...generators, ...effects]),
      );
    } catch (e) {
      AppLogger.error("Failed to initialize plugin registry: $e");
      // Return empty registry on failure so the app doesn't fatally crash
      return state;
    }
  }

  // ------------------------------------------------------------------
  // Synchronisation Actions
  // ------------------------------------------------------------------

  Future<void> fetchAvailableGenerators() async {
    final result = await AsyncValue.guard(() async {
      final list = await getAvailableGeneratorsWithIds(ctx: _ctx);
      
      if (state.hasValue) {
        final currentRegistry = state.requireValue.registry;
        // Purge old generators and replace with fresh list to avoid duplicates
        final updatedRegistry = currentRegistry.removeAllGenerators().addPlugins(list);
        state = AsyncData(state.requireValue.copyWith(registry: updatedRegistry));
      }
    });

    if (result.hasError) {
      AppLogger.error("Error fetching generators: ${result.error}");
    }
  }

  Future<void> fetchAvailableEffects() async {
    final result = await AsyncValue.guard(() async {
      final list = await getAvailableEffectsWithIds(ctx: _ctx);
      
      if (state.hasValue) {
        final currentRegistry = state.requireValue.registry;
        // Purge old effects and replace with fresh list
        final updatedRegistry = currentRegistry.removeAllEffects().addPlugins(list);
        state = AsyncData(state.requireValue.copyWith(registry: updatedRegistry));
      }
    });

    if (result.hasError) {
      AppLogger.error("Error fetching effect plugins: ${result.error}");
    }
  }

  // ------------------------------------------------------------------
  // Local State Mutations
  // ------------------------------------------------------------------

  void addPlugin(UiPluginInfo plugin) {
    if (!state.hasValue) return;
    state = AsyncData(
      state.requireValue.copyWith(
        registry: state.requireValue.registry.addPlugin(plugin),
      ),
    );
  }

  void removePlugin(UiPluginInfo plugin) {
    if (!state.hasValue) return;
    state = AsyncData(
      state.requireValue.copyWith(
        registry: state.requireValue.registry.removePlugin(plugin),
      ),
    );
  }

  // ------------------------------------------------------------------
  // UI Getters
  // ------------------------------------------------------------------

  /// Returns a clean list of generators synchronously.
  /// Safe to call directly from the UI once the provider `hasValue`.
  List<UiPluginInfo> getAvailableGenerators() {
    if (!state.hasValue) return [];
    return state.requireValue.registry.availablePlugins
        .where((plugin) => plugin.pluginType == KarbeatPluginType.generator)
        .toList();
  }

  /// Returns a clean list of effects synchronously.
  List<UiPluginInfo> getAvailableEffects() {
    if (!state.hasValue) return [];
    return state.requireValue.registry.availablePlugins
        .where((plugin) => plugin.pluginType == KarbeatPluginType.effect)
        .toList();
  }
}

final audioPluginProvider = AsyncNotifierProvider<PluginNotifier, PluginState>(PluginNotifier.new);