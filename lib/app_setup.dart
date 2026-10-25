import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'adaptive_ui.dart';
import 'i18n.dart';
import 'platform_files.dart';
import 'store.dart';

/// The app's build number; it must match pubspec.yaml (a test checks it).
const appBuild = 39;
const _repo = 'ABDULHODIY1/RomFlow';
const _bundleId = 'uz.romflow.workshop';

/// Shows the language picker; returns once a language is chosen. Asked on
/// the first start and again after every update.
Future<void> chooseLanguage(
  BuildContext context,
  Store store, {
  bool required = false,
}) async {
  final picked = await showGlassSheet<AppLanguage>(
    context: context,
    showDragHandle: !required,
    isScrollControlled: true,
    builder: (sheet) => PopScope(
      canPop: !required,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.translate, size: 34),
              const SizedBox(height: 10),
              // In all three languages: the reader has not chosen yet.
              const Text(
                'Tilni tanlang • Выберите язык • Choose a language',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              for (final lang in AppLanguage.values) ...[
                FilledButton.tonal(
                  key: ValueKey('language-${lang.name}'),
                  onPressed: () => Navigator.pop(sheet, lang),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                  child: Row(
                    children: [
                      Text(
                        const {
                          AppLanguage.uz: '🇺🇿',
                          AppLanguage.ru: '🇷🇺',
                          AppLanguage.en: '🇬🇧',
                        }[lang]!,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          languageNames[lang]!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (lang == appLanguage)
                        const Icon(Icons.check_circle, size: 22),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  if (picked == null && !required) return;
  await store.setLanguage((picked ?? appLanguage).name, appBuild);
}

/// A newer RomFlow than this one, and where to get it.
class AppUpdate {
  final String version;
  final int build;
  final Uri url;

  /// 'appstore' or 'github'.
  final String source;
  const AppUpdate(this.version, this.build, this.url, this.source);
}

int _compareVersions(String a, String b) {
  final x = a.split('.').map((p) => int.tryParse(p) ?? 0).toList(),
      y = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

Future<Object?> _getJson(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  request.headers.set('User-Agent', 'RomFlow');
  request.headers.set('Accept', 'application/json');
  final response = await request.close().timeout(const Duration(seconds: 12));
  if (response.statusCode != 200) {
    await response.drain<void>();
    return null;
  }
  final text = await response
      .transform(utf8.decoder)
      .join()
      .timeout(const Duration(seconds: 20));
  return jsonDecode(text);
}

/// Looks for a newer release: on iPhone first in the App Store, then in
/// the GitHub releases this app is also published to (the APK on Android,
/// the IPA on iPhone). Null when this one is the newest or offline.
Future<AppUpdate?> findUpdate({
  String version = '',
  int build = appBuild,
  HttpClient? client,
}) async {
  final http = client ?? HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);
  try {
    if (!kIsWeb && Platform.isIOS) {
      final store = await _getJson(
        http,
        Uri.https('itunes.apple.com', '/lookup', {
          'bundleId': _bundleId,
          'country': 'uz',
        }),
      );
      if (store is Map && store['results'] is List) {
        for (final r in store['results'] as List) {
          if (r is Map &&
              r['version'] is String &&
              r['trackViewUrl'] is String &&
              version.isNotEmpty &&
              _compareVersions(r['version'] as String, version) > 0) {
            return AppUpdate(
              r['version'] as String,
              0,
              Uri.parse(r['trackViewUrl'] as String),
              'appstore',
            );
          }
        }
      }
    }
    final releases = await _getJson(
      http,
      Uri.https('api.github.com', '/repos/$_repo/releases', {'per_page': '10'}),
    );
    if (releases is! List) return null;
    final asset = RegExp(
      r'^RomFlow-(\d+\.\d+\.\d+)-(\d+)'
      '${!kIsWeb && Platform.isIOS ? r'-ios-unsigned\.ipa' : r'\.apk'}\$',
    );
    AppUpdate? best;
    for (final release in releases) {
      if (release is! Map || release['draft'] == true) continue;
      for (final a in (release['assets'] as List? ?? const [])) {
        if (a is! Map || a['name'] is! String) continue;
        final m = asset.firstMatch(a['name'] as String);
        if (m == null) continue;
        final b = int.parse(m[2]!);
        if (b <= build || (best != null && b <= best.build)) continue;
        // iPhone: the release page (SideStore / AltStore install from it);
        // Android: the APK itself.
        final link = !kIsWeb && Platform.isIOS
            ? release['html_url']
            : a['browser_download_url'];
        if (link is! String) continue;
        best = AppUpdate(m[1]!, b, Uri.parse(link), 'github');
      }
    }
    return best;
  } catch (_) {
    return null;
  } finally {
    if (client == null) http.close(force: true);
  }
}

/// Offers [update] on a glass sheet: update now, or later.
Future<void> offerUpdate(
  BuildContext context,
  Store store,
  AppUpdate update,
) async {
  final go = await showGlassSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.system_update, size: 40),
            const SizedBox(height: 12),
            Tx(
              'Yangi versiya chiqdi',
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Tx(
              update.build > 0
                  ? 'RomFlow ${update.version} (${update.build})'
                  : 'RomFlow ${update.version}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Tx(
              update.source == 'appstore'
                  ? 'Yangilash uchun App Store ochiladi.'
                  : 'Yangilash uchun yuklab olish sahifasi ochiladi.',
              textAlign: TextAlign.center,
              style: Theme.of(sheet).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: const ValueKey('update-now'),
              onPressed: () => Navigator.pop(sheet, true),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Tx('Yangilash'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const ValueKey('update-later'),
              onPressed: () => Navigator.pop(sheet, false),
              child: const Tx('Keyinroq'),
            ),
          ],
        ),
      ),
    ),
  );
  if (go == true) {
    try {
      await nativeFiles.invokeMethod<void>('open', {'url': '${update.url}'});
    } catch (_) {}
  } else if (update.build > 0) {
    await store.dismissUpdate(update.build);
  }
}
