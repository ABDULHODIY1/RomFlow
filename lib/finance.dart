import 'package:flutter/material.dart';
import 'adaptive_ui.dart';
import 'calculator.dart';
import 'dialogs.dart';
import 'store.dart';
import 'workshop_field.dart';

/// Income, expenses, salaries and profit, plus order statistics. Everything is
/// computed from local records; nothing is sent anywhere.
class FinancePage extends StatefulWidget {
  final Store store;
  final int initialTab;
  const FinancePage({super.key, required this.store, this.initialTab = 0});
  @override
  State<FinancePage> createState() => _FinancePageState();
}

enum Period { month, lastMonth, quarter, year, all }

const periodNames = {
  Period.month: 'Bu oy',
  Period.lastMonth: 'O‘tgan oy',
  Period.quarter: '3 oy',
  Period.year: 'Bu yil',
  Period.all: 'Hammasi',
};

(DateTime, DateTime) periodRange(Period p, DateTime now) {
  final month = DateTime(now.year, now.month);
  return switch (p) {
    Period.month => (month, DateTime(now.year, now.month + 1)),
    Period.lastMonth => (DateTime(now.year, now.month - 1), month),
    Period.quarter => (
        DateTime(now.year, now.month - 2),
        DateTime(now.year, now.month + 1)
      ),
    Period.year => (DateTime(now.year), DateTime(now.year + 1)),
    Period.all => (DateTime(2000), DateTime(now.year + 100)),
  };
}

bool _within(String? iso, (DateTime, DateTime) range) {
  final at = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  return at != null && !at.isBefore(range.$1) && at.isBefore(range.$2);
}

/// Money movements of one period.
class FinanceSummary {
  final int income, expenses, salaries, accrued;
  FinanceSummary(this.income, this.expenses, this.salaries, this.accrued);
  int get profit => income - expenses - salaries;

  factory FinanceSummary.of(Store s, (DateTime, DateTime) range) {
    var income = 0, expenses = 0, salaries = 0, accrued = 0;
    for (final q in s.quotes) {
      for (final p in (q['payments'] as List? ?? [])) {
        if (_within(p['created'], range)) {
          income += (p['amount'] as num).toInt();
        }
      }
    }
    for (final e in s.expenses) {
      if (_within(e['created'], range)) expenses += e['amount'] as int;
    }
    for (final e in s.payroll) {
      if (!_within(e['created'], range)) continue;
      if (e['kind'] == 'advance' || e['kind'] == 'payment') {
        salaries += e['amount'] as int;
      } else if (e['kind'] == 'accrual' || e['kind'] == 'bonus') {
        accrued += e['amount'] as int;
      }
    }
    return FinanceSummary(income, expenses, salaries, accrued);
  }
}

/// Profit of one order: total minus material cost, salaries written for it
/// and expenses linked to it.
({int total, int material, int labour, int extra, int profit}) orderProfit(
    Store s, Map<String, dynamic> q) {
  final total = (q['total'] as num).round();
  final material = (q['items'] as List)
      .fold<num>(0, (sum, i) => sum + ((i['cost'] as num?) ?? 0))
      .round();
  final labour = s.payroll
      .where((e) => e['quoteId'] == q['id'] && e['kind'] == 'accrual')
      .fold<int>(0, (sum, e) => sum + (e['amount'] as int));
  final extra = s.expenses
      .where((e) => e['quoteId'] == q['id'])
      .fold<int>(0, (sum, e) => sum + (e['amount'] as int));
  return (
    total: total,
    material: material,
    labour: labour,
    extra: extra,
    profit: total - material - labour - extra
  );
}

const _monthNames = [
  'Yan',
  'Fev',
  'Mar',
  'Apr',
  'May',
  'Iyn',
  'Iyl',
  'Avg',
  'Sen',
  'Okt',
  'Noy',
  'Dek'
];

List<DateTime> lastMonths(DateTime now, int count) =>
    [for (var k = count - 1; k >= 0; k--) DateTime(now.year, now.month - k)];

class _FinancePageState extends State<FinancePage> {
  Period period = Period.month;
  Store get s => widget.store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: s,
      builder: (context, _) => DefaultTabController(
          length: 2,
          initialIndex: widget.initialTab,
          child: Scaffold(
            appBar: AppBar(
                title: const Text('Moliya va statistika'),
                bottom: const TabBar(tabs: [
                  Tab(text: 'Moliya'),
                  Tab(text: 'Statistika'),
                ])),
            floatingActionButton: Builder(
                builder: (context) => FloatingActionButton.extended(
                    onPressed: () => addExpense(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Xarajat'))),
            body: readable(TabBarView(children: [finance(), statistics()])),
          )));

  Widget periods() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final p in Period.values)
          Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                  label: Text(periodNames[p]!),
                  selected: period == p,
                  onSelected: (_) => setState(() => period = p))),
      ]));

  Widget finance() {
    final now = DateTime.now(), range = periodRange(period, now);
    final sum = FinanceSummary.of(s, range);
    final months = lastMonths(now, 6);
    final orders = [
      for (final q in s.quotes)
        if (q['status'] != 'cancelled' && _within(q['created'], range)) q
    ];
    final ranked = [for (final q in orders) (q, orderProfit(s, q))]
      ..sort((a, b) => b.$2.profit.compareTo(a.$2.profit));
    final expenses = [
      for (final e in s.expenses)
        if (_within(e['created'], range)) e
    ];
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          periods(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Kpi('Tushum', money(sum.income), Icons.south_west,
                    hint: 'Mijozlardan olingan to‘lovlar')),
            const SizedBox(width: 10),
            Expanded(
                child: Kpi('Xarajat', money(sum.expenses), Icons.north_east,
                    hint: 'Yozilgan xarajatlar')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: Kpi(
                    'Ish haqi', money(sum.salaries), Icons.badge_outlined,
                    hint: 'Avans va to‘lovlar')),
            const SizedBox(width: 10),
            Expanded(
                child: Kpi('Sof foyda', money(sum.profit),
                    Icons.account_balance_wallet_outlined,
                    hint: 'Tushum − xarajat − ish haqi', emphasis: true)),
          ]),
          const SizedBox(height: 18),
          BarChart(
            title: 'Tushum va xarajat • oxirgi 6 oy',
            labels: [for (final m in months) _monthNames[m.month - 1]],
            series: [
              ChartSeries('Tushum', 0, [
                for (final m in months)
                  FinanceSummary.of(s, (m, DateTime(m.year, m.month + 1)))
                      .income
                      .toDouble()
              ]),
              ChartSeries('Xarajat + ish haqi', 1, [
                for (final m in months)
                  () {
                    final f = FinanceSummary.of(
                        s, (m, DateTime(m.year, m.month + 1)));
                    return (f.expenses + f.salaries).toDouble();
                  }()
              ]),
            ],
            format: (v) => money(v),
          ),
          const SizedBox(height: 18),
          Text('Buyurtmalar foydasi',
              style: Theme.of(context).textTheme.titleMedium),
          Text(
              'Smeta summasi − material tannarxi − shu buyurtmaga yozilgan ish haqi va xarajat.',
              style: Theme.of(context).textTheme.bodySmall),
          if (ranked.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Bu davrda buyurtma yo‘q.')),
          for (final (q, p) in ranked.take(8))
            Card(
                child: ListTile(
                    title: Text(q['title'], overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        '${q['customer']} • ${money(p.total)}\nMaterial ${money(p.material)} • ish haqi ${money(p.labour)} • xarajat ${money(p.extra)}'),
                    isThreeLine: true,
                    trailing: Text(money(p.profit),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.profit < 0
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.onSurface)))),
          const SizedBox(height: 18),
          Text('Xarajatlar', style: Theme.of(context).textTheme.titleMedium),
          if (expenses.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    '“Xarajat” tugmasi bilan ijara, transport, material va boshqa xarajatlarni yozing.')),
          for (final e in expenses)
            Card(
                child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(Store.expenseCategories[e['category']]!),
                    subtitle: Text([
                      _date(e['created']),
                      if ((e['note'] ?? '').toString().isNotEmpty) e['note'],
                      if (e['quoteId'] != null)
                        s.quotes
                                .where((q) => q['id'] == e['quoteId'])
                                .map((q) => q['title'])
                                .firstOrNull ??
                            ''
                    ].join(' • ')),
                    trailing: Text(money(e['amount'])),
                    onLongPress: () => deleteExpense(e))),
        ]);
  }

  Widget statistics() {
    final now = DateTime.now(), range = periodRange(period, now);
    final quotes = [
      for (final q in s.quotes)
        if (_within(q['created'], range)) q
    ];
    final live = quotes.where((q) => q['status'] != 'cancelled').toList();
    final value = live.fold<num>(0, (a, q) => a + (q['total'] as num));
    final m2 = live.fold<double>(
        0,
        (a, q) =>
            a +
            (q['items'] as List).fold<double>(
                0,
                (b, i) =>
                    b +
                    ((i['areaM2'] as num?) ?? 0) *
                        ((i['quantity'] as num?) ?? 1)));
    final pieces = live.fold<num>(
        0,
        (a, q) =>
            a +
            (q['items'] as List)
                .fold<num>(0, (b, i) => b + ((i['quantity'] as num?) ?? 1)));
    final won = live.where((q) => q['status'] != 'draft').length;
    final byStatus = <String, int>{
      for (final k in statuses.keys)
        k: quotes.where((q) => q['status'] == k).length
    };
    final customers = <String, num>{};
    for (final q in live) {
      customers[q['customer'] as String] =
          (customers[q['customer']] ?? 0) + (q['total'] as num);
    }
    final top = customers.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final months = lastMonths(now, 6);
    return ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          periods(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Kpi('Buyurtmalar', '${live.length}',
                    Icons.receipt_long_outlined,
                    hint: '$won tasdiqlangan')),
            const SizedBox(width: 10),
            Expanded(
                child: Kpi(
                    'O‘rtacha chek',
                    money(live.isEmpty ? 0 : value / live.length),
                    Icons.calculate_outlined)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: Kpi('Konstruksiya', '${pieces.round()} dona',
                    Icons.window_outlined,
                    hint: '${m2.toStringAsFixed(1)} m²')),
            const SizedBox(width: 10),
            Expanded(
                child: Kpi(
                    'Konversiya',
                    '${live.isEmpty ? 0 : (won * 100 / live.length).round()}%',
                    Icons.trending_up,
                    hint: 'Smetadan buyurtmaga')),
          ]),
          const SizedBox(height: 18),
          BarChart(
            title: 'Yangi buyurtmalar soni • oxirgi 6 oy',
            labels: [for (final m in months) _monthNames[m.month - 1]],
            series: [
              ChartSeries('Buyurtmalar', 0, [
                for (final m in months)
                  s.quotes
                      .where((q) => _within(
                          q['created'], (m, DateTime(m.year, m.month + 1))))
                      .length
                      .toDouble()
              ]),
            ],
            format: (v) => '${v.round()} ta',
          ),
          const SizedBox(height: 18),
          Text('Bosqichlar bo‘yicha',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final e in byStatus.entries)
            StatusBar(
                label: statuses[e.key]!,
                count: e.value,
                max: byStatus.values.fold(1, (a, b) => a > b ? a : b)),
          const SizedBox(height: 18),
          Text('Eng yirik mijozlar',
              style: Theme.of(context).textTheme.titleMedium),
          if (top.isEmpty)
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Bu davrda buyurtma yo‘q.')),
          for (final (i, e) in top.take(5).indexed)
            ListTile(
                dense: true,
                leading: CircleAvatar(radius: 13, child: Text('${i + 1}')),
                title: Text(e.key),
                trailing: Text(money(e.value))),
        ]);
  }

  String _date(String raw) {
    final d = DateTime.parse(raw).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  Future<void> deleteExpense(Map<String, dynamic> e) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Xarajat o‘chirilsinmi?'),
                content: Text(
                    '${Store.expenseCategories[e['category']]} • ${money(e['amount'])}'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Bekor')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('O‘chirish')),
                ]));
    if (yes == true) await s.deleteExpense(e['id']);
  }

  Future<void> addExpense(BuildContext context) =>
      expenseDialog(context, s, null);
}

/// Shared "add expense" dialog; [quoteId] links it to an order.
Future<void> expenseDialog(
    BuildContext context, Store s, String? quoteId) async {
  final amount = TextEditingController(), note = TextEditingController();
  final form = GlobalKey<FormState>();
  String category = 'material';
  // Settled: the controllers are disposed only after the dialog is gone.
  final saved = await showSettledDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
          builder: (c, set) => AlertDialog(
                  title: const Text('Xarajat yozish'),
                  content: SingleChildScrollView(
                      child: Form(
                          key: form,
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: category,
                                decoration:
                                    const InputDecoration(labelText: 'Turi'),
                                items: [
                                  for (final e
                                      in Store.expenseCategories.entries)
                                    DropdownMenuItem(
                                        value: e.key, child: Text(e.value)),
                                ],
                                onChanged: (v) => set(() => category = v!)),
                            const SizedBox(height: 12),
                            WorkshopField(
                                controller: amount,
                                label: 'Summa (so‘m)',
                                number: true,
                                decimal: false,
                                validator: (v) =>
                                    (int.tryParse(v ?? '') ?? 0) <= 0
                                        ? 'Summani kiriting'
                                        : null),
                            const SizedBox(height: 12),
                            WorkshopField(
                                controller: note,
                                label: 'Izoh',
                                action: TextInputAction.done),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Bekor')),
                    FilledButton(
                        onPressed: () {
                          if (form.currentState!.validate()) {
                            Navigator.pop(c, true);
                          }
                        },
                        child: const Text('Saqlash')),
                  ])));
  if (saved == true) {
    try {
      await s.addExpense({
        'category': category,
        'amount': int.parse(amount.text),
        'note': note.text.trim(),
        if (quoteId != null) 'quoteId': quoteId,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))));
      }
    }
  }
  amount.dispose();
  note.dispose();
}

/// Accent colours for dashboard tiles: blue, green, orange, violet, teal
/// and rose, stepped for each theme.
Color toneColor(int tone, Brightness brightness) {
  const light = [
    Color(0xff2a78d6),
    Color(0xff1f9d55),
    Color(0xffdf7a1f),
    Color(0xff7c5ce0),
    Color(0xff13919f),
    Color(0xffd64d6f),
  ];
  const dark = [
    Color(0xff5ea2f0),
    Color(0xff4cc380),
    Color(0xfff2a15a),
    Color(0xffa58df0),
    Color(0xff45c1cd),
    Color(0xfff07c97),
  ];
  return (brightness == Brightness.dark ? dark : light)[tone % light.length];
}

class Kpi extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final String? hint;
  final bool emphasis;
  final int tone;
  const Kpi(this.label, this.value, this.icon,
      {super.key, this.hint, this.emphasis = false, this.tone = 0});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        accent = toneColor(tone, Theme.of(context).brightness);
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: accent.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 17, color: accent),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(label,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall)),
              ]),
              const SizedBox(height: 10),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: emphasis ? accent : scheme.onSurface))),
              if (hint != null)
                Text(hint!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontSize: 11)),
            ])));
  }
}

/// Categorical slots 1 and 2 of the reference palette, stepped per theme.
Color seriesColor(int slot, Brightness brightness) =>
    brightness == Brightness.dark
        ? const [Color(0xff3987e5), Color(0xffd95926)][slot]
        : const [Color(0xff2a78d6), Color(0xffeb6834)][slot];

class ChartSeries {
  final String name;
  final int slot;
  final List<double> values;
  const ChartSeries(this.name, this.slot, this.values);
}

/// Grouped column chart: one shared axis, thin bars, a legend for two or
/// more series and the selected month's exact values under the plot.
class BarChart extends StatefulWidget {
  final String title;
  final List<String> labels;
  final List<ChartSeries> series;
  final String Function(double) format;
  const BarChart(
      {super.key,
      required this.title,
      required this.labels,
      required this.series,
      required this.format});
  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  late int selected = widget.labels.length - 1;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    return Card(
        margin: EdgeInsets.zero,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.title, style: theme.textTheme.titleSmall),
              if (widget.series.length > 1)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(spacing: 14, children: [
                      for (final s in widget.series)
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  color: seriesColor(s.slot, theme.brightness),
                                  borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 5),
                          Text(s.name, style: theme.textTheme.bodySmall),
                        ]),
                    ])),
              const SizedBox(height: 10),
              SizedBox(
                  height: 150,
                  child: LayoutBuilder(
                      builder: (context, box) => GestureDetector(
                          onTapDown: (d) => setState(() => selected =
                              (d.localPosition.dx /
                                      (box.maxWidth / widget.labels.length))
                                  .floor()
                                  .clamp(0, widget.labels.length - 1)),
                          child: CustomPaint(
                              size: Size(box.maxWidth, 150),
                              painter: _BarsPainter(
                                  widget.labels,
                                  widget.series,
                                  selected,
                                  theme.brightness,
                                  scheme.outlineVariant,
                                  scheme.onSurfaceVariant,
                                  scheme.surfaceContainerHighest))))),
              const SizedBox(height: 8),
              Text(
                  '${widget.labels[selected]}: ${[
                    for (final s in widget.series)
                      '${widget.series.length > 1 ? '${s.name} ' : ''}${widget.format(s.values[selected])}'
                  ].join(' • ')}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ])));
  }
}

class _BarsPainter extends CustomPainter {
  final List<String> labels;
  final List<ChartSeries> series;
  final int selected;
  final Brightness brightness;
  final Color grid, text, highlight;
  _BarsPainter(this.labels, this.series, this.selected, this.brightness,
      this.grid, this.text, this.highlight);
  @override
  void paint(Canvas canvas, Size size) {
    const labelSpace = 18.0;
    final plot = size.height - labelSpace;
    final maxValue =
        series.expand((s) => s.values).fold<double>(0, (a, b) => a > b ? a : b);
    final band = size.width / labels.length;
    canvas.drawRect(Rect.fromLTWH(band * selected, 0, band, plot),
        Paint()..color = highlight.withValues(alpha: .55));
    canvas.drawLine(
        Offset(0, plot),
        Offset(size.width, plot),
        Paint()
          ..color = grid
          ..strokeWidth = 1);
    final gap = 2.0,
        width = ((band * .62 - gap * (series.length - 1)) / series.length)
            .clamp(4.0, 24.0);
    for (var i = 0; i < labels.length; i++) {
      final groupWidth = width * series.length + gap * (series.length - 1);
      var x = band * i + (band - groupWidth) / 2;
      for (final s in series) {
        final v = s.values[i];
        final h = maxValue <= 0 ? 0.0 : (v / maxValue) * (plot - 8);
        if (h > 0) {
          final r = h < 4 ? h : 4.0;
          canvas.drawRRect(
              RRect.fromRectAndCorners(Rect.fromLTWH(x, plot - h, width, h),
                  topLeft: Radius.circular(r), topRight: Radius.circular(r)),
              Paint()..color = seriesColor(s.slot, brightness));
        }
        x += width + gap;
      }
      final label = TextPainter(
          text: TextSpan(
              text: labels[i],
              style: TextStyle(
                  fontSize: 10,
                  color: text,
                  fontWeight:
                      i == selected ? FontWeight.w700 : FontWeight.w400)),
          textDirection: TextDirection.ltr)
        ..layout();
      label.paint(
          canvas, Offset(band * i + (band - label.width) / 2, plot + 4));
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}

class StatusBar extends StatelessWidget {
  final String label;
  final int count, max;
  const StatusBar(
      {super.key, required this.label, required this.count, required this.max});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall)),
          Expanded(
              child: LayoutBuilder(
                  builder: (context, box) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                          height: 12,
                          width: count == 0
                              ? 0
                              : (box.maxWidth * count / max)
                                  .clamp(4.0, box.maxWidth),
                          decoration: BoxDecoration(
                              color: seriesColor(0, theme.brightness),
                              borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(4))))))),
          SizedBox(
              width: 36,
              child: Text('$count',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600))),
        ]));
  }
}
