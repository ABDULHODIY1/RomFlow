import 'calculator.dart';
import 'design_engine.dart';
import 'store.dart';

String _mm(num v) => '${v.round()}';

/// Plain-text estimate for Telegram/WhatsApp: header, positions and totals.
String quoteText(Store s, Map<String, dynamic> q) {
  final out = StringBuffer()
    ..writeln(s.workshopName)
    ..write(s.workshopPhone.isEmpty ? '' : '${s.workshopPhone}\n')
    ..writeln('—')
    ..writeln('Smeta: ${q['title']}')
    ..writeln(
        'Mijoz: ${q['customer']}${(q['phone'] ?? '').toString().isEmpty ? '' : ', ${q['phone']}'}');
  if ((q['address'] ?? '').toString().isNotEmpty) {
    out.writeln('Manzil: ${q['address']}');
  }
  out.writeln();
  for (final (i, item) in (q['items'] as List).indexed) {
    final glazing = item['recipe'] == null
        ? ''
        : ' • shisha ${GlazingSpec(Map<String, dynamic>.from(item['recipe'])).label}';
    final colour = item['recipe']?['finish'];
    out.writeln(
        '${i + 1}) ${item['label'] == null ? '' : '${item['label']} — '}${item['profileName']}: ${_mm(item['widthMm'])}×${_mm(item['heightMm'])} mm × ${item['quantity']} dona$glazing${colour == null ? '' : ' • ${finishNames[colour] ?? colour}'}');
    final openings = item['openingCount'];
    if (openings != null) out.writeln('   Ochiladigan qanot: $openings');
    out.writeln('   Narx: ${money(item['total'])}');
  }
  out.writeln();
  for (final e in q['extras'] as List? ?? const []) {
    out.writeln(
        '${e['name']}: ${e['qty']} ${e['unit']} × ${money(e['price'])} = ${money(extraLine(Map<String, dynamic>.from(e)))}');
  }
  out
    ..writeln('Montaj: ${money(q['installation'])}')
    ..writeln('Chegirma: ${money(q['discount'])}')
    ..writeln('JAMI: ${money(q['total'])}'
        '${s.usdRate > 0 ? ' (${dollars(q['total'], s.usdRate)})' : ''}')
    ..writeln(
        'To‘langan: ${money(q['paid'])} • qoldiq: ${money(q['balance'])}');
  if (q['installDate'] != null) {
    final d = DateTime.parse(q['installDate']).toLocal();
    out.writeln(
        'Montaj sanasi: ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}');
  }
  out.writeln('\nSmeta taxminiy; o‘lchov tasdiqlangach aniqlanadi.');
  return out.toString();
}

/// Workshop cut list: bars per profile with piece lengths, and glass/panel
/// sizes, for every position of the order.
String cutListText(Map<String, dynamic> q) {
  final out = StringBuffer()
    ..writeln('KESISH RO‘YXATI • ${q['title']}')
    ..writeln('Mijoz: ${q['customer']}');
  for (final (i, item) in (q['items'] as List).indexed) {
    out
      ..writeln()
      ..writeln(
          '${i + 1}) ${item['label'] == null ? '' : '${item['label']}: '}${_mm(item['widthMm'])}×${_mm(item['heightMm'])} mm × ${item['quantity']} dona — ${item['profileName']}');
    final cuts = Map<String, dynamic>.from(item['cuts'] ?? {});
    if (cuts.isEmpty) {
      out.writeln('   Chizmasiz pozitsiya: kesish rejasi yo‘q');
      continue;
    }
    for (final e in cuts.entries) {
      final bars = e.value['bars'] as List;
      out.writeln(
          '   ${materialNames[e.key] ?? e.key}: ${bars.length} tayoq × ${_mm(e.value['stockMm'])} mm');
      for (final (j, bar) in bars.indexed) {
        out.writeln(
            '     ${j + 1}. ${(bar['pieces'] as List).map((v) => _mm(v as num)).join(' + ')}  (qoldiq ${_mm(bar['remaining'] as num)})');
      }
    }
    final pieces = <String, int>{};
    for (final spec in (item['specs'] as List? ?? [])) {
      if (spec['fill'] == 'empty') continue;
      final key =
          '${materialNames[spec['fill']] ?? spec['fill']} ${_mm(spec['widthMm'])}×${_mm(spec['heightMm'])} mm';
      final count =
          ((spec['panes'] as num?) ?? 1).toInt() * (item['quantity'] as int);
      pieces[key] = (pieces[key] ?? 0) + count;
    }
    for (final e in pieces.entries) {
      out.writeln('   ${e.key} — ${e.value} dona');
    }
  }
  return out.toString();
}
