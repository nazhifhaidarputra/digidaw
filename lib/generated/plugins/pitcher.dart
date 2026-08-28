// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: effect_pitcher

import 'package:karbeat/src/rust/api/plugin.dart';

class PitcherSpecs {
  static const int id = 227290430;
  static const String idString = 'effect_pitcher';
  static const String name = 'Pitcher';
  static const bool isSynth = false;

  static const UiPluginParameter enginePitchRatio = UiPluginParameter(
    id: 1749825986,
    path: 'engine/pitch_ratio',
    name: 'Pitch Ratio',
    group: 'Pitcher',
    value: 1.0,
    min: 0.5,
    max: 2.0,
    defaultValue: 1.0,
    step: 0.001,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter enginePreserveFormants = UiPluginParameter(
    id: 158460893,
    path: 'engine/preserve_formants',
    name: 'Preserve Formants',
    group: 'Pitcher',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const List<UiPluginParameter> allParameters = [enginePitchRatio, enginePreserveFormants];
}
