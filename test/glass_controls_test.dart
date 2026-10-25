import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/adaptive_ui.dart';
import 'package:romflow/app_theme.dart';

void main() {
  tearDown(() => applyDesign('auto'));
  testWidgets(
      'all standard button families get glass and keep taps/disabled state',
      (tester) async {
    applyDesign('glass');
    var clicks = 0;
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: Scaffold(
            body: Column(children: [
          FilledButton(onPressed: () => clicks++, child: const Text('Save')),
          OutlinedButton(onPressed: () => clicks++, child: const Text('Open')),
          TextButton(onPressed: () => clicks++, child: const Text('Cancel')),
          IconButton(
              onPressed: () => clicks++,
              icon: const Icon(Icons.add),
              tooltip: 'Add'),
          FilledButton(onPressed: null, child: const Text('Disabled')),
        ]))));
    for (final type in [FilledButton, OutlinedButton, TextButton, IconButton]) {
      expect(
          find.descendant(
              of: find.byType(type).first, matching: find.byType(GlassSurface)),
          findsWidgets);
    }
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Open'));
    await tester.tap(find.text('Cancel'));
    await tester.tap(find.byTooltip('Add'));
    await tester.tap(find.text('Disabled'));
    expect(clicks, 4);
    expect(tester.takeException(), isNull);
  });
  testWidgets('local destructive colour survives; high contrast removes blur',
      (tester) async {
    applyDesign('glass');
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.dark),
        home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: Scaffold(
                body: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () {},
                    child: const Text('Delete'))))));
    final surfaces = tester.widgetList<GlassSurface>(find.byType(GlassSurface));
    expect(surfaces.any((s) => s.tint == Colors.red), isTrue);
    expect(find.byType(BackdropFilter), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow large-text action wraps and remains tappable',
      (tester) async {
    applyDesign('glass');
    tester.view.physicalSize = const Size(240, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var clicked = false;
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(240, 640), textScaler: TextScaler.linear(2)),
            child: Scaffold(
                floatingActionButton: GlassActionButton.extended(
                    onPressed: () => clicked = true,
                    icon: const Icon(Icons.add),
                    label: const Text('Yangi materiallarni qo‘shish'))))));
    expect(tester.getSize(find.byType(GlassActionButton)).width,
        lessThanOrEqualTo(208));
    await tester.tap(find.text('Yangi materiallarni qo‘shish'));
    expect(clicked, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('decorated field keeps focus, editing and validation',
      (tester) async {
    applyDesign('glass');
    final key = GlobalKey<FormState>();
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: Scaffold(
            body: Form(
                key: key,
                child: GlassControl(
                    child: TextFormField(
                        controller: controller,
                        validator: (v) => v!.isEmpty ? 'Required' : null))))));
    expect(key.currentState!.validate(), isFalse);
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), '1400');
    expect(key.currentState!.validate(), isTrue);
    expect(controller.text, '1400');
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard focus and activation stay available through decoration',
      (tester) async {
    applyDesign('glass');
    var clicks = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: Scaffold(
            body: FilledButton(
                focusNode: focus,
                onPressed: () => clicks++,
                child: const Text('Confirm')))));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(clicks, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Material preference keeps ordinary surfaces', (tester) async {
    applyDesign('material');
    await tester.pumpWidget(MaterialApp(
        theme: romFlowTheme(Brightness.light),
        home: Scaffold(
            body: GlassControl(
                child: FilledButton(
                    onPressed: () {}, child: const Text('Save'))))));
    expect(find.byType(GlassSurface), findsNothing);
  });
  test('native descriptors carry distinct action tints', () {
    final add = const GlassButton('add-material').toMap()['tint'];
    final remove = const GlassButton('delete-material').toMap()['tint'];
    final share = const GlassButton('export-image').toMap()['tint'];
    expect({add, remove, share}.length, 3);
    expect(const GlassButton('custom', tint: Colors.orange).toMap()['tint'],
        Colors.orange.toARGB32());
  });
}
