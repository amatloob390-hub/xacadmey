import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff (teacher / admin / manager) کے کام:
///  • نیا اسٹوڈنٹ ای میل سے دعوت / پہلے سے رجسٹرڈ کو enroll
///  • اسٹوڈنٹ تصدیق (login + join کھولے)
///  • رول تفویض (teacher/admin: manager/sub-admin بنائے)
class StaffService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// موجودہ لاگ اِن یوزر کا رول
  Future<String> myRole() async {
    final role = await _supabase.rpc('my_role');
    return (role as String?) ?? 'student';
  }

  /// نیا اسٹوڈنٹ ای میل سے شامل کرے۔
  /// اگر ای میل پہلے سے رجسٹرڈ ہو تو فوراً verify+enroll ('EXISTING_VERIFIED')،
  /// ورنہ دعوت محفوظ ہو جائے ('INVITED') — signup پر خودکار فعال۔
  Future<String> inviteStudent({
    required String email,
    String? fullName,
    String? classId,
  }) async {
    final res = await _supabase.rpc('invite_student', params: {
      'p_email': email,
      'p_full_name': fullName,
      'p_class_id': classId,
    });
    return (res as String?) ?? 'INVITED';
  }

  /// پہلے سے رجسٹرڈ اسٹوڈنٹ کو ای میل سے verify + (اختیاری) کلاس میں enroll
  Future<void> addExistingStudent({
    required String email,
    String? classId,
  }) async {
    await _supabase.rpc('staff_add_existing_student', params: {
      'p_email': email,
      'p_class_id': classId,
    });
  }

  /// اسٹوڈنٹ کی تصدیق (فیس سلپ دیکھنے کے بعد)
  Future<void> verifyStudent(String studentId) async {
    await _supabase.rpc('staff_verify_student', params: {
      'p_student_id': studentId,
    });
  }

  /// صرف teacher/admin: کسی کو رول دے (manager / sub-admin)
  Future<void> setUserRole({
    required String email,
    required String role,
  }) async {
    await _supabase.rpc('set_user_role', params: {
      'p_email': email,
      'p_role': role,
    });
  }

  /// staff (manager/teacher/admin) کی فہرست
  Future<List<Map<String, dynamic>>> listStaff() async {
    final rows = await _supabase.rpc('list_staff') as List;
    return List<Map<String, dynamic>>.from(rows);
  }

  /// تمام سائن اپ شدہ / رجسٹرڈ اسٹوڈنٹس کی فہرست
  Future<List<Map<String, dynamic>>> getRegisteredStudents() async {
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, full_name, email, role')
          .order('full_name', ascending: true);
      return (rows as List)
          .cast<Map<String, dynamic>>()
          .where((p) => (p['role'] == null || p['role'] == 'student' || p['role'] == ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// رجسٹرڈ اسٹوڈنٹ کو منتخب کلاس میں اینرول اور فعال کریں
  Future<void> enrollStudentInClass({
    required String studentId,
    required String classId,
  }) async {
    // 1. class_enrollments میں فعال داخلہ
    try {
      await _supabase.from('class_enrollments').upsert({
        'student_id': studentId,
        'class_id': classId,
        'status': 'approved',
      }, onConflict: 'student_id,class_id');
    } catch (_) {}

    // 2. enrollments میں بھی سٹیٹس
    try {
      await _supabase.from('enrollments').upsert({
        'student_id': studentId,
        'class_id': classId,
        'payment_status': 'paid',
      }, onConflict: 'student_id,class_id');
    } catch (_) {}

    // 3. پروفائل کی تصدیق
    try {
      await _supabase
          .from('profiles')
          .update({'is_verified': true})
          .eq('id', studentId);
    } catch (_) {}

    // 4. RPCs
    try {
      await _supabase.rpc('staff_verify_student', params: {'p_student_id': studentId});
    } catch (_) {}
  }

  /// ٹیچر کی اپنی کلاسز (Add-Student ڈائیلاگ میں کلاس منتخب کرنے کیلئے)
  Future<List<Map<String, dynamic>>> myClassesLite() async {
    final teacherId = _supabase.auth.currentUser!.id;
    final rows = await _supabase
        .from('classes')
        .select('id, title')
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }
}
