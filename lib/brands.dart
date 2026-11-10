import 'package:flutter/material.dart';
import 'adaptive_ui.dart';
import 'i18n.dart';
import 'store.dart';

/// How a brand shows on its tile: the wordmark, its colours and whether
/// the letters lean, as on the maker's own sign.
class _BrandStyle {
  final String word;
  final Color back, ink;
  final bool italic;
  const _BrandStyle(this.word, this.back, this.ink, {this.italic = false});
}

const _brandStyles = {
  'akfa': _BrandStyle('AKFA', Color(0xffd71920), Colors.white, italic: true),
  'engelberg': _BrandStyle('ENGELBERG', Color(0xff14284b), Colors.white),
  'imzo': _BrandStyle('IMZO', Color(0xff0b5cad), Colors.white),
  'alubest': _BrandStyle('Alubest', Color(0xff0e7c86), Colors.white),
  'alutex': _BrandStyle('ALUTEX', Color(0xff2f3b4a), Colors.white),
  'alsys': _BrandStyle('Alsys', Color(0xff1f6f43), Colors.white),
  'benkam': _BrandStyle('BENKAM', Color(0xff8a5a00), Colors.white),
  'rehau': _BrandStyle('REHAU', Color(0xffffffff), Color(0xff222222)),
};

/// Materials that are not a brand get a picture of the material.
const _materialIcons = {
  'umumiy pvx': Icons.window_outlined,
  'yog‘och': Icons.forest_outlined,
  'metall': Icons.hardware_outlined,
  'mdf': Icons.door_front_door_outlined,
};

/// "AKFA Aluminium" and "AKFA Plast" are one brand on the picker: [name]
/// reduced to the key of its style and of its logo file.
String brandKey(String name) {
  final low = name.trim().toLowerCase();
  for (final key in _brandStyles.keys) {
    if (low.startsWith(key) || low.contains(key)) return key;
  }
  return low;
}

/// The brand of a profile in the workshop's list.
String profileBrand(Store store, Map<String, dynamic> profile) {
  final system = store.catalog?.system('${profile['catalogId'] ?? ''}');
  if (system != null) {
    final name = system.name.toLowerCase();
    // ENGELBERG and REHAU systems carry their brand in the system's name.
    for (final key in const ['engelberg', 'rehau']) {
      if (name.contains(key)) return _brandStyles[key]!.word;
    }
    return store.catalog!.maker(system.manufacturer).name;
  }
  final brand = '${profile['brand'] ?? ''}'.trim();
  return brand.isEmpty ? '${profile['name'] ?? ''}' : brand;
}

/// A brand's sign: its logo file from assets/brands when the workshop has
/// added one, else the wordmark drawn in the brand's colours.
class MakerLogo extends StatelessWidget {
  final String brand;
  final double height;
  const MakerLogo(this.brand, {super.key, this.height = 44});

  @override
  Widget build(BuildContext context) {
    final key = brandKey(brand), style = _brandStyles[key];
    final scheme = Theme.of(context).colorScheme;
    final icon = _materialIcons[key];
    final Widget drawn = icon != null
        ? Icon(icon, size: height * .6, color: scheme.primary)
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                style?.word ?? brand,
                maxLines: 1,
                style: TextStyle(
                  color: style?.ink ?? scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w900,
                  fontStyle: style?.italic == true
                      ? FontStyle.italic
                      : FontStyle.normal,
                  fontSize: height * .42,
                  letterSpacing: .6,
                ),
              ),
            ),
          );
    return Semantics(
      label: brand,
      image: true,
      child: ExcludeSemantics(
        child: Container(
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: icon != null
                ? scheme.surfaceContainerHighest
                : style?.back ?? scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: style == null
              ? drawn
              : Image.asset(
                  'assets/brands/$key.png',
                  height: height,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => drawn,
                ),
        ),
      ),
    );
  }
}

/// The profile in use as a row with its brand's sign; a tap opens the
/// picker.
class ProfilePickTile extends StatelessWidget {
  final Store store;
  final String? profile;
  final ValueChanged<String> onChanged;
  const ProfilePickTile({
    super.key,
    required this.store,
    required this.profile,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = store.profiles.where((p) => p['id'] == profile).firstOrNull;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const ValueKey('pick-profile'),
        onTap: () async {
          final id = await pickProfile(context, store, current: profile);
          if (id != null && id != profile) onChanged(id);
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                child: MakerLogo(
                  current == null ? '' : profileBrand(store, current),
                  height: 40,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Tx(
                  '${current?['name'] ?? 'Profilni tanlang'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(Icons.expand_more, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picks a profile in two steps: the brand by its sign, then the series.
/// Returns the profile's id, or null when the sheet is closed.
Future<String?> pickProfile(
  BuildContext context,
  Store store, {
  String? current,
}) {
  final brands = <String, List<Map<String, dynamic>>>{};
  final names = <String, String>{};
  for (final p in store.profiles) {
    final name = profileBrand(store, Map<String, dynamic>.from(p));
    final key = brandKey(name);
    names.putIfAbsent(key, () => _brandStyles[key]?.word ?? name);
    brands.putIfAbsent(key, () => []).add(Map<String, dynamic>.from(p));
  }
  String? open;
  for (final e in brands.entries) {
    if (e.value.any((p) => p['id'] == current)) open = e.key;
  }
  open ??= brands.keys.firstOrNull;
  return showGlassSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, refresh) {
        final scheme = Theme.of(sheet).colorScheme;
        final series = brands[open] ?? const [];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * .82,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Tx('Brendni tanlang',
                    style: Theme.of(sheet).textTheme.titleLarge),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, box) {
                    final columns = box.maxWidth >= 520 ? 4 : 3;
                    final width = (box.maxWidth - (columns - 1) * 10) / columns;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final key in brands.keys)
                          SizedBox(
                            width: width,
                            child: Material(
                              color: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: key == open
                                      ? scheme.primary
                                      : scheme.outlineVariant,
                                  width: key == open ? 2.5 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: ValueKey('brand-$key'),
                                onTap: () => refresh(() => open = key),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Column(
                                    children: [
                                      MakerLogo(names[key]!, height: 46),
                                      const SizedBox(height: 4),
                                      Tx(
                                        '${brands[key]!.length} ta',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Tx('Turini tanlang',
                    style: Theme.of(sheet).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final p in series)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: p['id'] == current
                          ? scheme.primary.withValues(alpha: .16)
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: .6),
                      borderRadius: BorderRadius.circular(14),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: ValueKey('series-${p['id']}'),
                        onTap: () => Navigator.pop(sheet, '${p['id']}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Tx(
                                      '${p['name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_specs(store, p).isNotEmpty)
                                      Tx(
                                        _specs(store, p),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (p['id'] == current)
                                Icon(Icons.check_circle, color: scheme.primary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// "65 mm • 3 kamera • termo" for a catalog system; empty otherwise.
String _specs(Store store, Map<String, dynamic> profile) =>
    store.catalog?.system('${profile['catalogId'] ?? ''}')?.specs ?? '';
