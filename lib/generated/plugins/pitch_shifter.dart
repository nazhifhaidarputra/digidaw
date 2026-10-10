// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: effect_pitch_shifter

import 'package:karbeat/src/rust/api/plugin.dart';

class PitchShifterSpecs {
  static const int id = 3564254673;
  static const String idString = 'effect_pitch_shifter';
  static const String name = 'Pitch Shifter';
  static const bool isSynth = false;

  static const UiPluginParameter enginePitchCents = UiPluginParameter(
    id: 3127562262,
    path: 'engine/pitch_cents',
    name: 'Pitch Cents',
    group: 'Pitcher',
    value: 0.0,
    min: -2400.0,
    max: 2400.0,
    defaultValue: 0.0,
    step: 1.0,
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

  static const List<UiPluginParameter> allParameters = [enginePitchCents, enginePreserveFormants];
}
