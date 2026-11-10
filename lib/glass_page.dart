import 'package:flutter/material.dart';
import 'adaptive_ui.dart';
import 'calculator.dart';
import 'i18n.dart';
import 'manufacturers.dart';
import 'store.dart';

/// One square metre of [g] in so‘m: at today's dollar rate, or at the
/// catalog's own rate until the bank's rate is known.
int glassPriceSom(Store store, GlassType g) {
  final rate =
      store.usdRate > 0 ? store.usdRate : store.catalog?.referenceUsdRate ?? 0;
  return (g.usd * rate).round();
}

const _glassIcons = {
  'clear': Icons.crop_square,
  'toned': Icons.gradient,
  'matte': Icons.blur_on,
  'lowe': Icons.wb_sunny_outlined,
  'tempered': Icons.shield_outlined,
};

/// Every kind of glass in the catalog with today's price for a square
/// metre and where the price was read.
class GlassPage extends StatefulWidget {
  final Store store;
  const GlassPage({super.key, required this.store});
  @override
  State<GlassPage> createState() => _GlassPageState();
}

class _GlassPageState extends State<GlassPage> {
  Store get s => widget.store;
  bool busy = false;

  Future<void> refresh() async {
    setState(() => busy = true);
    String message;
    try {
      message = await s.refreshCatalog(force: true) ??
          tr('Narxlar eng yangi: ${_date(s.catalog?.date ?? '')}');
    } catch (e) {
      message = tr('Narxlar yangilanmadi: $e');
    }
    if (!mounted) return;
    setState(() => busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(message))));
  }

  static String _date(String iso) => iso.split('-').reversed.join('.');

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: s,
        builder: (context, _) {
          final catalog = s.catalog, text = Theme.of(context).textTheme;
          final scheme = Theme.of(context).colorScheme;
          final glass = catalog?.glass ?? const <GlassType>[];
          final units = [
            for (final m in catalog?.materialsMarket ?? const <MarketPrice>[])
              if (m.unit == 'm2') m,
          ];
          return Scaffold(
            extendBodyBehindAppBar: usesIOSGlass,
            appBar: GlassAppBar(
              title: const Tx('Oyna (shisha) narxlari'),
              actions: [
                IconButton(
                  key: const ValueKey('glass-refresh'),
                  tooltip: tr('Narxlarni yangilash'),
                  onPressed: busy ? null : refresh,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            body: ListView(
              key: const ValueKey('glass-list'),
              padding: EdgeInsets.fromLTRB(
                16,
                (usesIOSGlass
                        ? MediaQuery.paddingOf(context).top + kToolbarHeight
                        : 0) +
                    12,
                16,
                MediaQuery.paddingOf(context).bottom + 24,
              ),
              children: [
                if (catalog != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Tx(
                      'Narxlar sanasi: ${_date(catalog.date)} • 1 m² uchun • har kuni yangilanadi',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (glass.isEmpty)
                  const GlassCard(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Tx(
                        'Shisha narxlari hali yuklanmagan. Internetga ulanib, yangilash tugmasini bosing.',
                      ),
                    ),
                  ),
                for (final g in glass)
                  GlassCard(
                    key: ValueKey('glass-row-${g.id}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(
                            _glassIcons[g.kind] ?? Icons.crop_square,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tx(
                                  g.name,
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Tx(
                                  g.estimate
                                      ? 'Taxminiy: 3,5 mm shisha narxidan hisoblangan'
                                      : 'Manba: ${g.source}',
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tx(
                            '${money(glassPriceSom(s, g))}/m²',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final m in units)
                  GlassCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.layers_outlined, color: scheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Tx(
                                  m.what,
                                  style: text.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Tx(
                                  'Manba: ${m.source}',
                                  style: text.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tx(
                            '${money(m.som(s.usdRate > 0 ? s.usdRate : catalog!.referenceUsdRate))}/m²',
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Tx(
                  'Shisha turini chizish stolida tanlang: Rang → Shisha turi. O‘z narxingiz bo‘lsa, profilning “Shisha” narxini o‘zgartiring.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      );
}
