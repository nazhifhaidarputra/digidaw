// GENERATED CODE - DO NOT MODIFY BY HAND
// Source: effect_param_eq

import 'package:karbeat/src/rust/api/plugin.dart';

class DigiParametricEQSpecs {
  static const int id = 2105689785;
  static const String idString = 'effect_param_eq';
  static const String name = 'Digi Parametric EQ';
  static const bool isSynth = false;

  static const UiPluginParameter baseGain = UiPluginParameter(
    id: 193833662,
    path: 'base_gain',
    name: 'Base Gain',
    group: 'Master',
    value: 0.0,
    min: -60.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band0Freq = UiPluginParameter(
    id: 2065573273,
    path: 'band0/freq',
    name: 'Frequency',
    group: 'Band 1',
    value: 60.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band0Gain = UiPluginParameter(
    id: 2358230832,
    path: 'band0/gain',
    name: 'Gain',
    group: 'Band 1',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band0Q = UiPluginParameter(
    id: 1018703762,
    path: 'band0/q',
    name: 'Q',
    group: 'Band 1',
    value: 0.7070000171661377,
    min: 0.1,
    max: 20.0,
    defaultValue: 0.707,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band0Active = UiPluginParameter(
    id: 1640136425,
    path: 'band0/active',
    name: 'Active',
    group: 'Band 1',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter band0Type = UiPluginParameter(
    id: 4273755727,
    path: 'band0/type',
    name: 'Type',
    group: 'Band 1',
    value: 1.0,
    min: 0.0,
    max: 7.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Peaking', 'LowShelf', 'HighShelf', 'LowPass', 'HighPass', 'BandPass', 'Notch', 'Off'],
  );

  static const UiPluginParameter band0Slope = UiPluginParameter(
    id: 2319350422,
    path: 'band0/slope',
    name: 'Slope',
    group: 'Band 1',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Db12', 'Db24', 'Db36', 'Db48'],
  );

  static const UiPluginParameter band1Freq = UiPluginParameter(
    id: 2600073296,
    path: 'band1/freq',
    name: 'Frequency',
    group: 'Band 2',
    value: 125.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band1Gain = UiPluginParameter(
    id: 3288435937,
    path: 'band1/gain',
    name: 'Gain',
    group: 'Band 2',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band1Q = UiPluginParameter(
    id: 3113236973,
    path: 'band1/q',
    name: 'Q',
    group: 'Band 2',
    value: 0.7070000171661377,
    min: 0.1,
    max: 20.0,
    defaultValue: 0.707,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band1Active = UiPluginParameter(
    id: 2967052488,
    path: 'band1/active',
    name: 'Active',
    group: 'Band 2',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter band1Type = UiPluginParameter(
    id: 3707450542,
    path: 'band1/type',
    name: 'Type',
    group: 'Band 2',
    value: 0.0,
    min: 0.0,
    max: 7.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Peaking', 'LowShelf', 'HighShelf', 'LowPass', 'HighPass', 'BandPass', 'Notch', 'Off'],
  );

  static const UiPluginParameter band1Slope = UiPluginParameter(
    id: 233036353,
    path: 'band1/slope',
    name: 'Slope',
    group: 'Band 2',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Db12', 'Db24', 'Db36', 'Db48'],
  );

  static const UiPluginParameter band2Freq = UiPluginParameter(
    id: 2034342235,
    path: 'band2/freq',
    name: 'Frequency',
    group: 'Band 3',
    value: 250.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band2Gain = UiPluginParameter(
    id: 209391538,
    path: 'band2/gain',
    name: 'Gain',
    group: 'Band 3',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band2Q = UiPluginParameter(
    id: 1723376040,
    path: 'band2/q',
    name: 'Q',
    group: 'Band 3',
    value: 0.7070000171661377,
    min: 0.1,
    max: 20.0,
    defaultValue: 0.707,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band2Active = UiPluginParameter(
    id: 1809843915,
    path: 'band2/active',
    name: 'Active',
    group: 'Band 3',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter band2Type = UiPluginParameter(
    id: 682886689,
    path: 'band2/type',
    name: 'Type',
    group: 'Band 3',
    value: 0.0,
    min: 0.0,
    max: 7.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Peaking', 'LowShelf', 'HighShelf', 'LowPass', 'HighPass', 'BandPass', 'Notch', 'Off'],
  );

  static const UiPluginParameter band2Slope = UiPluginParameter(
    id: 3870157260,
    path: 'band2/slope',
    name: 'Slope',
    group: 'Band 3',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Db12', 'Db24', 'Db36', 'Db48'],
  );

  static const UiPluginParameter band3Freq = UiPluginParameter(
    id: 81808426,
    path: 'band3/freq',
    name: 'Frequency',
    group: 'Band 4',
    value: 500.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band3Gain = UiPluginParameter(
    id: 3291567171,
    path: 'band3/gain',
    name: 'Gain',
    group: 'Band 4',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band3Q = UiPluginParameter(
    id: 3270682851,
    path: 'band3/q',
    name: 'Q',
    group: 'Band 4',
    value: 0.7070000171661377,
    min: 0.1,
    max: 20.0,
    defaultValue: 0.707,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band3Active = UiPluginParameter(
    id: 4238247306,
    path: 'band3/active',
    name: 'Active',
    group: 'Band 4',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter band3Type = UiPluginParameter(
    id: 425267816,
    path: 'band3/type',
    name: 'Type',
    group: 'Band 4',
    value: 0.0,
    min: 0.0,
    max: 7.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Peaking', 'LowShelf', 'HighShelf', 'LowPass', 'HighPass', 'BandPass', 'Notch', 'Off'],
  );

  static const UiPluginParameter band3Slope = UiPluginParameter(
    id: 4245031999,
    path: 'band3/slope',
    name: 'Slope',
    group: 'Band 4',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Db12', 'Db24', 'Db36', 'Db48'],
  );

  static const UiPluginParameter band4Freq = UiPluginParameter(
    id: 1964431709,
    path: 'band4/freq',
    name: 'Frequency',
    group: 'Band 5',
    value: 1000.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band4Gain = UiPluginParameter(
    id: 1853146484,
    path: 'band4/gain',
    name: 'Gain',
    group: 'Band 5',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band4Q = UiPluginParameter(
    id: 2422928606,
    path: 'band4/q',
    name: 'Q',
    group: 'Band 5',
    value: 0.7070000171661377,
    min: 0.1,
    max: 20.0,
    defaultValue: 0.707,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band4Active = UiPluginParameter(
    id: 4255971413,
    path: 'band4/active',
    name: 'Active',
    group: 'Band 5',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter band4Type = UiPluginParameter(
    id: 3812807939,
    path: 'band4/type',
    name: 'Type',
    group: 'Band 5',
    value: 0.0,
    min: 0.0,
    max: 7.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Peaking', 'LowShelf', 'HighShelf', 'LowPass', 'HighPass', 'BandPass', 'Notch', 'Off'],
  );

  static const UiPluginParameter band4Slope = UiPluginParameter(
    id: 3242124890,
    path: 'band4/slope',
    name: 'Slope',
    group: 'Band 5',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Db12', 'Db24', 'Db36', 'Db48'],
  );

  static const UiPluginParameter band5Freq = UiPluginParameter(
    id: 907090052,
    path: 'band5/freq',
    name: 'Frequency',
    group: 'Band 6',
    value: 2000.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band5Gain = UiPluginParameter(
    id: 1191509909,
    path: 'band5/gain',
    name: 'Gain',
    group: 'Band 6',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band5Q = UiPluginParameter(
    id: 3990920601,
    path: 'band5/q',
    name: 'Q',
    group: 'Band 6',
    value: 0.7070000171661377,
    min: 0.1,
    max: 20.0,
    defaultValue: 0.707,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band5Active = UiPluginParameter(
    id: 158912628,
    path: 'band5/active',
    name: 'Active',
    group: 'Band 6',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter band5Type = UiPluginParameter(
    id: 50138242,
    path: 'band5/type',
    name: 'Type',
    group: 'Band 6',
    value: 0.0,
    min: 0.0,
    max: 7.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Peaking', 'LowShelf', 'HighShelf', 'LowPass', 'HighPass', 'BandPass', 'Notch', 'Off'],
  );

  static const UiPluginParameter band5Slope = UiPluginParameter(
    id: 310452965,
    path: 'band5/slope',
    name: 'Slope',
    group: 'Band 6',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Db12', 'Db24', 'Db36', 'Db48'],
  );

  static const UiPluginParameter band6Freq = UiPluginParameter(
    id: 3840406559,
    path: 'band6/freq',
    name: 'Frequency',
    group: 'Band 7',
    value: 4000.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band6Gain = UiPluginParameter(
    id: 3134098086,
    path: 'band6/gain',
    name: 'Gain',
    group: 'Band 7',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band6Q = UiPluginParameter(
    id: 3143166356,
    path: 'band6/q',
    name: 'Q',
    group: 'Band 7',
    value: 0.7070000171661377,
    min: 0.1,
    max: 20.0,
    defaultValue: 0.707,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band6Active = UiPluginParameter(
    id: 444090887,
    path: 'band6/active',
    name: 'Active',
    group: 'Band 7',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter band6Type = UiPluginParameter(
    id: 1435084005,
    path: 'band6/type',
    name: 'Type',
    group: 'Band 7',
    value: 0.0,
    min: 0.0,
    max: 7.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Peaking', 'LowShelf', 'HighShelf', 'LowPass', 'HighPass', 'BandPass', 'Notch', 'Off'],
  );

  static const UiPluginParameter band6Slope = UiPluginParameter(
    id: 3779714464,
    path: 'band6/slope',
    name: 'Slope',
    group: 'Band 7',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Db12', 'Db24', 'Db36', 'Db48'],
  );

  static const UiPluginParameter band7Freq = UiPluginParameter(
    id: 625183134,
    path: 'band7/freq',
    name: 'Frequency',
    group: 'Band 8',
    value: 8000.0,
    min: 20.0,
    max: 20000.0,
    defaultValue: 1000.0,
    step: 1.0,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band7Gain = UiPluginParameter(
    id: 2306850215,
    path: 'band7/gain',
    name: 'Gain',
    group: 'Band 8',
    value: 0.0,
    min: -24.0,
    max: 24.0,
    defaultValue: 0.0,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band7Q = UiPluginParameter(
    id: 395505871,
    path: 'band7/q',
    name: 'Q',
    group: 'Band 8',
    value: 0.7070000171661377,
    min: 0.1,
    max: 20.0,
    defaultValue: 0.707,
    step: 0.1,
    paramType: UiParameterType.float,
    choices: [],
  );

  static const UiPluginParameter band7Active = UiPluginParameter(
    id: 798526086,
    path: 'band7/active',
    name: 'Active',
    group: 'Band 8',
    value: 1.0,
    min: 0.0,
    max: 1.0,
    defaultValue: 1.0,
    step: 1.0,
    paramType: UiParameterType.bool,
    choices: [],
  );

  static const UiPluginParameter band7Type = UiPluginParameter(
    id: 1177465132,
    path: 'band7/type',
    name: 'Type',
    group: 'Band 8',
    value: 2.0,
    min: 0.0,
    max: 7.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Peaking', 'LowShelf', 'HighShelf', 'LowPass', 'HighPass', 'BandPass', 'Notch', 'Off'],
  );

  static const UiPluginParameter band7Slope = UiPluginParameter(
    id: 2992920819,
    path: 'band7/slope',
    name: 'Slope',
    group: 'Band 8',
    value: 0.0,
    min: 0.0,
    max: 3.0,
    defaultValue: 0.0,
    step: 1.0,
    paramType: UiParameterType.choice,
    choices: ['Db12', 'Db24', 'Db36', 'Db48'],
  );

  static const List<UiPluginParameter> allParameters = [baseGain, band0Freq, band0Gain, band0Q, band0Active, band0Type, band0Slope, band1Freq, band1Gain, band1Q, band1Active, band1Type, band1Slope, band2Freq, band2Gain, band2Q, band2Active, band2Type, band2Slope, band3Freq, band3Gain, band3Q, band3Active, band3Type, band3Slope, band4Freq, band4Gain, band4Q, band4Active, band4Type, band4Slope, band5Freq, band5Gain, band5Q, band5Active, band5Type, band5Slope, band6Freq, band6Gain, band6Q, band6Active, band6Type, band6Slope, band7Freq, band7Gain, band7Q, band7Active, band7Type, band7Slope];
}
