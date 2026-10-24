import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/store.dart';

void main() {
  test(
      'fully offline records, profile edits, staff, unlimited quotes and backup restore',
      () async {
    final dir = await Directory.systemTemp.createTemp('romflow-test-');
    addTearDown(() => dir.delete(recursive: true));
    final s = Store(directory: dir);
    await s.init();
    await s.addCustomer({'name': 'Ali', 'phone': '99890', 'address': 'Uy'});
    final p = {...s.profiles.first, 'framePrice': 60000, 'demo': false};
    await s.saveProfile(p);
    expect(s.profiles.first['framePrice'], 60000);
    await s
        .saveStaff({'name': 'Vali', 'phone': '', 'role': 'Usta', 'notes': ''});
    final body = {
      'customerId': s.customers.first['id'],
      'title': 'Uy romi',
      'items': [
        {
          'profileId': p['id'],
          'template': 'double',
          'widthMm': 1400,
          'heightMm': 1500,
          'quantity': 1,
          'color': 'white',
          'mosquito': false
        }
      ],
      'discount': 0,
      'installation': 0,
      'notes': ''
    };
    final q = await s.saveQuote(body);
    await s.payment(q, 10000, 'Avans');
    await s.changeStatus(q, 'accepted');
    await s.assignStaff(q, s.staff.first['id']);
    for (var i = 0; i < 12; i++) {
      await s.saveQuote(body);
    }
    expect(s.quotes.length, 13);
    final backup = await s.exportBackup();
    final other = await Directory.systemTemp.createTemp('romflow-restore-');
    addTearDown(() => other.delete(recursive: true));
    final restored = Store(directory: other);
    await restored.init();
    await restored.importBackup(backup);
    expect(restored.quotes.length, 13);
    expect(restored.staff.single['name'], 'Vali');
    expect(restored.quotes.last['paid'], 10000);
    expect(restored.quotes.last['status'], 'accepted');
    final snapshot = jsonDecode(await restored.exportBackup());
    await expectLater(
        restored.importBackup('{"format":"wrong"}'), throwsA(anything));
    expect(jsonDecode(await restored.exportBackup()), snapshot);
    final reopened = Store(directory: other);
    await reopened.init();
    expect(reopened.quotes.length, 13);
    expect(reopened.profiles.first['framePrice'], 60000);
  });
  test(
      'corrupt primary recovers from backup; corrupt files never silently erase records',
      () async {
    final dir = await Directory.systemTemp.createTemp('romflow-recovery-');
    addTearDown(() => dir.delete(recursive: true));
    final s = Store(directory: dir);
    await s.init();
    await s.addCustomer({'name': 'Ali', 'phone': '', 'address': ''});
    await s.saveStaff({'name': 'Vali', 'phone': '', 'role': '', 'notes': ''});
    await File('${dir.path}/romflow-offline.json').writeAsString('broken');
    final restored = Store(directory: dir);
    await restored.init();
    expect(restored.customers.single['name'], 'Ali');
    expect(restored.startupMessage, isNotNull);
  });
}
