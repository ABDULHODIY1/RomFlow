import 'package:flutter/material.dart';
import 'calculator.dart';
import 'dialogs.dart';
import 'main.dart' show guarded, uzbekDay;
import 'store.dart';

enum InstallmentState { paid, waiting, late }

/// Each scheduled payment with its state: payments made since the plan was
/// set count against the rows in order.
List<(Json, InstallmentState)> installmentRows(Json q, {DateTime? now}) {
  final plan = q['schedule'];
  if (plan is! Map) return const [];
  var covered = (q['paid'] as num) - (plan['paidAtStart'] as num? ?? 0);
  final today = now ?? DateTime.now();
  return [
    for (final row in plan['rows'] as List)
      () {
        final amount = row['amount'] as num;
        final paid = covered >= amount;
        covered -= amount;
        return (
          Map<String, dynamic>.from(row),
          paid
              ? InstallmentState.paid
              : DateTime.parse(row['due']).isBefore(today)
                  ? InstallmentState.late
                  : InstallmentState.waiting
        );
      }()
  ];
}

class InstallmentCard extends StatelessWidget {
  final Store store;
  final Json quote;
  const InstallmentCard({super.key, required this.store, required this.quote});

  Future<void> plan(BuildContext context) async {
    var months = 3;
    var first = DateTime.now().add(const Duration(days: 30));
    final ok = await showSettledDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Bo‘lib to‘lash'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Qoldiq: ${money(quote['balance'])}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: months,
              decoration: const InputDecoration(labelText: 'Necha oyga'),
              items: [
                for (final m in [2, 3, 4, 6, 9, 12, 18, 24])
                  DropdownMenuItem(
                      value: m,
                      child: Text(
                          '$m oy • oyiga ~${money((quote['balance'] as num) / m)}')),
              ],
              onChanged: (v) => set(() => months = v!),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Birinchi to‘lov: ${uzbekDay(first)}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final d = await showDatePicker(
                    context: c,
                    initialDate: first,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 400)));
                if (d != null) set(() => first = d);
              },
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Bekor qilish')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Jadval tuzish')),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await guarded(
          context, () => store.setPaymentSchedule(quote['id'], months, first));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = installmentRows(quote), scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      if ((quote['balance'] as num) <= 0 || quote['status'] == 'cancelled') {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: OutlinedButton.icon(
          key: const ValueKey('plan-installments'),
          onPressed: () => plan(context),
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Bo‘lib to‘lash jadvali'),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.calendar_month_outlined),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Bo‘lib to‘lash • ${rows.length} oy',
                    style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
                tooltip: 'Jadvalni olib tashlash',
                onPressed: () => guarded(
                    context, () => store.clearPaymentSchedule(quote['id'])),
                icon: const Icon(Icons.delete_outline)),
          ]),
          for (final (row, state) in rows)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                  switch (state) {
                    InstallmentState.paid => Icons.check_circle,
                    InstallmentState.late => Icons.error_outline,
                    InstallmentState.waiting => Icons.schedule,
                  },
                  color: switch (state) {
                    InstallmentState.paid => const Color(0xff1f9d55),
                    InstallmentState.late => scheme.error,
                    InstallmentState.waiting => scheme.onSurfaceVariant,
                  }),
              title: Text(uzbekDay(DateTime.parse(row['due']))),
              subtitle: Text(switch (state) {
                InstallmentState.paid => 'To‘langan',
                InstallmentState.late => 'Muddati o‘tgan',
                InstallmentState.waiting => 'Kutilmoqda',
              }),
              trailing: Text(money(row['amount']),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }
}
