import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/calculator.dart';

void main() {
  test(
      '48 constructions match backend snapshot including rounding and material quantities',
      () {
    final fixture =
        jsonDecode(File('test/fixtures/calculation.json').readAsStringSync());
    for (final c in fixture['cases']) {
      final actual = calculate(Map<String, dynamic>.from(c['input']),
          Map<String, dynamic>.from(fixture['profile']));
      expect(actual['total'], c['result']['total']);
      expect(actual['cost'], c['result']['cost']);
      expect(actual['parts'], c['result']['parts']);
    }
  });
  test('reject impossible panes and negative net total', () {
    expect(
        () => calculate({
              'profileId': 'p',
              'template': 'triple',
              'widthMm': 300,
              'heightMm': 300,
              'quantity': 1,
              'color': 'white',
              'mosquito': false
            }, sampleProfiles().first),
        throwsException);
    expect(() => totals([], 1, 0), throwsException);
  });
}
