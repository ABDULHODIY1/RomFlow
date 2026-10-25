import 'package:flutter/material.dart';
import 'calculator.dart';
import 'dialogs.dart';
import 'main.dart'
    show BuilderPage, callNumber, confirm, guarded, message, uzbekDay;
import 'store.dart';
import 'adaptive_ui.dart';

String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String sizesSummary(List sizes) => sizes.isEmpty
    ? 'O‘lcham yozilmagan'
    : '${sizes.fold<int>(0, (n, s) => n + (s['quantity'] as int))} dona: ${sizes.take(3).map((s) => '${s['widthMm']}×${s['heightMm']}').join(', ')}${sizes.length > 3 ? '…' : ''}';

/// Measuring visits ("razmer"): planned with a reminder, measured on site,
/// then turned into an estimate with every opening already filled in.
class MeasurementsPage extends StatelessWidget {
  final Store store;
  const MeasurementsPage({super.key, required this.store});

  Future<void> toQuote(BuildContext context, Json m) async {
    await guarded(context, () async {
      var customerId = m['customerId'] as String?;
      if (customerId == null ||
          !store.customers.any((c) => c['id'] == customerId)) {
        customerId = newId();
        await store.addCustomer({
          'id': customerId,
          'name': m['customer'],
          'phone': m['phone'] ?? '',
          'address': m['address'] ?? '',
        });
      }
      if (m['status'] == 'planned') {
        await store.setMeasurementStatus(m['id'], 'done');
      }
      if (!context.mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BuilderPage(
                      store: store,
                      initialCustomer: customerId,
                      initialTitle: 'Razmer: ${m['customer']}',
                      initialNotes: m['note'],
                      initialItems: [
                        for (final s in m['sizes'] as List)
                          {
                            'profileId': store.profiles.first['id'],
                            'template': s['template'] ?? 'double',
                            'widthMm': s['widthMm'],
                            'heightMm': s['heightMm'],
                            'quantity': s['quantity'],
                            'color': 'white',
                            'mosquito': false,
                          }
                      ])));
    });
  }

  Widget card(BuildContext context, Json m) {
    final at = DateTime.parse(m['date']).toLocal(),
        scheme = Theme.of(context).colorScheme,
        planned = m['status'] == 'planned',
        late = planned && at.isBefore(DateTime.now());
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    MeasurementEditor(store: store, measurement: m))),
        onLongPress: () async {
          if (await confirm(context, 'Razmer o‘chirilsinmi?',
              '${m['customer']} • ${uzbekDay(at)}')) {
            await store.deleteMeasurement(m['id']);
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.event,
                  size: 18, color: late ? scheme.error : scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('${uzbekDay(at)} • ${_time(at)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: late ? scheme.error : null)),
              ),
              Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(Store.measurementStatuses[m['status']]!)),
            ]),
            const SizedBox(height: 4),
            Text(m['customer'], style: Theme.of(context).textTheme.titleMedium),
            if ('${m['address'] ?? ''}'.isNotEmpty)
              Text(m['address'], style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(sizesSummary(m['sizes'] as List),
                style: Theme.of(context).textTheme.bodySmall),
            Wrap(spacing: 4, children: [
              if ('${m['phone'] ?? ''}'.isNotEmpty)
                TextButton.icon(
                    onPressed: () => callNumber(context, m['phone']),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Qo‘ng‘iroq')),
              if (planned)
                TextButton.icon(
                    onPressed: () => guarded(context,
                        () => store.setMeasurementStatus(m['id'], 'done')),
                    icon: const Icon(Icons.check),
                    label: const Text('O‘lchandi')),
              TextButton.icon(
                  key: ValueKey('to-quote-${m['id']}'),
                  onPressed: (m['sizes'] as List).isEmpty
                      ? null
                      : () => toQuote(context, m),
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Smetaga')),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final planned = store.measurements
                  .where((m) => m['status'] == 'planned')
                  .toList(),
              past = store.measurements
                  .where((m) => m['status'] != 'planned')
                  .toList()
                  .reversed
                  .toList();
          return Scaffold(
            appBar: GlassAppBar(title: const Text('Razmer — o‘lchash')),
            floatingActionButton: FloatingActionButton.extended(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MeasurementEditor(store: store))),
                icon: const Icon(Icons.add),
                label: const Text('Razmer')),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      Text(
                          'Mijozning uyiga borib o‘lchash rejasi. Bir soat oldin eslatma keladi; o‘lchamlarni yozib, bitta tugma bilan smetaga aylantiring.',
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      Text('Rejada (${planned.length})',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      if (planned.isEmpty)
                        Text('Rejalashtirilgan razmer yo‘q.',
                            style: Theme.of(context).textTheme.bodySmall),
                      for (final m in planned) card(context, m),
                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text('Tarix',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        for (final m in past) card(context, m),
                      ],
                    ]),
              ),
            ),
          );
        },
      );
}

class MeasurementEditor extends StatefulWidget {
  final Store store;
  final Json? measurement;
  const MeasurementEditor({super.key, required this.store, this.measurement});
  @override
  State<MeasurementEditor> createState() => _MeasurementEditorState();
}

class _SizeRow {
  final width = TextEditingController(),
      height = TextEditingController(),
      quantity = TextEditingController(text: '1'),
      note = TextEditingController();
  String template = 'double';
  void dispose() {
    for (final c in [width, height, quantity, note]) {
      c.dispose();
    }
  }
}

class _MeasurementEditorState extends State<MeasurementEditor> {
  final customer = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      note = TextEditingController();
  final rows = <_SizeRow>[];
  String? customerId;
  late DateTime date;
  Store get s => widget.store;

  @override
  void initState() {
    super.initState();
    final m = widget.measurement;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    date = m == null
        ? DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10)
        : DateTime.parse(m['date']).toLocal();
    customerId = m?['customerId'];
    customer.text = m?['customer'] ?? '';
    phone.text = m?['phone'] ?? '';
    address.text = m?['address'] ?? '';
    note.text = m?['note'] ?? '';
    for (final size in (m?['sizes'] as List? ?? const [])) {
      rows.add(_SizeRow()
        ..template = size['template'] ?? 'double'
        ..width.text = '${size['widthMm']}'
        ..height.text = '${size['heightMm']}'
        ..quantity.text = '${size['quantity']}'
        ..note.text = size['note'] ?? '');
    }
    if (rows.isEmpty) rows.add(_SizeRow());
  }

  @override
  void dispose() {
    for (final c in [customer, phone, address, note]) {
      c.dispose();
    }
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate() async {
    final day = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 730)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(date));
    setState(() => date = DateTime(day.year, day.month, day.day,
        time?.hour ?? date.hour, time?.minute ?? date.minute));
  }

  Future<void> save() async {
    await guarded(context, () async {
      final sizes = <Json>[];
      for (final r in rows) {
        if (r.width.text.trim().isEmpty && r.height.text.trim().isEmpty) {
          continue;
        }
        final w = int.tryParse(r.width.text.trim()),
            h = int.tryParse(r.height.text.trim()),
            q = int.tryParse(r.quantity.text.trim());
        if (w == null || h == null || q == null) {
          throw Exception('Eni, bo‘yi va sonini raqam bilan kiriting');
        }
        sizes.add({
          'template': r.template,
          'widthMm': w,
          'heightMm': h,
          'quantity': q,
          if (r.note.text.trim().isNotEmpty) 'note': r.note.text.trim(),
        });
      }
      await s.saveMeasurement({
        ...?widget.measurement,
        'customerId': customerId,
        'customer': customer.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'date': date.toIso8601String(),
        'note': note.text.trim(),
        'sizes': sizes,
      });
      if (mounted) {
        message(context, 'Razmer saqlandi');
        Navigator.pop(context);
      }
    });
  }

  Future<void> chooseCustomer() async {
    final picked = await showSettledDialog<Json>(
        context: context,
        builder: (c) => SimpleDialog(title: const Text('Mijoz'), children: [
              for (final x in s.customers)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, x),
                    child: Text('${x['name']}  ${x['phone'] ?? ''}')),
            ]));
    if (picked == null) return;
    setState(() {
      customerId = picked['id'];
      customer.text = picked['name'];
      phone.text = picked['phone'] ?? '';
      address.text = picked['address'] ?? '';
    });
  }

  Widget sizeRow(int i) {
    final r = rows[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: r.template,
                isExpanded: true,
                decoration: InputDecoration(labelText: '${i + 1}. Turi'),
                items: [
                  for (final t in templates)
                    DropdownMenuItem(
                        value: t['id'] as String,
                        child:
                            Text(t['name'], overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => r.template = v!),
              ),
            ),
            IconButton(
                tooltip: 'Olib tashlash',
                onPressed: rows.length == 1
                    ? null
                    : () => setState(() => rows.removeAt(i).dispose()),
                icon: const Icon(Icons.delete_outline)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            for (final (c, label) in [
              (r.width, 'Eni, mm'),
              (r.height, 'Bo‘yi, mm'),
              (r.quantity, 'Soni'),
            ]) ...[
              Expanded(
                child: TextField(
                    key: ValueKey('size-$i-$label'),
                    controller: c,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: label)),
              ),
              const SizedBox(width: 8),
            ],
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 8),
            child: TextField(
                controller: r.note,
                decoration: const InputDecoration(
                    labelText: 'Izoh (xona, qavat, ochilishi…)')),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: GlassAppBar(
            title:
                Text(widget.measurement == null ? 'Yangi razmer' : 'Razmer')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.icon(
                key: const ValueKey('save-measurement'),
                onPressed: save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Saqlash')),
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Expanded(
                  child: TextField(
                      key: const ValueKey('measurement-customer'),
                      controller: customer,
                      onChanged: (_) => customerId = null,
                      decoration: const InputDecoration(labelText: 'Mijoz')),
                ),
                if (s.customers.isNotEmpty)
                  IconButton(
                      tooltip: 'Mijozlardan tanlash',
                      onPressed: chooseCustomer,
                      icon: const Icon(Icons.contacts_outlined)),
              ]),
              const SizedBox(height: 12),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telefon')),
              const SizedBox(height: 12),
              TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Manzil')),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text('${uzbekDay(date)} • ${_time(date)}'),
                subtitle: const Text('Bir soat oldin eslatma'),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: pickDate,
              ),
              const SizedBox(height: 8),
              Text('O‘lchamlar', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (var i = 0; i < rows.length; i++) sizeRow(i),
              OutlinedButton.icon(
                  onPressed: () => setState(() => rows.add(_SizeRow())),
                  icon: const Icon(Icons.add),
                  label: const Text('O‘lcham qo‘shish')),
              const SizedBox(height: 12),
              TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Umumiy izoh')),
            ]),
          ),
        ),
      );
}
