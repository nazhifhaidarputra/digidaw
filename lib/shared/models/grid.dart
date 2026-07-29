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
    GridSize.infinity => 'None',
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
    MusicalBeatSize.four => '1 Bar',
    MusicalBeatSize.three => '3 Beats',
    MusicalBeatSize.two => '2 Beats',
    MusicalBeatSize.one => '1 Beat',
    MusicalBeatSize.half => '1/2 Step',
    MusicalBeatSize.third => '1/3 Step',
    MusicalBeatSize.quarter => '1/4 Step',
    MusicalBeatSize.sixth => '1/6 Step',
    MusicalBeatSize.eighth => '1/8 Step',
    MusicalBeatSize.twelfth => '1/12 Step',
    MusicalBeatSize.sixteenth => '1/16 Step',
    MusicalBeatSize.thirtysecond => '1/32 Step',
    MusicalBeatSize.sixtyfourth => '1/64 Step',
    MusicalBeatSize.none => 'None',
  };
}
