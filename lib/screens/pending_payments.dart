import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/payment_service.dart';

class PendingPayments extends StatefulWidget {
  const PendingPayments({super.key});

  @override
  State<PendingPayments> createState() => _PendingPaymentsState();
}

class _PendingPaymentsState extends State<PendingPayments> {
  final PaymentService _service = PaymentService();
  late Future<List<PendingPayment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getPending();
  }

  void _refresh() => setState(() => _future = _service.getPending());

  Future<void> _act(String id, bool approve) async {
    approve ? await _service.approve(id) : await _service.reject(id);
    if (mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve
              ? L.t('ادائیگی منظور ہو گئی ✅', 'Payment approved ✅')
              : L.t('ادائیگی رد ہو گئی', 'Payment rejected'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('زیرِ التوا ادائیگیاں', 'Pending Payments'))),
      body: FutureBuilder<List<PendingPayment>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
                child: Text(L.t('کوئی زیرِ التوا ادائیگی نہیں۔', 'No pending payments.')));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.studentName} — ${p.classTitle}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                          '${L.t('رقم', 'Amount')}: ${p.amount} ${L.t('روپے', 'Rs')}  •  ${L.t('طریقہ', 'Method')}: ${p.method}'),
                      Text('${L.t('ٹرانزیکشن آئی ڈی', 'Transaction ID')}: ${p.txnReference}'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => _act(p.paymentId, false),
                              child: Text(L.t('رد', 'Reject'),
                                  style: const TextStyle(color: Colors.red))),
                          const SizedBox(width: 8),
                          ElevatedButton(
                              onPressed: () => _act(p.paymentId, true),
                              child: Text(L.t('منظور', 'Approve'))),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
