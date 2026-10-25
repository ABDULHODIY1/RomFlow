import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/adaptive_ui.dart';
import 'package:romflow/app_theme.dart';

void main() {
  tearDown(() => applyDesign('auto'));

  Widget page(Widget child,
          {Brightness brightness = Brightness.light, bool contrast = false}) =>
      MaterialApp(
        theme: romFlowTheme(brightness),
        home: MediaQuery(
          data: MediaQueryData(highContrast: contrast),
          child: Scaffold(body: Center(child: child)),
        ),
      );

  testWidgets('glass cards preserve their original bounds and taps',
      (tester) async {
    var taps = 0;
    Widget card() => SizedBox(
        width: 280,
        child: GlassCard(
            margin: const EdgeInsets.all(12),
            child: InkWell(
                onTap: () => taps++,
                child: const SizedBox(height: 120, child: Text('Smeta')))));
    applyDesign('material');
    await tester.pumpWidget(page(card()));
    final before = tester.getRect(find.text('Smeta'));
    final bounds = tester.getRect(find.byType(InkWell));
    applyDesign('glass');
    await tester.pumpWidget(page(card()));
    expect(tester.getRect(find.text('Smeta')), before);
    expect(tester.getRect(find.byType(InkWell)), bounds);
    expect(find.byType(GlassSurface), findsOneWidget);
    await tester.tap(find.text('Smeta'));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('high contrast glass removes blur and uses an opaque body',
      (tester) async {
    applyDesign('glass');
    await tester.pumpWidget(page(
      const GlassSurface(child: SizedBox(width: 100, height: 100)),
      brightness: Brightness.dark,
      contrast: true,
    ));
    expect(find.byType(BackdropFilter), findsNothing);
    final body = tester.widget<ColoredBox>(find.descendant(
        of: find.byType(GlassSurface), matching: find.byType(ColoredBox)));
    expect(body.color.a, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small glass icons have a 48 pixel tap area and stay disabled',
      (tester) async {
    var taps = 0;
    Widget button(bool enabled) => GlassIconButton(
        size: 32,
        icon: Icons.add,
        tooltip: 'Qo‘shish',
        onPressed: enabled ? () => taps++ : null);
    await tester.pumpWidget(page(button(true)));
    final ink = find.byType(InkWell);
    expect(tester.getSize(ink), const Size(48, 48));
    await tester.tapAt(tester.getCenter(ink) + const Offset(22, 0));
    expect(taps, 1);
    await tester.pumpWidget(page(button(false)));
    await tester.tapAt(tester.getCenter(ink));
    expect(taps, 1);
  });

  testWidgets('glass navigation follows the selected theme and keeps routing',
      (tester) async {
    applyDesign('glass');
    int? selected;
    Widget navigation() =>
        IOSGlassNavigation(selected: 0, onChanged: (i) => selected = i);
    await tester.pumpWidget(page(navigation()));
    final light =
        tester.widget<Icon>(find.byIcon(Icons.dashboard_outlined)).color;
    await tester.pumpWidget(page(navigation(), brightness: Brightness.dark));
    await tester.pumpAndSettle();
    final dark =
        tester.widget<Icon>(find.byIcon(Icons.dashboard_outlined)).color;
    expect(dark, romFlowTheme(Brightness.dark).colorScheme.primary);
    expect(dark, isNot(light));
    await tester.tap(find.text('Katalog'));
    expect(selected, 2);
  });

  testWidgets(
      'glass dialog keeps keyboard avoidance and scrollable form actions',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    applyDesign('glass');
    await tester.pumpWidget(MaterialApp(
      theme: romFlowTheme(Brightness.light),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (c) => GlassAlertDialog(
                            title: const Text('Smeta'),
                            scrollable: true,
                            content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const TextField(
                                      decoration:
                                          InputDecoration(labelText: 'Izoh')),
                                  for (var i = 0; i < 8; i++)
                                    const Text('Buyurtma ma’lumotlari'),
                                ]),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text('Saqlash'))
                            ],
                          )),
                  child: const Text('Ochish')))),
    ));
    await tester.tap(find.text('Ochish'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 230);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(GlassAlertDialog),
            matching: find.byType(GlassSurface)),
        findsWidgets);
    await tester.ensureVisible(find.text('Saqlash'));
    await tester.tap(find.text('Saqlash'));
    await tester.pumpAndSettle();
    expect(find.byType(GlassAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
