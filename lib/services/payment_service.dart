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

  // Track processed/dismissed IDs locally in memory to guarantee immediate filtering
  static final Set<String> _dismissedKeys = {};

  /// اسٹوڈنٹ: ادائیگی کا دعویٰ جمع کرائے (تصویر کے ساتھ محفوظ ریسیٹ ہینڈلنگ)
  Future<void> submitPayment({
    required String classId,
    required double amount,
    required String method,
    required String txnReference,
    String? receiptImage,
  }) async {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) return;
    final studentId = currentUser.id;

    final cleanTxn = txnReference.trim();
    final formattedTxn = (receiptImage != null && receiptImage.isNotEmpty)
        ? '$cleanTxn||RECEIPT:$receiptImage'
        : cleanTxn;

    final Map<String, dynamic> payloadFull = {
      'student_id': studentId,
      'class_id': classId,
      'amount': amount,
      'method': method,
      'txn_reference': formattedTxn,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    if (receiptImage != null && receiptImage.isNotEmpty) {
      payloadFull['receipt_url'] = receiptImage;
    }

    final Map<String, dynamic> payloadSafe = {
      'student_id': studentId,
      'class_id': classId,
      'amount': amount,
      'method': method,
      'txn_reference': formattedTxn,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. پچھلی ردی یا التوا فیس ہٹائیں
    try {
      await _supabase
          .from('payments')
          .delete()
          .eq('student_id', studentId)
          .eq('class_id', classId)
          .neq('status', 'approved');
    } catch (_) {}

    // 2. نئی درخواست insert کریں (پہلے receipt_url کے ساتھ، ورنہ محفوظ کالمز کے ساتھ)
    bool inserted = false;
    try {
      await _supabase.from('payments').insert(payloadFull);
      inserted = true;
    } catch (_) {}

    if (!inserted) {
      try {
        await _supabase.from('payments').insert(payloadSafe);
        inserted = true;
      } catch (_) {}
    }

    // 3. اگر insert نہ ہو سکے (مثلاً ڈپلیکیٹ کی یا RLS کی وجہ سے)، تو update کریں
    if (!inserted) {
      try {
        await _supabase
            .from('payments')
            .update(payloadFull)
            .eq('student_id', studentId)
            .eq('class_id', classId)
            .neq('status', 'approved');
      } catch (_) {
        try {
          await _supabase
              .from('payments')
              .update(payloadSafe)
              .eq('student_id', studentId)
              .eq('class_id', classId)
              .neq('status', 'approved');
        } catch (_) {}
      }
    }

    // 4. class_enrollments اور enrollments میں بھی سٹیٹس التوا رکھیں تاکہ ٹیچر پینل کو فوراً ڈیٹا ملے
    try {
      await _supabase.from('class_enrollments').upsert({
        'student_id': studentId,
        'class_id': classId,
        'status': 'pending',
      }, onConflict: 'student_id,class_id');
    } catch (_) {}

    try {
      await _supabase.from('enrollments').upsert({
        'student_id': studentId,
        'class_id': classId,
        'payment_status': 'pending',
      }, onConflict: 'student_id,class_id');
    } catch (_) {}
  }

  Future<List<PendingPayment>> getPending() async {
    List<PendingPayment> result = [];

    // 1. Primary: Direct Table Query on payments
    try {
      final rows = await _supabase
          .from('payments')
          .select(
              'id, student_id, class_id, amount, method, txn_reference, receipt_url, created_at, status, profiles(full_name), classes(title)')
          .or('status.eq.pending,status.is.null')
          .order('created_at', ascending: true);

      if ((rows as List).isNotEmpty) {
        result = (rows).map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final profile = m['profiles'] as Map<String, dynamic>?;
          final cls = m['classes'] as Map<String, dynamic>?;
          return PendingPayment.fromMap({
            'payment_id': m['id'],
            'student_id': m['student_id'],
            'class_id': m['class_id'],
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

    // 2. Secondary: RPC Call if direct query yielded empty
    if (result.isEmpty) {
      try {
        final rows = await _supabase.rpc('get_pending_payments') as List?;
        if (rows != null && rows.isNotEmpty) {
          result = rows
              .map((r) => PendingPayment.fromMap(r as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    // 3. Fallback: Check pending enrollments if no payment record exists yet
    if (result.isEmpty) {
      try {
        final rows = await _supabase.rpc('get_pending_students') as List?;
        if (rows != null && rows.isNotEmpty) {
          result = rows.map((r) {
            final m = Map<String, dynamic>.from(r as Map);
            final sId = m['student_id'] ?? m['user_id'] ?? m['id'] ?? '';
            final cId = m['class_id'] ?? '';
            return PendingPayment.fromMap({
              'payment_id': 'enrollment_${sId}_$cId',
              'student_id': sId,
              'class_id': cId,
              'student_name': m['student_name'] ?? m['full_name'] ?? 'اسٹوڈنٹ',
              'class_title': m['class_title'] ?? m['title'] ?? 'کلاس',
              'method': 'JazzCash / EasyPaisa',
              'txn_reference': 'درخواست جمع ہو گئی',
              'amount': 1500,
              'created_at': DateTime.now().toIso8601String(),
            });
          }).toList();
        }
      } catch (_) {}
    }

    // Filter out locally dismissed items
    return result.where((p) {
      if (_dismissedKeys.contains(p.paymentId)) return false;
      if (p.paymentId.startsWith('enrollment_')) {
        final parts = p.paymentId.split('_');
        if (parts.length >= 3) {
          final sId = parts[1];
          if (_dismissedKeys.contains(sId)) return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> approve(String paymentId) async {
    _dismissedKeys.add(paymentId);

    String? studentId;
    String? classId;

    if (paymentId.startsWith('enrollment_')) {
      final parts = paymentId.split('_');
      if (parts.length >= 3) {
        studentId = parts[1];
        classId = parts[2];
        _dismissedKeys.add(studentId);
      }
    } else {
      // Try fetching student_id & class_id from payment record
      try {
        final res = await _supabase
            .from('payments')
            .select('student_id, class_id')
            .eq('id', paymentId)
            .maybeSingle();
        if (res != null) {
          studentId = res['student_id']?.toString();
          classId = res['class_id']?.toString();
          if (studentId != null) _dismissedKeys.add(studentId);
        }
      } catch (_) {}
    }

    // Update payments table
    if (!paymentId.startsWith('enrollment_')) {
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

    // Update class_enrollments and profiles if studentId is known
    if (studentId != null && studentId.isNotEmpty) {
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
        var query = _supabase.from('class_enrollments').update({'status': 'approved'}).eq('student_id', studentId);
        if (classId != null && classId.isNotEmpty) {
          query = query.eq('class_id', classId);
        }
        await query;
      } catch (_) {}
    }
  }

  Future<void> reject(String paymentId) async {
    _dismissedKeys.add(paymentId);

    String? studentId;
    String? classId;

    if (paymentId.startsWith('enrollment_')) {
      final parts = paymentId.split('_');
      if (parts.length >= 3) {
        studentId = parts[1];
        classId = parts[2];
        _dismissedKeys.add(studentId);
      }
    } else {
      // Fetch student_id & class_id from payments table before deleting
      try {
        final res = await _supabase
            .from('payments')
            .select('student_id, class_id')
            .eq('id', paymentId)
            .maybeSingle();
        if (res != null) {
          studentId = res['student_id']?.toString();
          classId = res['class_id']?.toString();
          if (studentId != null) _dismissedKeys.add(studentId);
        }
      } catch (_) {}
    }

    // 1. Delete/Update payments table
    if (!paymentId.startsWith('enrollment_')) {
      try {
        await _supabase.rpc('reject_payment', params: {'p_payment_id': paymentId});
      } catch (_) {}
      try {
        await _supabase.from('payments').delete().eq('id', paymentId);
      } catch (_) {
        try {
          await _supabase.from('payments').update({'status': 'rejected'}).eq('id', paymentId);
        } catch (_) {}
      }
    }

    // Also delete/update payments by studentId/classId if available
    if (studentId != null && studentId.isNotEmpty) {
      try {
        var q = _supabase.from('payments').delete().eq('student_id', studentId);
        if (classId != null && classId.isNotEmpty) q = q.eq('class_id', classId);
        await q;
      } catch (_) {
        try {
          var q = _supabase.from('payments').update({'status': 'rejected'}).eq('student_id', studentId);
          if (classId != null && classId.isNotEmpty) q = q.eq('class_id', classId);
          await q;
        } catch (_) {}
      }

      // 2. CRITICAL: Delete/Update class_enrollments table so student enrollment is rejected as well
      try {
        var q = _supabase.from('class_enrollments').delete().eq('student_id', studentId);
        if (classId != null && classId.isNotEmpty) q = q.eq('class_id', classId);
        await q;
      } catch (_) {
        try {
          var q = _supabase.from('class_enrollments').update({'status': 'rejected'}).eq('student_id', studentId);
          if (classId != null && classId.isNotEmpty) q = q.eq('class_id', classId);
          await q;
        } catch (_) {}
      }

      // Try RPC calls if available
      try {
        await _supabase.rpc('reject_student', params: {'p_student_id': studentId});
      } catch (_) {}
    }
  }
}
