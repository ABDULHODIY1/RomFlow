import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romflow/adaptive_ui.dart';
import 'package:romflow/main.dart';
import 'package:romflow/store.dart';

void main() {
  tearDown(() => applyDesign('auto'));

  testWidgets('Liquid Glass: glass bars over the content, glass sheets',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dir = Directory.systemTemp.createTempSync('romflow-glass-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = Store(directory: dir);
    await tester.runAsync(store.init);
    store.designPreference = 'glass';
    await tester.pumpWidget(RomFlow(store: store));
    await tester.pumpAndSettle();
    expect(usesIOSGlass, isTrue);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.extendBody, isTrue);
    expect(scaffold.extendBodyBehindAppBar, isTrue);
    // The tab bar and the bar's tariff button are blurred glass; the app
    // bar itself is no slab, the page fades out under its title.
    expect(find.byType(GlassSurface), findsAtLeastNWidgets(2));
    expect(find.byType(BackdropFilter), findsAtLeastNWidgets(2));
    // The first row is not hidden under the glass app bar.
    final appBar = tester.getRect(find.byType(GlassAppBar).first);
    expect(tester.getRect(find.text('Mening ustaxonam')).top,
        greaterThan(appBar.bottom));
    // A sheet is glass too.
    showGlassSheet<void>(
        context: tester.element(find.byType(Scaffold).first),
        showDragHandle: true,
        builder: (_) => const SizedBox(height: 200, child: Text('varaq')));
    await tester.pumpAndSettle();
    expect(
        find.ancestor(
            of: find.text('varaq'), matching: find.byType(GlassSurface)),
        findsOneWidget);
    expect(tester.takeException(), isNull);

    // "Oddiy" brings the Material design back.
    store.designPreference = 'material';
    await tester.pumpWidget(RomFlow(store: store));
    await tester.pumpAndSettle();
    expect(usesIOSGlass, isFalse);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
