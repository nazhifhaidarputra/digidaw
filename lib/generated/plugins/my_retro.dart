// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: synth_my_retro

import 'package:karbeat/src/rust/api/plugin.dart';

class MyRetroSpecs {
  static const int id = 575666755;
  static const String idString = 'synth_my_retro';
  static const String name = 'My Retro';
  static const bool isSynth = true;

  static const UiPluginParameter bitcrush = UiPluginParameter(
    id: 3052501135,
    path: 'bitcrush',
    name: 'Resolution',
    group: 'Bitcrush',
    value: 16.0,
    min: 2.0,
    max: 256.0,
    defaultValue: 16.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter gain = UiPluginParameter(
    id: 458499838,
    path: 'gain',
    name: 'Gain',
    group: 'Master',
    value: 0.800000011920929,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.8,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter baseFreq = UiPluginParameter(
    id: 2154388407,
    path: 'base_freq',
    name: 'Base frequency',
    group: 'Master',
    value: 440.0,
    min: 432.0,
    max: 448.0,
    defaultValue: 440.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc0Waveform = UiPluginParameter(
    id: 1262875742,
    path: 'osc0/waveform',
    name: 'Waveform',
    group: 'Oscillator 1',
    value: 2.0,
    min: 0.0,
    max: 4.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Sine', 'Saw', 'Square', 'Triangle', 'Noise'],
  );

  static const UiPluginParameter osc0Detune = UiPluginParameter(
    id: 1191210616,
    path: 'osc0/detune',
    name: 'Detune',
    group: 'Oscillator 1',
    value: 0.0,
    min: -48.0,
    max: 48.0,
    defaultValue: 0.0,
    step: 0.2,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc0PhaseOffset = UiPluginParameter(
    id: 2617434910,
    path: 'osc0/phase_offset',
    name: 'Phase Offset',
    group: 'Oscillator 1',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc0Mix = UiPluginParameter(
    id: 3788236845,
    path: 'osc0/mix',
    name: 'Mix',
    group: 'Oscillator 1',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc0PulseWidth = UiPluginParameter(
    id: 3207620001,
    path: 'osc0/pulse_width',
    name: 'Pulse Width',
    group: 'Oscillator 1',
    value: 0.5,
    min: 0.01,
    max: 0.99,
    defaultValue: 0.5,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc1Waveform = UiPluginParameter(
    id: 4009544755,
    path: 'osc1/waveform',
    name: 'Waveform',
    group: 'Oscillator 2',
    value: 2.0,
    min: 0.0,
    max: 4.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Sine', 'Saw', 'Square', 'Triangle', 'Noise'],
  );

  static const UiPluginParameter osc1Detune = UiPluginParameter(
    id: 2165867149,
    path: 'osc1/detune',
    name: 'Detune',
    group: 'Oscillator 2',
    value: -12.0,
    min: -48.0,
    max: 48.0,
    defaultValue: 0.0,
    step: 0.2,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc1PhaseOffset = UiPluginParameter(
    id: 2748436067,
    path: 'osc1/phase_offset',
    name: 'Phase Offset',
    group: 'Oscillator 2',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc1Mix = UiPluginParameter(
    id: 2841829646,
    path: 'osc1/mix',
    name: 'Mix',
    group: 'Oscillator 2',
    value: 0.800000011920929,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc1PulseWidth = UiPluginParameter(
    id: 907917422,
    path: 'osc1/pulse_width',
    name: 'Pulse Width',
    group: 'Oscillator 2',
    value: 0.5,
    min: 0.01,
    max: 0.99,
    defaultValue: 0.5,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter ampEnvAttack = UiPluginParameter(
    id: 3344238218,
    path: 'amp_env/attack',
    name: 'Attack',
    group: 'Envelope',
    value: 10.0,
    min: 1.0,
    max: 10000.0,
    defaultValue: 10.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter ampEnvDecay = UiPluginParameter(
    id: 4033872628,
    path: 'amp_env/decay',
    name: 'Decay',
    group: 'Envelope',
    value: 200.0,
    min: 1.0,
    max: 10000.0,
    defaultValue: 200.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter ampEnvSustain = UiPluginParameter(
    id: 2427644079,
    path: 'amp_env/sustain',
    name: 'Sustain',
    group: 'Envelope',
    value: 0.699999988079071,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.7,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter ampEnvRelease = UiPluginParameter(
    id: 2226377911,
    path: 'amp_env/release',
    name: 'Release',
    group: 'Envelope',
    value: 500.0,
    min: 1.0,
    max: 10000.0,
    defaultValue: 500.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const List<UiPluginParameter> allParameters = [bitcrush, gain, baseFreq, osc0Waveform, osc0Detune, osc0PhaseOffset, osc0Mix, osc0PulseWidth, osc1Waveform, osc1Detune, osc1PhaseOffset, osc1Mix, osc1PulseWidth, ampEnvAttack, ampEnvDecay, ampEnvSustain, ampEnvRelease];
}
