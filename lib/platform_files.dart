import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Native document pickers and the dialer on Android and iOS.
const nativeFiles = MethodChannel('romflow/offline');

bool get isDesktop =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// Lets the user choose where to save [bytes]. Returns false if cancelled.
Future<bool> saveFileAs(String name, String mime, List<int> bytes) async {
  if (!isDesktop) {
    return await nativeFiles.invokeMethod<bool>(
            'saveFile', {'name': name, 'mime': mime, 'bytes': bytes}) ==
        true;
  }
  final extension = name.contains('.') ? name.split('.').last : '';
  final location =
      await getSaveLocation(suggestedName: name, acceptedTypeGroups: [
    XTypeGroup(label: extension.toUpperCase(), extensions: [
      if (extension.isNotEmpty) extension
    ], mimeTypes: [
      mime
    ], uniformTypeIdentifiers: [
      if (extension == 'json') 'public.json',
      if (extension == 'pdf') 'com.adobe.pdf',
    ])
  ]);
  if (location == null) return false;
  var path = location.path;
  if (extension.isNotEmpty && !path.toLowerCase().endsWith('.$extension')) {
    path = '$path.$extension';
  }
  await File(path).writeAsBytes(bytes, flush: true);
  return true;
}

/// Lets the user pick a UTF-8 text file (backup, price list). Null if
/// cancelled.
Future<String?> pickTextFile(
    {String label = 'JSON', List<String> extensions = const ['json']}) async {
  if (!isDesktop) return nativeFiles.invokeMethod<String>('pickBackup');
  final file = await openFile(acceptedTypeGroups: [
    XTypeGroup(label: label, extensions: extensions),
    const XTypeGroup(label: 'Barcha fayllar'),
  ]);
  if (file == null) return null;
  if (await file.length() > 10 * 1024 * 1024) {
    throw Exception('Fayl 10 MBdan katta');
  }
  return utf8.decode(await file.readAsBytes());
}

/// Linux has no share sheet: files are saved and texts copied instead.
bool get canShareFiles => !Platform.isLinux;

/// Shares a file; on Linux asks where to save it. Returns a short note
/// for the user when something other than sharing happened.
Future<String?> shareFile(String name, String mime, List<int> bytes,
    {String? text, Rect? origin}) async {
  if (!canShareFiles) {
    return await saveFileAs(name, mime, bytes) ? 'Fayl saqlandi' : null;
  }
  final dir = await getTemporaryDirectory(), file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: mime)],
      text: text, sharePositionOrigin: origin);
  return null;
}

/// Shares text; on Linux copies it to the clipboard.
Future<String?> shareText(String text, {String? subject, Rect? origin}) async {
  if (Platform.isLinux) {
    await Clipboard.setData(ClipboardData(text: text));
    return 'Matn nusxalandi — xohlagan joyga joylang';
  }
  await Share.share(text, subject: subject, sharePositionOrigin: origin);
  return null;
}
