import 'package:flutter/material.dart';
import 'adaptive_ui.dart';
import 'calculator.dart';
import 'dialogs.dart';
import 'store.dart';
import 'workshop_field.dart';
import 'i18n.dart';

String _day(String raw) {
  final d = DateTime.parse(raw).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year}';
}

String rateLabel(Map<String, dynamic> worker) {
  final rate = (worker['rate'] as num?) ?? 0;
  return switch (worker['payType']) {
    'percent' => '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)}% buyurtmadan',
    'perM2' => '${money(rate)} / m²',
    'piece' => '${money(rate)} / konstruksiya',
    'daily' => '${money(rate)} / kun',
    'monthly' => '${money(rate)} / oy',
    _ => 'Stavka kiritilmagan',
  };
}

/// Workers, how they are paid and what is owed to each of them.
class StaffPage extends StatelessWidget {
  final Store store;
  const StaffPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final owed = store.staff.fold<int>(
            0,
            (sum, w) => sum + store.staffBalance(w['id']),
          );
          return Scaffold(
            appBar: GlassAppBar(title: const Tx('Xodimlar va ish haqi')),
            floatingActionButton: GlassActionButton.extended(
              onPressed: () => editWorker(context, store),
              icon: const Icon(Icons.person_add_alt),
              label: const Tx('Xodim'),
            ),
            body: readable(
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                children: [
                  GlassCard(
                    child: GlassControl(
                        child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: const Tx('Xodimlarga berilishi kerak'),
                      subtitle: const Tx(
                        'Hisoblangan ish haqi va bonus − avans, to‘lov va jarima',
                      ),
                      trailing: Tx(
                        money(owed),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 8),
                  if (store.staff.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Tx(
                        'Xodim qo‘shing: ism, vazifa va ish haqi turi (oylik, kunlik, m², buyurtmadan % yoki dona).',
                      ),
                    ),
                  for (final w in store.staff)
                    GlassCard(
                      child: GlassControl(
                          child: ListTile(
                        leading: CircleAvatar(
                          child: Tx(
                            (w['name'] as String).isEmpty
                                ? '?'
                                : (w['name'] as String)[0].toUpperCase(),
                          ),
                        ),
                        title: Tx(w['name']),
                        subtitle: Tx(
                          '${(w['role'] ?? '').toString().isEmpty ? 'Vazifa yo‘q' : w['role']} • ${rateLabel(w)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Tx(
                              money(store.staffBalance(w['id'])),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            Tx(
                              'qoldiq',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StaffDetailPage(store: store, staffId: w['id']),
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

Future<void> editWorker(
  BuildContext context,
  Store store, [
  Map<String, dynamic>? worker,
]) async {
  final name = TextEditingController(text: worker?['name'] ?? ''),
      phone = TextEditingController(text: worker?['phone'] ?? ''),
      role = TextEditingController(text: worker?['role'] ?? ''),
      rate = TextEditingController(
        text: ((worker?['rate'] as num?) ?? 0).toString().replaceAll(
              RegExp(r'\.0$'),
              '',
            ),
      ),
      notes = TextEditingController(text: worker?['notes'] ?? '');
  String payType = worker?['payType'] ?? 'perM2';
  final form = GlobalKey<FormState>();
  await showSettledDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => GlassAlertDialog(
        title: Tx(worker == null ? 'Yangi xodim' : 'Xodimni tahrirlash'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WorkshopField(
                  controller: name,
                  label: 'Ism',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Ismni kiriting' : null,
                ),
                const SizedBox(height: 12),
                WorkshopField(
                  controller: phone,
                  label: 'Telefon',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                WorkshopField(
                  controller: role,
                  label: 'Vazifa (usta, montajchi…)',
                ),
                const SizedBox(height: 12),
                GlassControl(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: payType,
                    decoration: InputDecoration(
                      labelText: tr('Ish haqi turi'),
                    ),
                    items: [
                      for (final e in Store.payTypes.entries)
                        DropdownMenuItem(value: e.key, child: Tx(e.value)),
                    ],
                    onChanged: (v) => set(() => payType = v!),
                  ),
                ),
                const SizedBox(height: 12),
                WorkshopField(
                  controller: rate,
                  label: payType == 'percent' ? 'Foiz (%)' : 'Stavka (so‘m)',
                  number: true,
                  validator: (v) {
                    final n = num.tryParse(v ?? '');
                    if (n == null || n < 0) return 'Stavkani kiriting';
                    if (payType == 'percent' && n > 100) return '0–100%';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                WorkshopField(
                  controller: notes,
                  label: 'Izoh',
                  action: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (worker != null)
            TextButton(
              onPressed: () async {
                try {
                  await store.deleteStaff(worker['id']);
                  if (c.mounted) Navigator.pop(c);
                  if (context.mounted) Navigator.maybePop(context);
                } catch (e) {
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(
                        content: Tx('$e'.replaceFirst('Exception: ', '')),
                      ),
                    );
                  }
                }
              },
              child: const Tx('O‘chirish'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Tx('Bekor'),
          ),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              await store.saveStaff({
                ...?worker,
                'name': name.text.trim(),
                'phone': phone.text.trim(),
                'role': role.text.trim(),
                'notes': notes.text.trim(),
                'payType': payType,
                'rate': num.parse(rate.text),
              });
              if (c.mounted) Navigator.pop(c);
            },
            child: const Tx('Saqlash'),
          ),
        ],
      ),
    ),
  );
  for (final t in [name, phone, role, rate, notes]) {
    t.dispose();
  }
}

/// Records salary accruals, advances and payments for one worker.
Future<void> payrollDialog(
  BuildContext context,
  Store store,
  String staffId, {
  String kind = 'accrual',
  int? suggested,
  String? quoteId,
  String? note,
}) async {
  final amount = TextEditingController(
        text: suggested == null || suggested <= 0 ? '' : '$suggested',
      ),
      comment = TextEditingController(text: note ?? '');
  final form = GlobalKey<FormState>();
  var chosen = kind;
  final ok = await showSettledDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => GlassAlertDialog(
        title: const Tx('Ish haqi yozuvi'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassControl(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: chosen,
                    decoration: InputDecoration(labelText: tr('Turi')),
                    items: [
                      for (final e in Store.payKinds.entries)
                        DropdownMenuItem(value: e.key, child: Tx(e.value)),
                    ],
                    onChanged: (v) => set(() => chosen = v!),
                  ),
                ),
                const SizedBox(height: 12),
                WorkshopField(
                  controller: amount,
                  label: 'Summa (so‘m)',
                  number: true,
                  decimal: false,
                  helperText: suggested != null && suggested > 0
                      ? 'Stavka bo‘yicha: ${money(suggested)}'
                      : null,
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                      ? 'Summani kiriting'
                      : null,
                ),
                const SizedBox(height: 12),
                WorkshopField(
                  controller: comment,
                  label: 'Izoh',
                  action: TextInputAction.done,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Tx('Bekor'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Tx('Yozish'),
          ),
        ],
      ),
    ),
  );
  if (ok == true) {
    try {
      await store.addPayroll({
        'staffId': staffId,
        'kind': chosen,
        'amount': int.parse(amount.text),
        'note': comment.text.trim(),
        if (quoteId != null) 'quoteId': quoteId,
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Tx('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }
  amount.dispose();
  comment.dispose();
}

class StaffDetailPage extends StatelessWidget {
  final Store store;
  final String staffId;
  const StaffDetailPage({
    super.key,
    required this.store,
    required this.staffId,
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final found = store.staff.where((w) => w['id'] == staffId);
          if (found.isEmpty) {
            return Scaffold(
              appBar: GlassAppBar(),
              body: const Center(child: Tx('Xodim topilmadi')),
            );
          }
          final w = found.first;
          final rows = store.payroll.where((e) => e['staffId'] == staffId);
          int total(Set<String> kinds) => rows
              .where((e) => kinds.contains(e['kind']))
              .fold(0, (sum, e) => sum + (e['amount'] as int));
          final orders =
              store.quotes.where((q) => q['staffId'] == staffId).toList();
          return Scaffold(
            appBar: GlassAppBar(
              title: Tx(w['name']),
              actions: [
                IconButton(
                  tooltip: tr('Tahrirlash'),
                  onPressed: () => editWorker(context, store, w),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            body: readable(
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                children: [
                  Tx(
                    '${(w['role'] ?? '').toString().isEmpty ? 'Xodim' : w['role']} • ${rateLabel(w)}${(w['phone'] ?? '').toString().isEmpty ? '' : ' • ${w['phone']}'}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tx(
                            'Berilishi kerak',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Tx(
                            money(store.staffBalance(staffId)),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Tx(
                            'Hisoblangan: ${money(total({
                                  'accrual'
                                }))} • bonus ${money(total({
                                  'bonus'
                                }))}\nAvans: ${money(total({
                                  'advance'
                                }))} • to‘langan ${money(total({
                                  'payment'
                                }))} • jarima ${money(total({'penalty'}))}',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => payrollDialog(
                          context,
                          store,
                          staffId,
                          kind: 'accrual',
                          suggested: (w['payType'] == 'monthly' ||
                                  w['payType'] == 'daily')
                              ? ((w['rate'] as num?) ?? 0).round()
                              : null,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Tx('Ish haqi yozish'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => payrollDialog(context, store, staffId,
                            kind: 'advance'),
                        icon: const Icon(Icons.north_east),
                        label: const Tx('Avans'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => payrollDialog(
                          context,
                          store,
                          staffId,
                          kind: 'payment',
                          suggested: store.staffBalance(staffId),
                        ),
                        icon: const Icon(Icons.payments_outlined),
                        label: const Tx('To‘lash'),
                      ),
                    ],
                  ),
                  if (orders.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Tx(
                      'Biriktirilgan buyurtmalar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final q in orders)
                      GlassControl(
                          child: ListTile(
                        dense: true,
                        title: Tx(q['title']),
                        subtitle: Tx(
                          '${statuses[q['status']]} • stavka bo‘yicha ${money(Store.suggestedPay(w, q))}',
                        ),
                        trailing: store.payroll.any(
                          (e) =>
                              e['quoteId'] == q['id'] &&
                              e['staffId'] == staffId &&
                              e['kind'] == 'accrual',
                        )
                            ? const Icon(Icons.check_circle_outline)
                            : TextButton(
                                onPressed: () => payrollDialog(
                                  context,
                                  store,
                                  staffId,
                                  suggested: Store.suggestedPay(w, q),
                                  quoteId: q['id'],
                                  note: q['title'],
                                ),
                                child: const Tx('Yozish'),
                              ),
                      )),
                  ],
                  const SizedBox(height: 18),
                  Tx('Tarix', style: Theme.of(context).textTheme.titleMedium),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Tx('Hali yozuv yo‘q.'),
                    ),
                  for (final e in rows)
                    GlassCard(
                      child: GlassControl(
                          child: ListTile(
                        leading: Icon(
                          const {'accrual', 'bonus'}.contains(e['kind'])
                              ? Icons.add_circle_outline
                              : Icons.remove_circle_outline,
                        ),
                        title: Tx(Store.payKinds[e['kind']]!),
                        subtitle: Tx(
                          [
                            _day(e['created']),
                            if ((e['note'] ?? '').toString().isNotEmpty)
                              e['note'],
                          ].join(' • '),
                        ),
                        trailing: Tx(
                          '${const {
                            'accrual',
                            'bonus'
                          }.contains(e['kind']) ? '+' : '−'}${money(e['amount'])}',
                        ),
                        onLongPress: () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (c) => GlassAlertDialog(
                              title: const Tx('Yozuv o‘chirilsinmi?'),
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
                          if (yes == true) await store.deletePayroll(e['id']);
                        },
                      )),
                    ),
                ],
              ),
            ),
          );
        },
      );
}
