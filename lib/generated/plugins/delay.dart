// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: effect_delay

import 'package:karbeat/src/rust/api/plugin.dart';

class DigidawDelaySpecs {
  static const int id = 2289644740;
  static const String idString = 'effect_delay';
  static const String name = 'DigiDAW Delay';
  static const bool isSynth = false;

  static const UiPluginParameter gain = UiPluginParameter(
    id: 458499838,
    path: 'gain',
    name: 'Output Gain',
    group: 'Master',
    value: 1.0,
    min: 0.0,
    max: 2.0,
    defaultValue: 1.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter delayDelayMs = UiPluginParameter(
    id: 4165279105,
    path: 'delay/delay_ms',
    name: 'Delay',
    group: 'Delay',
    value: 500.0,
    min: 1.0,
    max: 5000.0,
    defaultValue: 500.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter delayFeedback = UiPluginParameter(
    id: 3444624594,
    path: 'delay/feedback',
    name: 'Feedback',
    group: 'Delay',
    value: 0.35,
    min: 0.0,
    max: 0.95,
    defaultValue: 0.35,
    step: 0.001,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter delayDryMix = UiPluginParameter(
    id: 3538180627,
    path: 'delay/dry_mix',
    name: 'Dry',
    group: 'Delay',
    value: 0.5,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.5,
    step: 0.001,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter delayWetMix = UiPluginParameter(
    id: 860611838,
    path: 'delay/wet_mix',
    name: 'Wet',
    group: 'Delay',
    value: 0.5,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.5,
    step: 0.001,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter delayType = UiPluginParameter(
    id: 3585274621,
    path: 'delay/type',
    name: 'Type',
    group: 'Delay',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Feedback', 'PingPong', 'MultiTap', 'Off'],
  );

  static const UiPluginParameter delayTapCount = UiPluginParameter(
    id: 4196020494,
    path: 'delay/tap_count',
    name: 'Tap Count',
    group: 'Multi Tap',
    value: 4.0,
    min: 2.0,
    max: 8.0,
    defaultValue: 4.0,
    step: 1.0,
    paramType: UiParameterType.int,
    choices: [],
  );

  static const UiPluginParameter delayTapDecay = UiPluginParameter(
    id: 3121094031,
    path: 'delay/tap_decay',
    name: 'Tap Decay',
    group: 'Multi Tap',
    value: 0.7,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.7,
    step: 0.001,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const List<UiPluginParameter> allParameters = [gain, delayDelayMs, delayFeedback, delayDryMix, delayWetMix, delayType, delayTapCount, delayTapDecay];
}
