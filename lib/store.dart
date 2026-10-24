import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'calculator.dart';
import 'design_engine.dart';
import 'reminder_service.dart';
import 'billing.dart' show defaultSubscription;
import 'exchange_rate.dart';
import 'manufacturers.dart';
import 'price_sources.dart'
    show PriceChange, downloadPriceList, quickPriceFields;

/// All data is kept on the device. The network is used only to download
/// price lists from sources the workshop adds.
class Store extends ChangeNotifier {
  Store({Directory? directory}) : _directory = directory;
  Directory? _directory;
  Future<void> _queue = Future.value();
  bool ready = false;
  bool get online => false;
  bool get isOwner => true;
  String workshopName = 'Mening ustaxonam',
      workshopPhone = '',
      workshopAddress = '';
  String themePreference = 'system';
  String? startupMessage;

  /// So‘m per US dollar for prices quoted in dollars; 0 when not set.
  num usdRate = 0;

  /// Where [usdRate] came from: 'cbu' (the Central Bank's daily rate) or
  /// 'manual'; the bank's date for it; and whether it updates itself.
  String usdRateSource = '', usdRateDate = '';
  bool usdRateAuto = true;
  DateTime? _rateCheckedAt;

  /// The manufacturers' price catalog: the one in the app, or a newer one
  /// downloaded since. [catalogSeeded] lists the default systems already
  /// added to [profiles] once, so a deleted one does not come back.
  ManufacturerCatalog? catalog;
  List<String> catalogSeeded = [];
  DateTime? _catalogCheckedAt;
  static Future<String> Function() bundledCatalog =
      () => rootBundle.loadString(manufacturersAsset);
  File get _catalogFile => File('${_directory!.path}/manufacturers-uz.json');
  Json subscription = defaultSubscription();
  List<Json> profiles = sampleProfiles(),
      customers = [],
      quotes = [],
      staff = [],
      audit = [],
      debts = [],
      reminders = [],
      inventory = [],
      inventoryMoves = [],
      drawingTemplates = [],
      expenses = [],
      payroll = [],
      priceSources = [],
      measurements = [];
  File get _file => File('${_directory!.path}/romflow-offline.json');

  /// The workshop's own Anthropic API key for the AI camera. It lives in a
  /// separate file, never in the data or its backups, so a shared backup
  /// does not carry it.
  String aiKey = '';
  File get _aiKeyFile => File('${_directory!.path}/ai-key');

  Future<void> setAiKey(String key) async {
    final value = key.trim();
    if (value.isEmpty) {
      if (await _aiKeyFile.exists()) await _aiKeyFile.delete();
    } else {
      await _aiKeyFile.writeAsString(value, flush: true);
    }
    aiKey = value;
    notifyListeners();
  }

  Future<void> init() async {
    _directory ??= await getApplicationSupportDirectory().timeout(
      const Duration(seconds: 8),
    );
    await _directory!.create(recursive: true);
    try {
      if (await _aiKeyFile.exists()) {
        aiKey = (await _aiKeyFile.readAsString()).trim();
      }
    } catch (_) {
      aiKey = '';
    }
    await _loadCatalog();
    var found = false;
    for (final suffix in ['', '.bak', '.tmp']) {
      final f = File('${_file.path}$suffix');
      if (!await f.exists()) continue;
      found = true;
      try {
        _load(jsonDecode(await f.readAsString()));
        for (final p in sampleProfiles()
            .where((p) => p['id'].toString().startsWith('series-'))) {
          if (!profiles.any((existing) => existing['id'] == p['id'])) {
            profiles.add(p);
          }
        }
        _seedCatalog();
        ready = true;
        await ReminderScheduler.reconcile(reminders);
        if (suffix.isNotEmpty) {
          startupMessage = 'Ma’lumotlar zaxira nusxadan tiklandi.';
        }
        return;
      } catch (_) {
        /* Try the intact backup before reporting a recovery error. */
      }
    }
    if (found) {
      throw const FormatException(
        'Saqlangan fayl buzilgan. Fayllar o‘chirilgani yo‘q. Zaxira nusxa orqali tiklash kerak.',
      );
    }
    _seedCatalog();
    ready = true;
    await _write();
  }

  /// The catalog in the app, or the newer one downloaded earlier.
  Future<void> _loadCatalog() async {
    ManufacturerCatalog? best;
    try {
      best = ManufacturerCatalog.parse(await bundledCatalog());
    } catch (_) {
      // Without the bundled file (plain unit tests) there is no catalog.
    }
    try {
      if (await _catalogFile.exists()) {
        final cached =
            ManufacturerCatalog.parse(await _catalogFile.readAsString());
        if (best == null || cached.version > best.version) best = cached;
      }
    } catch (_) {
      // A damaged download is ignored; the bundled catalog stays.
    }
    catalog = best;
  }

  /// Every workshop, new or updating the app, gets each popular system in
  /// its profile list once.
  void _seedCatalog() {
    final c = catalog;
    if (c == null) return;
    for (final id in defaultCatalogSystems) {
      final system = c.system(id);
      if (system == null || catalogSeeded.contains(id)) continue;
      if (!profiles.any((p) => p['catalogId'] == id)) {
        profiles.add(c.profileFor(system, usdRate));
      }
      catalogSeeded.add(id);
    }
  }

  /// The profile for catalog system [systemId], added if the workshop does
  /// not use it yet. Returns the profile id.
  Future<String> addCatalogProfile(String systemId) async {
    final existing = profiles.where((p) => p['catalogId'] == systemId);
    if (existing.isNotEmpty) return existing.first['id'] as String;
    final system = catalog?.system(systemId);
    if (system == null) throw Exception('Katalogda bunday tizim yo‘q');
    final profile = catalog!.profileFor(system, usdRate);
    await _change('Profil qo‘shildi: ${system.name}', () {
      validateProfile(profile);
      profiles.add(profile);
    });
    return profile['id'] as String;
  }

  /// A newer catalog from the public repository, at most daily unless
  /// [force]d. Dollar prices the workshop left as they came follow it;
  /// prices it typed or imported itself stay. Returns a note on change.
  Future<String?> refreshCatalog(
      {bool force = false, Future<String> Function()? fetch}) async {
    final last = _catalogCheckedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(hours: 20)) {
      return null;
    }
    final text = await (fetch ?? () => downloadPriceList(manufacturersUrl))();
    _catalogCheckedAt = DateTime.now();
    final fresh = ManufacturerCatalog.parse(text);
    if (catalog != null && fresh.version <= catalog!.version) return null;
    var updated = 0;
    // The new catalog counts only once the profiles took its prices: a
    // failed save leaves both as they were, and the next check retries.
    await _change('Ishlab chiqaruvchilar katalogi yangilandi', () {
      for (final p in profiles) {
        final system = fresh.system('${p['catalogId'] ?? ''}');
        if (system == null) continue;
        final recipe = Map<String, dynamic>.from(p['drawingRecipe'] ?? {});
        final usd = Map<String, dynamic>.from(recipe['usdPrices'] ?? {}),
            before = Map<String, dynamic>.from(recipe['catalogUsd'] ?? {}),
            next = fresh.usdFor(system);
        for (final e in next.entries) {
          // Still the catalog's own price (or not priced yet): follow it.
          if (!usd.containsKey(e.key) && before.containsKey(e.key)) continue;
          if (usd.containsKey(e.key) && usd[e.key] != before[e.key]) continue;
          usd[e.key] = e.value;
        }
        recipe['usdPrices'] = usd;
        recipe['catalogUsd'] = next;
        recipe['catalogVersion'] = fresh.version;
        p['drawingRecipe'] = recipe;
        updated++;
      }
      _repriceUsd();
    });
    catalog = fresh;
    await _catalogFile.writeAsString(text, flush: true);
    notifyListeners();
    return 'Ishlab chiqaruvchilar katalogi: ${fresh.date}, ${fresh.systems.length} ta tizim${updated > 0 ? ', $updated ta profil narxi yangilandi' : ''}';
  }

  List<Json> _list(dynamic x) {
    if (x is! List) throw const FormatException('Ro‘yxat formati xato');
    return x.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  void _load(dynamic d) {
    if (d is! Map || d['format'] != 'romflow-offline' || d['version'] != 1) {
      throw const FormatException('RomFlow zaxira formati xato');
    }
    final p = _list(d['profiles']),
        c = _list(d['customers']),
        q = _list(d['quotes']);
    if (p.isEmpty) throw const FormatException('Kamida bitta profil kerak');
    for (final x in p) {
      validateProfile(x);
      if (x['id'] is! String) throw const FormatException('Profil ID xato');
    }
    for (final x in c) {
      if (x['id'] is! String || x['name'] is! String) {
        throw const FormatException('Mijoz formati xato');
      }
    }
    for (final x in q) {
      if (x['id'] is! String ||
          x['title'] is! String ||
          !statuses.containsKey(x['status']) ||
          x['items'] is! List ||
          x['total'] is! num ||
          x['paid'] is! num ||
          x['balance'] is! num) {
        throw const FormatException('Smeta formati xato');
      }
    }
    final loadedDebts = _list(d['debts'] ?? []),
        loadedReminders = _list(d['reminders'] ?? []);
    for (final item in loadedDebts) {
      validateDebt(item);
    }
    for (final item in loadedReminders) {
      validateReminder(item);
    }
    debts = loadedDebts;
    reminders = loadedReminders;
    final loadedExpenses = _list(d['expenses'] ?? []),
        loadedPayroll = _list(d['payroll'] ?? []);
    for (final row in loadedExpenses) {
      validateExpense(row);
    }
    for (final row in loadedPayroll) {
      validatePayroll(row);
    }
    expenses = loadedExpenses;
    payroll = loadedPayroll;
    inventory = _list(d['inventory'] ?? []);
    inventoryMoves = _list(d['inventoryMoves'] ?? []);
    drawingTemplates = _list(d['drawingTemplates'] ?? []);
    for (final row in inventory) {
      validateStock(row);
    }
    for (final row in drawingTemplates) {
      if (row['id'] is! String ||
          row['name'] is! String ||
          row['item'] is! Map) {
        throw const FormatException('Andoza noto‘g‘ri');
      }
      layoutDrawing(Map<String, dynamic>.from(row['item']['drawing']),
          Map<String, dynamic>.from(row['item']['recipe']));
    }
    themePreference = d['themePreference'] ?? 'system';
    if (!const {'system', 'light', 'dark'}.contains(themePreference)) {
      throw const FormatException('Tema noto‘g‘ri');
    }
    profiles = p;
    customers = c;
    quotes = q;
    staff = _list(d['staff'] ?? []);
    audit = _list(d['audit'] ?? []);
    workshopName = (d['workshopName'] ?? 'Mening ustaxonam').toString();
    workshopPhone = (d['workshopPhone'] ?? '').toString();
    workshopAddress = (d['workshopAddress'] ?? '').toString();
    final rate = d['usdRate'] ?? 0;
    if (rate is! num || !rate.isFinite || rate < 0) {
      throw const FormatException('Dollar kursi noto‘g‘ri');
    }
    usdRate = rate;
    usdRateSource = '${d['usdRateSource'] ?? ''}';
    usdRateDate = '${d['usdRateDate'] ?? ''}';
    usdRateAuto = d['usdRateAuto'] != false;
    catalogSeeded = [
      for (final id in (d['catalogSeeded'] is List ? d['catalogSeeded'] : []))
        '$id'
    ];
    subscription = d['subscription'] is Map
        ? Map<String, dynamic>.from(d['subscription'])
        : defaultSubscription();
    priceSources = _list(d['priceSources'] ?? []);
    final loadedMeasurements = _list(d['measurements'] ?? []);
    for (final m in loadedMeasurements) {
      validateMeasurement(m);
    }
    measurements = loadedMeasurements;
    extraPrices = {
      for (final e in Map<String, dynamic>.from(d['extraPrices'] ?? {}).entries)
        if (e.value is num) e.key: e.value as num
    };
  }

  Json snapshot() => {
        'format': 'romflow-offline',
        'version': 1,
        'workshopName': workshopName,
        'workshopPhone': workshopPhone,
        'workshopAddress': workshopAddress,
        'profiles': profiles,
        'customers': customers,
        'quotes': quotes,
        'staff': staff,
        'audit': audit,
        'debts': debts,
        'reminders': reminders,
        'themePreference': themePreference,
        'inventory': inventory,
        'inventoryMoves': inventoryMoves,
        'drawingTemplates': drawingTemplates,
        'expenses': expenses,
        'payroll': payroll,
        'usdRate': usdRate,
        'usdRateSource': usdRateSource,
        'usdRateDate': usdRateDate,
        'usdRateAuto': usdRateAuto,
        'catalogSeeded': catalogSeeded,
        'subscription': subscription,
        'priceSources': priceSources,
        'measurements': measurements,
        'extraPrices': extraPrices,
      };
  Future<void> _write() async {
    final temp = File('${_file.path}.tmp');
    await temp.writeAsString(jsonEncode(snapshot()), flush: true);
    if (await _file.exists()) {
      try {
        jsonDecode(await _file.readAsString());
        await _file.copy('${_file.path}.bak');
      } catch (_) {}
    }
    await temp.rename(_file.path);
  }

  Future<void> _change(String action, void Function() update) {
    final result = _queue.then((_) async {
      if (!ready) throw StateError('Saqlash joyi tayyor emas');
      final before = jsonDecode(jsonEncode(snapshot()));
      try {
        update();
        audit.insert(0, {
          'id': newId(),
          'action': action,
          'created': DateTime.now().toIso8601String(),
        });
        if (audit.length > 1000) audit.removeRange(1000, audit.length);
        await _write();
        if (jsonEncode(before['reminders']) != jsonEncode(reminders)) {
          await ReminderScheduler.reconcile(reminders);
        }
      } catch (e) {
        _load(before);
        rethrow;
      }
      notifyListeners();
    });
    _queue = result.catchError((Object _) {});
    return result;
  }

  Future<void> refresh() async {
    await _queue;
    notifyListeners();
  }

  Future<void> setWorkshop(String name, {String? phone, String? address}) =>
      _change('Ustaxona ma’lumotlari o‘zgartirildi', () {
        if (name.trim().isEmpty) throw Exception('Nom kiriting');
        workshopName = name.trim();
        if (phone != null) workshopPhone = phone.trim();
        if (address != null) workshopAddress = address.trim();
      });
  Future<void> addCustomer(Json c) => _change('Mijoz saqlandi', () {
        if ((c['name'] ?? '').toString().trim().isEmpty) {
          throw Exception('Mijoz ismini kiriting');
        }
        final data = {'id': c['id'] ?? newId(), ...c};
        final i = customers.indexWhere((x) => x['id'] == data['id']);
        if (i < 0) {
          customers.insert(0, data);
        } else {
          customers[i] = data;
        }
      });
  void validateProfile(Json p) {
    if (p['drawingRecipe'] != null) validateRecipe(recipeFor(p));
    if ((p['name'] ?? '').toString().trim().isEmpty ||
        (p['brand'] ?? '').toString().trim().isEmpty) {
      throw Exception('Profil nomi va brend kerak');
    }
    for (final k in [
      'framePrice',
      'sashPrice',
      'mullionPrice',
      'glassPrice',
      'hardwarePrice',
      'gasketPrice',
      'laborPrice',
      'wastePct',
      'markupPct',
      'frameFaceMm',
      'sashFaceMm',
    ]) {
      final n = p[k];
      if (n is! num || !n.isFinite || n < 0 || n > 100000000) {
        throw Exception('$k qiymati noto‘g‘ri');
      }
    }
    if (p['frameFaceMm'] < 10 ||
        p['frameFaceMm'] > 150 ||
        p['sashFaceMm'] < 10 ||
        p['sashFaceMm'] > 150 ||
        p['wastePct'] > 40 ||
        p['markupPct'] > 200) {
      throw Exception('Profil yuzi 10–150 mm, chiqindi 0–40%, ustama 0–200%');
    }
    for (final k in ['meshPrice', 'anthraciteFactor', 'oakFactor']) {
      if (p.containsKey(k) &&
          (p[k] is! num || p[k] < 0 || !(p[k] as num).isFinite)) {
        throw Exception('$k qiymati noto‘g‘ri');
      }
    }
  }

  /// [typed] names the quick price fields the workshop changed in the
  /// editor; without it, a field that differs from the stored one counts.
  Future<void> saveProfile(Json p, {Set<String>? typed}) =>
      _change('Profil narxlari saqlandi', () {
        validateProfile(p);
        final data = {'id': p['id'] ?? newId(), ...p};
        final i = profiles.indexWhere((x) => x['id'] == data['id']);
        if (i >= 0) _takeOverTypedPrices(profiles[i], data, typed);
        if (i < 0) {
          profiles.add(data);
        } else {
          profiles[i] = data;
        }
      });

  /// A quick price typed over one that came in dollars: the typed so‘m
  /// price now counts for the drawing too and no longer follows the rate.
  /// Fields left alone keep their stored value, which the rate may have
  /// moved while the editor was open.
  void _takeOverTypedPrices(Json before, Json after, Set<String>? typed) {
    bool changed(String field) =>
        typed?.contains(field) ?? after[field] != before[field];
    if (typed != null && before['drawingRecipe'] != null) {
      after['drawingRecipe'] = before['drawingRecipe'];
    }
    if (before.containsKey('hardwareFollows')) {
      after['hardwareFollows'] =
          before['hardwareFollows'] == true && !changed('hardwarePrice');
      if (!changed('hardwarePrice')) {
        after['hardwarePrice'] = before['hardwarePrice'];
      }
    }
    final recipe = after['drawingRecipe'];
    if (recipe is! Map) return;
    final r = Map<String, dynamic>.from(recipe),
        prices = Map<String, dynamic>.from(r['prices'] ?? {}),
        usd = Map<String, dynamic>.from(r['usdPrices'] ?? {});
    for (final e in quickPriceFields.entries) {
      if (!changed(e.value) || after[e.value] is! num) {
        if (before.containsKey(e.value)) after[e.value] = before[e.value];
        continue;
      }
      if (prices.containsKey(e.key)) prices[e.key] = after[e.value];
      usd.remove(e.key);
    }
    r['prices'] = prices;
    usd.isEmpty ? r.remove('usdPrices') : r['usdPrices'] = usd;
    after['drawingRecipe'] = r;
  }

  Future<void> saveStaff(Json p) => _change('Xodim saqlandi', () {
        if ((p['name'] ?? '').toString().trim().isEmpty) {
          throw Exception('Ism kiriting');
        }
        final data = {'id': p['id'] ?? newId(), ...p};
        final i = staff.indexWhere((x) => x['id'] == data['id']);
        if (i < 0) {
          staff.add(data);
        } else {
          staff[i] = data;
        }
      });
  Future<void> deleteStaff(String id) => _change('Xodim ro‘yxatdan olindi', () {
        if (staffBalance(id) != 0) {
          throw Exception(
              'Avval xodim bilan hisob-kitobni yoping (qoldiq 0 bo‘lsin)');
        }
        staff.removeWhere((x) => x['id'] == id);
        payroll.removeWhere((p) => p['staffId'] == id);
        for (final q in quotes) {
          if (q['staffId'] == id) q.remove('staffId');
        }
      });
  Future<void> assignStaff(Json q, String? id) =>
      _change('Buyurtma xodimga biriktirildi', () {
        quotes.firstWhere((x) => x['id'] == q['id'])['staffId'] = id;
      });
  Future<Json> estimate(Json body) async {
    final raw = body['items'] as List;
    if (raw.isEmpty) throw Exception('Konstruksiya qo‘shing');
    final items = raw
        .map(
          (i) => calculate(
            Map<String, dynamic>.from(i),
            profiles.firstWhere((p) => p['id'] == i['profileId'],
                orElse: () => throw Exception(
                    'Pozitsiya profili katalogdan o‘chirilgan. Chizmani ochib boshqa profil tanlang')),
          ),
        )
        .toList();
    return {
      ...body,
      'items': items,
      ...totals(items, body['discount'], body['installation'],
          body['extras'] as List? ?? const []),
      'estimate': true,
      'calculationVersion': 'offline-estimate-v2',
    };
  }

  /// Last price used for each kind of extra work, offered next time.
  Map<String, num> extraPrices = {};

  void _rememberExtras(Json data) {
    for (final e in data['extras'] as List? ?? const []) {
      if (e['key'] != null && e['key'] != 'other') {
        extraPrices[e['key']] = e['price'];
      }
    }
  }

  Future<Json> saveQuote(Json body) async {
    final data = await estimate(body),
        c = customers.firstWhere((x) => x['id'] == body['customerId']);
    final q = <String, dynamic>{
      'id': newId(),
      ...data,
      'status': 'draft',
      'created': DateTime.now().toIso8601String(),
      'customer': c['name'],
      'phone': c['phone'],
      'address': c['address'],
      'paid': 0,
      'balance': data['total'],
      'payments': <Json>[],
    };
    await _change('Smeta yaratildi', () {
      quotes.insert(0, q);
      _rememberExtras(q);
    });
    return q;
  }

  /// Recalculates an existing order with new items and terms. Payments,
  /// status, staff and history stay; the balance follows the new total.
  Future<Json> updateQuote(String id, Json body) async {
    final data = await estimate(body),
        c = customers.firstWhere((x) => x['id'] == body['customerId']);
    late Json updated;
    await _change('Smeta tahrirlandi', () {
      final at = quotes.indexWhere((q) => q['id'] == id);
      if (at < 0) throw Exception('Smeta topilmadi');
      final old = quotes[at];
      final paid = old['paid'] as num, total = data['total'] as num;
      if (total < paid) {
        throw Exception(
            'Yangi summa ${money(total)} olingan to‘lovdan (${money(paid)}) kam bo‘lmasin');
      }
      updated = {
        ...old,
        ...data,
        'id': id,
        'status': old['status'],
        'created': old['created'],
        'edited': DateTime.now().toIso8601String(),
        'customer': c['name'],
        'phone': c['phone'],
        'address': c['address'],
        'paid': paid,
        'balance': total - paid,
        'payments': old['payments'] ?? [],
      };
      if (old['stockConsumed'] == true) {
        throw Exception(
            'Material ombordan chiqarilgan. Avval omborga qaytaring, keyin tahrirlang');
      }
      quotes[at] = updated;
      _rememberExtras(updated);
    });
    return updated;
  }

  /// A fresh draft with the same constructions and terms, no payments.
  Future<Json> duplicateQuote(String id) async {
    final old = quotes.firstWhere((q) => q['id'] == id);
    final copy = <String, dynamic>{
      ...Map<String, dynamic>.from(jsonDecode(jsonEncode(old))),
      'id': newId(),
      'title': '${old['title']} (nusxa)',
      'status': 'draft',
      'created': DateTime.now().toIso8601String(),
      'paid': 0,
      'balance': old['total'],
      'payments': <Json>[],
      'stockConsumed': false,
    }
      ..remove('stockUsage')
      ..remove('staffId')
      ..remove('installDate')
      ..remove('edited');
    await _change('Smeta nusxalandi', () => quotes.insert(0, copy));
    return copy;
  }

  Future<void> deleteQuote(String id) => _change('Smeta o‘chirildi', () {
        final q = quotes.firstWhere((q) => q['id'] == id);
        if (q['stockConsumed'] == true) {
          throw Exception('Avval ombordan chiqarilgan materialni qaytaring');
        }
        quotes.removeWhere((q) => q['id'] == id);
        // Salaries and expenses are money history: keep them, unlinked.
        for (final e in [...payroll, ...expenses]) {
          if (e['quoteId'] == id) e.remove('quoteId');
        }
      });

  Future<void> setInstallDate(String id, DateTime? date) =>
      _change('Montaj sanasi belgilandi', () {
        final q = quotes.firstWhere((q) => q['id'] == id);
        if (date == null) {
          q.remove('installDate');
        } else {
          q['installDate'] = date.toIso8601String();
        }
      });

  Future<void> deleteCustomer(String id) => _change('Mijoz o‘chirildi', () {
        // Orders keep their own copy of the customer's name and phone.
        customers.removeWhere((c) => c['id'] == id);
      });

  Future<void> deleteProfile(String id) => _change('Profil o‘chirildi', () {
        if (profiles.length <= 1) throw Exception('Kamida bitta profil qoladi');
        profiles.removeWhere((p) => p['id'] == id);
      });

  static const expenseCategories = <String, String>{
    'material': 'Material xaridi',
    'transport': 'Transport / yetkazish',
    'rent': 'Ijara',
    'utility': 'Kommunal',
    'tools': 'Asbob-uskuna',
    'ads': 'Reklama',
    'other': 'Boshqa',
  };

  static void validateExpense(Json e) {
    if (e['id'] is! String ||
        !expenseCategories.containsKey(e['category']) ||
        e['amount'] is! int ||
        e['amount'] <= 0 ||
        e['amount'] > 1000000000000 ||
        DateTime.tryParse(e['created'] ?? '') == null) {
      throw const FormatException('Xarajat yozuvi noto‘g‘ri');
    }
  }

  Future<void> addExpense(Json body) => _change('Xarajat yozildi', () {
        final entry = <String, dynamic>{
          'note': '',
          'created': DateTime.now().toIso8601String(),
          ...body,
          'id': newId(),
        };
        validateExpense(entry);
        expenses.insert(0, entry);
      });

  Future<void> deleteExpense(String id) => _change(
      'Xarajat o‘chirildi', () => expenses.removeWhere((e) => e['id'] == id));

  /// How a worker is paid: the rate means so‘m per month, day, m², percent
  /// of the order total or per construction.
  static const payTypes = <String, String>{
    'monthly': 'Oylik (oyiga)',
    'daily': 'Kunlik',
    'perM2': 'Har m² uchun',
    'percent': 'Buyurtmadan %',
    'piece': 'Har konstruksiya uchun',
  };
  static const payKinds = <String, String>{
    'accrual': 'Ish haqi hisoblandi',
    'bonus': 'Bonus',
    'penalty': 'Jarima / ushlab qolish',
    'advance': 'Avans berildi',
    'payment': 'Ish haqi to‘landi',
  };

  static void validatePayroll(Json e) {
    if (e['id'] is! String ||
        e['staffId'] is! String ||
        !payKinds.containsKey(e['kind']) ||
        e['amount'] is! int ||
        e['amount'] <= 0 ||
        e['amount'] > 1000000000000 ||
        DateTime.tryParse(e['created'] ?? '') == null) {
      throw const FormatException('Ish haqi yozuvi noto‘g‘ri');
    }
  }

  Future<void> addPayroll(Json body) =>
      _change(payKinds[body['kind']] ?? 'Ish haqi yozuvi', () {
        if (!staff.any((s) => s['id'] == body['staffId'])) {
          throw Exception('Xodim topilmadi');
        }
        final entry = <String, dynamic>{
          'note': '',
          'created': DateTime.now().toIso8601String(),
          ...body,
          'id': newId(),
        };
        validatePayroll(entry);
        payroll.insert(0, entry);
      });

  Future<void> deletePayroll(String id) => _change('Ish haqi yozuvi o‘chirildi',
      () => payroll.removeWhere((e) => e['id'] == id));

  /// What the workshop still owes the worker (negative: worker owes).
  int staffBalance(String staffId) =>
      payroll.where((e) => e['staffId'] == staffId).fold<int>(0, (sum, e) {
        final amount = e['amount'] as int;
        return const {'accrual', 'bonus'}.contains(e['kind'])
            ? sum + amount
            : sum - amount;
      });

  /// Salary the worker's rate gives for one order; 0 when paid by time.
  static int suggestedPay(Json worker, Json quote) {
    final rate = (worker['rate'] as num?) ?? 0;
    final items = (quote['items'] as List).cast<Map>();
    switch (worker['payType']) {
      case 'perM2':
        final m2 = items.fold<double>(
            0,
            (s, i) =>
                s +
                ((i['areaM2'] as num?) ?? 0) * ((i['quantity'] as num?) ?? 1));
        return (m2 * rate).round();
      case 'percent':
        return ((quote['total'] as num) * rate / 100).round();
      case 'piece':
        return (items.fold<num>(
                    0, (s, i) => s + ((i['quantity'] as num?) ?? 1)) *
                rate)
            .round();
    }
    return 0;
  }

  Future<void> changeStatus(Json q, String status) =>
      _change('Buyurtma holati o‘zgardi', () {
        final item = quotes.firstWhere((x) => x['id'] == q['id']);
        if (!(transitions[item['status']] ?? []).contains(status)) {
          throw Exception('Noto‘g‘ri bosqich');
        }
        item['status'] = status;
      });
  Future<void> payment(Json q, int amount, String note) =>
      _change('To‘lov qayd etildi', () {
        final item = quotes.firstWhere((x) => x['id'] == q['id']);
        if (amount <= 0 ||
            amount > (item['balance'] as num) ||
            item['status'] == 'cancelled') {
          throw Exception('To‘lov summasi noto‘g‘ri');
        }
        item['paid'] += amount;
        item['balance'] -= amount;
        (item['payments'] as List).add({
          'amount': amount,
          'note': note,
          'created': DateTime.now().toIso8601String(),
        });
      });
  Future<void> setTheme(String value) => _change('Tema o‘zgartirildi', () {
        if (!const {'system', 'light', 'dark'}.contains(value)) {
          throw Exception('Tema noto‘g‘ri');
        }
        themePreference = value;
      });
  static void validateStock(Json row) {
    if (row['id'] is! String ||
        row['profileId'] is! String ||
        !materialNames.containsKey(row['key']) ||
        row['unit'] is! String) {
      throw const FormatException('Ombor yozuvi noto‘g‘ri');
    }
    for (final k in ['quantity', 'price', 'minimum']) {
      final v = row[k];
      if (v is! num || !v.isFinite || v < 0 || v > 1e12) {
        throw const FormatException('Ombor miqdori yoki narxi noto‘g‘ri');
      }
    }
  }

  static String stockId(String profile, String key, String unit) =>
      '$profile|$key|$unit';
  Future<void> saveStock(Json body) => _change('Ombor qoldig‘i saqlandi', () {
        final row = <String, dynamic>{
          'price': 0,
          'minimum': 0,
          ...body,
          'id': stockId(body['profileId'], body['key'], body['unit'])
        };
        validateStock(row);
        final at = inventory.indexWhere((r) => r['id'] == row['id']);
        if (at < 0) {
          inventory.add(row);
        } else {
          inventory[at] = row;
        }
      });
  Future<void> stockMovement(String id, double delta, String note) =>
      _change('Ombor kirim/chiqimi', () {
        if (!delta.isFinite || delta == 0) throw Exception('Miqdor noto‘g‘ri');
        final row = inventory.firstWhere((r) => r['id'] == id),
            next = (row['quantity'] as num) + delta;
        if (next < -.000001) throw Exception('Ombor qoldig‘i yetmaydi');
        row['quantity'] = next.abs() < .000001 ? 0 : next;
        inventoryMoves.insert(0, {
          'id': newId(),
          'stockId': id,
          'delta': delta,
          'note': note,
          'created': DateTime.now().toIso8601String()
        });
      });
  List<Json> stockNeeds(List items) {
    final grouped = <String, Json>{};
    for (final item in items) {
      if (item['parts'] is! List) {
        throw Exception('Ombor taqqoslash uchun chizmali smeta kerak');
      }
      for (final part in item['parts']) {
        final key = part['key'] as String;
        if (!materialNames.containsKey(key) ||
            const {'labor', 'bending'}.contains(key)) {
          continue;
        }
        final id = stockId(item['profileId'], key, part['unit']);
        final row = grouped.putIfAbsent(
            id,
            () => {
                  'id': id,
                  'profileId': item['profileId'],
                  'profileName': item['profileName'] ?? item['profileId'],
                  'key': key,
                  'name': part['name'],
                  'unit': part['unit'],
                  'required': 0.0,
                  'price': part['price']
                });
        row['required'] = (row['required'] as num) + (part['quantity'] as num);
      }
    }
    return grouped.values.map((need) {
      final found = inventory.where((r) => r['id'] == need['id']);
      final have =
          found.isEmpty ? 0.0 : (found.first['quantity'] as num).toDouble();
      final missing =
          ((need['required'] as num) - have).clamp(0, double.infinity);
      return <String, dynamic>{
        ...need,
        'available': have,
        'missing': missing,
        'purchaseCost':
            (missing * (found.isEmpty ? need['price'] : found.first['price']))
                .round()
      };
    }).toList();
  }

  Future<void> applyQuoteStock(String quoteId, bool consume) => _change(
          consume
              ? 'Buyurtmaga ombordan chiqarildi'
              : 'Buyurtma materiali omborga qaytarildi', () {
        final q = quotes.firstWhere((q) => q['id'] == quoteId);
        if (consume) {
          if (q['stockConsumed'] == true) {
            throw Exception('Bu buyurtma materiali allaqachon chiqarilgan');
          }
          if (q['status'] == 'cancelled') {
            throw Exception('Bekor qilingan buyurtma');
          }
          final needs = stockNeeds(q['items']);
          if (needs.isEmpty) throw Exception('Material yo‘q');
          if (needs.any((r) => (r['missing'] as num) > .000001)) {
            throw Exception('Ombor yetmaydi; yetishmovchilikni to‘ldiring');
          }
          q['stockUsage'] = [
            for (final row in needs)
              {'id': row['id'], 'quantity': row['required']}
          ];
          for (final use in q['stockUsage']) {
            final stock = inventory.firstWhere((r) => r['id'] == use['id']);
            stock['quantity'] =
                ((stock['quantity'] as num) - (use['quantity'] as num))
                    .clamp(0, double.infinity);
          }
          q['stockConsumed'] = true;
        } else {
          if (q['stockConsumed'] != true) {
            throw Exception('Ombordan chiqarilmagan');
          }
          for (final use in q['stockUsage'] as List) {
            final stock = inventory.firstWhere((r) => r['id'] == use['id']);
            stock['quantity'] =
                (stock['quantity'] as num) + (use['quantity'] as num);
          }
          q['stockConsumed'] = false;
        }
        inventoryMoves.insert(0, {
          'id': newId(),
          'quoteId': quoteId,
          'note': consume ? 'Buyurtmaga sarf' : 'Buyurtmadan qaytdi',
          'created': DateTime.now().toIso8601String()
        });
      });
  Future<void> saveDrawingTemplate(String name, Json item) =>
      _change('Chizma andozasi saqlandi', () {
        if (name.trim().isEmpty) throw Exception('Andoza nomini kiriting');
        layoutDrawing(Map<String, dynamic>.from(item['drawing']),
            Map<String, dynamic>.from(item['recipe']));
        drawingTemplates.insert(0, {
          'id': newId(),
          'name': name.trim(),
          'item': jsonDecode(jsonEncode(item)),
          'created': DateTime.now().toIso8601String()
        });
      });
  Future<void> deleteDrawingTemplate(String id) => _change('Andoza o‘chirildi',
      () => drawingTemplates.removeWhere((t) => t['id'] == id));

  static int debtPaid(Json d) => (d['payments'] as List? ?? [])
      .fold<int>(0, (sum, p) => sum + (p['amount'] as int));
  static int debtBalance(Json d) => (d['amount'] as int) - debtPaid(d);
  static void validateDebt(Json d) {
    if (d['id'] is! String ||
        (d['person'] as String? ?? '').trim().isEmpty ||
        !const {'receivable', 'payable'}.contains(d['direction']) ||
        d['amount'] is! int ||
        d['amount'] <= 0 ||
        d['amount'] > 1000000000000 ||
        (d['due'] != null && DateTime.tryParse(d['due']) == null) ||
        d['payments'] is! List) {
      throw const FormatException('Qarz ma’lumotlari noto‘g‘ri');
    }
    final ids = <String>{};
    for (final p in d['payments']) {
      if (p is! Map ||
          p['id'] is! String ||
          !ids.add(p['id']) ||
          p['amount'] is! int ||
          p['amount'] <= 0 ||
          DateTime.tryParse(p['created'] ?? '') == null) {
        throw const FormatException('Qarz to‘lovi noto‘g‘ri');
      }
    }
    if (debtBalance(d) < 0) throw const FormatException('To‘lov qarzdan katta');
  }

  static void validateReminder(Json r) {
    if (r['id'] is! String ||
        (r['title'] as String? ?? '').trim().isEmpty ||
        DateTime.tryParse(r['due'] ?? '') == null ||
        r['done'] is! bool) {
      throw const FormatException('Eslatma noto‘g‘ri');
    }
  }

  Future<void> addDebt(Json body) => _change('Qarz daftariga yozildi', () {
        final entry = <String, dynamic>{
          ...body,
          'id': newId(),
          'created': DateTime.now().toIso8601String(),
          'payments': <Json>[]
        };
        validateDebt(entry);
        debts.insert(0, entry);
      });
  Future<void> debtPayment(String id, int amount, String note) =>
      _change('Qarz to‘lovi yozildi', () {
        final d = debts.firstWhere((d) => d['id'] == id);
        if (amount <= 0 || amount > debtBalance(d)) {
          throw Exception('To‘lov qolgan qarzdan oshmasin');
        }
        (d['payments'] as List).add({
          'id': newId(),
          'amount': amount,
          'note': note.trim(),
          'created': DateTime.now().toIso8601String()
        });
      });
  Future<String> saveReminder(Json body) async {
    final id = body['id'] as String? ?? newId();
    await _change('Eslatma saqlandi', () {
      final entry = <String, dynamic>{
        'note': '',
        'done': false,
        ...body,
        'id': id
      };
      validateReminder(entry);
      final at = reminders.indexWhere((r) => r['id'] == id);
      if (at < 0) {
        reminders.add(entry);
      } else {
        reminders[at] = entry;
      }
    });
    return id;
  }

  Future<void> completeReminder(String id, bool done) =>
      _change('Eslatma holati o‘zgardi', () {
        reminders.firstWhere((r) => r['id'] == id)['done'] = done;
      });
  Future<void> deleteReminder(String id) => _change(
      'Eslatma o‘chirildi', () => reminders.removeWhere((r) => r['id'] == id));

  Future<String> exportBackup() async {
    await _queue;
    return const JsonEncoder.withIndent('  ').convert(snapshot());
  }

  Future<void> importBackup(String raw) async {
    if (raw.length > 10 * 1024 * 1024) throw Exception('Zaxira 10 MBdan katta');
    final decoded = jsonDecode(raw);
    // Validate in an isolated store before touching current records.
    final check = Store(directory: _directory);
    check._load(decoded);
    await _change('Zaxira nusxa tiklandi', () => _load(decoded));
  }

  Future<void> deleteAccount(String _) =>
      _change('Mahalliy ma’lumotlar tozalandi', () {
        profiles = sampleProfiles();
        catalogSeeded = [];
        _seedCatalog();
        customers = [];
        quotes = [];
        staff = [];
        audit = [];
        debts = [];
        expenses = [];
        payroll = [];
        reminders = [];
        inventory = [];
        inventoryMoves = [];
        drawingTemplates = [];
        themePreference = 'system';
        priceSources = [];
        measurements = [];
        usdRate = 0;
        usdRateSource = '';
        usdRateDate = '';
      });

  static const measurementStatuses = {
    'planned': 'Rejada',
    'done': 'O‘lchandi',
    'cancelled': 'Bekor qilindi',
  };

  /// A measuring visit at the customer's: when, where, and the openings
  /// measured there (mm).
  static void validateMeasurement(Json m) {
    if (m['id'] is! String ||
        '${m['customer'] ?? ''}'.trim().isEmpty ||
        DateTime.tryParse('${m['date']}') == null ||
        !measurementStatuses.containsKey(m['status']) ||
        m['sizes'] is! List) {
      throw const FormatException('Razmer ma’lumoti noto‘g‘ri');
    }
    for (final size in m['sizes'] as List) {
      if (size is! Map) throw const FormatException('O‘lcham noto‘g‘ri');
      for (final k in ['widthMm', 'heightMm']) {
        final v = size[k];
        if (v is! num || v < 300 || v > 6000) {
          throw const FormatException('O‘lcham 300–6000 mm bo‘lsin');
        }
      }
      final q = size['quantity'];
      if (q is! int || q < 1 || q > 100) {
        throw const FormatException('Soni 1–100 bo‘lsin');
      }
      if (!templates.any((t) => t['id'] == (size['template'] ?? 'double'))) {
        throw const FormatException('Konstruksiya turi noma’lum');
      }
    }
  }

  void _measurementReminder(Json m) {
    final id = 'zamer-${m['id']}';
    reminders.removeWhere((r) => r['id'] == id);
    final at = DateTime.parse(m['date']);
    if (m['status'] != 'planned' || !at.isAfter(DateTime.now())) return;
    reminders.add({
      'id': id,
      'title': 'Razmer: ${m['customer']}',
      'note': '${m['address'] ?? ''}',
      'due': at.subtract(const Duration(hours: 1)).toIso8601String(),
      'done': false,
    });
  }

  Future<Json> saveMeasurement(Json body) async {
    final data = {
      'status': 'planned',
      'sizes': <Json>[],
      ...body,
      'id': body['id'] ?? newId(),
    };
    await _change('Razmer saqlandi', () {
      validateMeasurement(data);
      final i = measurements.indexWhere((x) => x['id'] == data['id']);
      i < 0 ? measurements.add(data) : measurements[i] = data;
      measurements.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
      _measurementReminder(data);
    });
    return data;
  }

  Future<void> setMeasurementStatus(String id, String status,
          {String? quoteId}) =>
      _change('Razmer holati: ${measurementStatuses[status]}', () {
        if (!measurementStatuses.containsKey(status)) {
          throw Exception('Holat noma’lum');
        }
        final m = measurements.firstWhere((x) => x['id'] == id);
        m['status'] = status;
        if (quoteId != null) m['quoteId'] = quoteId;
        _measurementReminder(m);
      });

  /// Splits what is still owed on an order into [months] monthly payments
  /// from [first], with a reminder on each due date.
  Future<void> setPaymentSchedule(String quoteId, int months, DateTime first) =>
      _change('Bo‘lib to‘lash jadvali tuzildi', () {
        final q = quotes.firstWhere((x) => x['id'] == quoteId);
        final balance = (q['balance'] as num).round();
        if (months < 2 || months > 36) throw Exception('Muddat 2–36 oy');
        if (balance <= 0) throw Exception('Qoldiq yo‘q');
        // Round to thousands; the last payment takes the rest.
        final part = ((balance / months) / 1000).floor() * 1000;
        final rows = <Json>[];
        for (var i = 0; i < months; i++) {
          final due = DateTime(first.year, first.month + i, first.day, 10);
          rows.add({
            'due': due.toIso8601String(),
            'amount': i == months - 1 ? balance - part * (months - 1) : part,
          });
        }
        q['schedule'] = {'paidAtStart': q['paid'], 'rows': rows};
        reminders.removeWhere((r) => '${r['id']}'.startsWith('pay-$quoteId-'));
        for (var i = 0; i < rows.length; i++) {
          if (!DateTime.parse(rows[i]['due']).isAfter(DateTime.now())) continue;
          reminders.add({
            'id': 'pay-$quoteId-$i',
            'title': 'To‘lov: ${q['customer']} — ${money(rows[i]['amount'])}',
            'note': '${q['title']} • ${i + 1}/${rows.length}',
            'due': rows[i]['due'],
            'done': false,
          });
        }
      });

  Future<void> clearPaymentSchedule(String quoteId) =>
      _change('Bo‘lib to‘lash jadvali olib tashlandi', () {
        quotes.firstWhere((x) => x['id'] == quoteId).remove('schedule');
        reminders.removeWhere((r) => '${r['id']}'.startsWith('pay-$quoteId-'));
      });

  Future<void> deleteMeasurement(String id) => _change('Razmer o‘chirildi', () {
        measurements.removeWhere((x) => x['id'] == id);
        reminders.removeWhere((r) => r['id'] == 'zamer-$id');
      });

  static String rateSourceName(String source) => switch (source) {
        'cbu' => 'Markaziy bank',
        'open' => 'xalqaro kurs, ExchangeRate-API',
        _ => 'qo‘lda',
      };

  /// A new dollar rate; every price that came in dollars follows it.
  Future<void> setUsdRate(num rate,
          {String source = 'manual', String date = ''}) =>
      _change(
          source == 'manual'
              ? 'Dollar kursi o‘zgartirildi'
              : 'Dollar kursi (${rateSourceName(source)}): $rate', () {
        if (!rate.isFinite || rate < 0 || rate > 1000000) {
          throw Exception('Dollar kursi 0–1 000 000 so‘m bo‘lsin');
        }
        usdRate = rate;
        usdRateSource = source;
        usdRateDate = date;
        _repriceUsd();
      });

  Future<void> setUsdRateAuto(bool on) => _change(
      on
          ? 'Dollar kursi avtomatik yangilanadi'
          : 'Dollar kursi qo‘lda kiritiladi',
      () => usdRateAuto = on);

  /// Today's official rate from the Central Bank, at most every six hours
  /// unless [force]d. Returns a note when the rate changed.
  Future<String?> refreshOfficialRate(
      {bool force = false, Future<OfficialRate> Function()? fetch}) async {
    if (!force && !usdRateAuto) return null;
    final last = _rateCheckedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(hours: 6)) {
      return null;
    }
    final official = await (fetch ?? fetchUsdRate)();
    _rateCheckedAt = DateTime.now();
    final rate = (official.rate * 100).round() / 100;
    if (rate == usdRate &&
        usdRateSource == official.source &&
        usdRateDate == official.date) {
      return null;
    }
    await setUsdRate(rate, source: official.source, date: official.date);
    return 'Dollar kursi: 1 \$ = ${rate.toStringAsFixed(2)} so‘m (${rateSourceName(official.source)}${official.date.isEmpty ? '' : ', ${official.date}'})';
  }

  /// Prices that came in dollars, at the current rate.
  void _repriceUsd() {
    // Before the first official rate, the catalog's own rate stands in.
    final rate = usdRate > 0 ? usdRate : catalog?.referenceUsdRate ?? 0;
    if (rate <= 0) return;
    final today = DateTime.now().toIso8601String().split('T').first;
    for (final p in profiles) {
      final recipe = Map<String, dynamic>.from(p['drawingRecipe'] ?? {});
      final usd = recipe['usdPrices'];
      if (usd is! Map || usd.isEmpty) continue;
      final prices = Map<String, dynamic>.from(recipe['prices'] ?? {});
      for (final e in usd.entries) {
        if (e.value is! num) continue;
        final value = ((e.value as num) * rate).round();
        prices[e.key] = value;
        final quick = quickPriceFields[e.key];
        if (quick != null) p[quick] = value;
      }
      if (p['hardwareFollows'] == true) {
        p['hardwarePrice'] =
            quickHardware(prices, sliding: p['sliding'] == true);
      }
      recipe['prices'] = prices;
      recipe['priceDate'] = today;
      p['drawingRecipe'] = recipe;
      validateProfile(p);
    }
  }

  Future<void> savePriceSource(Json source) =>
      _change('Narx manbasi saqlandi', () {
        final name = '${source['name'] ?? ''}'.trim(),
            url = Uri.tryParse('${source['url'] ?? ''}'.trim());
        if (name.isEmpty) throw Exception('Manba nomini kiriting');
        if (url == null ||
            !const {'http', 'https'}.contains(url.scheme) ||
            url.host.isEmpty) {
          throw Exception('Havola https:// bilan boshlansin');
        }
        final data = {
          ...source,
          'id': source['id'] ?? newId(),
          'name': name,
          'url': url.toString()
        };
        final i = priceSources.indexWhere((x) => x['id'] == data['id']);
        i < 0 ? priceSources.add(data) : priceSources[i] = data;
      });

  Future<void> deletePriceSource(String id) => _change(
      'Narx manbasi o‘chirildi',
      () => priceSources.removeWhere((x) => x['id'] == id));

  Future<void> notePriceSource(String id, {String? error}) =>
      _change('Narx manbasi tekshirildi', () {
        for (final src in priceSources.where((x) => x['id'] == id)) {
          src['lastError'] =
              error?.replaceFirst(RegExp(r'^\w*Exception: '), '');
        }
      });

  /// Writes new prices into the profiles' recipes; the quick estimate's
  /// own price fields follow for the same materials.
  Future<void> applyPriceChanges(List<PriceChange> changes, String source,
          {String? sourceId, int? count}) =>
      _change('Narxlar yangilandi: $source', () {
        final today = DateTime.now().toIso8601String().split('T').first;
        for (final c in changes) {
          final p = profiles.firstWhere((x) => x['id'] == c.profileId);
          final recipe = Map<String, dynamic>.from(p['drawingRecipe'] ?? {});
          recipe['prices'] = {
            ...Map<String, dynamic>.from(recipe['prices'] ?? {}),
            c.key: c.after
          };
          // A dollar price is kept to follow the rate later.
          final usd = Map<String, dynamic>.from(recipe['usdPrices'] ?? {});
          if (c.usd != null) {
            usd[c.key] = c.usd;
          } else {
            usd.remove(c.key);
          }
          if (usd.isEmpty) {
            recipe.remove('usdPrices');
          } else {
            recipe['usdPrices'] = usd;
          }
          recipe['priceDate'] = today;
          recipe['priceSource'] = source;
          p['drawingRecipe'] = recipe;
          final quick = quickPriceFields[c.key];
          if (quick != null) p[quick] = c.after;
          validateProfile(p);
        }
        for (final src in priceSources.where((x) => x['id'] == sourceId)) {
          src['lastFetched'] = DateTime.now().toIso8601String();
          src['lastCount'] = count ?? changes.length;
          src.remove('lastError');
        }
      });
}
