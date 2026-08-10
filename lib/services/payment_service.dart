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
        txnReference = _parseTxn(m['txn_reference']),
        receiptUrl = m['receipt_url'] ?? m['receipt_image'] ?? _parseReceipt(m['txn_reference']),
        amount = m['amount'] ?? 0,
        createdAt = DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now();

  static String _parseTxn(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString();
    if (s.contains('||RECEIPT:')) {
      return s.split('||RECEIPT:').first.trim();
    }
    return s;
  }

  static String? _parseReceipt(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString();
    if (s.contains('||RECEIPT:')) {
      final parts = s.split('||RECEIPT:');
      if (parts.length >= 2 && parts[1].trim().isNotEmpty) {
        return parts[1].trim();
      }
    }
    return null;
  }
}

class PaymentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// اسٹوڈنٹ: ادائیگی کا دعویٰ جمع کرائے (تصویر کے ساتھ محفوظ ریسیٹ ہینڈلنگ)
  Future<void> submitPayment({
    required String classId,
    required double amount,
    required String method,
    required String txnReference,
    String? receiptImage,
  }) async {
    final studentId = _supabase.auth.currentUser!.id;
    final cleanTxn = txnReference.trim();
    final formattedTxn = (receiptImage != null && receiptImage.isNotEmpty)
        ? '$cleanTxn||RECEIPT:$receiptImage'
        : cleanTxn;

    final Map<String, dynamic> payload = {
      'student_id': studentId,
      'class_id': classId,
      'amount': amount,
      'method': method,
      'txn_reference': formattedTxn,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    if (receiptImage != null && receiptImage.isNotEmpty) {
      payload['receipt_url'] = receiptImage;
    }

    // 1. پچھلی ردی (rejected) یا التوا (pending) فیس کی ریکارڈ ہٹائیں تاکہ ڈپلیکیٹ ایرر نہ آئے
    try {
      await _supabase
          .from('payments')
          .delete()
          .eq('student_id', studentId)
          .eq('class_id', classId)
          .neq('status', 'approved');
    } catch (_) {}

    // 2. نئی درخواست insert کریں
    try {
      await _supabase.from('payments').insert(payload);
    } catch (_) {
      // 3. اگر insert میں کوئی مسلہ آئے تو سابقہ ریکارڈ اپڈیٹ کریں
      await _supabase
          .from('payments')
          .update(payload)
          .eq('student_id', studentId)
          .eq('class_id', classId)
          .neq('status', 'approved');
    }
  }

  Future<List<PendingPayment>> getPending() async {
    // 1. Primary: Direct Table Query on payments (کوڈ سے براہ راست تصویری ڈیٹا اور پروفائل لیتا ہے)
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
            'txn_reference': m['txn_reference'] ?? '',
            'receipt_url': m['receipt_url'],
            'amount': m['amount'] ?? 1500,
            'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }).toList();
      }
    } catch (_) {}

    // 2. Secondary: RPC Call
    try {
      final rows = await _supabase.rpc('get_pending_payments') as List?;
      if (rows != null && rows.isNotEmpty) {
        return rows
            .map((r) => PendingPayment.fromMap(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // 3. Fallback: Check pending enrollments if no payment record exists yet
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

  Future<void> approve(String paymentId) async {
    if (paymentId.startsWith('enrollment_')) {
      final parts = paymentId.split('_');
      if (parts.length >= 3) {
        final studentId = parts[1];
        final classId = parts[2];
        try {
          await _supabase.rpc('verify_student', params: {'p_student_id': studentId});
        } catch (_) {}
        try {
          await _supabase
              .from('profiles')
              .update({'is_verified': true})
              .eq('id', studentId);
        } catch (_) {}
        try {
          await _supabase
              .from('class_enrollments')
              .update({'status': 'approved'})
              .eq('student_id', studentId)
              .eq('class_id', classId);
        } catch (_) {}
        return;
      }
    }

    try {
      await _supabase.rpc('approve_payment', params: {'p_payment_id': paymentId});
    } catch (_) {}

    try {
      await _supabase
          .from('payments')
          .update({'status': 'approved'})
          .eq('id', paymentId);
    } catch (_) {}
  }

  Future<void> reject(String paymentId) async {
    if (paymentId.startsWith('enrollment_')) {
      final parts = paymentId.split('_');
      if (parts.length >= 3) {
        final studentId = parts[1];
        final classId = parts[2];

        try {
          await _supabase
              .from('class_enrollments')
              .delete()
              .eq('student_id', studentId)
              .eq('class_id', classId);
        } catch (_) {
          await _supabase
              .from('class_enrollments')
              .update({'status': 'rejected'})
              .eq('student_id', studentId)
              .eq('class_id', classId);
        }

        try {
          await _supabase
              .from('payments')
              .update({'status': 'rejected'})
              .eq('student_id', studentId)
              .eq('class_id', classId);
        } catch (_) {}
        return;
      }
    }

    try {
      await _supabase.rpc('reject_payment', params: {'p_payment_id': paymentId});
    } catch (_) {}

    try {
      await _supabase
          .from('payments')
          .update({'status': 'rejected'})
          .eq('id', paymentId);
    } catch (_) {}
  }
}
