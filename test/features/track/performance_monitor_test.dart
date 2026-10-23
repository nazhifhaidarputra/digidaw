import 'package:flutter_test/flutter_test.dart';
import 'package:karbeat/features/track/view/performance_monitor.dart';

void main() {
  test('PDC latency is shown in samples and milliseconds', () {
    expect(formatPdcLatency(0, 48000), '0 smp (0.0 ms)');
    expect(formatPdcLatency(128, 48000), '128 smp (2.7 ms)');
    expect(formatPdcLatency(4410, 44100), '4410 smp (100.0 ms)');
  });

  test('PDC latency without a sample rate shows samples only', () {
    expect(formatPdcLatency(128, 0), '128 smp');
  });
}
