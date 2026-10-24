import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'billing.dart';
import 'calculator.dart';
import 'design_engine.dart';
import 'dialogs.dart';
import 'exchange_rate.dart';
import 'manufacturers.dart' show manufacturersUrl;
import 'platform_files.dart';
import 'store.dart';
import 'workshop_tools.dart' show localDate;

/// Price lists from sources the workshop is allowed to use: a dealer's or
/// supplier's feed, or its own published spreadsheet (Google Sheets →
/// Share → Publish to the web → CSV). CSV or JSON, prices in so‘m or USD.
class PriceRow {
  final String key, label;
  final double price;

  /// Profile id or name the price is for; null for every chosen profile.
  final String? profile;
  final bool usd;
  const PriceRow(this.key, this.label, this.price, this.profile,
      {this.usd = false});
}

class PriceList {
  final List<PriceRow> rows;
  final List<String> skipped;
  const PriceList(this.rows, this.skipped);
}

String _norm(Object? v) => '${v ?? ''}'
    .toLowerCase()
    .replaceAll(RegExp('[ʻʼ‘’`´]'), "'")
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Workshop words for the materials, as they are written on price lists.
const _aliases = <String, String>{
  'kosa': 'frame',
  'rama': 'frame',
  'rom': 'frame',
  'qanot': 'sash',
  'stvorka': 'sash',
  'orta': 'mullion',
  "o'rta": 'mullion',
  'impost': 'mullion',
  'shtapik': 'bead',
  'shisha': 'glass',
  'oyna': 'glass',
  'steklo': 'glass',
  'tutqich': 'handle',
  'ruchka': 'handle',
  'delfin': 'handle',
  'petlya': 'hinge',
  'zapor': 'windowLock',
  'rezina': 'uGasket',
  'setka': 'mesh',
  'qayt': 'cornerProfile',
  'samorez': 'screw',
  'anker': 'anchor',
  "ko'pik": 'foam',
  'pena': 'foam',
  'silikon': 'silicone',
  'sendvich': 'panel',
  'lambir': 'lambris',
  'ish haqi': 'labor',
};

/// Material key for a name in a price list: the key itself, its Uzbek
/// name in the app, or a common workshop word.
String? materialKeyFor(String name) {
  final n = _norm(name);
  if (n.isEmpty) return null;
  for (final key in materialNames.keys) {
    if (_norm(key) == n) return key;
  }
  for (final e in materialNames.entries) {
    if (_norm(e.value) == n) return e.key;
  }
  return _aliases[n];
}

/// "48 000", "48000 so‘m", "48,000", "1.5" and "1,5" all read as numbers.
double? parsePrice(Object? raw) {
  if (raw is num) return raw.toDouble();
  var s = _norm(raw)
      .replaceAll(RegExp(r"so'm|som|сум|uzs|usd|\$"), '')
      .replaceAll(RegExp(r'[\s  ]'), '');
  if (s.isEmpty) return null;
  if (RegExp(r'^\d{1,3}(,\d{3})+$').hasMatch(s)) s = s.replaceAll(',', '');
  if (RegExp(r'^\d{1,3}(\.\d{3}){2,}$').hasMatch(s)) s = s.replaceAll('.', '');
  s = s.replaceAll(',', '.');
  final v = double.tryParse(s);
  return v == null || !v.isFinite || v < 0 ? null : v;
}

List<String> _csvLine(String line, String sep) {
  final out = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (ch == sep && !quoted) {
      out.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(ch);
    }
  }
  out.add(cell.toString().trim());
  return out;
}

PriceList parsePriceList(String text) {
  final body = text.replaceFirst('﻿', '').trim();
  if (body.isEmpty) throw const FormatException('Narx ro‘yxati bo‘sh');
  final rows = <PriceRow>[], skipped = <String>[];
  void add(Object? name, Object? price, Object? profile, Object? currency) {
    final key = materialKeyFor('$name'), value = parsePrice(price);
    if (key == null || value == null) {
      skipped.add('$name: $price');
      return;
    }
    final p = _norm(profile);
    rows.add(PriceRow(key, materialNames[key] ?? key, value,
        p.isEmpty ? null : '$profile'.trim(),
        usd: _norm(currency) == 'usd' || '$price'.contains(r'$')));
  }

  if (body.startsWith('{') || body.startsWith('[')) {
    final data = jsonDecode(body);
    final currency = data is Map ? data['currency'] ?? data['valyuta'] : null;
    if (data is Map && data['prices'] is Map) {
      for (final e in (data['prices'] as Map).entries) {
        add(e.key, e.value, null, currency);
      }
    }
    final items = data is List ? data : (data is Map ? data['items'] : null);
    if (items is List) {
      for (final item in items) {
        if (item is! Map) continue;
        add(
            item['material'] ?? item['key'] ?? item['name'] ?? item['nomi'],
            item['price'] ?? item['narx'],
            item['profile'] ?? item['profil'],
            item['currency'] ?? item['valyuta'] ?? currency);
      }
    }
  } else {
    final lines = const LineSplitter()
        .convert(body)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    final first = lines.first;
    final sep = [';', '\t', ','].reduce((a, b) =>
        a.allMatches(first).length >= b.allMatches(first).length ? a : b);
    var cols = (name: 0, price: 1, profile: 2, currency: -1);
    var start = 0;
    final head = _csvLine(first, sep).map(_norm).toList();
    if (head.length > 1 && parsePrice(head[1]) == null) {
      int find(List<String> words, int fallback) {
        final i = head.indexWhere((h) => words.any(h.contains));
        return i < 0 ? fallback : i;
      }

      cols = (
        name: find(['material', 'nomi', 'kalit', 'key', 'name'], 0),
        price: find(['narx', 'price', 'summa', 'нарх', 'цена'], 1),
        profile: find(['profil', 'profile', 'tizim'], -1),
        currency: find(['valyuta', 'currency'], -1),
      );
      start = 1;
    }
    for (final line in lines.skip(start)) {
      final c = _csvLine(line, sep);
      String at(int i) => i >= 0 && i < c.length ? c[i] : '';
      add(at(cols.name), at(cols.price), at(cols.profile), at(cols.currency));
    }
  }
  if (rows.isEmpty) {
    throw FormatException(
        'Tanish material topilmadi. Birinchi ustun — material (masalan frame yoki “Tashqi rama”), ikkinchisi — narx.');
  }
  return PriceList(rows, skipped);
}

/// Downloads a price list. Only http(s), at most 2 MB, 20 s.
Future<String> downloadPriceList(Uri url, {HttpClient? client}) async {
  if (url.scheme != 'https' && url.scheme != 'http') {
    throw const FormatException(
        'Havola http:// yoki https:// bilan boshlansin');
  }
  final http = client ?? HttpClient()
    ..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await http.getUrl(url).timeout(const Duration(seconds: 20));
    request.headers.set(HttpHeaders.acceptHeader,
        'text/csv, application/json, text/plain, */*');
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw HttpException('Server javobi: ${response.statusCode}');
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 20))) {
      bytes.addAll(chunk);
      if (bytes.length > 2 * 1024 * 1024) {
        throw const FormatException('Narx fayli 2 MBdan katta');
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  } on SocketException {
    throw const HttpException('Internetga ulanib bo‘lmadi');
  } on HandshakeException {
    throw const HttpException('Internetga ulanib bo‘lmadi');
  } on TimeoutException {
    throw const HttpException('Server javob bermadi: internetni tekshiring');
  } on HttpException catch (e) {
    // A proxy or a dropped connection, not the server's own answer.
    if (e.message.startsWith('Server javobi')) rethrow;
    throw const HttpException('Internetga ulanib bo‘lmadi');
  } finally {
    if (client == null) http.close(force: true);
  }
}

class PriceChange {
  final String profileId, profileName, key, label;
  final num? before;
  final num after;

  /// The dollar price when the list gave one: it follows the rate later.
  final num? usd;
  const PriceChange(this.profileId, this.profileName, this.key, this.label,
      this.before, this.after,
      {this.usd});
}

/// What applying [list] would change in the chosen profiles. USD prices
/// are converted at [usdRate] so‘m.
List<PriceChange> priceChanges(
    List<Json> profiles, PriceList list, Set<String> chosen,
    {num usdRate = 0}) {
  final out = <PriceChange>[];
  for (final p in profiles.where((p) => chosen.contains(p['id']))) {
    final prices = Map<String, dynamic>.from(recipeFor(p)['prices']),
        dollars = Map<String, dynamic>.from(
            (p['drawingRecipe'] as Map?)?['usdPrices'] ?? {});
    final latest = <String, PriceRow>{};
    for (final row in list.rows) {
      final target = _norm(row.profile);
      if (target.isNotEmpty &&
          target != _norm(p['id']) &&
          target != _norm(p['name'])) {
        continue;
      }
      // A row for this profile wins over a general one.
      if (latest[row.key]?.profile != null && row.profile == null) continue;
      latest[row.key] = row;
    }
    for (final row in latest.values) {
      if (row.usd && usdRate <= 0) {
        throw const FormatException(
            'Narxlar dollarda: avval Sozlamalarda dollar kursini kiriting');
      }
      final value = (row.usd ? row.price * usdRate : row.price).round();
      final before = prices[row.key] as num?;
      if (before == value && dollars[row.key] == (row.usd ? row.price : null)) {
        continue;
      }
      out.add(PriceChange(p['id'], p['name'], row.key, row.label, before, value,
          usd: row.usd ? row.price : null));
    }
  }
  return out;
}

/// Fields of the quick (non-drawing) estimate that follow the same prices.
const quickPriceFields = {
  'frame': 'framePrice',
  'sash': 'sashPrice',
  'mullion': 'mullionPrice',
  'glass': 'glassPrice',
  'uGasket': 'gasketPrice',
  'labor': 'laborPrice',
};

/// A CSV the workshop can fill in, e.g. as a Google Sheet.
String priceTemplateCsv(Json profile) {
  final prices = Map<String, dynamic>.from(recipeFor(profile)['prices']);
  final out = StringBuffer('material;nomi;narx;profil\n');
  for (final e in materialNames.entries) {
    out.writeln('${e.key};${e.value};${prices[e.key] ?? 0};');
  }
  return out.toString();
}

/// The daily update: today's official dollar rate (prices that came in
/// dollars follow it) and every price source marked automatic. Returns
/// short notes of what changed; a source that fails keeps its error.
Future<List<String>> autoUpdatePrices(Store s, {HttpClient? client}) async {
  final notes = <String>[];
  try {
    final rate =
        await s.refreshOfficialRate(fetch: () => fetchCbuUsd(client: client));
    if (rate != null) notes.add(rate);
  } catch (_) {
    // Offline: the last rate stays.
  }
  try {
    final note = await s.refreshCatalog(
        fetch: () => downloadPriceList(manufacturersUrl, client: client));
    if (note != null) notes.add(note);
  } catch (_) {
    // Offline or not published yet: the catalog in the app stays.
  }
  for (final src in [...s.priceSources.where((x) => x['auto'] == true)]) {
    final last = DateTime.tryParse('${src['lastFetched'] ?? ''}');
    if (last != null &&
        DateTime.now().difference(last) < const Duration(hours: 20)) {
      continue;
    }
    try {
      final list = parsePriceList(
          await downloadPriceList(Uri.parse(src['url']), client: client));
      final changes = priceChanges(
          s.profiles, list, {for (final p in s.profiles) p['id'] as String},
          usdRate: s.usdRate);
      await s.applyPriceChanges(changes, src['name'],
          sourceId: src['id'], count: list.rows.length);
      if (changes.isNotEmpty) {
        notes.add('${src['name']}: ${changes.length} ta narx yangilandi');
      }
    } catch (e) {
      await s.notePriceSource(src['id'], error: '$e');
    }
  }
  return notes;
}

class PriceSourcesPage extends StatefulWidget {
  final Store store;
  const PriceSourcesPage({super.key, required this.store});
  @override
  State<PriceSourcesPage> createState() => _PriceSourcesPageState();
}

class _PriceSourcesPageState extends State<PriceSourcesPage> {
  Store get s => widget.store;
  String? busy;

  void say(Object text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$text'.replaceFirst(RegExp(r'^\w*Exception: '), ''))));

  Future<void> editSource([Json? source]) async {
    final name = TextEditingController(text: source?['name'] ?? ''),
        url = TextEditingController(text: source?['url'] ?? '');
    var auto = source?['auto'] ?? true;
    final ok = await showSettledDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, setDialog) => AlertDialog(
                title: Text(source == null
                    ? 'Narx manbasi qo‘shish'
                    : 'Manbani tahrirlash'),
                content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: name,
                        decoration: const InputDecoration(
                            labelText: 'Nomi (masalan: Diler)')),
                    const SizedBox(height: 12),
                    TextField(
                        key: const ValueKey('price-source-url'),
                        controller: url,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                            labelText: 'Havola (CSV yoki JSON)',
                            hintText: 'https://…')),
                    const SizedBox(height: 8),
                    Text(
                        'Google Sheets: Fayl → Ulashish → Internetda e’lon qilish → CSV havolasini nusxalang.',
                        style: Theme.of(c).textTheme.bodySmall),
                    SwitchListTile(
                      key: const ValueKey('price-source-auto'),
                      contentPadding: EdgeInsets.zero,
                      value: auto == true,
                      onChanged: (v) => setDialog(() => auto = v),
                      title: const Text('Har kuni o‘zi yangilansin'),
                      subtitle: const Text(
                          'Ilova ochilganda kuniga bir marta narxlar shu havoladan olinadi'),
                    ),
                  ]),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Bekor qilish')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Saqlash')),
                ],
              )),
    );
    if (ok != true) return;
    try {
      await s.savePriceSource({
        ...?source,
        'name': name.text,
        'url': url.text.trim(),
        'auto': auto == true
      });
    } catch (e) {
      say(e);
    }
  }

  Future<void> refresh(Json source) async {
    setState(() => busy = source['id']);
    try {
      final text = await downloadPriceList(Uri.parse(source['url']));
      final list = parsePriceList(text);
      if (!mounted) return;
      await review(list, source['name'], sourceId: source['id']);
    } catch (e) {
      await s.notePriceSource(source['id'], error: '$e');
      if (mounted) say(e);
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Future<void> fromFile() async {
    try {
      final text = await pickTextFile(
          label: 'CSV / JSON', extensions: const ['csv', 'json', 'txt']);
      if (text == null || !mounted) return;
      await review(parsePriceList(text), 'Fayl');
    } catch (e) {
      if (mounted) say(e);
    }
  }

  Future<void> template() async {
    try {
      final ok = await saveFileAs('RomFlow-narxlar.csv', 'text/csv',
          utf8.encode(priceTemplateCsv(s.profiles.first)));
      if (ok && mounted) {
        say('Namuna saqlandi — to‘ldirib, havola yoki fayl sifatida yuklang');
      }
    } catch (e) {
      if (mounted) say(e);
    }
  }

  Future<void> review(PriceList list, String sourceName,
      {String? sourceId}) async {
    final chosen = {for (final p in s.profiles) p['id'] as String};
    final applied = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => PriceReviewPage(
                store: s,
                list: list,
                sourceName: sourceName,
                sourceId: sourceId,
                initial: chosen)));
    if (applied == true && mounted) say('Narxlar yangilandi');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Narxlarni yangilash')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => editSource(),
            icon: const Icon(Icons.add_link),
            label: const Text('Manba')),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  Text(
                      'Narxlarni diler, yetkazib beruvchi yoki o‘zingizning Google Sheets jadvalingizdan oling. Ochiq havola yoki ruxsat berilgan API bo‘lsa yetarli: CSV yoki JSON. Qo‘llashdan oldin har bir o‘zgarish ko‘rsatiladi.',
                      style: text.bodyMedium),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                        onPressed: fromFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Fayldan yuklash')),
                    OutlinedButton.icon(
                        onPressed: template,
                        icon: const Icon(Icons.table_view_outlined),
                        label: const Text('Namuna jadval')),
                  ]),
                  const SizedBox(height: 16),
                  Text('Manbalar', style: text.titleLarge),
                  const SizedBox(height: 8),
                  if (s.priceSources.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                            'Hali manba yo‘q. “Manba” tugmasi bilan diler havolasini yoki e’lon qilingan jadvalingizni qo‘shing.',
                            style: text.bodySmall),
                      ),
                    ),
                  for (final src in s.priceSources)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_download_outlined),
                        title: Text(src['name']),
                        subtitle: Text(
                            [
                              src['url'],
                              if (src['lastFetched'] != null)
                                'Oxirgi: ${localDate(src['lastFetched'])} • ${src['lastCount'] ?? 0} ta narx${src['auto'] == true ? ' • har kuni o‘zi' : ''}',
                              if (src['lastError'] != null)
                                'Xato: ${src['lastError']}',
                            ].join('\n'),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                        isThreeLine: true,
                        onTap: () => editSource(src),
                        onLongPress: () async {
                          await s.deletePriceSource(src['id']);
                        },
                        trailing: busy == src['id']
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : IconButton(
                                tooltip: 'Yangilash',
                                onPressed: () => refresh(src),
                                icon: const Icon(Icons.sync)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                      'Ustunlar: material (masalan frame, “Tashqi rama”, kosa, qanot, orta, shtapik, shisha), narx, ixtiyoriy profil va valyuta (USD). Manbani o‘chirish uchun uzoq bosing.',
                      style: text.bodySmall),
                ]),
          ),
        ),
      ),
    );
  }
}

class PriceReviewPage extends StatefulWidget {
  final Store store;
  final PriceList list;
  final String sourceName;
  final String? sourceId;
  final Set<String> initial;
  const PriceReviewPage(
      {super.key,
      required this.store,
      required this.list,
      required this.sourceName,
      required this.initial,
      this.sourceId});
  @override
  State<PriceReviewPage> createState() => _PriceReviewPageState();
}

class _PriceReviewPageState extends State<PriceReviewPage> {
  late final chosen = {...widget.initial};
  String? error;

  @override
  Widget build(BuildContext context) {
    final s = widget.store, text = Theme.of(context).textTheme;
    List<PriceChange> changes = const [];
    error = null;
    try {
      changes =
          priceChanges(s.profiles, widget.list, chosen, usdRate: s.usdRate);
    } catch (e) {
      error = '$e'.replaceFirst('FormatException: ', '');
    }
    return Scaffold(
      appBar: AppBar(title: Text('Narxlar • ${widget.sourceName}')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            key: const ValueKey('apply-prices'),
            onPressed: changes.isEmpty
                ? null
                : () async {
                    await s.applyPriceChanges(changes, widget.sourceName,
                        sourceId: widget.sourceId,
                        count: widget.list.rows.length);
                    if (context.mounted) Navigator.pop(context, true);
                  },
            icon: const Icon(Icons.check),
            label: Text(changes.isEmpty
                ? 'O‘zgarish yo‘q'
                : '${changes.length} ta narxni qo‘llash'),
          ),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(
                '${widget.list.rows.length} ta narx o‘qildi${widget.list.skipped.isEmpty ? '' : ', ${widget.list.skipped.length} ta qator tanilmadi'}.',
                style: text.bodyMedium),
            const SizedBox(height: 10),
            Text('Qaysi profillarga', style: text.titleMedium),
            for (final p in s.profiles)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: chosen.contains(p['id']),
                title: Text(p['name'],
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onChanged: (v) => setState(() =>
                    v == true ? chosen.add(p['id']) : chosen.remove(p['id'])),
              ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            const Divider(),
            for (final c in changes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(c.label),
                subtitle: Text(c.profileName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(
                    '${c.before == null ? '—' : money(c.before!)} → ${money(c.after)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            if (widget.list.skipped.isNotEmpty) ...[
              const Divider(),
              Text('Tanilmagan qatorlar', style: text.titleSmall),
              for (final line in widget.list.skipped.take(20))
                Text(line, style: text.bodySmall),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Opens the price sources if the plan includes them.
Future<void> openPriceSources(BuildContext context, Store store) =>
    openWithPlan(
        context, store, 'priceSources', () => PriceSourcesPage(store: store));
