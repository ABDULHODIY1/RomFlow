import 'workshop_field.dart';
import 'package:flutter/material.dart';
import 'adaptive_ui.dart';
import 'package:flutter/services.dart';
import 'calculator.dart';
import 'design_engine.dart';
import 'store.dart';

String materialUnit(String k) => k == 'desiccant'
    ? 'kg'
    : linearStock.contains(k) || meterMaterials.contains(k)
        ? 'm'
        : areaMaterials.contains(k)
            ? 'm²'
            : 'dona';

class WarehousePage extends StatelessWidget {
  final Store store;
  final List? items;
  final String? quoteId;
  const WarehousePage({
    super.key,
    required this.store,
    this.items,
    this.quoteId,
  });
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          List<Map<String, dynamic>> needs = [];
          String? warning;
          if (items != null) {
            try {
              needs = store.stockNeeds(items!);
            } catch (e) {
              warning = '$e';
            }
          }
          return Scaffold(
            appBar: GlassAppBar(
              title:
                  Text(items == null ? 'Ombor' : 'Material yetishmovchiligi'),
              actions: [
                if (items != null)
                  IconButton(
                    tooltip: 'Xarid ro‘yxatini nusxalash',
                    icon: const Icon(Icons.copy),
                    onPressed: () async {
                      final text = needs
                          .where((r) => (r['missing'] as num) > 0)
                          .map(
                            (r) =>
                                '${r['profileName']} • ${r['name']}: ${(r['missing'] as num).toStringAsFixed(3)} ${r['unit']}',
                          )
                          .join('\n');
                      await Clipboard.setData(
                        ClipboardData(
                          text: text.isEmpty ? 'Materiallar yetarli' : text,
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Xarid ro‘yxati nusxalandi'),
                          ),
                        );
                      }
                    },
                  ),
              ],
            ),
            body: readable(
              SafeArea(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    const Text(
                      'Profil tizimi va material turi bo‘yicha alohida qoldiq. Miqdorlar metr, m², kg yoki dona bilan kiritiladi. Tayoq uzunligi va list joylashuvini raskroyda tekshiring.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    if (warning != null)
                      Text(
                        warning,
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    if (items != null) ...[
                      Text(
                        'Yetishmayotgan material xaridi: ${money(needs.fold<num>(0, (a, r) => a + (r['purchaseCost'] as num)))}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Narxi 0 bo‘lgan materiallar summaga qo‘shilmaydi. Smeta summasi ombor narxi bilan almashtirilmaydi.',
                        style: TextStyle(fontSize: 12),
                      ),
                      for (final n in needs)
                        GlassCard(
                          child: GlassControl(
                              child: ListTile(
                            title: Text(n['name']),
                            subtitle: Text(
                              '${n['profileName']}\nKerak: ${(n['required'] as num).toStringAsFixed(3)} ${n['unit']} • Bor: ${(n['available'] as num).toStringAsFixed(3)}',
                            ),
                            trailing: SizedBox(
                              width: 94,
                              child: Text(
                                (n['missing'] as num) > .000001
                                    ? 'Kam: ${(n['missing'] as num).toStringAsFixed(3)} ${n['unit']}'
                                    : 'Yetarli',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: (n['missing'] as num) > .000001
                                      ? Colors.deepOrange
                                      : Colors.teal,
                                ),
                              ),
                            ),
                            onTap: () => editStock(context, n),
                          )),
                        ),
                      if (quoteId != null)
                        FilledButton.icon(
                          onPressed: () async {
                            final q = store.quotes.firstWhere(
                                  (q) => q['id'] == quoteId,
                                ),
                                consume = q['stockConsumed'] != true;
                            final yes = await showDialog<bool>(
                              context: context,
                              builder: (c) => GlassAlertDialog(
                                title: Text(
                                  consume
                                      ? 'Ombordan chiqarish'
                                      : 'Materialni qaytarish',
                                ),
                                content: Text(
                                  consume
                                      ? 'Smetadagi xarid miqdorlari ombor qoldig‘idan ayriladi. Bu amalni keyin qaytarish mumkin.'
                                      : 'Aynan shu buyurtmaga chiqarilgan miqdorlar omborga qaytariladi.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Bekor'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Tasdiqlash'),
                                  ),
                                ],
                              ),
                            );
                            if (yes == true) {
                              try {
                                await store.applyQuoteStock(quoteId!, consume);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.inventory),
                          label: Text(
                            store.quotes.firstWhere(
                                      (q) => q['id'] == quoteId,
                                    )['stockConsumed'] ==
                                    true
                                ? 'Omborga qaytarish'
                                : 'Buyurtmaga ombordan chiqarish',
                          ),
                        ),
                      const Divider(height: 30),
                    ],
                    const Text(
                      'Ombor qoldiqlari',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    if (store.inventory.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Material qo‘shish tugmasidan boshlang.'),
                      ),
                    for (final row in store.inventory)
                      GlassCard(
                        child: GlassControl(
                            child: ListTile(
                          title: Text(materialNames[row['key']] ?? row['key']),
                          subtitle: Text(
                            '${store.profiles.firstWhere((p) => p['id'] == row['profileId'], orElse: () => {
                                  'name': row['profileId']
                                })['name']}\n${row['quantity']} ${row['unit']} • ${money(row['price'])} / ${row['unit']}',
                          ),
                          trailing: Icon(
                            (row['quantity'] as num) < (row['minimum'] as num)
                                ? Icons.warning_amber
                                : Icons.edit_outlined,
                            color: (row['quantity'] as num) <
                                    (row['minimum'] as num)
                                ? Colors.deepOrange
                                : null,
                          ),
                          onTap: () => editStock(context, row),
                        )),
                      ),
                  ],
                ),
              ),
            ),
            floatingActionButton: GlassActionButton.extended(
              onPressed: () => editStock(context),
              icon: const Icon(Icons.add),
              label: const Text('Material qo‘shish'),
            ),
          );
        },
      );
  Future<void> editStock(
    BuildContext context, [
    Map<String, dynamic>? source,
  ]) async {
    final existing = source == null
        ? null
        : store.inventory.where((r) => r['id'] == source['id']);
    final initial =
        existing != null && existing.isNotEmpty ? existing.first : source;
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => StockForm(store: store, initial: initial),
      ),
    );
    if (result == null) return;
    try {
      await store.saveStock(result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class StockForm extends StatefulWidget {
  final Store store;
  final Map<String, dynamic>? initial;
  const StockForm({super.key, required this.store, this.initial});
  @override
  State<StockForm> createState() => _StockFormState();
}

class _StockFormState extends State<StockForm> {
  final form = GlobalKey<FormState>();
  late String profile, key;
  late TextEditingController qty, price, minimum;
  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    profile = i?['profileId'] ?? widget.store.profiles.first['id'];
    key = i?['key'] ?? 'frame';
    qty = TextEditingController(
      text: '${i?['quantity'] ?? i?['available'] ?? 0}',
    );
    price = TextEditingController(text: '${i?['price'] ?? 0}');
    minimum = TextEditingController(text: '${i?['minimum'] ?? 0}');
  }

  @override
  void dispose() {
    qty.dispose();
    price.dispose();
    minimum.dispose();
    super.dispose();
  }

  Widget number(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: WorkshopField(
          controller: c,
          label: label,
          number: true,
          validator: (v) {
            final n = double.tryParse((v ?? '').replaceAll(',', '.'));
            return n == null || !n.isFinite || n < 0 || n > 1e12
                ? 'Musbat yoki 0 miqdor kiriting'
                : null;
          },
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: GlassAppBar(title: const Text('Material qoldig‘i')),
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
                      initialValue: profile,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Profil tizimi'),
                      items: [
                        for (final p in widget.store.profiles)
                          DropdownMenuItem(
                              value: p['id'], child: Text(p['name'])),
                      ],
                      onChanged: (v) => setState(() => profile = v!),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GlassControl(
                    child: DropdownButtonFormField<String>(
                      initialValue: key,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Material'),
                      items: [
                        for (final e in materialNames.entries)
                          if (!const {'labor', 'bending'}.contains(e.key))
                            DropdownMenuItem(
                                value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => key = v!),
                    ),
                  ),
                  const SizedBox(height: 14),
                  number(qty, 'Qoldiq (${materialUnit(key)})'),
                  number(price, 'Ombor narxi (so‘m / ${materialUnit(key)})'),
                  number(
                      minimum, 'Kam qoldiq chegarasi (${materialUnit(key)})'),
                  FilledButton(
                    onPressed: () {
                      if (!form.currentState!.validate()) return;
                      double n(TextEditingController c) =>
                          double.parse(c.text.replaceAll(',', '.'));
                      Navigator.pop(context, {
                        'profileId': profile,
                        'key': key,
                        'unit': materialUnit(key),
                        'quantity': n(qty),
                        'price': n(price),
                        'minimum': n(minimum),
                      });
                    },
                    child: const Text('Qoldiqni saqlash'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
