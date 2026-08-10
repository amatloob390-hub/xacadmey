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
      'status': 'pending',
    });
  }

  Future<List<PendingPayment>> getPending() async {
    // 1. Primary: RPC Call
    try {
      final rows = await _supabase.rpc('get_pending_payments') as List?;
      if (rows != null && rows.isNotEmpty) {
        return rows
            .map((r) => PendingPayment.fromMap(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // 2. Fallback: Direct Table Query
    try {
      final rows = await _supabase
          .from('payments')
          .select(
              'id, amount, method, txn_reference, created_at, status, profiles(full_name), classes(title)')
          .or('status.eq.pending,status.is.null')
          .order('created_at', ascending: true);

      return (rows as List).map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        final profile = m['profiles'] as Map<String, dynamic>?;
        final cls = m['classes'] as Map<String, dynamic>?;
        return PendingPayment.fromMap({
          'payment_id': m['id'],
          'student_name': profile?['full_name'] ?? 'اسٹوڈنٹ',
          'class_title': cls?['title'] ?? 'کلاس',
          'method': m['method'] ?? '',
          'txn_reference': m['txn_reference'] ?? '',
          'amount': m['amount'] ?? 0,
          'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> approve(String paymentId) =>
      _supabase.rpc('approve_payment', params: {'p_payment_id': paymentId});

  Future<void> reject(String paymentId) =>
      _supabase.rpc('reject_payment', params: {'p_payment_id': paymentId});
}
