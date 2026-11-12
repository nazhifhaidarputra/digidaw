import 'package:karbeat/core/l10n/localizer.dart';

enum GridSize {
  oneBar(0.25),
  twoBeat(0.5),
  full(1),
  half(2),
  third(3),
  quarter(4),
  sixth(6),
  eighth(8),
  twelfth(12),
  sixteenth(16),
  thirtysecond(32),
  sixtyfourth(64),
  infinity(double.infinity);

  final double value;
  const GridSize(this.value);
  String get label => switch (this) {
    GridSize.oneBar => '4/1',
    GridSize.twoBeat => '2/1',
    GridSize.full => '1/1',
    GridSize.half => '1/2',
    GridSize.third => '1/3',
    GridSize.quarter => '1/4',
    GridSize.sixth => '1/6',
    GridSize.eighth => '1/8',
    GridSize.twelfth => '1/12',
    GridSize.sixteenth => '1/16',
    GridSize.thirtysecond => '1/32',
    GridSize.sixtyfourth => '1/64',
    GridSize.infinity => tr('common-none'),
  };

  double get sizeInBeat => switch (this) {
    GridSize.infinity => 4 / 960,
    _ => 4 / value,
  };
}

enum MusicalBeatSize {
  four(4),
  three(3),
  two(2),
  one(1),
  half(0.5),
  third(1 / 3),
  quarter(1 / 4),
  sixth(1 / 6),
  eighth(1 / 8),
  twelfth(1 / 12),
  sixteenth(1 / 16),
  thirtysecond(1 / 32),
  sixtyfourth(1 / 64),
  none(0); // this means one tick size

  final double value;
  const MusicalBeatSize(this.value);

  String get label => switch (this) {
    MusicalBeatSize.four => tr('common-grid-bar'),
    MusicalBeatSize.three => tr('common-grid-beats', {'count': 3}),
    MusicalBeatSize.two => tr('common-grid-beats', {'count': 2}),
    MusicalBeatSize.one => tr('common-grid-beats', {'count': 1}),
    MusicalBeatSize.half => tr('common-grid-step', {'fraction': '1/2'}),
    MusicalBeatSize.third => tr('common-grid-step', {'fraction': '1/3'}),
    MusicalBeatSize.quarter => tr('common-grid-step', {'fraction': '1/4'}),
    MusicalBeatSize.sixth => tr('common-grid-step', {'fraction': '1/6'}),
    MusicalBeatSize.eighth => tr('common-grid-step', {'fraction': '1/8'}),
    MusicalBeatSize.twelfth => tr('common-grid-step', {'fraction': '1/12'}),
    MusicalBeatSize.sixteenth => tr('common-grid-step', {'fraction': '1/16'}),
    MusicalBeatSize.thirtysecond => tr('common-grid-step', {
      'fraction': '1/32',
    }),
    MusicalBeatSize.sixtyfourth => tr('common-grid-step', {'fraction': '1/64'}),
    MusicalBeatSize.none => tr('common-none'),
  };
}
