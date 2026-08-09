import 'package:supabase_flutter/supabase_flutter.dart';

class PendingStudent {
  final String studentId, studentName, classId, classTitle, paymentStatus;
  final DateTime graceUntil;

  PendingStudent.fromMap(Map<String, dynamic> m)
      : studentId = m['student_id'],
        studentName = m['student_name'],
        classId = m['class_id'],
        classTitle = m['class_title'],
        paymentStatus = m['payment_status'],
        graceUntil = DateTime.parse(m['grace_until']);

  bool get isBlocked => graceUntil.isBefore(DateTime.now());
  Duration get remaining => graceUntil.difference(DateTime.now());
}

class PendingStudentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<PendingStudent>> getPending() async {
    final rows = await _supabase.rpc('get_pending_students') as List;
    return rows
        .map((r) => PendingStudent.fromMap(r as Map<String, dynamic>))
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
}
