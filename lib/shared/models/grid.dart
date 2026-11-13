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

  /// Ticks spanned by one grid cell; a single tick when there is no grid.
  int get ticks => this == GridSize.infinity ? 1 : (960 * 4 / value).round();

  /// [tick] moved to the nearest grid line.
  int snap(int tick) => (tick / ticks).round() * ticks;
}
