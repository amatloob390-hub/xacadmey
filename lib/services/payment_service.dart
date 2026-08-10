import 'package:supabase_flutter/supabase_flutter.dart';

class PendingPayment {
  final String paymentId, studentName, classTitle, method, txnReference;
  final String? receiptUrl;
  final num amount;
  final DateTime createdAt;

  PendingPayment.fromMap(Map<String, dynamic> m)
      : paymentId = m['payment_id'] ?? m['id'] ?? '',
        studentName = m['student_name'] ?? 'اسٹوڈنٹ',
        classTitle = m['class_title'] ?? 'کلاس',
        method = m['method'] ?? 'JazzCash',
        txnReference = m['txn_reference'] ?? '',
        receiptUrl = m['receipt_url'] ?? m['receipt_image'],
        amount = m['amount'] ?? 0,
        createdAt = DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now();
}

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// اسٹوڈنٹ: ادائیگی کا دعویٰ جمع کرائے
  Future<void> submitPayment({
    required String classId,
    required double amount,
    required String method,
    required String txnReference,
    String? receiptImage,
  }) async {
    final studentId = _supabase.auth.currentUser!.id;
    final Map<String, dynamic> payload = {
      'student_id': studentId,
      'class_id': classId,
      'amount': amount,
      'method': method,
      'txn_reference': txnReference,
      'status': 'pending',
    };

    if (receiptImage != null && receiptImage.isNotEmpty) {
      payload['receipt_url'] = receiptImage;
    }

    await _supabase.from('payments').insert(payload);
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

    // 2. Fallback: Direct Table Query on payments
    try {
      final rows = await _supabase
          .from('payments')
          .select(
              'id, amount, method, txn_reference, receipt_url, created_at, status, profiles(full_name), classes(title)')
          .or('status.eq.pending,status.is.null')
          .order('created_at', ascending: true);

      if ((rows as List).isNotEmpty) {
        return (rows).map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final profile = m['profiles'] as Map<String, dynamic>?;
          final cls = m['classes'] as Map<String, dynamic>?;
          return PendingPayment.fromMap({
            'payment_id': m['id'],
            'student_name': profile?['full_name'] ?? 'اسٹوڈنٹ',
            'class_title': cls?['title'] ?? 'کلاس',
            'method': m['method'] ?? 'JazzCash',
            'txn_reference': m['txn_reference'] ?? 'TXN-12345',
            'receipt_url': m['receipt_url'],
            'amount': m['amount'] ?? 1500,
            'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }).toList();
      }
    } catch (_) {}

    // 3. Fallback 2: Check pending enrollments if no payment record exists yet
    try {
      final rows = await _supabase.rpc('get_pending_students') as List?;
      if (rows != null && rows.isNotEmpty) {
        return rows.map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          return PendingPayment.fromMap({
            'payment_id': 'enrollment_${m['student_id']}_${m['class_id']}',
            'student_name': m['student_name'] ?? 'اسٹوڈنٹ',
            'class_title': m['class_title'] ?? 'کلاس',
            'method': 'JazzCash / EasyPaisa',
            'txn_reference': 'درخواست جمع ہو گئی',
            'amount': 1500,
            'created_at': DateTime.now().toIso8601String(),
          });
        }).toList();
      }
    } catch (_) {}

    return [];
  }

  Future<void> approve(String paymentId) =>
      _supabase.rpc('approve_payment', params: {'p_payment_id': paymentId});

  Future<void> reject(String paymentId) =>
      _supabase.rpc('reject_payment', params: {'p_payment_id': paymentId});
}
