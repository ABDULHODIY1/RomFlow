import 'package:flutter/services.dart';
import 'dart:io';

const _channel = MethodChannel('romflow/reminders');

class ReminderScheduler {
  static Future<void> reconcile(List<Map<String, dynamic>> rows) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>('reconcile', {
        'items': [
          for (final r in rows)
            if (r['done'] != true &&
                DateTime.parse(r['due']).isAfter(DateTime.now()))
              {
                'id': r['id'],
                'title': r['title'],
                'note': r['note'] ?? '',
                'timeMs': DateTime.parse(r['due']).millisecondsSinceEpoch,
              },
        ],
      });
    } on MissingPluginException {
      /* No native scheduler in Flutter tests. */
    } on PlatformException {
      /* The persisted in-app list remains available. */
    }
  }

  static Future<bool> schedule(Map<String, dynamic> r) async {
    if (r['done'] == true ||
        !DateTime.parse(r['due']).isAfter(DateTime.now())) {
      await cancel(r['id']);
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('schedule', {
            'id': r['id'],
            'title': r['title'],
            'note': r['note'] ?? '',
            'timeMs': DateTime.parse(r['due']).millisecondsSinceEpoch,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'id': id});
    } on MissingPluginException {
      /* App list still works in test environments. */
    }
  }
}
