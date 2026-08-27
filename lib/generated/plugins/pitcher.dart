// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: effect_pitcher

import 'package:karbeat/src/rust/api/plugin.dart';

class PitcherSpecs {
  static const int id = 227290430;
  static const String idString = 'effect_pitcher';
  static const String name = 'Pitcher';
  static const bool isSynth = false;

  static const UiPluginParameter mode = UiPluginParameter(
    id: 3966689298,
    path: 'mode',
    name: 'Pitch Shift mode',
    group: 'Pitcher',
    value: 0.0,
    min: 0.0,
    max: 0.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['TDPSOLA'],
  );

  static const UiPluginParameter pitchShiftEnginePitchRatio = UiPluginParameter(
    id: 3250024140,
    path: 'pitch_shift_engine/pitch_ratio',
    name: 'Pitch Ratio',
    group: 'Pitcher',
    value: 1.0,
    min: 0.5,
    max: 2.0,
    defaultValue: 1.0,
    step: 0.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const List<UiPluginParameter> allParameters = [mode, pitchShiftEnginePitchRatio];
}
