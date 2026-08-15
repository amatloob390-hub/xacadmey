import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingPayment {
  final String paymentId, studentId, classId, studentName, classTitle, method, txnReference;
  final String? receiptUrl;
  final num amount;
  final DateTime createdAt;

  PendingPayment.fromMap(Map<String, dynamic> m)
      : paymentId = m['payment_id'] ?? m['id'] ?? '',
        studentId = m['student_id'] ?? '',
        classId = m['class_id'] ?? '',
        studentName = m['student_name'] ?? 'اسٹوڈنٹ',
        classTitle = m['class_title'] ?? 'کلاس',
        method = _formatMethod(m['method']),
        txnReference = _parseTxn(m['txn_reference']),
        receiptUrl = m['receipt_url'] ?? m['receipt_image'] ?? _parseReceipt(m['txn_reference']),
        amount = _parseNum(m['amount']),
        createdAt = DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now();

  static String _formatMethod(dynamic method) {
    if (method == null) return 'JazzCash';
    final m = method.toString().toLowerCase().trim();
    if (m == 'jazzcash') return 'JazzCash';
    if (m == 'easypaisa') return 'EasyPaisa';
    if (m == 'bank') return 'Bank Transfer';
    if (m == 'other') return 'Other';
    return method.toString();
  }

  static num _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse(v.toString()) ?? 0;
  }

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

  // Dismissed IDs are kept in memory ONLY (cleared on every reload). The
  // server already excludes approved/rejected payments via get_pending_payments,
  // so there is nothing to persist — and persisting used to permanently hide a
  // student's later, legitimate submissions.
  static final Set<String> _dismissedKeys = {};
  static bool _purgedLegacy = false;

  static Future<void> _initPrefs() async {
    if (_purgedLegacy) return;
    _purgedLegacy = true;
    // One-time cleanup of any stale persisted list from older builds.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('dismissed_payments_v2');
    } catch (_) {}
  }

  static Future<void> _saveDismissed(String key) async {
    if (key.trim().isEmpty) return;
    _dismissedKeys.add(key.trim()); // in-memory only
  }

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
    await _initPrefs();
    List<PendingPayment> result = [];

    // 1. Primary: get_pending_payments RPC — SECURITY DEFINER, so it returns
    //    real student names, amounts, methods and receipts across RLS, and
    //    de-duplicates to the latest submission per student+class.
    try {
      final rpcRows = await _supabase.rpc('get_pending_payments') as List?;
      if (rpcRows != null && rpcRows.isNotEmpty) {
        result = rpcRows
            .map((r) =>
                PendingPayment.fromMap(Map<String, dynamic>.from(r as Map)))
            .toList();
      }
    } catch (_) {}

    // 2. Fallback: direct table query if the RPC returned nothing
    if (result.isEmpty) {
    try {
      final rows = await _supabase
          .from('payments')
          .select('id, student_id, class_id, amount, method, txn_reference, receipt_url, created_at, status')
          // treat every not-yet-decided state as pending: pending / submitted / null
          .or('status.eq.pending,status.eq.submitted,status.is.null')
          .order('created_at', ascending: true);

      if ((rows as List).isNotEmpty) {
        final paymentList = rows as List;
        final studentIds = paymentList
            .map((r) => r['student_id']?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet();
        final classIds = paymentList
            .map((r) => r['class_id']?.toString())
            .whereType<String>()
            .where((c) => c.isNotEmpty)
            .toSet();

        Map<String, String> profileNames = {};
        Map<String, String> classTitles = {};

        if (studentIds.isNotEmpty) {
          try {
            final pRows = await _supabase
                .from('profiles')
                .select('id, full_name')
                .inFilter('id', studentIds.toList());
            for (var pr in (pRows as List)) {
              if (pr['id'] != null) {
                profileNames[pr['id'].toString()] =
                    pr['full_name']?.toString() ?? 'اسٹوڈنٹ';
              }
            }
          } catch (_) {}
        }

        if (classIds.isNotEmpty) {
          try {
            final cRows = await _supabase
                .from('classes')
                .select('id, title')
                .inFilter('id', classIds.toList());
            for (var cr in (cRows as List)) {
              if (cr['id'] != null) {
                classTitles[cr['id'].toString()] =
                    cr['title']?.toString() ?? 'کلاس';
              }
            }
          } catch (_) {}
        }

        result = paymentList.map((r) {
          final m = Map<String, dynamic>.from(r as Map);
          final sId = m['student_id']?.toString() ?? '';
          final cId = m['class_id']?.toString() ?? '';
          return PendingPayment.fromMap({
            'payment_id': m['id'],
            'student_id': sId,
            'class_id': cId,
            'student_name': profileNames[sId] ?? 'اسٹوڈنٹ',
            'class_title': classTitles[cId] ?? 'کلاس',
            'method': m['method'] ?? 'JazzCash',
            'txn_reference': m['txn_reference'] ?? '',
            'receipt_url': m['receipt_url'],
            'amount': m['amount'],
            'created_at': m['created_at'] ?? DateTime.now().toIso8601String(),
          });
        }).toList();
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
              'amount': m['amount'],
              'created_at': DateTime.now().toIso8601String(),
            });
          }).toList();
        }
      } catch (_) {}
    }

    // 4. Auto-Enrich payment info (receipt screenshot, txn_reference) for any student record lacking receipt image
    for (int i = 0; i < result.length; i++) {
      final item = result[i];
      if (item.studentId.isNotEmpty &&
          (item.txnReference == 'درخواست جمع ہو گئی' || item.receiptUrl == null)) {
        try {
          final pRows = await _supabase
              .from('payments')
              .select('id, method, txn_reference, amount, receipt_url')
              .eq('student_id', item.studentId)
              .order('created_at', ascending: false)
              .limit(1);

          if ((pRows as List).isNotEmpty) {
            final pRow = (pRows).first as Map;
            final txn = pRow['txn_reference']?.toString() ?? '';
            if (txn.isNotEmpty) {
              result[i] = PendingPayment.fromMap({
                'payment_id': pRow['id']?.toString() ?? item.paymentId,
                'student_id': item.studentId,
                'class_id': item.classId,
                'student_name': item.studentName,
                'class_title': item.classTitle,
                'method': pRow['method']?.toString() ?? item.method,
                'txn_reference': txn,
                'receipt_url': pRow['receipt_url'],
                'amount': pRow['amount'] ?? item.amount,
                'created_at': item.createdAt.toIso8601String(),
              });
            }
          }
        } catch (_) {}
      }
    }

    // Filter out locally dismissed items.
    // A real payment is hidden ONLY by its own id, so a NEW submission from
    // a student the teacher previously actioned still shows up. StudentId
    // dismissal applies only to synthetic enrollment placeholders.
    return result.where((p) {
      if (_dismissedKeys.contains(p.paymentId)) return false;
      if (p.paymentId.startsWith('enrollment_')) {
        if (_dismissedKeys.contains(p.studentId)) return false;
        final parts = p.paymentId.split('_');
        if (parts.length >= 3 && _dismissedKeys.contains(parts[1])) return false;
      }
      return true;
    }).toList();
  }

  Future<void> approve(String paymentId) async {
    await _saveDismissed(paymentId);

    String? studentId;
    String? classId;

    if (paymentId.startsWith('enrollment_')) {
      final parts = paymentId.split('_');
      if (parts.length >= 3) {
        studentId = parts[1];
        classId = parts[2];
        await _saveDismissed(studentId);
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
          if (studentId != null) await _saveDismissed(studentId);
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

      try {
        var query = _supabase.from('enrollments').update({'payment_status': 'paid'}).eq('student_id', studentId);
        if (classId != null && classId.isNotEmpty) {
          query = query.eq('class_id', classId);
        }
        await query;
      } catch (_) {}
    }
  }

  Future<void> reject(String paymentId) async {
    await _saveDismissed(paymentId);

    String? studentId;
    String? classId;

    if (paymentId.startsWith('enrollment_')) {
      final parts = paymentId.split('_');
      if (parts.length >= 3) {
        studentId = parts[1];
        classId = parts[2];
        await _saveDismissed(studentId);
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
          if (studentId != null) await _saveDismissed(studentId);
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

      // 2. Delete/Update class_enrollments table
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

      // 3. Delete/Update enrollments table
      try {
        var q = _supabase.from('enrollments').delete().eq('student_id', studentId);
        if (classId != null && classId.isNotEmpty) q = q.eq('class_id', classId);
        await q;
      } catch (_) {
        try {
          var q = _supabase.from('enrollments').update({'payment_status': 'rejected'}).eq('student_id', studentId);
          if (classId != null && classId.isNotEmpty) q = q.eq('class_id', classId);
          await q;
        } catch (_) {}
      }

      // Try RPC calls if available
      try {
        await _supabase.rpc('reject_student', params: {'p_student_id': studentId});
      } catch (_) {}
      try {
        await _supabase.rpc('staff_reject_student', params: {'p_student_id': studentId});
      } catch (_) {}
    }
  }
}
