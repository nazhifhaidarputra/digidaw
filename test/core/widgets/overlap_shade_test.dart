import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/core/widgets/overlap_shade.dart';

void main() {
  test('spans that only touch do not overlap', () {
    expect(overlapSpans([(start: 0, end: 10), (start: 10, end: 20)]), isEmpty);
  });

  test('a fully stacked duplicate overlaps across its whole length', () {
    expect(overlapSpans([(start: 5, end: 15), (start: 5, end: 15)]), [
      (start: 5, end: 15),
    ]);
  });

  test('partial overlaps report only the shared range, in any input order', () {
    expect(overlapSpans([(start: 8, end: 20), (start: 0, end: 10)]), [
      (start: 8, end: 10),
    ]);
  });

  test('each overlapping pair is reported, so triple stacks build up', () {
    expect(
      overlapSpans([
        (start: 0, end: 30),
        (start: 10, end: 20),
        (start: 15, end: 40),
      ]),
      [(start: 10, end: 20), (start: 15, end: 30), (start: 15, end: 20)],
    );
  });

  test('empty spans are ignored', () {
    expect(overlapSpans([(start: 5, end: 5), (start: 0, end: 10)]), isEmpty);
  });
}
