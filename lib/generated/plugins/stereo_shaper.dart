// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: effect_stereo_shaper

import 'package:karbeat/src/rust/api/plugin.dart';

class DigidawStereoShaperSpecs {
  static const int id = 329376391;
  static const String idString = 'effect_stereo_shaper';
  static const String name = 'DigiDAW Stereo Shaper';
  static const bool isSynth = false;

  static const UiPluginParameter source = UiPluginParameter(
    id: 466561496,
    path: 'source',
    name: 'Source',
    group: 'Input',
    value: 0.0,
    min: 0.0,
    max: 4.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Stereo', 'Mono', 'LeftOnly', 'RightOnly', 'Swap'],
  );

  static const UiPluginParameter invertLeft = UiPluginParameter(
    id: 736419063,
    path: 'invert_left',
    name: 'Invert Left',
    group: 'Input',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter invertRight = UiPluginParameter(
    id: 1479457256,
    path: 'invert_right',
    name: 'Invert Right',
    group: 'Input',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter width = UiPluginParameter(
    id: 2508680735,
    path: 'width',
    name: 'Width',
    group: 'Image',
    value: 1.0,
    min: 0.0,
    max: 2.0,
    defaultValue: 1.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter midDb = UiPluginParameter(
    id: 746384052,
    path: 'mid_db',
    name: 'Mid',
    group: 'Image',
    value: 0.0,
    min: -48.0,
    max: 12.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter sideDb = UiPluginParameter(
    id: 2972835605,
    path: 'side_db',
    name: 'Side',
    group: 'Image',
    value: 0.0,
    min: -48.0,
    max: 12.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter rotation = UiPluginParameter(
    id: 564937055,
    path: 'rotation',
    name: 'Rotation',
    group: 'Image',
    value: 0.0,
    min: -45.0,
    max: 45.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter bassMono = UiPluginParameter(
    id: 563184160,
    path: 'bass_mono',
    name: 'Mono Bass',
    group: 'Bass',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter bassMonoHz = UiPluginParameter(
    id: 3908563519,
    path: 'bass_mono_hz',
    name: 'Mono Below',
    group: 'Bass',
    value: 120.0,
    min: 20.0,
    max: 500.0,
    defaultValue: 120.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter haasMs = UiPluginParameter(
    id: 2930663243,
    path: 'haas_ms',
    name: 'Haas Delay',
    group: 'Space',
    value: 0.0,
    min: -30.0,
    max: 30.0,
    defaultValue: 0.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter balance = UiPluginParameter(
    id: 2560266987,
    path: 'balance',
    name: 'Balance',
    group: 'Output',
    value: 0.0,
    min: -1.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter outputDb = UiPluginParameter(
    id: 1385409639,
    path: 'output_db',
    name: 'Output',
    group: 'Output',
    value: 0.0,
    min: -24.0,
    max: 12.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const List<UiPluginParameter> allParameters = [source, invertLeft, invertRight, width, midDb, sideDb, rotation, bassMono, bassMonoHz, haasMs, balance, outputDb];
}
