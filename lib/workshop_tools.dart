import 'workshop_field.dart';
import 'package:flutter/material.dart';
import 'adaptive_ui.dart';
import 'calculator.dart';
import 'store.dart';
import 'reminder_service.dart';
import 'i18n.dart';

String localDate(String raw) {
  final d = DateTime.parse(raw).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

class WorkshopTools extends StatefulWidget {
  final Store store;
  final int initialPage;
  const WorkshopTools({super.key, required this.store, this.initialPage = 0});
  @override
  State<WorkshopTools> createState() => _WorkshopToolsState();
}

class _WorkshopToolsState extends State<WorkshopTools> {
  late int page = widget.initialPage;
  String filter = 'all';
  Store get s => widget.store;
  void error(Object e) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(
          SnackBar(content: Tx('$e'.replaceFirst('Exception: ', ''))));
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: s,
        builder: (context, _) => Scaffold(
          appBar: GlassAppBar(
            title: Tx(page == 0 ? 'Qarz daftari' : 'Eslatmalar'),
          ),
          body: readable(
            SafeArea(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  GlassControl(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Tx('Qarzlar'),
                          icon: Icon(Icons.account_balance_wallet_outlined),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Tx('Eslatmalar'),
                          icon: Icon(Icons.notifications_none),
                        ),
                      ],
                      selected: {page},
                      onSelectionChanged: (v) =>
                          setState(() => page = v.single),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (page == 0) ...debts() else ...reminders(),
                ],
              ),
            ),
          ),
          floatingActionButton: GlassActionButton.extended(
            onPressed: page == 0 ? addDebt : () => editReminder(),
            icon: const Icon(Icons.add),
            label: Tx(page == 0 ? 'Qarz yozish' : 'Eslatma qo‘shish'),
          ),
        ),
      );
  List<Widget> debts() {
    int total(String kind) => s.debts
        .where((d) => d['direction'] == kind)
        .fold(0, (a, d) => a + Store.debtBalance(d));
    return [
      Row(
        children: [
          Expanded(
            child: summary(
              'Menga qarz',
              money(total('receivable')),
              Colors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: summary(
              'Men qarzman',
              money(total('payable')),
              Colors.deepOrange,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          for (final e in {
            'all': 'Barchasi',
            'receivable': 'Menga qarz',
            'payable': 'Men qarzman',
          }.entries)
            GlassControl(
              child: ChoiceChip(
                label: Tx(e.value),
                selected: filter == e.key,
                onSelected: (_) => setState(() => filter = e.key),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (s.debts.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Tx(
            'Qarz yozish orqali shaxs, summa va qaytarish muddatini kiriting.',
          ),
        ),
      for (final d in s.debts.where(
        (d) => filter == 'all' || d['direction'] == filter,
      ))
        GlassCard(
          child: GlassControl(
              child: ListTile(
            leading: Icon(
              d['direction'] == 'receivable'
                  ? Icons.south_west
                  : Icons.north_east,
              color: Store.debtBalance(d) == 0
                  ? Colors.grey
                  : Theme.of(context).colorScheme.primary,
            ),
            title: Tx(
              d['person'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Tx(
              '${d['direction'] == 'receivable' ? 'Menga qarz' : 'Men qarzman'} • ${Store.debtBalance(d) == 0 ? 'Yopilgan' : 'Qoldiq: ${money(Store.debtBalance(d))}'}${d['due'] == null ? '' : '\nMuddat: ${localDate(d['due'])}'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => debtDetails(d['id']),
          )),
        ),
      const SizedBox(height: 18),
      const Tx(
        'Buyurtmalar bo‘yicha qoldiqlar',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const Tx(
        'Smetadagi to‘lovlardan olinadi. Yuqoridagi qo‘lda yozilgan qarzlar jamiga qo‘shilmagan.',
        style: TextStyle(fontSize: 12),
      ),
      for (final q in s.quotes.where(
        (q) => q['status'] != 'cancelled' && (q['balance'] as num) > 0,
      ))
        GlassControl(
            child: ListTile(
          title: Tx(q['customer']),
          subtitle: Tx(q['title']),
          trailing: Tx(money(q['balance'])),
        )),
    ];
  }

  Widget summary(String title, String sum, Color color) => GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tx(title),
              const SizedBox(height: 8),
              Tx(
                sum,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
  List<Widget> reminders() {
    final rows = [...s.reminders]..sort((a, b) {
        if (a['done'] != b['done']) return a['done'] == true ? 1 : -1;
        return a['due'].compareTo(b['due']);
      });
    return [
      const Tx(
        'Muddatli ishlar, o‘lchov, montaj va qarz qaytarish uchun.',
        style: TextStyle(fontSize: 15),
      ),
      const SizedBox(height: 8),
      const Tx(
        'Bildirishnoma uchun tizim ruxsati kerak. Android quvvat tejash rejimida xabar kechikishi mumkin.',
        style: TextStyle(fontSize: 12, color: Colors.blueGrey),
      ),
      if (rows.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Tx('Hozircha eslatma yo‘q.'),
        ),
      for (final r in rows)
        GlassCard(
          child: GlassControl(
              child: ListTile(
            leading: GlassControl(
              child: Checkbox(
                value: r['done'],
                onChanged: (v) async {
                  try {
                    await s.completeReminder(r['id'], v!);
                    if (v) {
                      await ReminderScheduler.cancel(r['id']);
                    } else {
                      await ReminderScheduler.schedule(r);
                    }
                  } catch (e) {
                    if (mounted) error(e);
                  }
                },
              ),
            ),
            title: Tx(
              r['title'],
              style: TextStyle(
                decoration:
                    r['done'] == true ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Tx(
              '${localDate(r['due'])}${r['note'] == '' ? '' : '\n${r['note']}'}',
              style: TextStyle(
                color: r['done'] != true &&
                        DateTime.parse(r['due']).isBefore(DateTime.now())
                    ? Colors.deepOrange
                    : null,
              ),
            ),
            onTap: () => editReminder(r),
            trailing: IconButton(
              tooltip: tr('Eslatmani o‘chirish'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: context,
                  builder: (c) => GlassAlertDialog(
                    title: const Tx('Eslatma o‘chirilsinmi?'),
                    content: Tx(r['title']),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Tx('Bekor'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Tx('O‘chirish'),
                      ),
                    ],
                  ),
                );
                if (yes == true) {
                  try {
                    await s.deleteReminder(r['id']);
                    await ReminderScheduler.cancel(r['id']);
                  } catch (e) {
                    if (mounted) error(e);
                  }
                }
              },
            ),
          )),
        ),
    ];
  }

  Future<void> addDebt() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const DebtForm()),
    );
    if (result == null) return;
    try {
      await s.addDebt(result);
    } catch (e) {
      if (mounted) error(e);
    }
  }

  Future<void> debtDetails(String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DebtDetail(store: s, id: id),
      ),
    );
  }

  Future<void> editReminder([Map<String, dynamic>? r]) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => ReminderForm(initial: r)),
    );
    if (result == null) return;
    try {
      final id = await s.saveReminder(result),
          saved = s.reminders.firstWhere((r) => r['id'] == id);
      final scheduled = await ReminderScheduler.schedule(saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Tx(
              scheduled
                  ? 'Eslatma va mahalliy bildirishnoma saqlandi.'
                  : 'Eslatma saqlandi. Tizim bildirishnomasi yoqilmadi; ruxsat va muddatni tekshiring.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) error(e);
    }
  }
}

class DebtForm extends StatefulWidget {
  const DebtForm({super.key});
  @override
  State<DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<DebtForm> {
  final form = GlobalKey<FormState>(),
      person = TextEditingController(),
      amount = TextEditingController(),
      phone = TextEditingController(),
      note = TextEditingController();
  String direction = 'receivable';
  DateTime? due;
  @override
  void dispose() {
    for (final c in [person, amount, phone, note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: GlassAppBar(title: const Tx('Qarz yozish')),
        body: readable(
          SafeArea(
            child: Form(
              key: form,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  GlassControl(
                    child: DropdownButtonFormField<String>(
                      initialValue: direction,
                      decoration: InputDecoration(
                        labelText: tr('Qarz yo‘nalishi'),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'receivable',
                          child: Tx('Menga qarz'),
                        ),
                        DropdownMenuItem(
                          value: 'payable',
                          child: Tx('Men qarzman'),
                        ),
                      ],
                      onChanged: (v) => direction = v!,
                    ),
                  ),
                  const SizedBox(height: 14),
                  input(person, 'Shaxs / tashkilot', required: true),
                  input(phone, 'Telefon'),
                  input(amount, 'Summa (so‘m)', number: true, required: true),
                  input(note, 'Izoh'),
                  GlassControl(
                      child: ListTile(
                    title: const Tx('Qaytarish muddati'),
                    subtitle: Tx(
                      due == null
                          ? 'Belgilanmagan'
                          : localDate(due!.toIso8601String()),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: c,
                        initialDate: due ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) {
                        setState(
                            () => due = DateTime(d.year, d.month, d.day, 18));
                      }
                    },
                  )),
                  FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(c, {
                          'person': person.text.trim(),
                          'phone': phone.text.trim(),
                          'amount': int.parse(amount.text),
                          'direction': direction,
                          'note': note.text.trim(),
                          'due': due?.toIso8601String(),
                        });
                      }
                    },
                    child: const Tx('Qarzni saqlash'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

Widget input(
  TextEditingController controller,
  String title, {
  bool number = false,
  bool required = false,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: WorkshopField(
        controller: controller,
        label: title,
        number: number,
        decimal: false,
        keyboardType: title.toLowerCase().contains('telefon')
            ? TextInputType.phone
            : null,
        validator: (v) {
          if (required && (v ?? '').trim().isEmpty) return 'To‘ldiring';
          if (number) {
            final n = int.tryParse(v ?? '');
            if (n == null || n <= 0 || n > 1000000000000) {
              return 'Musbat butun summa kiriting';
            }
          }
          return null;
        },
      ),
    );

class DebtDetail extends StatelessWidget {
  final Store store;
  final String id;
  const DebtDetail({super.key, required this.store, required this.id});
  @override
  Widget build(BuildContext c) => AnimatedBuilder(
        animation: store,
        builder: (c, _) {
          final d = store.debts.firstWhere((d) => d['id'] == id),
              balance = Store.debtBalance(d);
          return Scaffold(
            appBar: GlassAppBar(title: Tx(d['person'])),
            body: readable(
              SafeArea(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Tx(
                      money(balance),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Tx(
                      '${d['direction'] == 'receivable' ? 'Menga qarz' : 'Men qarzman'} • qoldiq',
                    ),
                    const SizedBox(height: 18),
                    Tx(
                      'Boshlang‘ich: ${money(d['amount'])}\nTo‘langan: ${money(Store.debtPaid(d))}\n${d['phone']}\n${d['note']}${d['due'] == null ? '' : '\nMuddat: ${localDate(d['due'])}'}',
                    ),
                    const SizedBox(height: 20),
                    if (balance > 0)
                      FilledButton.icon(
                        icon: const Icon(Icons.payments_outlined),
                        label: const Tx('To‘lov yozish'),
                        onPressed: () async {
                          final result =
                              await Navigator.push<Map<String, dynamic>>(
                            c,
                            MaterialPageRoute(
                              builder: (_) => PaymentForm(maximum: balance),
                            ),
                          );
                          if (result != null) {
                            try {
                              await store.debtPayment(
                                id,
                                result['amount'],
                                result['note'],
                              );
                            } catch (e) {
                              if (c.mounted) {
                                ScaffoldMessenger.of(
                                  c,
                                ).showSnackBar(SnackBar(content: Tx('$e')));
                              }
                            }
                          }
                        },
                      ),
                    const SizedBox(height: 20),
                    const Tx(
                      'To‘lovlar tarixi',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    for (final p in (d['payments'] as List).reversed)
                      GlassControl(
                          child: ListTile(
                        title: Tx(money(p['amount'])),
                        subtitle:
                            Tx('${localDate(p['created'])}\n${p['note']}'),
                      )),
                  ],
                ),
              ),
            ),
          );
        },
      );
}

class PaymentForm extends StatefulWidget {
  final int maximum;
  const PaymentForm({super.key, required this.maximum});
  @override
  State<PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<PaymentForm> {
  final form = GlobalKey<FormState>(),
      amount = TextEditingController(),
      note = TextEditingController();
  String? error;
  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: GlassAppBar(title: const Tx('Qarz to‘lovi')),
        body: readable(
          Form(
            key: form,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                Tx('Qoldiq: ${money(widget.maximum)}'),
                const SizedBox(height: 16),
                input(amount, 'To‘lov (so‘m)', number: true, required: true),
                input(note, 'To‘lov izohi'),
                if (error != null)
                  Tx(error!, style: const TextStyle(color: Colors.red)),
                FilledButton(
                  onPressed: () {
                    if (!form.currentState!.validate()) return;
                    final n = int.parse(amount.text);
                    if (n > widget.maximum) {
                      setState(() => error = 'Qoldiqdan oshmasin');
                      return;
                    }
                    Navigator.pop(c, {'amount': n, 'note': note.text.trim()});
                  },
                  child: const Tx('To‘lovni saqlash'),
                ),
              ],
            ),
          ),
        ),
      );
}

class ReminderForm extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const ReminderForm({super.key, this.initial});
  @override
  State<ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<ReminderForm> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, note;
  late DateTime due;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.initial?['title'] ?? '');
    note = TextEditingController(text: widget.initial?['note'] ?? '');
    due = widget.initial == null
        ? DateTime.now().add(const Duration(hours: 1))
        : DateTime.parse(widget.initial!['due']).toLocal();
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: GlassAppBar(title: const Tx('Eslatma')),
        body: readable(
          SafeArea(
            child: Form(
              key: form,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16),
                children: [
                  input(title, 'Eslatma nomi', required: true),
                  input(note, 'Izoh'),
                  GlassControl(
                      child: ListTile(
                    title: Tx(localDate(due.toIso8601String())),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: c,
                        initialDate: due,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d == null || !c.mounted) return;
                      final t = await showTimePicker(
                        context: c,
                        initialTime: TimeOfDay.fromDateTime(due),
                      );
                      if (t != null) {
                        setState(
                          () => due = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          ),
                        );
                      }
                    },
                  )),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(c, {
                          'id': widget.initial?['id'],
                          'title': title.text.trim(),
                          'note': note.text.trim(),
                          'due': due.toIso8601String(),
                          'done': widget.initial?['done'] ?? false,
                        });
                      }
                    },
                    child: const Tx('Eslatmani saqlash'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
