import 'dart:io';
import 'package:flutter/material.dart';
import 'calculator.dart' show Json;
import 'store.dart';

/// Tariffs and payments. The paid plans and payment methods are in place,
/// but charging is switched off: while [BillingConfig.paymentsEnabled] is
/// false every workshop has the full Pro plan free. Turning it on needs a
/// merchant contract with the payment providers and a server that confirms
/// each payment; the app alone cannot verify one.
class BillingConfig {
  static bool paymentsEnabled = false;
}

class Plan {
  final String id, name, tagline;

  /// Monthly price in so‘m; null while it is not announced yet.
  final int? monthlyUzs;
  final List<String> features;
  const Plan(this.id, this.name, this.tagline, this.monthlyUzs, this.features);
}

const plans = <Plan>[
  Plan('start', 'Start', 'Yakka usta uchun', 0, [
    'Smeta, rom chizish va 3D',
    'PDF, matn va kesish ro‘yxatini ulashish',
    'Mijozlar, buyurtmalar va to‘lovlar',
  ]),
  Plan('pro', 'Pro', 'Ustaxona uchun', null, [
    'Start’dagi hamma narsa',
    'Moliya, statistika va ish haqi',
    'Narxlarni internetdagi manbadan yangilash',
    'Ombor, raskroy va eslatmalar',
  ]),
  Plan('business', 'Biznes', 'Bir nechta filial va xodimlar', null, [
    'Pro’dagi hamma narsa',
    'Bir nechta qurilmada ishlash (tez orada)',
    'Bulutli zaxira (tez orada)',
  ]),
];

/// Features that the Start plan does not include.
const proFeatures = {'finance', 'payroll', 'priceSources', 'warehouse'};

class PaymentMethod {
  final String id, name;
  final IconData icon;
  const PaymentMethod(this.id, this.name, this.icon);
}

const paymentMethods = <PaymentMethod>[
  PaymentMethod('click', 'Click', Icons.touch_app_outlined),
  PaymentMethod('payme', 'Payme', Icons.account_balance_wallet_outlined),
  PaymentMethod('uzum', 'Uzum Bank', Icons.account_balance_outlined),
  PaymentMethod('card', 'Uzcard / Humo / Visa', Icons.credit_card),
];

Plan planById(String? id) =>
    plans.firstWhere((p) => p.id == id, orElse: () => plans[1]);

/// A new workshop starts on Pro during the free period.
Json defaultSubscription() => {
      'plan': 'pro',
      'status': 'promo',
      'since': DateTime.now().toIso8601String(),
      'payments': <Json>[],
    };

extension Billing on Store {
  /// The plan whose features are open now.
  Plan get activePlan {
    if (!BillingConfig.paymentsEnabled) return planById('pro');
    final paidUntil = DateTime.tryParse(subscription['paidUntil'] ?? '');
    final paid = paidUntil != null && paidUntil.isAfter(DateTime.now());
    return paid ? planById(subscription['plan']) : planById('start');
  }

  bool allows(String feature) =>
      !proFeatures.contains(feature) || activePlan.id != 'start';
}

/// Opens [page] if the plan includes [feature], otherwise the tariffs.
Future<void> openWithPlan(
    BuildContext context, Store store, String feature, Widget Function() page) {
  final target = store.allows(feature) ? page() : TariffPage(store: store);
  return Navigator.push(context, MaterialPageRoute(builder: (_) => target));
}

String planPrice(Plan p) => p.monthlyUzs == null
    ? 'Narxi keyinroq e’lon qilinadi'
    : p.monthlyUzs == 0
        ? 'Bepul'
        : '${p.monthlyUzs} so‘m / oy';

class TariffPage extends StatelessWidget {
  final Store store;
  const TariffPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme,
        current = store.activePlan,
        free = !BillingConfig.paymentsEnabled,
        apple = Platform.isIOS || Platform.isMacOS;
    return Scaffold(
      appBar: AppBar(title: const Text('Tarif va to‘lov')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                    colors: [Color(0xff1659b8), Color(0xff2f86ea)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.workspace_premium,
                          color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      Text(current.name,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 10),
                      if (free)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: const Color(0xff4cc36b),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text('Hozircha bepul',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                        free
                            ? 'Barcha imkoniyatlar ochiq. To‘lov tizimi tayyor, lekin hozircha pul olinmaydi — tariflar ishga tushishidan oldin xabar beramiz.'
                            : current.tagline,
                        style: const TextStyle(
                            color: Colors.white, height: 1.4, fontSize: 14)),
                  ]),
            ),
            const SizedBox(height: 18),
            Text('Tariflar', style: text.titleLarge),
            const SizedBox(height: 10),
            for (final p in plans)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(p.name,
                                  style: text.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800))),
                          if (p.id == current.id)
                            Chip(
                                label: const Text('Joriy'),
                                avatar: Icon(Icons.check_circle,
                                    size: 18, color: scheme.primary)),
                        ]),
                        Text(p.tagline, style: text.bodySmall),
                        const SizedBox(height: 8),
                        for (final f in p.features)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check,
                                      size: 18, color: scheme.primary),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(f)),
                                ]),
                          ),
                        const SizedBox(height: 8),
                        Text(planPrice(p),
                            style: text.titleSmall
                                ?.copyWith(color: scheme.primary)),
                      ]),
                ),
              ),
            const SizedBox(height: 8),
            Text('To‘lov usullari', style: text.titleLarge),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final m in paymentMethods)
                Container(
                  width: 168,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.outlineVariant)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(m.icon, color: scheme.primary),
                        const SizedBox(height: 8),
                        Text(m.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                            BillingConfig.paymentsEnabled
                                ? 'Mavjud'
                                : 'Tez orada',
                            style: text.bodySmall),
                      ]),
                ),
            ]),
            const SizedBox(height: 14),
            Text(
                apple
                    ? 'App Store orqali o‘rnatilgan iPhone, iPad va Mac versiyalarida obuna Apple orqali to‘lanadi.'
                    : 'To‘lovlar Click, Payme, Uzum Bank yoki bank kartasi orqali qabul qilinadi.',
                style: text.bodySmall),
            const SizedBox(height: 18),
            Text('To‘lovlar tarixi', style: text.titleLarge),
            const SizedBox(height: 6),
            if ((store.subscription['payments'] as List? ?? const []).isEmpty)
              Text('Hali to‘lov yo‘q.', style: text.bodySmall)
            else
              for (final p in store.subscription['payments'] as List)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_outlined),
                    title: Text('${p['plan']} • ${p['amount']} so‘m'),
                    subtitle: Text('${p['date']} • ${p['method']}')),
          ]),
        ),
      ),
    );
  }
}
