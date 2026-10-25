import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calculator.dart';
import 'design_engine.dart';
import 'manufacturers.dart';
import 'price_sources.dart' show openPriceSources;
import 'store.dart';
import 'adaptive_ui.dart';
import 'i18n.dart';

String _clean(Object e) => '$e'.replaceFirst(RegExp(r'^\w*Exception: '), '');

/// "AKFA Group • Toshkent • Profil zavodi".
String _makerLine(Manufacturer m) => [
      if (m.group.isNotEmpty) m.group,
      if (m.city.isNotEmpty) m.city,
      manufacturerRoles[m.role] ?? m.role,
    ].join(' • ');

/// "2026-10-24" → "24.10.2026"; a month alone → "10.2026".
String _date(String iso) => iso.split('-').reversed.join('.');

String _marketText(MarketPrice m) =>
    '${m.currency == 'USD' ? '${m.price} \$' : money(m.price)}${m.unit == 'm2' ? '/m²' : ''}';

/// Every manufacturer in the catalog with its systems and what one square
/// metre costs in each; a system joins the workshop's profiles in a tap.
class ManufacturersPage extends StatefulWidget {
  final Store store;
  const ManufacturersPage({super.key, required this.store});
  @override
  State<ManufacturersPage> createState() => _ManufacturersPageState();
}

class _ManufacturersPageState extends State<ManufacturersPage> {
  Store get s => widget.store;
  String filter = 'all';
  bool busy = false;
  final _m2 = <String, num?>{};

  void say(Object text) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Tx(_clean(text))));

  /// The profile a system is priced with: the workshop's own, if it has one.
  Json profileOf(ManufacturerCatalog c, ProfileSystem system) {
    final own = s.profiles.where((p) => p['catalogId'] == system.id);
    return own.isEmpty ? c.profileFor(system, s.usdRate) : own.first;
  }

  num? squareMetre(ManufacturerCatalog c, ProfileSystem system) {
    final profile = profileOf(c, system);
    final key = '${system.id}|${c.version}|${jsonEncode(profile)}';
    return _m2.putIfAbsent(key, () {
      try {
        return referenceSquareMetre(system, profile);
      } catch (_) {
        return null;
      }
    });
  }

  bool shown(ProfileSystem x) => switch (filter) {
        'aluminium' || 'pvc' => x.material == filter,
        'thermal' => x.material == 'aluminium' && x.thermal,
        'sliding' => x.sliding,
        _ => true,
      };

  Future<void> refresh() async {
    setState(() => busy = true);
    try {
      final note = await s.refreshCatalog(force: true);
      say(note ?? 'Katalog eng yangi: ${s.catalog?.date ?? ''}');
    } catch (e) {
      say('Katalog yangilanmadi: ${_clean(e)}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add(ProfileSystem system) async {
    try {
      await s.addCatalogProfile(system.id);
      say('${system.name} profillar ro‘yxatiga qo‘shildi');
    } catch (e) {
      say(e);
    }
  }

  void copy(String url) {
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    say('Havola nusxalandi: $url');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final c = s.catalog;
        return Scaffold(
          appBar: GlassAppBar(
            title: const Tx('Ishlab chiqaruvchilar'),
            actions: [
              busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      key: const ValueKey('catalog-refresh'),
                      tooltip: tr('Katalogni yangilash'),
                      onPressed: refresh,
                      icon: const Icon(Icons.sync),
                    ),
            ],
          ),
          body: c == null
              ? const Center(child: Tx('Katalog yuklanmadi'))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView(
                      key: const ValueKey('manufacturers-list'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      children: [
                        summary(c),
                        const SizedBox(height: 12),
                        filters(),
                        const SizedBox(height: 4),
                        for (final m in c.manufacturers)
                          if (filter == 'all' || c.systemsOf(m.id).any(shown))
                            makerCard(c, m),
                        materials(c),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget summary(ManufacturerCatalog c) {
    final scheme = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme;
    final rate = s.usdRate > 0 ? s.usdRate : c.referenceUsdRate;
    return GlassCard(
      key: const ValueKey('mf-summary'),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx(
              'O‘zbekiston zavodlari narxi',
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Tx(
              '${c.manufacturers.length} ta ishlab chiqaruvchi • ${c.systems.length} ta profil tizimi',
              style: text.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 2),
            Tx(
              'Katalog ${_date(c.date)} • 1 \$ = ${money(rate)}${s.usdRate > 0 ? '' : ' (taxminiy kurs)'}',
              style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            Tx(
              '1 m² narxi — 1400 × 1400 mm, 2 bo‘limli, bitta ochiladigan rom; sizning ustamangiz bilan. Narxlar ochiq bozor e’lonlaridan olingan taxminiy narx: diler narxini kiritsangiz, sizniki ishlatiladi.',
              style: text.bodySmall?.copyWith(color: scheme.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  Widget filters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (id, name) in const [
              ('all', 'Hammasi'),
              ('aluminium', 'Alyuminiy'),
              ('pvc', 'PVX'),
              ('thermal', 'Termo alyuminiy'),
              ('sliding', 'Surilma'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GlassControl(
                  child: ChoiceChip(
                    key: ValueKey('mf-filter-$id'),
                    label: Tx(name),
                    selected: filter == id,
                    onSelected: (_) => setState(() => filter = id),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget makerCard(ManufacturerCatalog c, Manufacturer m) {
    final scheme = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme;
    final systems = [...c.systemsOf(m.id).where(shown)]..sort(
        (a, b) => (squareMetre(c, a) ?? double.infinity).compareTo(
          squareMetre(c, b) ?? double.infinity,
        ),
      );
    return GlassCard(
      key: ValueKey('maker-${m.id}'),
      margin: const EdgeInsets.only(top: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.secondaryContainer,
                  child: Tx(
                    m.name.characters.first,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tx(
                        m.name,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Tx(
                        _makerLine(m),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (m.website.isNotEmpty)
                  IconButton(
                    tooltip: tr('Sayt havolasini nusxalash'),
                    onPressed: () => copy(m.website),
                    icon: const Icon(Icons.link),
                  ),
              ],
            ),
            if (m.about.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 0),
                child: Tx(m.about, style: text.bodySmall),
              ),
            if (systems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  onPressed: () => openPriceSources(context, s),
                  icon: const Icon(Icons.cloud_sync_outlined),
                  label: const Tx('Diler narxini kiritish'),
                ),
              ),
            for (final system in systems) systemRow(c, system),
          ],
        ),
      ),
    );
  }

  Widget systemRow(ManufacturerCatalog c, ProfileSystem system) {
    final scheme = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme;
    final m2 = squareMetre(c, system);
    final used = s.profiles.any((p) => p['catalogId'] == system.id);
    return Padding(
      padding: const EdgeInsets.only(top: 10, right: 8),
      child: GlassControl(
          child: InkWell(
        key: ValueKey('system-${system.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => details(c, system),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tx(
                      system.name,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Tx(
                      system.specs,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Tx(
                      m2 == null
                          ? 'Hisoblanmadi'
                          : '≈ ${money((m2 / 1000).round() * 1000)}/m²',
                      key: ValueKey('m2-${system.id}'),
                      style: text.titleSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    for (final market in system.market)
                      Tx(
                        'Bozor: ${_marketText(market)} — ${market.source}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              used
                  ? Tooltip(
                      message: 'Profillar ro‘yxatida bor',
                      child: Icon(
                        Icons.check_circle,
                        key: ValueKey('mf-used-${system.id}'),
                        color: scheme.primary,
                      ),
                    )
                  : IconButton.filledTonal(
                      key: ValueKey('mf-add-${system.id}'),
                      tooltip: tr('Profillar ro‘yxatiga qo‘shish'),
                      onPressed: () => add(system),
                      icon: const Icon(Icons.add),
                    ),
            ],
          ),
        ),
      )),
    );
  }

  Future<void> details(ManufacturerCatalog c, ProfileSystem system) async {
    final text = Theme.of(context).textTheme;
    final profile = profileOf(c, system);
    final prices = Map<String, dynamic>.from(recipeFor(profile)['prices']);
    final usd = Map<String, dynamic>.from(
      profile['drawingRecipe']?['usdPrices'] ?? const {},
    );
    await showGlassSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Tx(system.name, style: text.titleLarge),
              Tx(
                '${c.maker(system.manufacturer).name} • ${system.specs}',
                style: text.bodySmall,
              ),
              if (system.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Tx(system.note, style: text.bodySmall),
                ),
              const SizedBox(height: 12),
              for (final k in const [
                'frame',
                'sash',
                'mullion',
                'bead',
                'glass',
              ])
                GlassControl(
                    child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Tx(materialNames[k] ?? k),
                  trailing: Tx(
                    '${money(prices[k])}${k == 'glass' ? '/m²' : '/m'}${usd[k] is num ? '  (${usd[k]} \$)' : ''}',
                  ),
                )),
              const SizedBox(height: 8),
              for (final market in system.market)
                GlassControl(
                    child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.storefront_outlined),
                  title: Tx('${market.what}: ${_marketText(market)}'),
                  subtitle: Tx('${market.source} • ${_date(market.seen)}'),
                  trailing: market.url.isEmpty
                      ? null
                      : IconButton(
                          tooltip: tr('Havolani nusxalash'),
                          onPressed: () => copy(market.url),
                          icon: const Icon(Icons.copy, size: 20),
                        ),
                )),
              if (system.catalogUrl.isNotEmpty)
                TextButton.icon(
                  onPressed: () => copy(system.catalogUrl),
                  icon: const Icon(Icons.link),
                  label: const Tx('Zavod sahifasi havolasi'),
                ),
              const SizedBox(height: 8),
              Tx(
                'Narxni o‘zgartirish: Profillar → “Narxlarni tahrirlash” yoki diler jadvalidan yuklang. Siz kiritgan narx katalog yangilanganda ham saqlanadi.',
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget materials(ManufacturerCatalog c) {
    if (c.materialsMarket.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return GlassCard(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tx('Materiallar bozori', style: text.titleMedium),
            for (final m in c.materialsMarket)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Tx(
                  '${m.what}: ${_marketText(m)} — ${m.source}',
                  style: text.bodySmall,
                ),
              ),
            const SizedBox(height: 8),
            Tx(c.note, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// The drawing on the desk priced with every manufacturer's system,
/// cheapest first. Returns the profile id the workshop picks, adding the
/// system to its profiles when needed.
Future<String?> showPriceComparison(
  BuildContext context,
  Store store, {
  required DMap drawing,
  required int quantity,
  Map<String, dynamic> keep = const {},
  String? currentProfile,
  num? currentTotal,
}) async {
  final catalog = store.catalog;
  if (catalog == null) return null;
  final quotes = compareSystems(
    catalog,
    store.profiles,
    drawing,
    quantity,
    keep: keep,
    usdRate: store.usdRate,
  );
  final currentData =
      store.profiles.where((p) => p['id'] == currentProfile).firstOrNull;
  final current = currentData?['catalogId'];
  final picked = await showGlassSheet<ProfileSystem>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ComparisonSheet(
      catalog,
      quotes,
      drawing,
      quantity,
      current,
      currentName: currentData?['name'],
      currentTotal: currentTotal,
    ),
  );
  if (picked == null) return null;
  return store.addCatalogProfile(picked.id);
}

class _ComparisonSheet extends StatefulWidget {
  final ManufacturerCatalog catalog;
  final List<SystemQuote> quotes;
  final DMap drawing;
  final int quantity;
  final Object? current;

  /// The desk's own profile and price, for a profile not in the catalog.
  final String? currentName;
  final num? currentTotal;
  const _ComparisonSheet(
    this.catalog,
    this.quotes,
    this.drawing,
    this.quantity,
    this.current, {
    this.currentName,
    this.currentTotal,
  });
  @override
  State<_ComparisonSheet> createState() => _ComparisonSheetState();
}

class _ComparisonSheetState extends State<_ComparisonSheet> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme;
    final shown = [
      for (final q in widget.quotes)
        if (filter == 'all' || q.system.material == filter) q,
    ];
    final cheapest = shown
        .where((q) => q.total != null)
        .map((q) => q.total!)
        .fold<num?>(null, (a, b) => a == null || b < a ? b : a);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Tx('Zavodlar narxi', style: text.titleLarge),
                  Tx(
                    '${widget.drawing['widthMm']} × ${widget.drawing['heightMm']} mm × ${widget.quantity} dona • ${widget.quotes.length} ta tizim • arzonidan',
                    style: text.bodySmall,
                  ),
                  if (widget.current == null &&
                      widget.currentName != null &&
                      widget.currentTotal != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Tx(
                        'Hozirgi: ${widget.currentName} — ${money(widget.currentTotal)}',
                        key: const ValueKey('compare-current'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (id, name) in const [
                        ('all', 'Hammasi'),
                        ('aluminium', 'Alyuminiy'),
                        ('pvc', 'PVX'),
                      ])
                        GlassControl(
                          child: ChoiceChip(
                            key: ValueKey('compare-filter-$id'),
                            label: Tx(name),
                            selected: filter == id,
                            onSelected: (_) => setState(() => filter = id),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('compare-list'),
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final q = shown[i];
                  final isCurrent = q.system.id == widget.current;
                  final extra =
                      q.total == null || cheapest == null || cheapest == 0
                          ? null
                          : ((q.total! / cheapest - 1) * 100).round();
                  return GlassCard(
                    color: isCurrent ? scheme.primaryContainer : null,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: GlassControl(
                        child: ListTile(
                      key: ValueKey('compare-${q.system.id}'),
                      enabled: q.total != null,
                      onTap: () => Navigator.pop(context, q.system),
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor: i == 0 && q.total != null
                            ? Colors.green.shade600
                            : scheme.surfaceContainerHighest,
                        child: Tx(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: i == 0 && q.total != null
                                ? Colors.white
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                      title: Tx(
                        q.system.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Tx(
                        q.error ??
                            '${widget.catalog.maker(q.system.manufacturer).name} • ${q.system.specs}${isCurrent ? ' • hozirgi' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: q.total == null
                          ? null
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Tx(
                                  money(q.total),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (extra != null && extra > 0)
                                  Tx(
                                    '+$extra%',
                                    style: text.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                    )),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
