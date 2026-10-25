import 'package:flutter/material.dart';
import 'i18n_data.dart';

/// The app's languages. Uzbek is the source text written in the code;
/// Russian and English come from [i18nPlain] and [i18nTemplates].
enum AppLanguage { uz, ru, en }

AppLanguage appLanguage = AppLanguage.uz;

AppLanguage languageFromCode(String? code) => switch (code) {
      'ru' => AppLanguage.ru,
      'en' => AppLanguage.en,
      _ => AppLanguage.uz,
    };

/// Each language's name in itself, for the picker.
const languageNames = {
  AppLanguage.uz: 'O‘zbekcha',
  AppLanguage.ru: 'Русский',
  AppLanguage.en: 'English',
};

final _cache = <AppLanguage, Map<String, String>>{};
List<(RegExp, List<String>)>? _templates;

List<(RegExp, List<String>)> get _compiledTemplates => _templates ??= [
      for (final e in (i18nTemplates.entries.toList()
        // The most specific templates first.
        ..sort((a, b) => b.key
            .replaceAll('{}', '')
            .length
            .compareTo(a.key.replaceAll('{}', '').length))))
        (
          RegExp(
            '^${e.key.split('{}').map(RegExp.escape).join('(.+?)')}\$',
            dotAll: true,
          ),
          e.value,
        ),
    ];

/// [uz] in the chosen language. Text the app wrote is translated whole;
/// text with numbers or names in it is matched against the templates, and
/// the parts in it are translated too. Anything else (a customer's name,
/// an address) is left as it is.
String tr(String uz) {
  final lang = appLanguage;
  if (lang == AppLanguage.uz || uz.trim().isEmpty) return uz;
  final cache = _cache.putIfAbsent(lang, () => {});
  final hit = cache[uz];
  if (hit != null) return hit;
  final out = _translate(uz, lang, 0);
  if (cache.length > 4000) cache.clear();
  cache[uz] = out;
  return out;
}

String _translate(String uz, AppLanguage lang, int depth) {
  final index = lang == AppLanguage.ru ? 0 : 1;
  final plain = i18nPlain[uz];
  if (plain != null) return plain[index];
  if (depth > 2 || !uz.contains(RegExp('[A-Za-z]'))) return uz;
  for (final (pattern, values) in _compiledTemplates) {
    final m = pattern.firstMatch(uz);
    if (m == null) continue;
    var out = values[index];
    for (var i = m.groupCount; i >= 1; i--) {
      out = out.replaceAll(
        '{${i - 1}}',
        _translate(m.group(i)!, lang, depth + 1),
      );
    }
    return out;
  }
  // A name and its count, as on filter chips: "Derazalar 27".
  final counted = _counted.firstMatch(uz);
  if (counted != null) {
    final head = _translate(counted[1]!, lang, depth + 1);
    if (head != counted[1]) return '$head${counted[2]}';
  }
  return uz;
}

final _counted = RegExp(r'^(.*\S)(\s+\d+)$');

/// [Text] that shows its text in the chosen language.
class Tx extends Text {
  const Tx(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  @override
  Widget build(BuildContext context) {
    final text = data;
    if (text == null || appLanguage == AppLanguage.uz) {
      return super.build(context);
    }
    // The translated copy is built in place, so the tree (and a finder
    // looking for the source text) still holds one Text.
    return Text(
      tr(text),
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel == null ? null : tr(semanticsLabel!),
      semanticsIdentifier: semanticsIdentifier,
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    ).build(context);
  }
}
