import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/calculator.dart';

void main() {
  test('offline cut plan conserves stock and accounts for kerf', () {
    final r = optimizeCuts(6000, 4, [
      {'lengthMm': 1400, 'quantity': 4},
      {'lengthMm': 1200, 'quantity': 4}
    ]);
    final bars = r['bars'] as List;
    expect(bars.expand((b) => b['pieces'] as List).length, 8);
    for (final b in bars) {
      expect(
          (b['pieces'] as List).fold<num>(0, (s, n) => s + (n as num) + 4) +
              b['remainingMm'],
          6000);
    }
    expect(
        () => optimizeCuts(1000, 4, [
              {'lengthMm': 1001, 'quantity': 1}
            ]),
        throwsException);
  });
}
