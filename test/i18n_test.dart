import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/app_setup.dart';
import 'package:romflow/i18n.dart';
import 'package:romflow/main.dart';
import 'package:romflow/store.dart';

void main() {
  tearDown(() => appLanguage = AppLanguage.uz);

  test('the build number in the code is the one in pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(int.parse(line.split('+').last.trim()), appBuild);
  });

  test('text is translated whole, by template, and names stay', () {
    appLanguage = AppLanguage.ru;
    expect(tr('Buyurtmalar'), 'Заказы');
    expect(tr('3 dona'), '3 шт');
    expect(tr('1 500 so‘m'), '1 500 сум');
    // A value inside a template is translated too.
    expect(tr('Hammasi 27'), 'Все 27');
    // A name with its count, as on the catalog's tabs and chips.
    expect(tr('Derazalar 27'), 'Окна 27');
    expect(tr('Fortochkali 5'), 'С форточкой 5');
    expect(tr('Aziz Karimov'), 'Aziz Karimov');
    appLanguage = AppLanguage.en;
    expect(tr('Smetaga qo‘shish'), 'Add to estimate');
    expect(tr('1500 × 1200 mm'), '1500 × 1200 mm');
    appLanguage = AppLanguage.uz;
    expect(tr('Buyurtmalar'), 'Buyurtmalar');
  });

  testWidgets('the app opens in the chosen language', (tester) async {
    final dir = Directory.systemTemp.createTempSync('romflow-i18n-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    await tester.runAsync(() => store.setLanguage('ru', appBuild));
    await tester.pumpWidget(RomFlow(store: store));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Новая смета', findRichText: true), findsWidgets);
    expect(find.text('Главная', findRichText: true), findsWidgets);
    // Stored again, read back.
    final again = Store(directory: dir);
    await tester.runAsync(again.init);
    expect(again.language, 'ru');
    expect(again.languageBuild, appBuild);
  });
}
