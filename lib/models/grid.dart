enum GridSize {
  oneBar(0.25),
  twoBeat(0.5),
  full(1),
  half(2),
  third(3),
  quarter(4),
  sixth(6),
  eighth(8),
  sixteenth(16),
  thirtysecond(32),
  sixtyfourth(64),
  infinity(double.infinity);

  final double value;
  const GridSize(this.value);
}

enum MusicalBeatSize {
  four(4),
  three(3),
  two(2),
  one(1),
  half(0.5),
  quarter(0.25),
  eighth(0.125),
  sixteenth(0.0625),
  thirtysecond(0.03125),
  sixtyfourth(0.015625),
  none(0); // this means one tick size

  final double value;
  const MusicalBeatSize(this.value);
}
