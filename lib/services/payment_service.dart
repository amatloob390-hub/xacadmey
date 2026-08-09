import 'package:supabase_flutter/supabase_flutter.dart';

class PendingPayment {
  final String paymentId, studentName, classTitle, method, txnReference;
  final num amount;
  final DateTime createdAt;

  PendingPayment.fromMap(Map<String, dynamic> m)
      : paymentId = m['payment_id'],
        studentName = m['student_name'],
        classTitle = m['class_title'],
        method = m['method'],
        txnReference = m['txn_reference'],
        amount = m['amount'],
        createdAt = DateTime.parse(m['created_at']);
}

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// اسٹوڈنٹ: ادائیگی کا دعویٰ جمع کرائے
  Future<void> submitPayment({
    required String classId,
    required double amount,
    required String method,
    required String txnReference,
  }) async {
    final studentId = _supabase.auth.currentUser!.id;
    await _supabase.from('payments').insert({
      'student_id': studentId,
      'class_id': classId,
      'amount': amount,
      'method': method,
      'txn_reference': txnReference,
    });
  }

  Future<List<PendingPayment>> getPending() async {
    final rows = await _supabase.rpc('get_pending_payments') as List;
    return rows
        .map((r) => PendingPayment.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> approve(String paymentId) =>
      _supabase.rpc('approve_payment', params: {'p_payment_id': paymentId});

  Future<void> reject(String paymentId) =>
      _supabase.rpc('reject_payment', params: {'p_payment_id': paymentId});
}
