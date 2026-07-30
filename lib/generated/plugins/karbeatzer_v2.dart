// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: synth_karbeatzer_v2

import 'package:karbeat/src/rust/api/plugin.dart';

class KarbeatzerV2Specs {
  static const int id = 1597416290;
  static const String idString = 'synth_karbeatzer_v2';
  static const String name = 'Karbeatzer V2';
  static const bool isSynth = true;

  static const UiPluginParameter drive = UiPluginParameter(
    id: 531555959,
    path: 'drive',
    name: 'Drive',
    group: 'Master',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 0.01,
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

  static const UiPluginParameter osc0Waveform = UiPluginParameter(
    id: 1262875742,
    path: 'osc0/waveform',
    name: 'Waveform',
    group: 'Oscillator 1',
    value: 1.0,
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
    value: 0.10000000149011612,
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
    value: 0.5,
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

  static const UiPluginParameter osc2Waveform = UiPluginParameter(
    id: 4146162432,
    path: 'osc2/waveform',
    name: 'Waveform',
    group: 'Oscillator 3',
    value: 0.0,
    min: 0.0,
    max: 4.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Sine', 'Saw', 'Square', 'Triangle', 'Noise'],
  );

  static const UiPluginParameter osc2Detune = UiPluginParameter(
    id: 627716106,
    path: 'osc2/detune',
    name: 'Detune',
    group: 'Oscillator 3',
    value: -12.0,
    min: -48.0,
    max: 48.0,
    defaultValue: 0.0,
    step: 0.2,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc2PhaseOffset = UiPluginParameter(
    id: 2635417572,
    path: 'osc2/phase_offset',
    name: 'Phase Offset',
    group: 'Oscillator 3',
    value: 0.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 0.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc2Mix = UiPluginParameter(
    id: 1468104687,
    path: 'osc2/mix',
    name: 'Mix',
    group: 'Oscillator 3',
    value: 0.30000001192092896,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter osc2PulseWidth = UiPluginParameter(
    id: 675802031,
    path: 'osc2/pulse_width',
    name: 'Pulse Width',
    group: 'Oscillator 3',
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

  static const UiPluginParameter filterFreq = UiPluginParameter(
    id: 1931150098,
    path: 'filter/freq',
    name: 'Frequency',
    group: 'Filter',
    value: 1000.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter filterGain = UiPluginParameter(
    id: 3180303307,
    path: 'filter/gain',
    name: 'Gain',
    group: 'Filter',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter filterQ = UiPluginParameter(
    id: 3101584891,
    path: 'filter/q',
    name: 'Q',
    group: 'Filter',
    value: 0.7070000171661377,
    min: 0.1,
    max: 10.0,
    defaultValue: 0.707,
    step: 0.01,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter filterActive = UiPluginParameter(
    id: 523745730,
    path: 'filter/active',
    name: 'Active',
    group: 'Filter',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter filterType = UiPluginParameter(
    id: 2579916128,
    path: 'filter/type',
    name: 'Type',
    group: 'Filter',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['LowPass', 'HighPass', 'BandPass', 'Off'],
  );

  static const UiPluginParameter filterCascades = UiPluginParameter(
    id: 1596721003,
    path: 'filter/cascades',
    name: 'Order',
    group: 'Filter',
    value: 1.0,
    min: 1.0,
    max: 8.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const List<UiPluginParameter> allParameters = [drive, gain, osc0Waveform, osc0Detune, osc0PhaseOffset, osc0Mix, osc0PulseWidth, osc1Waveform, osc1Detune, osc1PhaseOffset, osc1Mix, osc1PulseWidth, osc2Waveform, osc2Detune, osc2PhaseOffset, osc2Mix, osc2PulseWidth, ampEnvAttack, ampEnvDecay, ampEnvSustain, ampEnvRelease, filterFreq, filterGain, filterQ, filterActive, filterType, filterCascades];
}
