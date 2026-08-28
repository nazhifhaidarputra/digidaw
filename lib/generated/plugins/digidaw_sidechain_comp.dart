// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: effect_digidaw_sidechain_comp

import 'package:karbeat/src/rust/api/plugin.dart';

class DigidawSidechainCompressorSpecs {
  static const int id = 4115417077;
  static const String idString = 'effect_digidaw_sidechain_comp';
  static const String name = 'DigiDAW Sidechain Compressor';
  static const bool isSynth = false;

  static const UiPluginParameter channelMode = UiPluginParameter(
    id: 1615967742,
    path: 'channel_mode',
    name: 'Channel Mode',
    group: '',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Mono', 'Stereo'],
  );

  static const UiPluginParameter compressorAttack = UiPluginParameter(
    id: 425362513,
    path: 'compressor/attack',
    name: 'Attack',
    group: '',
    value: 5.0,
    min: 1.0,
    max: 1000.0,
    defaultValue: 5.0,
    step: 1.0,
    paramType: UiParameterType.int,
    choices: [],
  );

  static const UiPluginParameter compressorRelease = UiPluginParameter(
    id: 4082258858,
    path: 'compressor/release',
    name: 'Release',
    group: '',
    value: 5.0,
    min: 1.0,
    max: 1000.0,
    defaultValue: 5.0,
    step: 1.0,
    paramType: UiParameterType.int,
    choices: [],
  );

  static const UiPluginParameter compressorRatio = UiPluginParameter(
    id: 3182674304,
    path: 'compressor/ratio',
    name: 'Ratio',
    group: '',
    value: 4.0,
    min: 1.0,
    max: 24.0,
    defaultValue: 4.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter compressorThreshold = UiPluginParameter(
    id: 2691430956,
    path: 'compressor/threshold',
    name: 'Threshold',
    group: '',
    value: -18.0,
    min: -60.0,
    max: 0.0,
    defaultValue: -18.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter compressorDelay = UiPluginParameter(
    id: 1749740780,
    path: 'compressor/delay',
    name: 'Delay',
    group: '',
    value: 0.0,
    min: 0.0,
    max: 100.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.int,
    choices: [],
  );

  static const UiPluginParameter compressorKnee = UiPluginParameter(
    id: 3140348134,
    path: 'compressor/knee',
    name: 'Knee',
    group: '',
    value: 6.0,
    min: 0.0,
    max: 24.0,
    defaultValue: 6.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter compressorMakeupGain = UiPluginParameter(
    id: 1500576132,
    path: 'compressor/makeup_gain',
    name: 'MakeUp Gain',
    group: '',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter compressorWetMix = UiPluginParameter(
    id: 182769762,
    path: 'compressor/wet_mix',
    name: 'Wet Mix',
    group: '',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter compressorDryMix = UiPluginParameter(
    id: 204092199,
    path: 'compressor/dry_mix',
    name: 'Dry mix',
    group: '',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const List<UiPluginParameter> allParameters = [channelMode, compressorAttack, compressorRelease, compressorRatio, compressorThreshold, compressorDelay, compressorKnee, compressorMakeupGain, compressorWetMix, compressorDryMix];
}
