import 'package:karbeat/features/plugins/generators/abstract_generator_screen.dart';
import 'package:karbeat/features/plugins/generators/karbeatzer_screen.dart';
import 'package:karbeat/features/plugins/generators/my_retro_synth.dart';

import 'package:karbeat/generated/plugins/plugins.dart';

typedef GeneratorScreenBuilder =
    AbstractGeneratorScreen Function(int generatorId);

class SynthRegistry {

  SynthRegistry._();

  static final Map<int, GeneratorScreenBuilder> _synths = {
    KarbeatzerV2Specs.id: (id) => KarbeatzerScreen(generatorId: id), 
    MyRetroSpecs.id: (id) => MyRetroSynth(generatorId: id),
  };

  /// Retrieves the correct screen widget for a specific plugin.
  /// 
  /// [registryId] is the stable FNV-1a hash identifying the plugin type.
  /// [instanceId] is the unique ID of the specific generator allocated in the project.
  static AbstractGeneratorScreen getScreen({
    required int registryId,
    required int instanceId,
  }) {
    final builder = _synths[registryId];
    
    if (builder == null) {
      throw Exception(
        'UI Screen not found for Registry ID $registryId. '
        'Did you forget to add it to SynthRegistry?'
      );
    }
    
    return builder(instanceId);
  }
}
