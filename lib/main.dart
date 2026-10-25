import 'workshop_field.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:pdf/widgets.dart' as pw;

import 'calculator.dart';
import 'store.dart';
import 'dialogs.dart';
import 'drawing_ui.dart';
import 'design_catalog.dart';
import 'photo_window_page.dart';
import 'drawing_3d.dart';
import 'design_engine.dart';
import 'workshop_tools.dart';
import 'adaptive_ui.dart';
import 'branding.dart';
import 'warehouse.dart';
import 'app_theme.dart';
import 'finance.dart';
import 'staff_pay.dart';
import 'share_text.dart';
import 'platform_files.dart';
import 'billing.dart';
import 'exchange_rate.dart';
import 'price_sources.dart';
import 'manufacturers_page.dart';
import 'measurements.dart';
import 'installments.dart';
import 'reminder_service.dart';
import 'demo_overlay.dart';

const appVersion = '1.0.1';

const ink = Color(0xff172b4d),
    blue = Color(0xff206bc4),
    muted = Color(0xff718096);
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Bundled assets under their own licences, next to the packages' ones.
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'DejaVu Sans',
    ], await rootBundle.loadString('assets/FONT-LICENSE.txt'));
    yield LicenseEntryWithLineBreaks([
      'Tabler Icons',
    ], await rootBundle.loadString('assets/TABLER-ICONS-LICENSE.txt'));
  });
  runApp(const StartApp());
}

class StartApp extends StatefulWidget {
  const StartApp({super.key});
  @override
  State<StartApp> createState() => _StartAppState();
}

class _StartAppState extends State<StartApp> {
  Store? store;
  Object? failure;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      failure = null;
    });
    try {
      final next = Store();
      await next.init().timeout(const Duration(seconds: 12));
      if (mounted) setState(() => store = next);
    } catch (e) {
      if (mounted) setState(() => failure = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (store != null) return RomFlow(store: store!);
    return MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xfff5f7fb),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 68),
                  const SizedBox(height: 18),
                  const Text(
                    'RomFlow',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (loading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    const Text('Mahalliy ma’lumotlar ochilmoqda…'),
                  ] else ...[
                    const Text(
                      'Ilovani ochishda xato yuz berdi. Ma’lumotlar o‘chirilgani yo‘q.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText('$failure'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: load,
                      child: const Text('Qayta urinish'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: '$failure')),
                      child: const Text('Xatoni nusxalash'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RomFlow extends StatelessWidget {
  final Store store;
  const RomFlow({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) => MaterialApp(
          key: ValueKey(_designKey(store.designPreference)),
          title: 'RomFlow',
          // Very large Dynamic Type would push controls over each other on
          // a small phone: text grows at most 1.3×.
          builder: (context, child) => MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: demoMode
                ? DemoOverlay(child: WorkshopKeyboardTools(child: child!))
                : WorkshopKeyboardTools(child: child!),
          ),
          themeMode: store.themePreference == 'dark'
              ? ThemeMode.dark
              : store.themePreference == 'light'
                  ? ThemeMode.light
                  : ThemeMode.system,
          darkTheme: romFlowTheme(Brightness.dark),
          theme: romFlowTheme(Brightness.light),
          debugShowCheckedModeBanner: false,
          home: Home(store: store),
        ),
      );
}

void message(BuildContext c, Object e) {
  ScaffoldMessenger.of(c).showSnackBar(
    SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
  );
}

Future<void> guarded(BuildContext c, Future<void> Function() fn) async {
  try {
    await fn();
  } catch (e) {
    if (c.mounted) message(c, e);
  }
}

Widget heading(String text) => Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
Widget notice(String text) => Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            border: Border.all(color: scheme.outlineVariant, width: .8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
        );
      },
    );
Widget field(
  TextEditingController c,
  String label, {
  bool number = false,
  bool secret = false,
  String? Function(String?)? validate,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: WorkshopField(
        controller: c,
        label: label,
        number: number,
        decimal: false,
        keyboardType: label.toLowerCase().contains('telefon')
            ? TextInputType.phone
            : null,
        obscure: secret,
        validator: validate ??
            (v) => v == null || v.trim().isEmpty ? 'To‘ldiring' : null,
      ),
    );

class Home extends StatefulWidget {
  final Store store;
  const Home({super.key, required this.store});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int page = 0;
  bool showCustomers = false;
  String statusFilter = 'all';
  final search = TextEditingController();
  Store get s => widget.store;
  @override
  void initState() {
    super.initState();
    search.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (s.startupMessage != null) message(context, s.startupMessage!);
      dailyPrices();
    });
  }

  /// Once the app is open: the Central Bank's dollar rate and the price
  /// sources marked automatic. Not in tests or the demo recording.
  Future<void> dailyPrices() async {
    if (Platform.environment.containsKey('FLUTTER_TEST') ||
        const bool.fromEnvironment('ROMFLOW_DEMO')) {
      return;
    }
    final notes = await autoUpdatePrices(s);
    if (mounted && notes.isNotEmpty) message(context, notes.join('\n'));
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  /// A new smeta starts with drawing its first window.
  void newQuote() => drawWindow();

  /// A new smeta from a photo of the window (AI camera).
  Future<void> drawFromPhoto() async {
    final choice = await openPhotoWindow(context, s, catalogRecipe(s));
    if (!mounted || choice == null) return;
    final item = await Navigator.push<Json>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingEditor(store: s, initial: choice.item()),
      ),
    );
    if (!mounted || item == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BuilderPage(store: s, initialItem: item),
      ),
    );
  }

  Future<void> drawWindow() async {
    final choice = await openDesignCatalog(
      context,
      recipe: catalogRecipe(s),
      store: s,
    );
    if (!mounted || choice == null) return;
    final item = await Navigator.push<Json>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingEditor(store: s, initial: choice.item()),
      ),
    );
    if (!mounted || item == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => BuilderPage(store: s, initialItem: item),
      ),
    );
  }

  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Asosiy'),
    (Icons.receipt_long_outlined, Icons.receipt_long, 'Buyurtmalar'),
    (Icons.grid_view_outlined, Icons.grid_view, 'Katalog'),
    (Icons.tune, Icons.tune, 'Sozlamalar'),
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: s,
        builder: (context, _) {
          final width = MediaQuery.sizeOf(context).width,
              // Tablets, desktops and phones on their side get a side rail.
              wide = width >= 720,
              // Under Liquid Glass the list runs behind the bars; its own
              // padding keeps the first and last rows clear of them.
              glassLayout = usesIOSGlass && !wide,
              content = SafeArea(
                top: !glassLayout,
                bottom: !glassLayout,
                child: RefreshIndicator(
                  onRefresh: () => guarded(context, s.refresh),
                  // Below the glass app bar: status bar plus toolbar.
                  edgeOffset: glassLayout
                      ? MediaQuery.paddingOf(context).top + kToolbarHeight
                      : 0,
                  child: LayoutBuilder(
                    // Grids inside the list must not add the bars' padding
                    // again.
                    builder: (context, box) => MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      child: ListView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          math.max(16, (box.maxWidth - 1120) / 2),
                          8 +
                              (glassLayout
                                  ? MediaQuery.paddingOf(context).top
                                  : 0),
                          math.max(16, (box.maxWidth - 1120) / 2),
                          100 +
                              (glassLayout
                                  ? MediaQuery.paddingOf(context).bottom
                                  : 0),
                        ),
                        children: page == 0
                            ? dashboard(box.maxWidth)
                            : page == 1
                                ? orders()
                                : page == 2
                                    ? catalog()
                                    : settings(),
                      ),
                    ),
                  ),
                ),
              );
          return Scaffold(
            // Liquid Glass: the lists scroll under the glass bars.
            extendBody: usesIOSGlass && !wide,
            extendBodyBehindAppBar: usesIOSGlass && !wide,
            appBar: GlassAppBar(
              title: Row(
                children: [
                  const BrandLogo(size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      wide ? 'RomFlow • ${_destinations[page].$3}' : 'RomFlow',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                nativeGlass
                    ? NativeGlassButtons(
                        height: 40,
                        width: 40,
                        items: const [
                          GlassButton(
                            'tariff',
                            symbol: 'crown',
                            label: 'Tarif va to‘lov',
                            size: 40,
                          ),
                        ],
                        onTap: (_) => open(TariffPage(store: s)),
                        fallback: const SizedBox(),
                      )
                    : usesIOSGlass
                        ? GlassIconButton(
                            key: const ValueKey('tariff'),
                            tooltip: 'Tarif va to‘lov',
                            onPressed: () => open(TariffPage(store: s)),
                            icon: Icons.workspace_premium_outlined,
                            size: 40,
                          )
                        : IconButton(
                            key: const ValueKey('tariff'),
                            tooltip: 'Tarif va to‘lov',
                            onPressed: () => open(TariffPage(store: s)),
                            icon: const Icon(Icons.workspace_premium_outlined),
                          ),
                SizedBox(width: usesIOSGlass ? 12 : 4),
              ],
            ),
            body: wide
                ? Row(
                    children: [
                      GlassControl(
                          child: NavigationRail(
                        selectedIndex: page,
                        extended: width >= 1180,
                        // A phone on its side is too low for the labels.
                        labelType: width >= 1180 ||
                                MediaQuery.sizeOf(context).height < 520
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        onDestinationSelected: (p) => setState(() => page = p),
                        leading: page == 1
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FloatingActionButton(
                                  tooltip:
                                      showCustomers ? 'Mijoz' : 'Yangi smeta',
                                  elevation: 0,
                                  onPressed: showCustomers
                                      ? () => addCustomer(context, s)
                                      : newQuote,
                                  child: Icon(
                                    showCustomers
                                        ? Icons.person_add_alt
                                        : Icons.add,
                                  ),
                                ),
                              )
                            : const SizedBox(height: 8),
                        destinations: [
                          for (final (icon, selected, label) in _destinations)
                            NavigationRailDestination(
                              icon: Icon(icon),
                              selectedIcon: Icon(selected),
                              label: Text(label),
                            ),
                        ],
                      )),
                      const VerticalDivider(width: 1),
                      Expanded(child: content),
                    ],
                  )
                : content,
            floatingActionButton: page == 1 && !wide && nativeGlass
                ? NativeGlassButtons(
                    height: 52,
                    width: 170,
                    items: [
                      GlassButton(
                        'add',
                        symbol: showCustomers ? 'person.badge.plus' : 'plus',
                        title: showCustomers ? 'Mijoz' : 'Yangi smeta',
                        style: 'prominent',
                        expand: true,
                        height: 52,
                      ),
                    ],
                    onTap: (_) =>
                        showCustomers ? addCustomer(context, s) : newQuote(),
                    fallback: const SizedBox(),
                  )
                : page == 1 && !wide
                    ? GlassActionButton.extended(
                        onPressed: showCustomers
                            ? () => addCustomer(context, s)
                            : newQuote,
                        icon: Icon(
                            showCustomers ? Icons.person_add_alt : Icons.add),
                        label: Text(showCustomers ? 'Mijoz' : 'Yangi smeta'),
                      )
                    : null,
            bottomNavigationBar: wide
                ? null
                : usesIOSGlass
                    ? IOSGlassNavigation(
                        selected: page,
                        onChanged: (p) => setState(() => page = p),
                      )
                    : NavigationBar(
                        selectedIndex: page,
                        onDestinationSelected: (p) => setState(() => page = p),
                        destinations: [
                          for (final (icon, selected, label) in _destinations)
                            NavigationDestination(
                              icon: Icon(icon),
                              selectedIcon: Icon(selected),
                              label: label,
                            ),
                        ],
                      ),
          );
        },
      );

  List<Widget> dashboard(double width) {
    final now = DateTime.now();
    final month = FinanceSummary.of(s, periodRange(Period.month, now));
    final active = s.quotes.where(
      (q) => !const {'cancelled', 'installed'}.contains(q['status']),
    );
    final balance = s.quotes
        .where((q) => q['status'] != 'cancelled')
        .fold<num>(0, (n, q) => n + (q['balance'] as num));
    final soon = <(DateTime, String, String, VoidCallback)>[
      for (final q in s.quotes)
        if (q['installDate'] != null &&
            !const {'cancelled', 'installed'}.contains(q['status']))
          (
            DateTime.parse(q['installDate']).toLocal(),
            'Montaj: ${q['title']}',
            '${q['customer']} • ${q['address'] ?? ''}',
            () => open(QuotePage(store: s, id: q['id'])),
          ),
      // An install's own reminder is already listed through its order.
      for (final m in s.measurements)
        if (m['status'] == 'planned')
          (
            DateTime.parse(m['date']).toLocal(),
            'Razmer: ${m['customer']}',
            '${m['address'] ?? ''}',
            () => open(MeasurementsPage(store: s)),
          ),
      for (final r in s.reminders)
        if (r['done'] != true &&
            !(r['id'] as String).startsWith('install-') &&
            !(r['id'] as String).startsWith('zamer-'))
          (
            DateTime.parse(r['due']).toLocal(),
            r['title'] as String,
            (r['note'] ?? '') as String,
            () => open(WorkshopTools(store: s, initialPage: 1)),
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final kpis = [
      Kpi(
        'Faol buyurtma',
        '${active.length}',
        Icons.receipt_long_outlined,
        tone: 0,
      ),
      Kpi('Bu oy tushum', money(month.income), Icons.south_west, tone: 1),
      Kpi(
        'Mijozlar qarzi',
        money(balance),
        Icons.account_balance_wallet_outlined,
        tone: 2,
      ),
      Kpi(
        'Bu oy foyda',
        money(month.profit),
        Icons.trending_up,
        emphasis: true,
        tone: 3,
      ),
    ];
    final actions = [
      QuickAction(
        'AI kamera',
        Icons.photo_camera_outlined,
        drawFromPhoto,
        tone: 3,
      ),
      QuickAction('Mijozlar', Icons.people_outline, () {
        setState(() {
          page = 1;
          showCustomers = true;
        });
      }, tone: 0),
      QuickAction(
        'Razmer',
        Icons.straighten,
        () => open(MeasurementsPage(store: s)),
        tone: 1,
        badge: s.measurements.where((m) => m['status'] == 'planned').length,
      ),
      QuickAction(
        'Qarzlar',
        Icons.account_balance_wallet_outlined,
        () => open(WorkshopTools(store: s)),
        tone: 2,
      ),
      QuickAction(
        'Eslatma',
        Icons.notifications_none,
        () => open(WorkshopTools(store: s, initialPage: 1)),
        tone: 3,
        badge: s.reminders.where((r) => r['done'] != true).length,
      ),
      QuickAction(
        'Ombor',
        Icons.inventory_2_outlined,
        () => openWithPlan(
          context,
          s,
          'warehouse',
          () => WarehousePage(store: s),
        ),
        tone: 4,
      ),
      QuickAction(
        'Xodimlar',
        Icons.badge_outlined,
        () => openWithPlan(context, s, 'payroll', () => StaffPage(store: s)),
        tone: 5,
      ),
      QuickAction(
        'Moliya',
        Icons.payments_outlined,
        () => openWithPlan(context, s, 'finance', () => FinancePage(store: s)),
        tone: 1,
      ),
      QuickAction(
        'Statistika',
        Icons.bar_chart,
        () => openWithPlan(
          context,
          s,
          'finance',
          () => FinancePage(store: s, initialTab: 1),
        ),
        tone: 0,
      ),
      QuickAction(
        'Narxlar',
        Icons.cloud_sync_outlined,
        () => openPriceSources(context, s),
        tone: 4,
      ),
      QuickAction(
        'Zavodlar',
        Icons.factory_outlined,
        () => open(ManufacturersPage(store: s)),
        tone: 3,
      ),
      QuickAction(
        'Raskroy',
        Icons.content_cut,
        () => open(const CutsPage()),
        tone: 2,
      ),
    ];
    final columns = width >= 1000 ? 4 : 2,
        actionColumns = width >= 1000
            ? 10
            : width >= 600
                ? 5
                : 4;
    return [
      DashboardHero(
        workshop: s.workshopName,
        plan: s.activePlan.name,
        onDraw: drawWindow,
        onMeasure: () => open(MeasurementEditor(store: s)),
        onPlan: () => open(TariffPage(store: s)),
      ),
      const SizedBox(height: 16),
      GridView(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          // Taller with larger text, so the figures always fit.
          mainAxisExtent: 58 + MediaQuery.textScalerOf(context).scale(40),
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: kpis,
      ),
      const SizedBox(height: 16),
      GridView.count(
        crossAxisCount: actionColumns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: .92,
        children: actions,
      ),
      if (soon.isNotEmpty) ...[
        heading('Yaqin ishlar'),
        for (final (at, title, note, onTap) in soon.take(3))
          GlassCard(
            child: GlassControl(
                child: ListTile(
              leading: Icon(
                Icons.event_outlined,
                color: at.isBefore(now)
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
              ),
              title: Text(title, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${localDate(at.toIso8601String())}${note.trim().isEmpty ? '' : ' • $note'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: onTap,
            )),
          ),
      ],
      heading('Oxirgi buyurtmalar'),
      if (s.quotes.isEmpty)
        empty(
          'Birinchi smetangizni yarating',
          '“Yangi smeta”ni bosing va romni chizing — narx o‘zi hisoblanadi.',
        ),
      ...s.quotes.take(5).map(orderCard),
      notice(
        'Ma’lumotlar shu qurilmada saqlanadi. Muhim ma’lumotlar uchun Sozlamalardan zaxira nusxa saqlang.',
      ),
    ];
  }

  Widget empty(String title, String subtitle) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.window_outlined, size: 52, color: muted),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
      );
  Widget orderCard(Json q) => GlassCard(
        child: GlassControl(
            child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: () {
              final drawn = (q['items'] as List? ?? const []).where(
                (i) => i['drawing'] != null && i['recipe'] != null,
              );
              return drawn.isEmpty
                  ? Icon(Icons.window,
                      color: Theme.of(context).colorScheme.primary)
                  : WindowThumb(
                      drawing:
                          Map<String, dynamic>.from(drawn.first['drawing']),
                      recipe: Map<String, dynamic>.from(drawn.first['recipe']),
                    );
            }(),
          ),
          title: Text(
            q['title'],
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${q['customer']}\n${money(q['total'])} · ${statuses[q['status']]}${(q['balance'] as num) > 0 && q['status'] != 'cancelled' ? ' · qoldiq ${money(q['balance'])}' : ''}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(QuotePage(store: s, id: q['id'])),
        )),
      );

  bool matches(Json row, List<String> keys) {
    final text = search.text.trim().toLowerCase();
    if (text.isEmpty) return true;
    return keys.any(
      (k) => (row[k] ?? '').toString().toLowerCase().contains(text),
    );
  }

  List<Widget> orders() {
    final found = s.quotes
        .where(
          (q) =>
              (statusFilter == 'all' || q['status'] == statusFilter) &&
              matches(q, ['title', 'customer', 'phone', 'address', 'notes']),
        )
        .toList();
    final people = s.customers
        .where((c) => matches(c, ['name', 'phone', 'address']))
        .toList();
    return [
      const SizedBox(height: 8),
      GlassControl(
        child: SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text('Buyurtmalar (${s.quotes.length})'),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('Mijozlar (${s.customers.length})'),
              icon: const Icon(Icons.people_outline),
            ),
          ],
          selected: {showCustomers},
          onSelectionChanged: (v) => setState(() => showCustomers = v.single),
        ),
      ),
      const SizedBox(height: 12),
      GlassControl(
        child: TextField(
          controller: search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: showCustomers
                ? 'Ism, telefon yoki manzil'
                : 'Buyurtma, mijoz yoki telefon',
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Tozalash',
                    onPressed: search.clear,
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (!showCustomers) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final e in {'all': 'Barchasi', ...statuses}.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GlassControl(
                    child: ChoiceChip(
                      label: Text(
                        e.key == 'all'
                            ? e.value
                            : '${e.value} ${s.quotes.where((q) => q['status'] == e.key).length}',
                      ),
                      selected: statusFilter == e.key,
                      onSelected: (_) => setState(() => statusFilter = e.key),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (found.isEmpty)
          empty(
            s.quotes.isEmpty ? 'Buyurtmalar hali yo‘q' : 'Hech narsa topilmadi',
            s.quotes.isEmpty
                ? 'Yangi smeta tuzib, shu yerda kuzating.'
                : 'Qidiruv yoki bosqich filtrini o‘zgartiring.',
          ),
        ...found.map(orderCard),
      ] else ...[
        if (people.isEmpty)
          empty(
            s.customers.isEmpty ? 'Mijozlar hali yo‘q' : 'Hech kim topilmadi',
            'Pastdagi “Mijoz” tugmasi bilan qo‘shing.',
          ),
        for (final c in people)
          GlassCard(
            child: GlassControl(
                child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  (c['name'] as String).isEmpty
                      ? '?'
                      : (c['name'] as String)[0].toUpperCase(),
                ),
              ),
              title: Text(c['name']),
              subtitle: Text(
                '${c['phone'] ?? ''}${(c['address'] ?? '').toString().isEmpty ? '' : '\n${c['address']}'}',
              ),
              trailing: Text(
                '${s.quotes.where((q) => q['customerId'] == c['id']).length} ta',
              ),
              onTap: () => open(CustomerPage(store: s, customerId: c['id'])),
            )),
          ),
      ],
    ];
  }

  List<Widget> catalog() => [
        heading('Profil tizimlari'),
        FilledButton.icon(
          key: const ValueKey('open-manufacturers'),
          onPressed: () => open(ManufacturersPage(store: s)),
          icon: const Icon(Icons.factory_outlined),
          label: const Text('Zavodlar narxi: AKFA, Engelberg, Alubest…'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => editProfile(context, s),
          icon: const Icon(Icons.add),
          label: const Text('Yangi profil qo‘shish'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => openPriceSources(context, s),
          icon: const Icon(Icons.cloud_sync_outlined),
          label: const Text('Narxlarni yangilash (diler / jadval)'),
        ),
        const SizedBox(height: 12),
        notice(
          'Zavod katalogidagi narxlar ochiq bozor e’lonlaridan olingan taxminiy narx. Har bir profilning narxini shu yerda tahrirlang yoki diler, yetkazib beruvchi yoxud o‘z jadvalingizdan yangilang.',
        ),
        ...s.profiles.map(
          (p) => GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p['brand']} / ${p['material']}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Rama: ${money(p['framePrice'])}/m'),
                  Text('Shisha/panel: ${money(p['glassPrice'])}/m²'),
                  Text('Tannarxga ustama: ${p['markupPct']}%'),
                  Wrap(
                    spacing: 4,
                    children: [
                      TextButton.icon(
                        onPressed: () => editProfile(context, s, p),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Narxlarni tahrirlash'),
                      ),
                      if (s.profiles.length > 1)
                        TextButton.icon(
                          onPressed: () => deleteProfile(p),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('O‘chirish'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p['demo'] == true
                        ? 'NAMUNA QIYMATLAR'
                        : p['reference'] == true
                            ? 'ZAVOD KATALOGI • TAXMINIY NARX'
                            : 'SEX NARXLARI',
                    style: TextStyle(
                      fontSize: 11,
                      color: p['demo'] == true
                          ? Colors.orange.shade800
                          : p['reference'] == true
                              ? Colors.blue.shade800
                              : Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];

  Future<void> deleteProfile(Json p) async {
    final yes = await confirm(
      context,
      'Profil o‘chirilsinmi?',
      '${p['name']}. Saqlangan smetalar o‘z narxini saqlaydi.',
    );
    if (yes && mounted) await guarded(context, () => s.deleteProfile(p['id']));
  }

  List<Widget> settings() => [
        heading('Tarif'),
        GlassCard(
          child: GlassControl(
              child: ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(
              BillingConfig.paymentsEnabled
                  ? s.activePlan.name
                  : '${s.activePlan.name} • hozircha bepul',
            ),
            subtitle:
                const Text('Tariflar, to‘lov usullari va to‘lovlar tarixi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(TariffPage(store: s)),
          )),
        ),
        heading('Ustaxona'),
        GlassCard(
          child: GlassControl(
              child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: Text(s.workshopName),
            subtitle: Text(
              [
                if (s.workshopPhone.isNotEmpty) s.workshopPhone,
                if (s.workshopAddress.isNotEmpty) s.workshopAddress,
                if (s.workshopPhone.isEmpty && s.workshopAddress.isEmpty)
                  'Telefon va manzil PDF va ulashilgan smetaga yoziladi',
              ].join('\n'),
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: editWorkshop,
          )),
        ),
        heading('Narxlar'),
        GlassCard(
          child: GlassControl(
              child: ListTile(
            key: const ValueKey('settings-manufacturers'),
            leading: const Icon(Icons.factory_outlined),
            title: const Text('Ishlab chiqaruvchilar narxi'),
            subtitle: Text(
              s.catalog == null
                  ? 'Katalog yuklanmadi'
                  : '${s.catalog!.manufacturers.length} ta zavod • ${s.catalog!.systems.length} ta tizim • ${s.catalog!.date.split('-').reversed.join('.')}. Har kuni internetdan yangilanadi',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(ManufacturersPage(store: s)),
          )),
        ),
        GlassCard(
          child: GlassControl(
              child: ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Narxlarni internetdan yangilash'),
            subtitle: Text(
              s.priceSources.isEmpty
                  ? 'Diler havolasi, Google Sheets jadvali yoki fayl'
                  : '${s.priceSources.length} ta manba',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openPriceSources(context, s),
          )),
        ),
        GlassCard(
          child: GlassControl(
              child: ListTile(
            key: const ValueKey('usd-rate'),
            leading: const Icon(Icons.currency_exchange),
            title: Text(
              s.usdRate > 0
                  ? 'Dollar kursi: 1 \$ = ${money(s.usdRate)}'
                  : 'Dollar kursi kiritilmagan',
            ),
            subtitle: Text(
              [
                if (s.usdRateSource == 'cbu' || s.usdRateSource == 'open')
                  '${Store.rateSourceName(s.usdRateSource)}${s.usdRateDate.isEmpty ? '' : ', ${s.usdRateDate}'}',
                s.usdRateAuto
                    ? 'Har kuni Markaziy bankdan o‘zi yangilanadi; dollardagi narxlar kursga ergashadi'
                    : 'Qo‘lda kiritiladi; dollardagi narxlar shu kursda',
              ].join(' • '),
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: editUsdRate,
          )),
        ),
        heading('AI kamera'),
        GlassCard(
          child: GlassControl(
              child: ListTile(
            key: const ValueKey('ai-key'),
            leading: const Icon(Icons.auto_awesome),
            title: Text(
              s.aiKey.isEmpty ? 'Claude AI ulanmagan' : 'Claude AI ulangan',
            ),
            subtitle: const Text(
              'Kalitsiz ham ishlaydi: impostlar telefonda aniqlanadi. Kalit bilan ochilish turlari ham aniqlanadi.',
            ),
            trailing: const Icon(Icons.edit_outlined),
            onTap: editAiKey,
          )),
        ),
        heading('Ko‘rinish'),
        GlassControl(
          child: DropdownButtonFormField<String>(
            key: ValueKey('design-${s.designPreference}'),
            isExpanded: true,
            initialValue: s.designPreference,
            decoration: const InputDecoration(labelText: 'Dizayn'),
            items: const [
              DropdownMenuItem(
                value: 'auto',
                child: Text('Avto • iPhone’da Liquid Glass'),
              ),
              DropdownMenuItem(value: 'glass', child: Text('Liquid Glass')),
              DropdownMenuItem(value: 'material', child: Text('Oddiy')),
            ],
            onChanged: (v) => guarded(context, () => s.setDesign(v!)),
          ),
        ),
        const SizedBox(height: 12),
        GlassControl(
          child: DropdownButtonFormField<String>(
            key: ValueKey(s.themePreference),
            isExpanded: true,
            initialValue: s.themePreference,
            decoration: const InputDecoration(labelText: 'Ilova temasi'),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('Tizimga mos')),
              DropdownMenuItem(
                  value: 'light', child: Text('Och tema • oq logo')),
              DropdownMenuItem(
                  value: 'dark', child: Text('To‘q tema • qora logo')),
            ],
            onChanged: (v) => guarded(context, () => s.setTheme(v!)),
          ),
        ),
        const SizedBox(height: 18),
        heading('Asboblar'),
        for (final (icon, title, subtitle, page)
            in <(IconData, String, String, Widget Function())>[
          (
            Icons.payments_outlined,
            'Moliya va statistika',
            'Tushum, xarajat, foyda, grafiklar',
            () => FinancePage(store: s),
          ),
          (
            Icons.badge_outlined,
            'Xodimlar va ish haqi',
            '${s.staff.length} xodim • oylik, avans, to‘lov',
            () => StaffPage(store: s),
          ),
          (
            Icons.inventory_2_outlined,
            'Ombor va xarid ro‘yxati',
            '${s.inventory.length} ta material qoldig‘i',
            () => WarehousePage(store: s),
          ),
          (
            Icons.content_cut,
            'Profil raskroyi',
            'Tayoqlarga kesish rejasi',
            () => const CutsPage(),
          ),
          (
            Icons.history,
            'Faoliyat tarixi',
            '${s.audit.length} ta amal',
            () => AuditPage(store: s),
          ),
        ])
          GlassCard(
            child: GlassControl(
                child: ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(page()),
            )),
          ),
        heading('Zaxira nusxalar'),
        const Text(
          'Telefon almashtirishdan yoki ilovani o‘chirishdan oldin JSON zaxirasini saqlang. Tiklash joriy ma’lumotlarni almashtiradi.',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => guarded(context, () async {
            final raw = await s.exportBackup();
            final ok = await saveFileAs(
              'RomFlow-backup.json',
              'application/json',
              utf8.encode(raw),
            );
            if (mounted && ok) {
              message(context, 'Zaxira saqlandi');
            }
          }),
          icon: const Icon(Icons.save_alt),
          label: const Text('Zaxirani faylga saqlash'),
        ),
        OutlinedButton.icon(
          onPressed: () => guarded(context, () async {
            final yes = await confirm(
              context,
              'Zaxiradan tiklash',
              'Joriy ma’lumotlar tanlangan zaxira bilan almashtiriladi. Avval hozirgi zaxirangizni saqlang.',
              action: 'Fayl tanlash',
            );
            if (!yes) return;
            final raw = await pickTextFile();
            if (raw != null) {
              await s.importBackup(raw);
              if (mounted) message(context, 'Zaxira tiklandi');
            }
          }),
          icon: const Icon(Icons.restore),
          label: const Text('Zaxira faylidan tiklash'),
        ),
        heading('Maxfiylik'),
        const Text(
          'Mijozlar, narxlar, smetalar va to‘lov qaydlari faqat shu qurilmada, ilovaga ajratilgan joyda saqlanadi; serverga yuborilmaydi. Internet faqat: dollar kursi (Markaziy bank), zavodlar narx katalogi (GitHub), siz qo‘shgan narx havolalari va AI kamera (faqat o‘z Claude kalitingiz bilan, rasm Anthropic’ga yuboriladi). JSON/PDFni qayerga ulashishni o‘zingiz tanlaysiz.',
        ),
        heading('Ma’lumotlarni o‘chirish'),
        OutlinedButton.icon(
          onPressed: delete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Mahalliy ma’lumotlarni tozalash'),
        ),
        const SizedBox(height: 24),
        const Text(
          'RomFlow $appVersion\nSmeta taxminiy. Texnik katalog bilan tekshiring.',
          style: TextStyle(color: muted),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const ValueKey('licenses'),
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'RomFlow',
              applicationVersion: appVersion,
            ),
            child: const Text('Litsenziyalar'),
          ),
        ),
      ];

  Future<void> editAiKey() async {
    final key = TextEditingController(text: s.aiKey);
    final ok = await showSettledDialog<bool>(
      context: context,
      builder: (c) => GlassAlertDialog(
        title: const Text('Claude AI kaliti'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'console.anthropic.com saytida olingan API kaliti (sk-ant-…). Rasm Anthropic serveriga yuboriladi va to‘lov shu kalit hisobidan bo‘ladi. Kalit faqat shu qurilmada saqlanadi, zaxira faylga yozilmaydi.',
            ),
            const SizedBox(height: 12),
            GlassControl(
              child: TextField(
                controller: key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'API kaliti'),
              ),
            ),
          ],
        ),
        actions: [
          if (s.aiKey.isNotEmpty)
            TextButton(
              onPressed: () {
                key.clear();
                Navigator.pop(c, true);
              },
              child: const Text('O‘chirish'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await guarded(context, () => s.setAiKey(key.text));
    }
    key.dispose();
  }

  Future<void> editUsdRate() async {
    final rate = TextEditingController(
      text: s.usdRate > 0 ? '${s.usdRate.round()}' : '',
    );
    var auto = s.usdRateAuto, fetching = false;
    String? note;
    OfficialRate? fetched;
    final ok = await showSettledDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => GlassAlertDialog(
          title: const Text('Dollar kursi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassControl(
                  child: TextField(
                    controller: rate,
                    autofocus: !auto,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '1 \$ necha so‘m',
                      hintText: 'masalan 12650',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('usd-rate-cbu'),
                    onPressed: fetching
                        ? null
                        : () async {
                            setDialog(() {
                              fetching = true;
                              note = null;
                            });
                            try {
                              final r = await fetchUsdRate();
                              rate.text = r.rate.toStringAsFixed(2);
                              fetched = r;
                              note =
                                  '${Store.rateSourceName(r.source)}${r.date.isEmpty ? '' : ', ${r.date}'}';
                            } catch (e) {
                              note = '$e'.replaceFirst(
                                RegExp(r'^\w*Exception: '),
                                '',
                              );
                            }
                            if (c.mounted) {
                              setDialog(() => fetching = false);
                            }
                          },
                    icon: fetching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.account_balance_outlined),
                    label: const Text('Markaziy bankdan olish'),
                  ),
                ),
                if (note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(note!, style: Theme.of(c).textTheme.bodySmall),
                  ),
                GlassControl(
                  child: SwitchListTile(
                    key: const ValueKey('usd-rate-auto'),
                    contentPadding: EdgeInsets.zero,
                    value: auto,
                    onChanged: (v) => setDialog(() => auto = v),
                    title: const Text('Har kuni o‘zi yangilansin'),
                    subtitle: const Text(
                      'Ilova ochilganda Markaziy bankning rasmiy kursi olinadi (cbu.uz ochiq API); bank javob bermasa — xalqaro kurs (ExchangeRate-API)',
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Bekor qilish'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await guarded(context, () async {
      final value = num.tryParse(
        rate.text.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'),
      );
      if (value == null) throw Exception('Kursni raqam bilan kiriting');
      if (auto != s.usdRateAuto) await s.setUsdRateAuto(auto);
      final got = fetched;
      if (value != s.usdRate) {
        // The fetched rate keeps its source until a figure is typed over it.
        final same = got != null && (got.rate - value).abs() < .01;
        await s.setUsdRate(
          value,
          source: same ? got.source : 'manual',
          date: same ? got.date : '',
        );
      }
    });
  }

  Future<void> editWorkshop() async {
    final name = TextEditingController(text: s.workshopName),
        phone = TextEditingController(text: s.workshopPhone),
        address = TextEditingController(text: s.workshopAddress);
    final form = GlobalKey<FormState>();
    final ok = await showSettledDialog<bool>(
      context: context,
      builder: (c) => GlassAlertDialog(
        title: const Text('Ustaxona ma’lumotlari'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(name, 'Ustaxona nomi'),
                field(phone, 'Telefon', validate: (_) => null),
                field(address, 'Manzil', validate: (_) => null),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await guarded(
        context,
        () =>
            s.setWorkshop(name.text, phone: phone.text, address: address.text),
      );
    }
    for (final t in [name, phone, address]) {
      t.dispose();
    }
  }

  Future<void> delete() async {
    final confirmText = TextEditingController();
    final yes = await showSettledDialog<bool>(
      context: context,
      builder: (c) => GlassAlertDialog(
        title: const Text('Butunlay o‘chirish'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Davom etish uchun DELETE yozing.'),
              field(confirmText, 'DELETE'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, confirmText.text == 'DELETE'),
            child: const Text('O‘chirish'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await guarded(context, () => s.deleteAccount(''));
    }
    confirmText.dispose();
  }
}

/// − 3 + for the number of identical windows.
class _Stepper extends StatelessWidget {
  final int value;
  final ValueChanged<int>? onChanged;
  const _Stepper({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget button(IconData icon, int next, String tip) => SizedBox(
          width: 34,
          height: 34,
          child: IconButton(
            tooltip: tip,
            padding: EdgeInsets.zero,
            iconSize: 18,
            onPressed: onChanged == null || next < 1 || next > 100
                ? null
                : () => onChanged!(next),
            icon: Icon(icon),
          ),
        );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(Icons.remove, value - 1, 'Kamaytirish'),
          SizedBox(
            width: 34,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          button(Icons.add, value + 1, 'Ko‘paytirish'),
        ],
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final int badge, tone;
  const QuickAction(
    this.label,
    this.icon,
    this.onTap, {
    super.key,
    this.badge = 0,
    this.tone = 0,
  });
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        accent = toneColor(tone, Theme.of(context).brightness);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant, width: .8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .13),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 22),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _weekdays = [
  'Dushanba',
  'Seshanba',
  'Chorshanba',
  'Payshanba',
  'Juma',
  'Shanba',
  'Yakshanba',
];
const _months = [
  'yanvar',
  'fevral',
  'mart',
  'aprel',
  'may',
  'iyun',
  'iyul',
  'avgust',
  'sentabr',
  'oktabr',
  'noyabr',
  'dekabr',
];

/// "Payshanba, 22-oktabr"
String uzbekDay(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day}-${_months[d.month - 1]}';

/// Top of the dashboard: the workshop, today and the two main actions.
class DashboardHero extends StatelessWidget {
  final String workshop, plan;
  final VoidCallback onDraw, onMeasure, onPlan;
  const DashboardHero({
    super.key,
    required this.workshop,
    required this.plan,
    required this.onDraw,
    required this.onMeasure,
    required this.onPlan,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xff123a6e), Color(0xff1d5aa6)]
              : const [Color(0xff1659b8), Color(0xff2f86ea)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff1659b8).withValues(alpha: dark ? .2 : .25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ISH MAYDONI',
                      style: TextStyle(
                        color: Colors.white70,
                        letterSpacing: 1.4,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workshop,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      uzbekDay(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.white.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onPlan,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          plan,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Side by side on every phone; the labels shrink before wrapping.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: NativeGlassButtons(
              height: 50,
              equal: true,
              spacing: 10,
              items: const [
                GlassButton(
                  'draw',
                  symbol: 'pencil.and.ruler',
                  title: 'Yangi smeta',
                  style: 'white',
                  expand: true,
                  height: 50,
                ),
                GlassButton(
                  'measure',
                  symbol: 'ruler',
                  title: 'Razmer yozish',
                  light: true,
                  expand: true,
                  height: 50,
                ),
              ],
              onTap: (id) => id == 'draw' ? onDraw() : onMeasure(),
              fallback: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('home-draw'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xff1659b8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 14,
                        ),
                      ),
                      onPressed: onDraw,
                      icon: const Icon(
                        Icons.design_services_outlined,
                        size: 20,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Yangi smeta'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: glassOver(
                      OutlinedButton.icon(
                        key: const ValueKey('home-measure'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: usesIOSGlass
                              ? BorderSide.none
                              : const BorderSide(color: Colors.white70),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 14,
                          ),
                        ),
                        onPressed: onMeasure,
                        icon: const Icon(Icons.straighten, size: 20),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Razmer yozish'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design chosen in Settings, applied before the app is built; a new
/// key rebuilds every page when it changes.
String _designKey(String preference) {
  applyDesign(preference);
  return usesIOSGlass ? 'glass' : 'material';
}

/// [child] on a glass pill when Liquid Glass is on.
Widget glassOver(Widget child, {double radius = 22}) => usesIOSGlass
    ? GlassSurface(
        radius: BorderRadius.circular(radius),
        shadow: false,
        child: child,
      )
    : child;

Future<bool> confirm(
  BuildContext context,
  String title,
  String text, {
  String action = 'O‘chirish',
}) async {
  final yes = await showSettledDialog<bool>(
    context: context,
    builder: (c) => GlassAlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Bekor qilish'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return yes == true;
}

/// Opens the phone dialer; elsewhere the number is copied instead.
Future<void> callNumber(BuildContext context, String phone) async {
  final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) {
    message(context, 'Telefon raqami kiritilmagan');
    return;
  }
  try {
    await nativeFiles.invokeMethod<void>('dial', {'phone': number});
  } on MissingPluginException {
    await Clipboard.setData(ClipboardData(text: number));
    if (context.mounted) message(context, 'Raqam nusxalandi: $number');
  } on PlatformException catch (e) {
    if (context.mounted) message(context, e.message ?? 'Qo‘ng‘iroq ochilmadi');
  }
}

class CustomerPage extends StatelessWidget {
  final Store store;
  final String customerId;
  const CustomerPage({
    super.key,
    required this.store,
    required this.customerId,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final found = store.customers.where((c) => c['id'] == customerId);
          if (found.isEmpty) {
            return Scaffold(
              appBar: GlassAppBar(),
              body: const Center(child: Text('Mijoz topilmadi')),
            );
          }
          final c = found.first;
          final orders =
              store.quotes.where((q) => q['customerId'] == customerId).toList();
          final total = orders
              .where((q) => q['status'] != 'cancelled')
              .fold<num>(0, (a, q) => a + (q['total'] as num));
          final balance = orders
              .where((q) => q['status'] != 'cancelled')
              .fold<num>(0, (a, q) => a + (q['balance'] as num));
          return Scaffold(
            appBar: GlassAppBar(
              title: Text(c['name']),
              actions: [
                IconButton(
                  tooltip: 'Tahrirlash',
                  onPressed: () => addCustomer(context, store, c),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'O‘chirish',
                  onPressed: () async {
                    if (await confirm(
                          context,
                          'Mijoz o‘chirilsinmi?',
                          'Buyurtmalari o‘chmaydi, ularda ism va telefon saqlanadi.',
                        ) &&
                        context.mounted) {
                      await guarded(
                        context,
                        () => store.deleteCustomer(customerId),
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            floatingActionButton: GlassActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      BuilderPage(store: store, initialCustomer: customerId),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Smeta'),
            ),
            body: readable(
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  GlassCard(
                    child: GlassControl(
                        child: ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: Text(
                        (c['phone'] ?? '').toString().isEmpty
                            ? 'Telefon kiritilmagan'
                            : c['phone'],
                      ),
                      subtitle: (c['address'] ?? '').toString().isEmpty
                          ? null
                          : Text(c['address']),
                      trailing: FilledButton.tonalIcon(
                        onPressed: () => callNumber(context, c['phone'] ?? ''),
                        icon: const Icon(Icons.call),
                        label: const Text('Qo‘ng‘iroq'),
                      ),
                    )),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Kpi(
                          'Buyurtmalar',
                          money(total),
                          Icons.receipt_long_outlined,
                          hint: '${orders.length} ta smeta',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Kpi(
                          'Qoldiq',
                          money(balance),
                          Icons.account_balance_wallet_outlined,
                          emphasis: balance > 0,
                        ),
                      ),
                    ],
                  ),
                  heading('Buyurtmalar'),
                  if (orders.isEmpty) const Text('Hali smeta yo‘q.'),
                  for (final q in orders)
                    GlassCard(
                      child: GlassControl(
                          child: ListTile(
                        title: Text(q['title']),
                        subtitle: Text(
                          '${money(q['total'])} · ${statuses[q['status']]}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                QuotePage(store: store, id: q['id']),
                          ),
                        ),
                      )),
                    ),
                ],
              ),
            ),
          );
        },
      );
}

Future<void> addCustomer(BuildContext context, Store s, [Json? initial]) async {
  final name = TextEditingController(text: initial?['name'] ?? ''),
      phone = TextEditingController(text: initial?['phone'] ?? ''),
      address = TextEditingController(text: initial?['address'] ?? ''),
      key = GlobalKey<FormState>();
  bool saving = false;
  await showSettledDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => GlassAlertDialog(
        title: const Text('Yangi mijoz'),
        content: SingleChildScrollView(
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(name, 'Ism'),
                field(phone, 'Telefon', validate: (_) => null),
                field(address, 'Manzil', validate: (_) => null),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(c),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!key.currentState!.validate()) return;
                    set(() => saving = true);
                    try {
                      await s.addCustomer({
                        if (initial != null) 'id': initial['id'],
                        'name': name.text.trim(),
                        'phone': phone.text.trim(),
                        'address': address.text.trim(),
                      });
                      if (c.mounted) Navigator.pop(c);
                    } catch (e) {
                      if (c.mounted) {
                        message(c, e);
                        set(() => saving = false);
                      }
                    }
                  },
            child: Text(saving ? 'Saqlanmoqda…' : 'Saqlash'),
          ),
        ],
      ),
    ),
  );
  name.dispose();
  phone.dispose();
  address.dispose();
}

class BuilderPage extends StatefulWidget {
  final Store store;
  final Json? initialItem;
  final String? initialCustomer;

  /// Openings measured on site, already filled in (see measurements.dart).
  final List<Json> initialItems;
  final String? initialTitle, initialNotes;

  /// When set, the page edits this saved order instead of creating one.
  final Json? editing;
  const BuilderPage({
    super.key,
    required this.store,
    this.initialItem,
    this.initialCustomer,
    this.initialItems = const [],
    this.initialTitle,
    this.initialNotes,
    this.editing,
  });
  @override
  State<BuilderPage> createState() => _BuilderPageState();
}

class _BuilderPageState extends State<BuilderPage> {
  final w = TextEditingController(text: '1400'),
      h = TextEditingController(text: '1500'),
      qty = TextEditingController(text: '1'),
      title = TextEditingController(text: 'Yangi buyurtma'),
      discount = TextEditingController(text: '0'),
      install = TextEditingController(text: '0'),
      notes = TextEditingController();
  late String profile;
  String template = 'double', color = 'white';
  bool mosquito = false, busy = false;
  String? customer;
  List<Json> items = [];

  /// Sills, ebb, slopes, dismantling, delivery… sold with the windows.
  List<Json> extras = [];
  Json? result;
  final form = GlobalKey<FormState>();
  Store get s => widget.store;
  @override
  void initState() {
    super.initState();
    profile = s.profiles.first['id'];
    if (widget.initialItem != null) {
      items.add(Map<String, dynamic>.from(widget.initialItem!));
    }
    items.addAll(widget.initialItems.map((i) => Map<String, dynamic>.from(i)));
    if (widget.initialTitle != null) title.text = widget.initialTitle!;
    if (widget.initialNotes != null) notes.text = widget.initialNotes!;
    customer = s.customers.isNotEmpty ? s.customers.first['id'] : null;
    if (widget.initialCustomer != null &&
        s.customers.any((c) => c['id'] == widget.initialCustomer)) {
      customer = widget.initialCustomer;
    }
    final q = widget.editing;
    if (q != null) {
      items = [
        for (final i in q['items'] as List)
          Map<String, dynamic>.from(jsonDecode(jsonEncode(i))),
      ];
      title.text = q['title'];
      discount.text = '${q['discount'] ?? 0}';
      install.text = '${q['installation'] ?? 0}';
      notes.text = q['notes'] ?? '';
      extras = [
        for (final e in q['extras'] as List? ?? const [])
          Map<String, dynamic>.from(e),
      ];
      if (s.customers.any((c) => c['id'] == q['customerId'])) {
        customer = q['customerId'];
      }
    }
    w.addListener(redraw);
    h.addListener(redraw);
  }

  void redraw() {
    if (mounted) setState(() => result = null);
  }

  @override
  void dispose() {
    for (final c in [w, h, qty, title, discount, install, notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Json current() => {
        'profileId': profile,
        'template': template,
        'widthMm': int.parse(w.text),
        'heightMm': int.parse(h.text),
        'quantity': int.parse(qty.text),
        'color': color,
        'mosquito': mosquito,
      };
  Json body() => {
        'customerId': customer,
        'title': title.text.trim(),
        'items': items,
        'discount': int.parse(discount.text),
        'installation': int.parse(install.text),
        'extras': extras,
        'notes': notes.text,
      };

  Future<void> editExtra(String key, [int? index]) async {
    final (name0, unit, sample) = extraCatalog[key]!;
    final old = index == null ? null : extras[index];
    final name = TextEditingController(text: old?['name'] ?? name0),
        qty = TextEditingController(text: '${old?['qty'] ?? 1}'),
        price = TextEditingController(
          text: '${old?['price'] ?? s.extraPrices[key] ?? sample}',
        );
    final ok = await showSettledDialog<bool>(
      context: context,
      builder: (c) => GlassAlertDialog(
        title: Text(name0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (key == 'other') ...[
                GlassControl(
                  child: TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nomi'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GlassControl(
                child: TextField(
                  key: const ValueKey('extra-qty'),
                  controller: qty,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: 'Miqdori ($unit)'),
                ),
              ),
              const SizedBox(height: 12),
              GlassControl(
                child: TextField(
                  key: const ValueKey('extra-price'),
                  controller: price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Narxi, so‘m / $unit'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Qo‘shish'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final q = num.tryParse(qty.text.replaceAll(',', '.').trim()),
        p = num.tryParse(price.text.replaceAll(RegExp(r'[\s,]'), ''));
    if (q == null || q <= 0 || p == null || p < 0 || name.text.trim().isEmpty) {
      message(context, 'Miqdor va narxni to‘g‘ri kiriting');
      return;
    }
    final line = {
      'key': key,
      'name': name.text.trim(),
      'unit': unit,
      'qty': q,
      'price': p,
    };
    setState(() {
      index == null ? extras.add(line) : extras[index] = line;
      result = null;
    });
  }

  List<Widget> extrasSection() => [
        heading('Qo‘shimcha ishlar'),
        for (var i = 0; i < extras.length; i++)
          GlassCard(
            child: GlassControl(
                child: ListTile(
              title: Text(extras[i]['name']),
              subtitle: Text(
                '${extras[i]['qty']} ${extras[i]['unit']} × ${money(extras[i]['price'])}',
              ),
              onTap: () => editExtra(extras[i]['key'] ?? 'other', i),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    money(extraLine(extras[i])),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    tooltip: 'Olib tashlash',
                    onPressed: () => setState(() {
                      extras.removeAt(i);
                      result = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            )),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in extraCatalog.entries)
              GlassControl(
                child: ActionChip(
                  key: ValueKey('extra-${e.key}'),
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(e.value.$1),
                  onPressed: () => editExtra(e.key),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
      ];
  Widget choice(
    String label,
    String value,
    List<DropdownMenuItem<String>> options,
    ValueChanged<String?> changed,
  ) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GlassControl(
          child: DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: options,
            onChanged: changed,
          ),
        ),
      );

  /// Price of each window, recalculated only when the windows change.
  String? _totalsKey;
  List<num?> _itemTotals = const [];
  List<num?> itemTotals() {
    final key = jsonEncode(items);
    if (key == _totalsKey) return _itemTotals;
    _totalsKey = key;
    _itemTotals = [
      for (final i in items)
        () {
          try {
            final p = s.profiles.firstWhere((p) => p['id'] == i['profileId']);
            return calculate(Map<String, dynamic>.from(i), p)['total'] as num;
          } catch (_) {
            return null;
          }
        }(),
    ];
    return _itemTotals;
  }

  /// Total as it would be saved, or null while something is invalid.
  num? liveTotal() {
    final prices = itemTotals();
    if (items.isEmpty || prices.contains(null)) return null;
    final d = int.tryParse(discount.text.trim()),
        m = int.tryParse(install.text.trim());
    if (d == null || m == null || d < 0 || m < 0) return null;
    final extra = extras.fold<int>(0, (n, e) => n + extraLine(e));
    return prices.fold<num>(0, (n, p) => n + p!) + m + extra - d;
  }

  void changed(void Function() fn) => setState(() {
        fn();
        result = null;
      });

  Future<void> addWindow() async {
    final choice = await openDesignCatalog(
      context,
      recipe: catalogRecipe(s),
      store: s,
    );
    if (!mounted || choice == null) return;
    final item = await Navigator.push<Json>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingEditor(
          store: s,
          title: 'Smetaga rom qo‘shish',
          initial: choice.item(),
        ),
      ),
    );
    if (item != null && mounted) changed(() => items.add(item));
  }

  Future<void> editWindow(int index) async {
    final item = items[index];
    if (item['drawing'] == null) return;
    final updated = await Navigator.push<Json>(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingEditor(
          store: s,
          title: 'Romni tahrirlash',
          initial: item,
          key: ValueKey('edit-$index'),
        ),
      ),
    );
    if (updated != null && mounted) changed(() => items[index] = updated);
  }

  Future<void> windowMenu(int index, String action) async {
    switch (action) {
      case 'edit':
        await editWindow(index);
      case 'room':
        final value = await pickRoom(context, items[index]['label']);
        if (value == null || !mounted) return;
        changed(
          () => value.isEmpty
              ? items[index].remove('label')
              : items[index]['label'] = value,
        );
      case 'copy':
        changed(
          () => items.insert(
            index + 1,
            Map<String, dynamic>.from(jsonDecode(jsonEncode(items[index])))
              ..remove('label'),
          ),
        );
        message(context, 'Rom nusxalandi');
      case 'delete':
        final removed = items[index];
        changed(() => items.removeAt(index));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Rom olib tashlandi'),
              action: SnackBarAction(
                label: 'Qaytarish',
                onPressed: () {
                  if (mounted) {
                    changed(
                      () =>
                          items.insert(math.min(index, items.length), removed),
                    );
                  }
                },
              ),
            ),
          );
    }
  }

  Widget windowCard(int index, num? price) {
    final item = items[index],
        scheme = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme,
        drawn = item['drawing'] != null,
        count = (item['quantity'] as num).toInt(),
        profileName = s.profiles.firstWhere(
          (p) => p['id'] == item['profileId'],
          orElse: () => {'name': item['profileName'] ?? ''},
        )['name'];
    return GlassCard(
      key: ValueKey('window-$index'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: drawn && !busy ? () => editWindow(index) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 78,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: drawn
                    ? WindowThumb(
                        drawing: Map<String, dynamic>.from(item['drawing']),
                        recipe: Map<String, dynamic>.from(
                          item['recipe'] ??
                              recipeFor(
                                s.profiles.firstWhere(
                                  (p) => p['id'] == item['profileId'],
                                  orElse: () => s.profiles.first,
                                ),
                              ),
                        ),
                      )
                    : Icon(
                        Icons.window_outlined,
                        size: 36,
                        color: scheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['label'] ?? '${index + 1}-rom',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${item['widthMm']} × ${item['heightMm']} mm • $profileName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Stepper(
                          value: count,
                          onChanged: busy
                              ? null
                              : (v) =>
                                  changed(() => items[index]['quantity'] = v),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              price == null ? '—' : money(price),
                              style: text.titleSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('window-menu-$index'),
                tooltip: 'Amallar',
                enabled: !busy,
                onSelected: (v) => windowMenu(index, v),
                itemBuilder: (_) => [
                  if (drawn)
                    const PopupMenuItem(
                      value: 'edit',
                      child: GlassControl(
                          child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Chizmani tahrirlash'),
                      )),
                    ),
                  const PopupMenuItem(
                    value: 'room',
                    child: GlassControl(
                        child: ListTile(
                      leading: Icon(Icons.place_outlined),
                      title: Text('Joyini yozish'),
                    )),
                  ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: GlassControl(
                        child: ListTile(
                      leading: Icon(Icons.copy_outlined),
                      title: Text('Nusxa olish'),
                    )),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: GlassControl(
                        child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Olib tashlash'),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The old quick form: a window from a fixed layout, without drawing.
  Widget quickForm() {
    final t = templates.firstWhere((t) => t['id'] == template);
    return GlassCard(
      child: GlassControl(
          child: ExpansionTile(
        key: const ValueKey('quick-form'),
        leading: const Icon(Icons.bolt_outlined),
        title: const Text('Tezkor hisob (chizmasiz)'),
        subtitle: const Text('Tayyor sxema + eni va bo‘yi'),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Container(
            height: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: CustomPaint(
              painter: WindowPainter(
                t: t,
                width: w.text,
                height: h.text,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 14),
          choice(
            'Profil tizimi',
            profile,
            s.profiles
                .map(
                  (p) => DropdownMenuItem<String>(
                    value: p['id'],
                    child: Text(p['name'], overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            (v) => setState(() {
              profile = v!;
              result = null;
            }),
          ),
          choice(
            'Konstruksiya turi',
            template,
            templates
                .map(
                  (t) => DropdownMenuItem<String>(
                    value: t['id'],
                    child: Text(t['name']),
                  ),
                )
                .toList(),
            (v) => setState(() {
              template = v!;
              result = null;
            }),
          ),
          Row(
            children: [
              Expanded(
                child: field(w, 'Eni (mm)', number: true, validate: dimension),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: field(
                  h,
                  'Bo‘yi (mm)',
                  number: true,
                  validate: dimension,
                ),
              ),
            ],
          ),
          choice(
            'Rang',
            color,
            const [
              DropdownMenuItem(value: 'white', child: Text('Oq')),
              DropdownMenuItem(value: 'anthracite', child: Text('Antratsit')),
              DropdownMenuItem(value: 'oak', child: Text('Yog‘och rang')),
            ],
            (v) => setState(() {
              color = v!;
              result = null;
            }),
          ),
          field(
            qty,
            'Soni',
            number: true,
            validate: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 100 ? '1–100 dona' : null;
            },
          ),
          GlassControl(
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: mosquito,
              onChanged: (v) => setState(() => mosquito = v!),
              title: const Text('Setka qo‘shish'),
              subtitle: Text(
                '${money(s.profiles.firstWhere((p) => p['id'] == profile)['meshPrice'] ?? 75000)}/m²',
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : addItem,
            icon: const Icon(Icons.add),
            label: const Text('Smetaga qo‘shish'),
          ),
          const SizedBox(height: 8),
          Text(
            'Hisob taxminiy, chizma sxematik. To‘liq material, rezina va chiqindi uchun romni chizing.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      )),
    );
  }

  Widget totalBar(num? total) {
    final scheme = Theme.of(context).colorScheme;
    final count = items.fold<int>(
      0,
      (n, i) => n + (i['quantity'] as num).toInt(),
    );
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      items.isEmpty
                          ? 'Hali rom yo‘q'
                          : '${items.length} xil rom • $count dona',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        total == null ? '—' : money(total),
                        key: const ValueKey('smeta-total'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    if (total != null && s.usdRate > 0)
                      Text(
                        dollars(total, s.usdRate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                key: const ValueKey('save-smeta'),
                onPressed: busy ? null : () => run(true),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(widget.editing == null ? 'Saqlash' : 'Yangilash'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prices = itemTotals(), total = liveTotal();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: GlassAppBar(
        title: Text(widget.editing == null ? 'Smeta' : 'Smetani tahrirlash'),
      ),
      bottomNavigationBar: totalBar(total),
      body: readable(
        SafeArea(
          bottom: false,
          child: Form(
            key: form,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      children: [
                        field(title, 'Buyurtma nomi'),
                        if (s.customers.isNotEmpty)
                          choice(
                            'Mijoz',
                            customer ?? s.customers.first['id'],
                            s.customers
                                .map(
                                  (c) => DropdownMenuItem<String>(
                                    value: c['id'],
                                    child: Text(c['name']),
                                  ),
                                )
                                .toList(),
                            (v) => setState(() {
                              customer = v;
                              result = null;
                            }),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: busy
                                ? null
                                : () async {
                                    await addCustomer(context, s);
                                    if (mounted) {
                                      setState(
                                        () => customer = s.customers.isEmpty
                                            ? null
                                            : s.customers.first['id'],
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.person_add_alt),
                            label: Text(
                              s.customers.isEmpty
                                  ? 'Mijoz qo‘shish'
                                  : 'Yangi mijoz',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: heading('Romlar')),
                    if (items.isNotEmpty)
                      Text(
                        '${items.fold<int>(0, (n, i) => n + (i['quantity'] as num).toInt())} dona',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
                for (var i = 0; i < items.length; i++)
                  windowCard(i, i < prices.length ? prices[i] : null),
                Material(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    key: const ValueKey('add-window'),
                    borderRadius: BorderRadius.circular(16),
                    onTap: busy ? null : addWindow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            items.isEmpty
                                ? 'Rom chizib qo‘shish'
                                : 'Yana rom qo‘shish',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                quickForm(),
                const SizedBox(height: 4),
                ...extrasSection(),
                heading('Montaj, chegirma, izoh'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: WorkshopField(
                          controller: install,
                          label: 'Montaj, so‘m',
                          number: true,
                          decimal: false,
                          validator: nonnegative,
                          onChanged: (_) => setState(() => result = null),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: WorkshopField(
                          controller: discount,
                          label: 'Chegirma, so‘m',
                          number: true,
                          decimal: false,
                          validator: nonnegative,
                          onChanged: (_) => setState(() => result = null),
                        ),
                      ),
                    ),
                  ],
                ),
                field(notes, 'Izoh', validate: (_) => null),
                if (items.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => run(false),
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Tekshirish'),
                  ),
                if (result != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: notice(
                      'Smeta to‘g‘ri: ${(result!['items'] as List).length} ta pozitsiya, jami ${money(result!['total'])}.',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? dimension(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 300 || n > 6000 ? '300–6000 mm' : null;
  }

  String? nonnegative(String? v) {
    final n = int.tryParse(v ?? '');
    return n == null || n < 0 || n > 10000000000
        ? 'Musbat butun son kiriting'
        : null;
  }

  void addItem() {
    try {
      if (dimension(w.text) != null || dimension(h.text) != null) {
        throw Exception('O‘lcham: 300–6000 mm');
      }
      final item = current();
      final templateData = templates.firstWhere((t) => t['id'] == template);
      var sequence = 0;
      var opens = templateData['opening'] as int;
      Map<String, dynamic> leaf() {
        final n = newLeaf('quick-${sequence++}');
        if (opens > 0) {
          n['opening'] = template.contains('door')
              ? 'doorLeft'
              : template == 'sliding'
                  ? 'slideLeft'
                  : 'left';
          opens--;
        }
        n['mesh'] = mosquito;
        return n;
      }

      Map<String, dynamic> tree(int columns, int rows) {
        if (columns > 1) {
          return {
            'id': 'quick-s${sequence++}',
            'axis': 'v',
            'ratio': 1 / columns,
            'a': tree(1, rows),
            'b': tree(columns - 1, rows),
          };
        }
        if (rows > 1) {
          return {
            'id': 'quick-s${sequence++}',
            'axis': 'h',
            'ratio': 1 / rows,
            'a': leaf(),
            'b': tree(1, rows - 1),
          };
        }
        return leaf();
      }

      final profileData = s.profiles.firstWhere((p) => p['id'] == profile);
      item['drawing'] = {
        ...newDrawing(),
        'widthMm': item['widthMm'],
        'heightMm': item['heightMm'],
        'root': tree(templateData['columns'], templateData['rows']),
      };
      item['recipe'] = recipeFor(profileData);
      // The colour surcharge comes from the recipe's colour table, which
      // starts from the profile's anthracite and oak factors.
      if (color == 'anthracite') item['recipe']['finish'] = 'anthracite';
      if (color == 'oak') item['recipe']['finish'] = 'goldenOak';
      calculate(item, s.profiles.firstWhere((p) => p['id'] == profile));
      setState(() {
        items.add(item);
        result = null;
      });
      message(context, 'Konstruksiya smetaga qo‘shildi');
    } catch (e) {
      message(context, e);
    }
  }

  Future<void> run(bool save) async {
    if (!form.currentState!.validate()) return;
    if (items.isEmpty) {
      message(context, 'Avval rom qo‘shing');
      return;
    }
    if (customer == null) {
      // Ask for the customer right here instead of refusing to save.
      await addCustomer(context, s);
      if (!mounted || s.customers.isEmpty) return;
      setState(() => customer = s.customers.first['id']);
    }
    setState(() => busy = true);
    try {
      final q = !save
          ? await s.estimate(body())
          : widget.editing != null
              ? await s.updateQuote(widget.editing!['id'], body())
              : await s.saveQuote(body());
      if (!mounted) return;
      if (save) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QuotePage(store: s, id: q['id']),
          ),
        );
      } else {
        setState(() => result = q);
      }
    } catch (e) {
      if (mounted) message(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class WindowPainter extends CustomPainter {
  final Json t;
  final String width, height, color;
  WindowPainter({
    required this.t,
    required this.width,
    required this.height,
    required this.color,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final cols = t['columns'] as int, rows = t['rows'] as int;
    final stroke = {
      'white': const Color(0xff8b9db3),
      'anthracite': const Color(0xff334155),
      'oak': const Color(0xff97704f),
    }[color]!;
    final rect = Rect.fromLTWH(24, 30, size.width - 48, size.height - 60);
    canvas.drawRect(rect, Paint()..color = const Color(0xffd2e6f6));
    final frame = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawRect(rect, frame);
    for (var i = 1; i < cols; i++) {
      final x = rect.left + i * rect.width / cols;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), frame);
    }
    for (var i = 1; i < rows; i++) {
      final y = rect.top + i * rect.height / rows;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), frame);
    }
    if ((t['opening'] as int) > 0) {
      // Same rule as the drawing editor: the apex marks the hinge side.
      final p = Path()
        ..moveTo(rect.left + rect.width / cols - 5, rect.top + 5)
        ..lineTo(rect.left + 5, rect.top + rect.height / rows / 2)
        ..lineTo(
          rect.left + rect.width / cols - 5,
          rect.top + rect.height / rows - 5,
        );
      canvas.drawPath(
        p,
        Paint()
          ..color = muted
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    void text(String value, Offset pos) {
      final p = TextPainter(
        text: TextSpan(
          text: value,
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, pos - Offset(p.width / 2, 0));
    }

    text('$width mm', Offset(size.width / 2, 3));
    text('$height mm · sxematik', Offset(size.width / 2, size.height - 20));
  }

  @override
  bool shouldRepaint(covariant WindowPainter old) => true;
}

class QuotePage extends StatefulWidget {
  final Store store;
  final String id;
  const QuotePage({super.key, required this.store, required this.id});
  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuotePageState extends State<QuotePage> {
  bool busy = false;
  Store get s => widget.store;
  Future<void> action(Future<void> Function() fn) async {
    setState(() => busy = true);
    await guarded(context, fn);
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: s,
        builder: (context, _) {
          final matches = s.quotes.where((q) => q['id'] == widget.id);
          if (matches.isEmpty) {
            return Scaffold(
              appBar: GlassAppBar(),
              body: const Center(child: Text('Smeta topilmadi')),
            );
          }
          final q = matches.first;
          return Scaffold(
            appBar: GlassAppBar(
              title: const Text('Smeta tafsilotlari'),
              actions: [
                IconButton(
                  tooltip: 'PDF ulashish',
                  onPressed: busy ? null : () => action(() => exportPdf(q)),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey('quote-menu'),
                  onSelected: (v) => menu(q, v),
                  itemBuilder: (_) => [
                    for (final (id, icon, label) in const [
                      ('edit', Icons.edit_outlined, 'Tahrirlash'),
                      ('copy', Icons.copy_all_outlined, 'Nusxa olish'),
                      ('text', Icons.share_outlined, 'Matn bilan ulashish'),
                      ('cuts', Icons.content_cut, 'Kesish ro‘yxati (ustaga)'),
                      ('call', Icons.call_outlined, 'Mijozga qo‘ng‘iroq'),
                      ('delete', Icons.delete_outline, 'O‘chirish'),
                    ])
                      PopupMenuItem(
                        value: id,
                        child: GlassControl(
                            child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(icon),
                          title: Text(label),
                        )),
                      ),
                  ],
                ),
              ],
            ),
            body: readable(
              SafeArea(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      statuses[q['status']]!,
                      style: const TextStyle(
                        color: blue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    heading(q['title']),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WarehousePage(
                            store: s,
                            items: q['items'],
                            quoteId: q['id'],
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Ombor / xarid ro‘yxati'),
                    ),
                    GlassCard(
                      child: GlassControl(
                          child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(q['customer']),
                        subtitle: Text(
                          [
                            if ((q['phone'] ?? '').toString().isNotEmpty)
                              q['phone'],
                            if ((q['address'] ?? '').toString().isNotEmpty)
                              q['address'],
                          ].join('\n'),
                        ),
                        trailing: IconButton(
                          tooltip: 'Qo‘ng‘iroq',
                          onPressed: () =>
                              callNumber(context, q['phone'] ?? ''),
                          icon: const Icon(Icons.call_outlined),
                        ),
                      )),
                    ),
                    GlassCard(
                      child: GlassControl(
                          child: ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: const Text('Montaj sanasi'),
                        subtitle: Text(
                          q['installDate'] == null
                              ? 'Belgilanmagan — bosing'
                              : localDate(q['installDate']),
                        ),
                        trailing: q['installDate'] == null
                            ? const Icon(Icons.chevron_right)
                            : IconButton(
                                tooltip: 'Olib tashlash',
                                onPressed: () => action(
                                    () => s.setInstallDate(q['id'], null)),
                                icon: const Icon(Icons.close),
                              ),
                        onTap: busy ? null : () => pickInstallDate(q),
                      )),
                    ),
                    const SizedBox(height: 10),
                    notice(
                      'Chizmali pozitsiyalarda material va raskroy hisobi mavjud. Sex me’yorlari va namuna narxlarini haqiqiy katalog/prays bilan tekshiring.',
                    ),
                    ...((q['items'] as List).map(
                      (i) => GlassCard(
                        child: GlassControl(
                            child: ExpansionTile(
                          leading: i['drawing'] == null
                              ? const Icon(Icons.window_outlined)
                              : SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: WindowThumb(
                                    drawing: Map<String, dynamic>.from(
                                      i['drawing'],
                                    ),
                                    recipe:
                                        Map<String, dynamic>.from(i['recipe']),
                                  ),
                                ),
                          title: Text(
                            i['label'] == null
                                ? i['profileName']
                                : '${i['label']} • ${i['profileName']}',
                          ),
                          subtitle: Text(
                            '${i['widthMm']}×${i['heightMm']} mm · ${i['quantity']} dona\n${money(i['total'])}',
                          ),
                          children: [
                            if (i['drawing'] != null) ...[
                              TextButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => View3D(
                                      drawing: Map<String, dynamic>.from(
                                        i['drawing'],
                                      ),
                                      recipe: Map<String, dynamic>.from(
                                        i['recipe'],
                                      ),
                                      aiKey: s.aiKey,
                                      calculation: Map<String, dynamic>.from(i),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.view_in_ar),
                                label: const Text('3D / animatsiya'),
                              ),
                              SizedBox(
                                height: 300,
                                child: CustomPaint(
                                  painter: DrawingPainter(
                                    Map<String, dynamic>.from(i['drawing']),
                                    Map<String, dynamic>.from(i['recipe']),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: DrawingReport(
                                  item: Map<String, dynamic>.from(i),
                                ),
                              ),
                            ] else
                              ...((i['parts'] as List).map(
                                (p) => GlassControl(
                                    child: ListTile(
                                  dense: true,
                                  title: Text(p['name']),
                                  subtitle:
                                      Text('${p['quantity']} ${p['unit']}'),
                                  trailing: Text(money(p['cost'])),
                                )),
                              )),
                          ],
                        )),
                      ),
                    )),
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Oraliq: ${money(q['subtotal'])}'),
                            for (final e in q['extras'] as List? ?? const [])
                              Text(
                                '${e['name']}: ${e['qty']} ${e['unit']} × ${money(e['price'])} = ${money(extraLine(Map<String, dynamic>.from(e)))}',
                              ),
                            Text('Montaj: ${money(q['installation'])}'),
                            Text('Chegirma: ${money(q['discount'])}'),
                            const Divider(),
                            Text(
                              money(q['total']),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: blue,
                              ),
                            ),
                            if (s.usdRate > 0)
                              Text(
                                dollars(q['total'], s.usdRate),
                                style: const TextStyle(color: muted),
                              ),
                            Text('To‘langan: ${money(q['paid'])}'),
                            Text('Qoldiq: ${money(q['balance'])}'),
                          ],
                        ),
                      ),
                    ),
                    if ((q['notes'] ?? '').toString().isNotEmpty)
                      Text(q['notes']),
                    profitCard(q),
                    OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => action(() => exportPdf(q, save: true)),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('PDFni faylga saqlash'),
                    ),
                    heading('Buyurtma bosqichi'),
                    if (s.staff.isNotEmpty)
                      GlassControl(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              s.staff.any((p) => p['id'] == q['staffId'])
                                  ? q['staffId']
                                  : null,
                          decoration: const InputDecoration(
                            labelText: 'Mas’ul xodim',
                          ),
                          items: [
                            for (final person in s.staff)
                              DropdownMenuItem<String>(
                                value: person['id'],
                                child: Text(person['name']),
                              ),
                          ],
                          onChanged: busy
                              ? null
                              : (id) => action(() => s.assignStaff(q, id)),
                        ),
                      ),
                    if (s.staff.any((p) => p['id'] == q['staffId']))
                      Builder(
                        builder: (context) {
                          final worker = s.staff.firstWhere(
                            (p) => p['id'] == q['staffId'],
                          );
                          final done = s.payroll.any(
                            (e) =>
                                e['quoteId'] == q['id'] &&
                                e['staffId'] == worker['id'] &&
                                e['kind'] == 'accrual',
                          );
                          return GlassControl(
                              child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.badge_outlined),
                            title: Text(
                              done
                                  ? 'Ish haqi yozilgan'
                                  : 'Ish haqi: ${money(Store.suggestedPay(worker, q))}',
                            ),
                            subtitle: Text(rateLabel(worker)),
                            trailing: done
                                ? const Icon(Icons.check_circle_outline)
                                : FilledButton.tonal(
                                    onPressed: () => payrollDialog(
                                      context,
                                      s,
                                      worker['id'],
                                      suggested: Store.suggestedPay(worker, q),
                                      quoteId: q['id'],
                                      note: q['title'],
                                    ),
                                    child: const Text('Yozish'),
                                  ),
                          ));
                        },
                      ),
                    if (s.staff.isEmpty)
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => StaffPage(store: s)),
                        ),
                        icon: const Icon(Icons.person_add_alt),
                        label:
                            const Text('Xodim qo‘shib, buyurtmani biriktirish'),
                      ),
                    const SizedBox(height: 12),
                    for (final payment in q['payments'] ?? [])
                      GlassControl(
                          child: ListTile(
                        title: Text(money(payment['amount'])),
                        subtitle: Text(
                          '${payment['note']} · ${payment['created']}',
                        ),
                      )),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final status in transitions[q['status']]!)
                          FilledButton.tonal(
                            onPressed: busy
                                ? null
                                : () => action(() => s.changeStatus(q, status)),
                            child: Text(statuses[status]!),
                          ),
                      ],
                    ),
                    if (s.isOwner &&
                        q['balance'] > 0 &&
                        q['status'] != 'cancelled')
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => recordPayment(q),
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('To‘lovni qayd etish'),
                        ),
                      ),
                    InstallmentCard(store: s, quote: q),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => action(() => exportPdf(q)),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        busy ? 'Bajarilmoqda…' : 'PDF ulashish / saqlash',
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          );
        },
      );
  Future<void> recordPayment(Json q) async {
    final a = TextEditingController(text: '${(q['balance'] as num).round()}'),
        n = TextEditingController();
    final form = GlobalKey<FormState>();
    final yes = await showSettledDialog<bool>(
      context: context,
      builder: (c) => GlassAlertDialog(
        title: const Text('Qabul qilingan to‘lov'),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(
                a,
                'Summa (UZS)',
                number: true,
                validate: (v) {
                  final amount = int.tryParse(v ?? '');
                  if (amount == null || amount <= 0) return 'Summani kiriting';
                  if (amount > (q['balance'] as num)) {
                    return 'Qoldiqdan (${money(q['balance'])}) oshmasin';
                  }
                  return null;
                },
              ),
              field(n, 'Izoh', validate: (_) => null),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Qayd etish'),
          ),
        ],
      ),
    );

    if (yes == true && mounted) {
      await action(() => s.payment(q, int.parse(a.text), n.text));
    }
    a.dispose();
    n.dispose();
  }

  Future<void> menu(Json q, String choice) async {
    switch (choice) {
      case 'edit':
        if (q['stockConsumed'] == true) {
          message(
            context,
            'Material ombordan chiqarilgan. Avval “Ombor / xarid ro‘yxati”dan qaytaring.',
          );
          return;
        }
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BuilderPage(store: s, editing: q),
          ),
        );
      case 'copy':
        await action(() async {
          final copy = await s.duplicateQuote(q['id']);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => QuotePage(store: s, id: copy['id']),
            ),
          );
        });
      case 'text':
        await action(() async {
          final note = await shareText(
            quoteText(s, q),
            subject: 'RomFlow • ${q['title']}',
          );
          if (note != null && mounted) message(context, note);
        });
      case 'cuts':
        await action(() async {
          final note = await shareText(
            cutListText(q),
            subject: 'Kesish ro‘yxati • ${q['title']}',
          );
          if (note != null && mounted) message(context, note);
        });
      case 'call':
        await callNumber(context, q['phone'] ?? '');
      case 'delete':
        if (await confirm(
              context,
              'Smeta o‘chirilsinmi?',
              '${q['title']} • ${money(q['total'])}. To‘lov tarixi ham o‘chadi.',
            ) &&
            mounted) {
          await action(() async {
            await s.deleteQuote(q['id']);
            if (mounted) Navigator.pop(context);
          });
        }
    }
  }

  Future<void> pickInstallDate(Json q) async {
    final now = DateTime.now();
    final current = q['installDate'] == null
        ? null
        : DateTime.parse(q['installDate']).toLocal();
    final day = await showDatePicker(
      context: context,
      initialDate: current ?? now.add(const Duration(days: 1)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        current ?? DateTime(now.year, now.month, now.day, 10),
      ),
    );
    if (!mounted) return;
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      time?.hour ?? 10,
      time?.minute ?? 0,
    );
    await action(() async {
      await s.setInstallDate(q['id'], at);
      if (at.isAfter(DateTime.now())) {
        final id = await s.saveReminder({
          'id': 'install-${q['id']}',
          'title': 'Montaj: ${q['title']}',
          'note': '${q['customer']} ${q['phone'] ?? ''} ${q['address'] ?? ''}'
              .trim(),
          'due': at.subtract(const Duration(hours: 2)).toIso8601String(),
          'done': false,
        });
        final reminder = s.reminders.firstWhere((r) => r['id'] == id);
        await ReminderScheduler.schedule(reminder);
      }
      if (mounted) {
        message(context, 'Montaj sanasi saqlandi, 2 soat oldin eslatiladi');
      }
    });
  }

  Widget profitCard(Json q) {
    final p = orderProfit(s, q);
    Widget row(String label, int value, {bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                money(value),
                style: TextStyle(
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                  color: strong && value < 0
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ],
          ),
        );
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foyda hisobi',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            row('Smeta summasi', p.total),
            row('Material tannarxi', -p.material),
            row('Ish haqi (yozilgan)', -p.labour),
            row('Qo‘shimcha xarajat', -p.extra),
            const Divider(),
            row('Sof foyda', p.profit, strong: true),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => expenseDialog(context, s, q['id']),
                icon: const Icon(Icons.add),
                label: const Text('Shu buyurtmaga xarajat'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> exportPdf(Json q, {bool save = false}) async {
    final font = pw.Font.ttf(await rootBundle.load('assets/DejaVuSans.ttf'));
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        maxPages: 200,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(s.workshopName, style: pw.TextStyle(fontSize: 20)),
                    if (s.workshopPhone.isNotEmpty) pw.Text(s.workshopPhone),
                    if (s.workshopAddress.isNotEmpty)
                      pw.Text(s.workshopAddress),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('SMETA', style: pw.TextStyle(fontSize: 20)),
                  pw.Text(
                    localDate(
                      DateTime.now().toIso8601String(),
                    ).split(' ').first,
                  ),
                  pw.Text(statuses[q['status']] ?? ''),
                ],
              ),
            ],
          ),
          pw.Divider(),
          pw.Text(q['title'], style: pw.TextStyle(fontSize: 15)),
          pw.Text('Mijoz: ${q['customer']} / ${q['phone']}'),
          if ((q['address'] ?? '').toString().isNotEmpty)
            pw.Text('Manzil: ${q['address']}'),
          if (q['installDate'] != null)
            pw.Text('Montaj: ${localDate(q['installDate'])}'),
          pw.Text(
            'TAXMINIY SMETA. Ishlab chiqarish kesish kartasi emas.',
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.SizedBox(height: 14),
          ...((q['items'] as List).expand<pw.Widget>(
            (i) => [
              pw.Text(
                '${i['label'] == null ? '' : '${i['label']} | '}${i['profileName']} | ${i['widthMm']} x ${i['heightMm']} mm | ${i['quantity']} dona',
                style: pw.TextStyle(fontSize: 13),
              ),
              if (i['drawing'] != null)
                pw.SizedBox(
                  height: 220,
                  child: pw.SvgImage(
                    svg: drawingSvg(
                      Map<String, dynamic>.from(i['drawing']),
                      Map<String, dynamic>.from(i['recipe']),
                    ),
                  ),
                ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Material', 'Miqdor', 'Narx', 'Summa'],
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {
                  1: pw.Alignment.centerRight,
                  2: pw.Alignment.centerRight,
                  3: pw.Alignment.centerRight,
                },
                data: [
                  for (final p in i['parts'] as List)
                    [
                      p['name'],
                      '${((p['charged'] ?? p['quantity']) as num).toStringAsFixed(p['unit'] == 'dona' ? 0 : 2)} ${p['unit']}',
                      money(p['price']),
                      money(p['cost']),
                    ],
                ],
              ),
              if (i['cuts'] != null) ...[
                pw.Text('Profil raskroyi (jami pozitsiya):'),
                for (final entry in (i['cuts'] as Map).entries) ...[
                  pw.Text(
                    '${materialNames[entry.key] ?? entry.key}: ${(entry.value['bars'] as List).length} tayoq, arra ${entry.value['sawMm']} mm; yaroqli qoldiq ${entry.value['reusableMm']} mm, chiqindi ${entry.value['scrapMm']} mm',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  for (final bar in entry.value['bars'] as List)
                    pw.Text(
                      '${(bar['pieces'] as List).map((v) => (v as num).round()).join(' + ')} mm | qoldiq ${(bar['remaining'] as num).toStringAsFixed(1)} mm',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                ],
                for (final entry in (i['sheetPlans'] as Map).entries)
                  pw.Text(
                    '${materialNames[entry.key]}: ${(entry.value['sheets'] as List).length} list; qoldiq ${(entry.value['offcutM2'] as num).toStringAsFixed(3)} m2',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                pw.Text(i['warning'], style: const pw.TextStyle(fontSize: 8)),
              ],
              pw.Text('Pozitsiya: ${money(i['total'])}'),
              pw.SizedBox(height: 16),
            ],
          )),
          for (final e in q['extras'] as List? ?? const [])
            pw.Text(
              '${e['name']}: ${e['qty']} ${e['unit']} x ${money(e['price'])} = ${money(extraLine(Map<String, dynamic>.from(e)))}',
            ),
          pw.Text('Montaj: ${money(q['installation'])}'),
          pw.Text('Chegirma: ${money(q['discount'])}'),
          pw.Text(
            'JAMI: ${money(q['total'])}',
            style: pw.TextStyle(fontSize: 20),
          ),
          pw.Text(
            'To‘langan: ${money(q['paid'])} / Qoldiq: ${money(q['balance'])}',
          ),
          pw.Text(q['notes'] ?? ''),
        ],
      ),
    );
    if (save) {
      await saveFileAs(
        'RomFlow-${q['id']}.pdf',
        'application/pdf',
        await doc.save(),
      );
      return;
    }
    final bytes = await doc.save();
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final note = await shareFile(
      'RomFlow-${q['id']}.pdf',
      'application/pdf',
      bytes,
      text: 'RomFlow — taxminiy smeta',
      origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
    if (note != null && mounted) message(context, note);
  }
}

Future<void> editProfile(
  BuildContext context,
  Store store, [
  Json? initial,
]) async {
  final p = {...sampleProfiles().first, ...?initial};
  if (initial == null) p.remove('id');
  final labels = <String, String>{
    'name': 'Tizim / seriya nomi',
    'brand': 'Brend',
    'framePrice': 'Rama / metr (UZS)',
    'sashPrice': 'Tabaqa / metr',
    'mullionPrice': 'Impost / metr',
    'glassPrice': 'Shisha yoki panel / m²',
    'hardwarePrice': 'Furnitura / tabaqa',
    'gasketPrice': 'Zichlagich / metr',
    'laborPrice': 'Mehnat / m²',
    'wastePct': 'Chiqindi %',
    'markupPct': 'Tannarxga ustama %',
    'frameFaceMm': 'Rama yuzi (mm)',
    'sashFaceMm': 'Tabaqa yuzi (mm)',
    'meshPrice': 'Setka / m²',
    'anthraciteFactor': 'Antratsit koeffitsiyenti',
    'oakFactor': 'Yog‘och rang koeffitsiyenti',
  };
  p.putIfAbsent('meshPrice', () => 75000);
  p.putIfAbsent('anthraciteFactor', () => 1.2);
  p.putIfAbsent('oakFactor', () => 1.3);
  final fields = {
    for (final k in labels.keys) k: TextEditingController(text: '${p[k]}'),
  };
  final form = GlobalKey<FormState>();
  bool busy = false;
  await showSettledDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => GlassAlertDialog(
        title: Text(
          initial == null ? 'Yangi profil tizimi' : 'Narxlarni tahrirlash',
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final k in labels.keys)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: WorkshopField(
                        controller: fields[k]!,
                        label: labels[k]!,
                        number: !['name', 'brand'].contains(k),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'To‘ldiring' : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.pop(c),
            child: const Text('Bekor qilish'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    set(() => busy = true);
                    try {
                      final data = <String, dynamic>{
                        ...p,
                        'demo': false,
                        'reference': false,
                      };
                      for (final k in fields.keys) {
                        data[k] = ['name', 'brand'].contains(k)
                            ? fields[k]!.text.trim()
                            : num.parse(fields[k]!.text.replaceAll(',', '.'));
                      }
                      await store.saveProfile(
                        data,
                        typed: {
                          for (final k in fields.keys)
                            if (data[k] != p[k]) k,
                        },
                      );
                      if (c.mounted) Navigator.pop(c);
                    } catch (e) {
                      if (c.mounted) {
                        message(c, e);
                        set(() => busy = false);
                      }
                    }
                  },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    ),
  );
  for (final c in fields.values) {
    c.dispose();
  }
}

class CutsPage extends StatefulWidget {
  const CutsPage({super.key});
  @override
  State<CutsPage> createState() => _CutsPageState();
}

class _CutsPageState extends State<CutsPage> {
  final stock = TextEditingController(text: '6000'),
      kerf = TextEditingController(text: '4'),
      pieces = TextEditingController(text: '1400 x 4\n1200 x 4\n800 x 2');
  Json? result;
  @override
  void dispose() {
    stock.dispose();
    kerf.dispose();
    pieces.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: GlassAppBar(title: const Text('Profil raskroyi')),
        body: readable(
          ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            children: [
              notice(
                'Har bir profil artikulini alohida hisoblang. Tayyor kesish uzunliklarini kiriting. Usul chiqindini kamaytirishga yordam beradi; matematik eng yaxshi natija kafolatlanmaydi.',
              ),
              field(stock, 'Xom profil (mm)', number: true),
              field(kerf, 'Har detal uchun arra izi (mm)', number: true),
              GlassControl(
                child: TextField(
                  controller: pieces,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    labelText: 'Uzunlik × son; har qatorda: 1400 x 4',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  try {
                    final parts = pieces.text
                        .trim()
                        .split('\n')
                        .where((line) => line.trim().isNotEmpty)
                        .map((line) {
                      final m = RegExp(
                        r'^(\d+)\s*[x×*]\s*(\d+)$',
                      ).firstMatch(line.trim());
                      if (m == null) throw Exception('Format: 1400 x 4');
                      return {
                        'lengthMm': int.parse(m[1]!),
                        'quantity': int.parse(m[2]!),
                      };
                    }).toList();
                    setState(
                      () => result = optimizeCuts(
                        int.parse(stock.text),
                        num.parse(kerf.text.replaceAll(',', '.')),
                        parts,
                      ),
                    );
                  } catch (e) {
                    message(context, e);
                  }
                },
                child: const Text('Raskroyni hisoblash'),
              ),
              if (result != null) ...[
                heading('${(result!['bars'] as List).length} dona xom profil'),
                for (final bar in result!['bars'])
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${(bar['pieces'] as List).join(' + ')} mm'),
                          Text(
                            'Qoldiq: ${bar['remainingMm']} mm',
                            style: const TextStyle(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
}

class AuditPage extends StatelessWidget {
  final Store store;
  const AuditPage({super.key, required this.store});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: GlassAppBar(title: const Text('Faoliyat tarixi')),
        body: readable(
          ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            children: [
              if (store.audit.isEmpty) const Text('Hali amallar yo‘q.'),
              for (final entry in store.audit)
                GlassCard(
                  child: GlassControl(
                      child: ListTile(
                    title: Text(entry['action']),
                    subtitle: Text(entry['created']),
                  )),
                ),
            ],
          ),
        ),
      );
}
