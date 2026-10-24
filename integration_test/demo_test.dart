// Scripted walk-through of every main feature, used to record the demo
// video. Run with --dart-define=ROMFLOW_DEMO=true so captions and finger
// dots are drawn. Each step is paced for a viewer, not for speed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:romflow/demo_overlay.dart';
import 'package:romflow/design_engine.dart';
import 'package:romflow/drawing_3d.dart';
import 'package:romflow/drawing_ui.dart';
import 'package:romflow/main.dart' as app;

late WidgetTester t;
final failures = <String>[];

Future<void> wait(int ms) async {
  await Future<void>.delayed(Duration(milliseconds: ms));
  await t.pump();
}

Future<void> say(String text, {int ms = 1600}) async {
  demoCaption.value = text;
  // ignore: avoid_print
  print('STEP ${DateTime.now().toIso8601String()} $text');
  await wait(ms);
}

Finder vertical() => find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down);

/// Scrolls the visible vertical list until [f] is built, then centres it.
Future<void> reveal(Finder f) async {
  // Lists build lazily: look further down first, then back up.
  for (final (dy, tries) in const [(-260.0, 30), (260.0, 40)]) {
    for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
      final lists = vertical().evaluate().toList();
      if (lists.isEmpty) break;
      await t.drag(find.byWidget(lists.last.widget), Offset(0, dy));
      await wait(140);
    }
  }
  if (f.evaluate().isEmpty) throw StateError('Not found: $f');
  await t.ensureVisible(f.first);
  await wait(300);
}

/// Smoothly scrolls the main vertical list back to its start.
Future<void> toTop() async {
  final lists = vertical().evaluate().toList();
  if (lists.isEmpty) return;
  final state = t.state<ScrollableState>(find.byWidget(lists.last.widget));
  if (state.position.pixels <= 0) return;
  await state.position.animateTo(0,
      duration: const Duration(milliseconds: 450), curve: Curves.easeOut);
  await wait(250);
}

/// A quick tap. No frame is pumped while the finger is down: on a slow
/// emulator one frame can outlast the 500 ms long-press timeout, and the
/// tap would turn into a long press (a tooltip instead of a tab switch).
/// The overlay keeps the finger dot visible for a moment afterwards.
Future<void> press(Offset at) async {
  final gesture = await t.startGesture(at);
  await Future<void>.delayed(const Duration(milliseconds: 80));
  await gesture.up();
}

Future<void> tap(Finder f, {int after = 900}) async {
  await reveal(f);
  await press(t.getCenter(f.first));
  await wait(after);
}

Future<void> tapAt(Offset at, {int after = 900}) async {
  await press(at);
  await wait(after);
}

Future<void> drag(Offset from, Offset to,
    {int steps = 28,
    int hold = 700,
    bool lift = true,
    double lead = 28}) async {
  final gesture = await t.startGesture(from);
  await Future<void>.delayed(const Duration(milliseconds: 60));
  // Leave the toolbar vertically first so the part starts dragging.
  await gesture.moveBy(Offset(0, lead));
  await wait(60);
  final start = from + Offset(0, lead);
  for (var i = 1; i <= steps; i++) {
    await gesture.moveTo(Offset.lerp(start, to, i / steps)!);
    await wait(22);
  }
  await wait(hold);
  if (lift) await gesture.up();
  await wait(700);
}

/// Waits while a system dialog holds the window focus: an inactive app
/// drops keyboard focus, so typed text would go nowhere.
Future<void> foreground() async {
  for (var i = 0;
      i < 60 &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
      i++) {
    await wait(500);
  }
}

/// Types [text] letter by letter, as an edit made by the user. The field's
/// own state is updated directly rather than through `enterText`: with the
/// real Android keyboard attached, injected IME messages raced with the
/// keyboard and were lost.
Future<void> type(String label, String text) async {
  final field = find.widgetWithText(TextFormField, label);
  await reveal(field);
  await foreground();
  final editable = t.state<EditableTextState>(
      find.descendant(of: field.first, matching: find.byType(EditableText)));
  for (var i = 1; i <= text.length; i++) {
    editable.userUpdateTextEditingValue(
        TextEditingValue(
            text: text.substring(0, i),
            selection: TextSelection.collapsed(offset: i)),
        SelectionChangedCause.keyboard);
    await wait(45);
  }
  await wait(350);
  if (editable.widget.controller.text != text) {
    throw StateError('Could not type into $label');
  }
  // Close the keyboard so it does not cover the dialog buttons.
  FocusManager.instance.primaryFocus?.unfocus();
  await wait(250);
}

Future<void> back() async {
  await t.pageBack();
  await wait(900);
}

Future<void> nav(String label) => tap(find.descendant(
    of: find.byType(NavigationBar), matching: find.text(label)));

Future<void> step(String name, Future<void> Function() body) async {
  try {
    await body();
  } catch (e, st) {
    failures.add('$name: $e');
    // ignore: avoid_print
    print('DEMO STEP FAILED $name: $e\n$st');
    // Close whatever sheet or dialog was left open and carry on.
    for (var i = 0; i < 3; i++) {
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      if (!nav.canPop()) break;
      nav.pop();
      await wait(500);
    }
  }
}

DrawingPainter painter() => t
    .widget<CustomPaint>(find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is DrawingPainter))
    .painter! as DrawingPainter;

/// Screen position of a drawing point in millimetres.
Offset mm(double x, double y) {
  final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is DrawingPainter);
  final rect = t.getRect(canvas);
  return rect.topLeft +
      CanvasTransform(rect.size, painter().drawing, sectionDimensions: true)
          .to(V(x, y));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('RomFlow demo', (tester) async {
    t = tester;
    app.main();
    await wait(3500);
    await foreground();

    await step('home', () async {
      await say(
          'RomFlow 1.5 • eshik va rom ustalari uchun smeta: romni chizasiz — narx o‘zi hisoblanadi.',
          ms: 3200);
      await say(
          'Bosh sahifa: faol buyurtmalar, tushum, mijozlar qarzi, foyda va tezkor bo‘limlar.',
          ms: 2800);
    });

    await step('workshop', () async {
      await nav('Sozlamalar');
      await say(
          '1. Ustaxona ma’lumotlari PDF va ulashiladigan smetaga yoziladi.');
      await tap(find.text('Mening ustaxonam'));
      await type('Ustaxona nomi', 'Oyna Usta');
      await type('Telefon', '+998 90 123 45 67');
      await type('Manzil', 'Toshkent, Chilonzor');
      await tap(find.text('Saqlash'));
    });

    await step('customer', () async {
      await nav('Buyurtmalar');
      await say(
          '2. Mijoz qo‘shish: qidiruv, qo‘ng‘iroq va mijoz sahifasi bor.');
      await tap(find.textContaining('Mijozlar ('));
      await tap(find.text('Mijoz'));
      await type('Ism', 'Aziz Karimov');
      await type('Telefon', '+998 91 765 43 21');
      await type('Manzil', 'Yunusobod 7-mavze');
      await tap(find.text('Saqlash'));
    });

    await step('staff', () async {
      await nav('Asosiy');
      await say(
          '3. Xodimlar va ish haqi: oylik, kunlik, m², buyurtmadan % yoki dona bo‘yicha.');
      await tap(find.text('Xodimlar'));
      await tap(find.text('Xodim'));
      await type('Ism', 'Usta Karim');
      await type('Vazifa (usta, montajchi…)', 'Usta');
      await type('Stavka (so‘m)', '40000');
      await tap(find.text('Saqlash'));
      await wait(800);
      await back();
    });

    await step('presets', () async {
      await say(
          '4. Yangi smeta: rom turini tanlaymiz, o‘lchami va joyini yozamiz.');
      await toTop();
      await tap(find.byKey(const ValueKey('home-draw')), after: 1500);
      await say('Katalog: derazalar, eshiklar, arkalar — tayyor dizaynlar.');
      await tap(find.byKey(const ValueKey('group-Eshik')), after: 1300);
      await tap(find.byKey(const ValueKey('group-Arka')), after: 1300);
      await tap(find.byKey(const ValueKey('group-Deraza')), after: 1000);
      await type('Eni', '1500');
      await type('Bo‘yi', '1400');
      await tap(find.byKey(const ValueKey('catalog-room')), after: 900);
      await tap(find.widgetWithText(ActionChip, 'Zal'), after: 900);
      await say('Dizaynga bir bosish — chizma darhol ochiladi.');
      await tap(find.byKey(const ValueKey('design-twoOpen')), after: 1500);
    });

    await step('transom by drag', () async {
      await say(
          'Drag & drop: yotiq impostni chap qanotga sudraymiz — teng joyda yashil bo‘ladi.');
      await tap(find.text('Bo‘lish'));
      final source = t.getCenter(find.text('Yotiq bo‘lish'));
      await drag(source, mm(350, 470), hold: 1300);
      await say(
          'Fortochka: “Pastga” ochiladigan qanotni yuqori bo‘limga tashlaymiz.');
      await tap(find.text('Deraza'));
      await drag(t.getCenter(find.text('Pastga')), mm(350, 230), hold: 1000);
    });

    await step('divider snap and delete', () async {
      await say(
          'Impostni suring: o‘lchamlar jonli ko‘rinadi, ½ va ⅓ da yopishadi.');
      await tap(find.text('Bo‘lish'));
      await tap(find.text('Tanlash'));
      final gesture = await t.startGesture(mm(700, 1000));
      // Pass the touch slop before the long-press timer opens the menu.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await gesture.moveTo(mm(640, 1000));
      await gesture.moveTo(mm(600, 1000));
      await wait(110);
      for (final x in [540.0, 490, 470, 466, 480, 520, 600, 690, 700]) {
        await gesture.moveTo(mm(x.toDouble(), 1000));
        await wait(110);
      }
      await wait(600);
      await say('O‘chirish uchun impostni pastdagi qizil joyga tashlaymiz…',
          ms: 400);
      final rect = t.getRect(find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is DrawingPainter));
      final trash = Offset(rect.center.dx, rect.bottom - 30);
      final from = mm(700, 1000);
      for (var i = 1; i <= 16; i++) {
        await gesture.moveTo(Offset.lerp(from, trash, i / 16)!);
        await wait(40);
      }
      await wait(900);
      await gesture.up();
      await wait(1400);
      await say('…va “Orqaga” tugmasi bilan qaytaramiz.');
      await tap(find.byTooltip('Orqaga'), after: 1200);
    });

    await step('hardware', () async {
      await say('Furnitura: setkani o‘ng qanotga qo‘yamiz.');
      await tap(find.text('Furnitura'));
      await drag(t.getCenter(find.text('Setka')), mm(1050, 700), hold: 900);
      await say(
          'Furniturada faqat shu romga mos detallar: eshik bo‘lmasa dovodchik chiqmaydi.',
          ms: 2400);
    });

    await step('section menu', () async {
      await say(
          'Bo‘limni bosing: o‘lchami tepada chiqadi. “Sozlash” — ochilish, to‘ldirma, qulf, bo‘lish.');
      await tap(find.text('Bo‘lish'));
      await tap(find.text('Tanlash'));
      await tapAt(mm(1050, 900), after: 1400);
      await tap(find.text('Sozlash'), after: 2600);
      await tapAt(const Offset(200, 60), after: 900);
    });

    await step('section grips', () async {
      await say(
          'Bo‘lakni pastidan torting: faqat shu bo‘lak cho‘ziladi — rom zinapoya bo‘lib qoladi (eshik polgacha, deraza devor ustida).');
      await tap(find.text('Bo‘lish'));
      await tap(find.text('Tanlash'));
      await tapAt(mm(1050, 900), after: 1000);
      final grips = find.byKey(const ValueKey('section-handles'));
      final handles =
          (t.widget<CustomPaint>(grips).painter! as HandlesPainter).handles;
      final bottom = handles.firstWhere((h) => h.side == 'bottom');
      final from = t.getTopLeft(grips) + bottom.at;
      await drag(from, from + const Offset(0, 46), lead: 6, hold: 1400);
      await wait(1600);
      await say(
          'Yon tomoni impost bo‘lsa — qo‘shni bo‘lak o‘lchami o‘zgaradi.');
      final right = (t.widget<CustomPaint>(grips).painter! as HandlesPainter)
          .handles
          .where((h) => h.side == 'left')
          .firstOrNull;
      if (right != null) {
        final at = t.getTopLeft(grips) + right.at;
        await drag(at, at - const Offset(30, 0), lead: 0, hold: 1200);
      }
      await tap(find.byTooltip('Orqaga'), after: 700);
      await tap(find.byTooltip('Orqaga'), after: 900);
    });

    await step('live 3d', () async {
      await say('2D / 3D: chizma o‘rnida jonli 3D — barmoq bilan aylantiring.');
      await tap(find.byKey(const ValueKey('view-3D')), after: 1500);
      final c = t.getCenter(find.byKey(const ValueKey('live-3d')));
      await drag(c - const Offset(80, 0), c + const Offset(70, 20),
          lead: 0, hold: 400);
      await wait(900);
      await tap(find.byKey(const ValueKey('view-2D')), after: 900);
    });

    await step('camera in place', () async {
      await say(
          'Joyida: telefonni darchaga qarating — rom haqiqiy darchaga o‘zi qo‘yiladi.');
      await tap(find.byKey(const ValueKey('view-place')), after: 6500);
      if (find.byKey(const ValueKey('live-take')).evaluate().isNotEmpty) {
        await say(
            '“Rasmga olish” — burchaklarni aniqlashtirib, rasmni mijozga yuborasiz.');
        await tap(find.byKey(const ValueKey('live-take')), after: 4000);
      }
      await back();
    });

    await step('appearance', () async {
      await say(
          '“Rang”: profil rangi, 2 oynali shisha, delfin tutqich va narx usuli.');
      await tap(find.text('Rang'), after: 1200);
      await tap(find.textContaining('Antratsit'), after: 900);
      await tap(find.text('2 oynali paket'), after: 1200);
      await tap(find.text('Delfin'), after: 1200);
      await say(
          'Balkon burchagi: chap tomonda 90° qayt profili — smetaga o‘zi qo‘shiladi.');
      await tap(find.byKey(const ValueKey('join-left')), after: 1800);
      await tapAt(const Offset(200, 60), after: 900);
    });

    await step('dimensions', () async {
      await say(
          'O‘lchamni bosib raqam tugmalari bilan kiritamiz: eni 1800 mm.');
      await tap(find.byKey(const ValueKey('spec-width')));
      for (final key in ['1', '8', '0', '0']) {
        await tap(find.widgetWithText(OutlinedButton, key), after: 250);
      }
      await tap(find.text('Saqlash'), after: 900);
      await say(
          '“Tenglash” — bo‘limlarni teng taqsimlaydi. Narx pastda darhol yangilanadi.');
      await tap(find.text('Bo‘lish'));
      await tap(find.text('Tenglash'), after: 1800);
      await say('“Ko‘zgu”: chap va o‘ng almashadi — qarama-qarshi xona uchun.');
      await tap(find.text('Ko‘zgu'), after: 1800);
      await tap(find.text('Ko‘zgu'), after: 1200);
    });

    await step('manufacturer prices', () async {
      await say(
          'Zavodlar narxi: shu rom AKFA, ENGELBERG, Alubest va boshqa zavodlarning 14 ta tizimida — arzonidan qimmatiga.',
          ms: 2400);
      await tap(find.byKey(const ValueKey('compare-prices')), after: 2400);
      await tap(find.byKey(const ValueKey('compare-filter-pvc')), after: 1800);
      await tap(find.byKey(const ValueKey('compare-filter-aluminium')),
          after: 1500);
      await say(
          'Bittasini tanlang — smeta shu zavod tizimiga o‘tadi: AKFA ALDOX.');
      await tap(find.byKey(const ValueKey('compare-akfa-aldox')), after: 2000);
    });

    await step('3d', () async {
      await say(
          '5. 3D model: aylantirish, tayyor ko‘rinishlar, joyida ko‘rish.');
      await tap(find.byKey(const ValueKey('open-3d')), after: 2500);
      final canvas = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is ModelPainter);
      final c = t.getCenter(canvas);
      await drag(c - const Offset(90, 0), c + const Offset(80, 30),
          lead: 0, hold: 300);
      await tap(find.byKey(const ValueKey('view-front')), after: 1200);
      await tap(find.byKey(const ValueKey('view-left')), after: 1200);
      await tap(find.byKey(const ValueKey('view-iso')), after: 1200);
      // "Joyida" (the live camera on a phone) was shown on the desk.
      await say('Ochilish animatsiyasi: qanot va mexanizm harakatlanadi.');
      await tap(find.byIcon(Icons.play_circle_fill), after: 3400);
      await tap(find.byIcon(Icons.pause_circle_filled), after: 600);
      await say('Sochish / yig‘ish: har bir detal alohida, narxi bilan.');
      await tap(find.byKey(const ValueKey('mode-explode')), after: 2800);
      await tap(find.byKey(const ValueKey('mode-mechanism')), after: 2000);
      await tap(find.byKey(const ValueKey('mode-mechanism')), after: 600);
      await tap(find.byKey(const ValueKey('mode-open')), after: 900);
      await say(
          'Delfin tutqich: avval 90° buriladi, ilgagi ramadan chiqadi, keyin qanot ochiladi.');
      await tap(find.byTooltip('Detallar'), after: 1200);
      await tap(find.text('Delfin tutqich • egri dasta'), after: 1800);
      await tap(find.byIcon(Icons.play_circle_fill), after: 3600);
      await tap(find.byIcon(Icons.pause_circle_filled), after: 900);
      await tap(find.byTooltip('Tanlovni olish'), after: 600);
      await tap(find.byKey(const ValueKey('view-iso')), after: 900);
      await say(
          'Kesimlar: kosa, qanot, orta, shtapik va qayt — ustaxona rasmlari bo‘yicha.');
      await tap(find.byKey(const ValueKey('profile-sections')), after: 1800);
      for (final name in ['Qanot', 'Orta', 'Shtapik', 'Qayt 90°']) {
        await tap(find.text(name), after: 1700);
      }
      final pieces =
          t.getCenter(find.byKey(const ValueKey('profile-sections-canvas')));
      await drag(pieces - const Offset(60, 0), pieces + const Offset(60, 20),
          lead: 0, hold: 300);
      await wait(800);
      await back();
      await back();
    });

    await step('calculate', () async {
      await say(
          '6. “Sarf”: materiallar, raskroy, shisha listlari — sof sarf + chiqindi % bilan.');
      await tap(find.byKey(const ValueKey('calculate-drawing')), after: 2200);
      await t.drag(find.text('Materiallar va sarf'), const Offset(0, -300));
      await wait(1800);
      await tap(find.byKey(const ValueKey('report-add')), after: 1500);
    });

    await step('estimate', () async {
      await say(
          '7. Smeta: har bir rom rasmi, joyi, soni va narxi. Jami pastda doim ko‘rinadi.');
      await type('Buyurtma nomi', 'Aziz — uy derazalari');
      await say('Romdan nusxa olamiz va joyini yozamiz: yotoqxona.');
      await tap(find.byKey(const ValueKey('window-menu-0')), after: 900);
      await tap(find.text('Nusxa olish'), after: 1200);
      await tap(find.byKey(const ValueKey('window-menu-1')), after: 900);
      await tap(find.text('Joyini yozish'), after: 900);
      await tap(find.widgetWithText(ActionChip, 'Yotoqxona'), after: 1200);
      await say('Soni: “+” bilan 2 dona qilamiz — narx darhol yangilanadi.');
      await tap(find.byTooltip('Ko‘paytirish').first, after: 1600);
      await type('Montaj, so‘m', '300000');
      await tap(find.byKey(const ValueKey('save-smeta')), after: 1800);
    });

    await step('order', () async {
      await say(
          '8. Buyurtma: to‘lov, bosqich, xodim, ish haqi va montaj sanasi.');
      await tap(find.text('To‘lovni qayd etish'));
      await type('Summa (UZS)', '1000000');
      await tap(find.text('Qayd etish'), after: 1200);
      await tap(find.text('Tasdiqlangan'), after: 900);
      await tap(find.text('Ishlab chiqarishda'), after: 900);
      await tap(find.text('Mas’ul xodim'), after: 900);
      await tap(find.text('Usta Karim').last, after: 1200);
      await say('Usta stavkasi bo‘yicha ish haqi avtomatik hisoblanadi.');
      await tap(find.text('Yozish'));
      await tap(find.text('Yozish').last, after: 1200);
      await tap(find.text('Montaj sanasi'));
      await tap(find.text('OK'), after: 700);
      await tap(find.text('OK'), after: 1600);
      await say('Foyda hisobi: smeta − material − ish haqi − xarajat.');
      await reveal(find.text('Foyda hisobi'));
      await wait(2200);
      await say(
          'Menyu: tahrirlash, nusxa, matn yoki kesish ro‘yxatini ustaga yuborish.');
      await tap(find.byKey(const ValueKey('quote-menu')), after: 2200);
      await tapAt(const Offset(30, 400), after: 700);
      await back();
    });

    await step('finance', () async {
      await say('9. Moliya: xarajat yozamiz, tushum va foydani ko‘ramiz.');
      await nav('Asosiy');
      await toTop();
      await tap(find.text('Moliya'), after: 1200);
      await tap(find.widgetWithText(FloatingActionButton, 'Xarajat'));
      await type('Summa (so‘m)', '150000');
      await type('Izoh', 'Shisha yetkazib berish');
      await tap(find.text('Saqlash'), after: 1600);
      await reveal(find.textContaining('Tushum va xarajat'));
      await wait(2000);
      await say(
          'Statistika: buyurtmalar, o‘rtacha chek, konversiya, eng yirik mijozlar.');
      await tap(find.text('Statistika'), after: 2600);
      await back();
    });

    await step('payroll', () async {
      await say('10. Ish haqi: avans beramiz, qoldiq avtomatik.');
      await tap(find.text('Xodimlar'));
      await tap(find.text('Usta Karim'));
      await tap(find.text('Avans'));
      await type('Summa (so‘m)', '200000');
      await tap(find.text('Yozish').last, after: 1800);
      await back();
      await back();
    });

    await step('tools', () async {
      await say(
          '11. Qarz daftari, eslatmalar (montaj eslatmasi o‘zi qo‘shildi) va ombor.');
      await tap(find.text('Eslatma'), after: 2200);
      await back();
      await tap(find.text('Ombor'), after: 1800);
      await back();
    });

    await step('finish', () async {
      await say('Bosh sahifa yangilandi: tushum, qarz, foyda va yaqin montaj.',
          ms: 3500);
      demoCaption.value = failures.isEmpty
          ? 'Tayyor! RomFlow 1.5'
          : 'Tayyor! (${failures.length} qadam o‘tkazib yuborildi)';
      await wait(2500);
    });
    // ignore: avoid_print
    print('DEMO DONE failures=${failures.length} ${failures.join(' | ')}');
  });
}
