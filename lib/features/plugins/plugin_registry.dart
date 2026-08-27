import 'package:karbeat/features/plugins/abstract_plugin_screen.dart';
import 'package:karbeat/features/plugins/effects/effects.dart';
import 'package:karbeat/features/plugins/generators/generators.dart';
import 'package:karbeat/src/rust/api/plugin.dart' as plugin_api;

import '../../generated/plugins/plugins.dart';

/// A unified builder signature now that both effects and generators
/// inherit from AbstractPluginScreen.
typedef PluginScreenBuilder =
    AbstractPluginScreen Function(
      plugin_api.UiPluginTarget target,
      int pluginId,
    );

class PluginRegistryFlutter {
  PluginRegistryFlutter._();

  // ===========================================================================
  // EFFECTS REGISTRY
  // ===========================================================================
  static final Map<int, PluginScreenBuilder> _effects = {
    DigiParametricEQSpecs.id: (target, id) =>
        KarbeatParametricEq(target: target),
    PitcherSpecs.id: (target, pluginId) => DigidawPitcher(target: target),
  };

  // ===========================================================================
  // GENERATORS REGISTRY
  // ===========================================================================
  static final Map<int, PluginScreenBuilder> _generators = {
    KarbeatzerV2Specs.id: (target, id) => KarbeatzerScreen(target: target),
    MyRetroSpecs.id: (target, id) => MyRetroSynth(target: target),
  };

  // ===========================================================================
  // UNIFIED GETTER
  // ===========================================================================

  /// Retrieves the correct screen widget for ANY plugin type.
  ///
  /// [registryId] is the blueprint ID (from the generated Specs).
  /// [instanceId] is the living instance ID (from the audio engine).
  /// [target] is the unified FFI target.
  static AbstractPluginScreen getScreen({
    required int registryId,
    required int instanceId,
    required plugin_api.UiPluginTarget target,
  }) {
    // 1. Check Effects First
    if (_effects.containsKey(registryId)) {
      return _effects[registryId]!(target, instanceId);
    }

    // 2. Check Generators Second
    if (_generators.containsKey(registryId)) {
      return _generators[registryId]!(target, instanceId);
    }

    // 3. Throw a helpful error if totally unregistered
    throw Exception(
      'UI Screen not found for Registry ID $registryId. '
      'Did you forget to add it to the PluginRegistry mappings?',
    );
  }

  // ===========================================================================
  // TYPE-SPECIFIC GETTERS (Optional convenience methods)
  // ===========================================================================

  /// Strict fetcher if you absolutely know it's a generator.
  /// Since generators are always targeted by GeneratorId, we can infer the target.
  static AbstractPluginScreen getGeneratorScreen({
    required int registryId,
    required int instanceId,
  }) {
    final builder = _generators[registryId];
    if (builder == null) {
      throw Exception(
        'Generator UI Screen not found for Registry ID $registryId.',
      );
    }

    // Automatically construct the generator target
    final target = plugin_api.UiPluginTarget.generator(instanceId);
    return builder(target, instanceId);
  }
}
