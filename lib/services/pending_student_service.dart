import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingStudent {
  final String studentId, studentName, classId, classTitle, paymentStatus;
  final DateTime graceUntil;

  PendingStudent.fromMap(Map<String, dynamic> m)
      : studentId = m['student_id'] ?? m['user_id'] ?? m['id'] ?? '',
        studentName = m['student_name'] ?? m['full_name'] ?? 'اسٹوڈنٹ',
        classId = m['class_id'] ?? '',
        classTitle = m['class_title'] ?? m['title'] ?? 'کلاس',
        paymentStatus = m['payment_status'] ?? 'pending',
        graceUntil = DateTime.tryParse(m['grace_until'] ?? '') ?? DateTime.now();

  bool get isBlocked => graceUntil.isBefore(DateTime.now());
  Duration get remaining => graceUntil.difference(DateTime.now());
}

class PendingStudentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Removed-student keys are kept in memory ONLY (cleared on every reload)
  // and scoped to student+class only — matching payment_service.dart's
  // identical fix ("Stop persistently hiding payments"). Persisting this
  // forever, and matching by studentId alone, used to permanently hide a
  // student's later, legitimate pending-fee entries for ANY class.
  static final Set<String> _removedStudentKeys = {};
  static bool _purgedLegacy = false;

  static Future<void> _initPrefs() async {
    if (_purgedLegacy) return;
    _purgedLegacy = true;
    // One-time cleanup of any stale persisted list from older builds.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('removed_pending_students_v2');
    } catch (_) {}
  }

  static Future<void> _saveRemoved(String studentId, String classId) async {
    if (studentId.isNotEmpty && classId.isNotEmpty) {
      _removedStudentKeys.add('${studentId}_$classId'); // in-memory only
    }
  }

  Future<List<PendingStudent>> getPending() async {
    await _initPrefs();

    List<PendingStudent> result = [];
    try {
      final rows = await _supabase.rpc('get_pending_students') as List?;
      if (rows != null && rows.isNotEmpty) {
        result = rows
            .map((r) => PendingStudent.fromMap(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return result
        .where((s) => !_removedStudentKeys.contains('${s.studentId}_${s.classId}'))
        .toList();
  }

  /// آج سے X دن نئی مہلت مقرر کرے
  Future<void> setGracePeriod({
    required String studentId,
    required String classId,
    required int days,
  }) async {
    await _supabase.rpc('set_grace_period', params: {
      'p_student_id': studentId,
      'p_class_id': classId,
      'p_days': days,
    });
  }

  /// موجودہ مہلت میں مزید دن جوڑے
  Future<void> extendGracePeriod({
    required String studentId,
    required String classId,
    required int days,
  }) async {
    await _supabase.rpc('extend_grace_period', params: {
      'p_student_id': studentId,
      'p_class_id': classId,
      'p_days': days,
    });
  }

  /// ٹرائل ختم ہونے پر اسٹوڈنٹ کو لسٹ اور کلاس سے ہٹائے
  Future<void> removeStudent({
    required String studentId,
    required String classId,
  }) async {
    await _saveRemoved(studentId, classId);

    // 1. Delete from class_enrollments
    try {
      await _supabase
          .from('class_enrollments')
          .delete()
          .eq('student_id', studentId)
          .eq('class_id', classId);
    } catch (_) {
      try {
        await _supabase
            .from('class_enrollments')
            .update({'status': 'rejected'})
            .eq('student_id', studentId)
            .eq('class_id', classId);
      } catch (_) {}
    }

    // 2. Delete from enrollments
    try {
      await _supabase
          .from('enrollments')
          .delete()
          .eq('student_id', studentId)
          .eq('class_id', classId);
    } catch (_) {
      try {
        await _supabase
            .from('enrollments')
            .update({'payment_status': 'rejected'})
            .eq('student_id', studentId)
            .eq('class_id', classId);
      } catch (_) {}
    }

    // 3. Delete from payments
    try {
      await _supabase
          .from('payments')
          .delete()
          .eq('student_id', studentId)
          .eq('class_id', classId);
    } catch (_) {
      try {
        await _supabase
            .from('payments')
            .update({'status': 'rejected'})
            .eq('student_id', studentId)
            .eq('class_id', classId);
      } catch (_) {}
    }

    // 4. Try calling RPCs if available
    try {
      await _supabase.rpc('staff_reject_student', params: {'p_student_id': studentId});
    } catch (_) {}
    try {
      await _supabase.rpc('reject_student', params: {'p_student_id': studentId});
    } catch (_) {}
  }
}
