import 'dart:convert';
import 'dart:io';
import 'price_sources.dart' show downloadPriceList;

/// The Central Bank of Uzbekistan's open rate service (cbu.uz →
/// "Veb-masterlarga"): today's official so‘m rate as JSON, free and
/// without a key.
final cbuUsdUrl = Uri.parse('https://cbu.uz/uz/arkhiv-kursov-valyut/json/USD/');

/// When the bank does not answer (its site is often slow from abroad or
/// on some networks): ExchangeRate-API's open daily rates, free, no key.
final openUsdUrl = Uri.parse('https://open.er-api.com/v6/latest/USD');

class OfficialRate {
  /// So‘m for one dollar.
  final double rate;

  /// The source's date for the rate, e.g. "24.10.2026".
  final String date;

  /// 'cbu' for the Central Bank, 'open' for the international rate.
  final String source;
  const OfficialRate(this.rate, this.date, {this.source = 'cbu'});
}

/// The so‘m rate from an open.er-api.com answer:
/// `{"result": "success", "time_last_update_utc": "…", "rates": {"UZS": …}}`.
OfficialRate parseOpenRate(String text) {
  final Object? data;
  try {
    data = jsonDecode(text);
  } catch (_) {
    throw const FormatException('Kurs javobi o‘qilmadi');
  }
  final rates =
      data is Map && data['result'] == 'success' ? data['rates'] : null;
  final rate = rates is Map ? rates['UZS'] : null;
  if (rate is! num || !rate.isFinite || rate <= 0) {
    throw const FormatException('Kurs javobida so‘m kursi topilmadi');
  }
  // "Fri, 24 Oct 2026 00:02:31 +0000" → "24 Oct 2026".
  final when = '${(data as Map)['time_last_update_utc'] ?? ''}'.split(' ');
  return OfficialRate(
    rate.toDouble(),
    when.length >= 4 ? when.sublist(1, 4).join(' ') : '',
    source: 'open',
  );
}

/// Today's dollar rate: the Central Bank's, or the international one when
/// the bank cannot be reached.
Future<OfficialRate> fetchUsdRate({HttpClient? client}) async {
  try {
    return await fetchCbuUsd(client: client);
  } catch (_) {
    return parseOpenRate(await downloadPriceList(openUsdUrl, client: client));
  }
}

/// The [currency] rate from a cbu.uz JSON answer: a list of
/// `{"Ccy": "USD", "Nominal": "1", "Rate": "12650.50", "Date": "…"}`.
OfficialRate parseCbuRate(String text, {String currency = 'USD'}) {
  final Object? data;
  try {
    data = jsonDecode(text);
  } catch (_) {
    throw const FormatException('Markaziy bank javobi o‘qilmadi');
  }
  for (final row in data is List ? data : [data]) {
    if (row is! Map || '${row['Ccy']}'.toUpperCase() != currency) continue;
    final rate = double.tryParse(
          '${row['Rate']}'.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
        ),
        nominal = double.tryParse('${row['Nominal'] ?? 1}') ?? 1;
    if (rate == null || !rate.isFinite || rate <= 0 || nominal <= 0) break;
    return OfficialRate(rate / nominal, '${row['Date'] ?? ''}');
  }
  throw const FormatException('Markaziy bank javobida dollar kursi topilmadi');
}

Future<OfficialRate> fetchCbuUsd({HttpClient? client}) async =>
    parseCbuRate(await downloadPriceList(cbuUsdUrl, client: client));
