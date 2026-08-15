import 'package:supabase_flutter/supabase_flutter.dart';

/// Staff (teacher / admin / manager) کے کام:
///  • نیا اسٹوڈنٹ ای میل سے دعوت / پہلے سے رجسٹرڈ کو enroll
///  • اسٹوڈنٹ تصدیق (login + join کھولے)
///  • رول تفویض (teacher/admin: manager/sub-admin بنائے)
class StaffService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// موجودہ لاگ اِن یوزر کا رول
  Future<String> myRole() async {
    try {
      final role = await _supabase.rpc('my_role');
      return (role as String?) ?? 'student';
    } catch (_) {
      return 'teacher';
    }
  }

  /// نیا اسٹوڈنٹ ای میل سے شامل کرے۔
  Future<String> inviteStudent({
    required String email,
    String? fullName,
    String? classId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      final res = await _supabase.rpc('invite_student', params: {
        'p_email': cleanEmail,
        'p_full_name': fullName,
        'p_class_id': classId,
      });
      return (res as String?) ?? 'INVITED';
    } catch (_) {
      return 'INVITED';
    }
  }

  /// پہلے سے رجسٹرڈ اسٹوڈنٹ کو ای میل سے verify + (اختیاری) کلاس میں enroll
  Future<void> addExistingStudent({
    required String email,
    String? classId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      await _supabase.rpc('staff_add_existing_student', params: {
        'p_email': cleanEmail,
        'p_class_id': classId,
      });
    } catch (_) {}
  }

  /// کسی بھی ای میل کو براہِ راست تلاش، تصدیق اور کلاس میں داخل کریں
  Future<void> directEnrollByEmail({
    required String email,
    required String classId,
    String? fullName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. RPCs trigger
    await inviteStudent(email: cleanEmail, fullName: fullName, classId: classId);
    await addExistingStudent(email: cleanEmail, classId: classId);

    // 2. Find student ID across all sources
    String? sId;

    // 2a. Check list_pending_students RPC
    try {
      final rpcRows = await _supabase.rpc('list_pending_students') as List?;
      if (rpcRows != null) {
        for (var r in rpcRows) {
          final m = Map<String, dynamic>.from(r as Map);
          final em = m['email']?.toString().trim().toLowerCase();
          if (em == cleanEmail) {
            sId = m['id']?.toString() ??
                m['user_id']?.toString() ??
                m['student_id']?.toString();
            break;
          }
        }
      }
    } catch (_) {}

    // 2b. Check profiles table
    if (sId == null) {
      try {
        final pRows = await _supabase.from('profiles').select('id, email');
        if (pRows is List) {
          for (var r in pRows) {
            final m = Map<String, dynamic>.from(r as Map);
            if (m['email']?.toString().trim().toLowerCase() == cleanEmail) {
              sId = m['id']?.toString();
              break;
            }
          }
        }
      } catch (_) {}
    }

    // 3. If found, apply full verification & class enrollment
    if (sId != null && sId.isNotEmpty) {
      await enrollStudentInClass(studentId: sId, classId: classId);
      try {
        await _supabase.rpc('staff_verify_student_paid', params: {'p_student_id': sId});
      } catch (_) {}
      try {
        await _supabase.rpc('staff_verify_student_trial', params: {'p_student_id': sId, 'p_days': 30});
      } catch (_) {}
      try {
        await _supabase.rpc('staff_verify_student', params: {'p_student_id': sId});
      } catch (_) {}
    }
  }

  /// اسٹوڈنٹ کی تصدیق (فیس سلپ دیکھنے کے بعد)
  Future<void> verifyStudent(String studentId) async {
    try {
      await _supabase.rpc('staff_verify_student', params: {
        'p_student_id': studentId,
      });
    } catch (_) {}
    try {
      await _supabase.rpc('staff_verify_student_paid', params: {
        'p_student_id': studentId,
      });
    } catch (_) {}
    try {
      await _supabase.from('profiles').update({'is_verified': true}).eq('id', studentId);
    } catch (_) {}
  }

  /// صرف teacher/admin: کسی کو رول دے (manager / sub-admin)
  Future<void> setUserRole({
    required String email,
    required String role,
  }) async {
    await _supabase.rpc('set_user_role', params: {
      'p_email': email.trim().toLowerCase(),
      'p_role': role,
    });
  }

  /// staff (manager/teacher/admin) کی فہرست
  Future<List<Map<String, dynamic>>> listStaff() async {
    try {
      final rows = await _supabase.rpc('list_staff') as List;
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// تمام سائن اپ شدہ / رجسٹرڈ اسٹوڈنٹس کی فہرست (profiles, payments, RPCs سے)
  Future<List<Map<String, dynamic>>> getRegisteredStudents() async {
    Map<String, Map<String, dynamic>> studentMap = {};

    // 1. Fetch profiles
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, full_name, email, role');
      if (rows is List) {
        for (var r in rows) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = m['id']?.toString() ?? '';
          final role = m['role']?.toString().toLowerCase() ?? '';
          if (id.isNotEmpty && role != 'teacher' && role != 'admin' && role != 'manager') {
            studentMap[id] = {
              'id': id,
              'full_name': m['full_name']?.toString() ?? 'اسٹوڈنٹ',
              'email': m['email']?.toString() ?? '',
            };
          }
        }
      }
    } catch (_) {}

    // 2. Fetch list_pending_students RPC
    try {
      final rpcRows = await _supabase.rpc('list_pending_students') as List?;
      if (rpcRows != null) {
        for (var r in rpcRows) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = m['id']?.toString() ?? m['user_id']?.toString() ?? m['student_id']?.toString() ?? '';
          if (id.isNotEmpty) {
            studentMap[id] = {
              'id': id,
              'full_name': m['full_name']?.toString() ?? m['student_name']?.toString() ?? 'اسٹوڈنٹ',
              'email': m['email']?.toString() ?? '',
            };
          }
        }
      }
    } catch (_) {}

    // 3. Fetch payments to find any additional student IDs
    try {
      final pRows = await _supabase.from('payments').select('student_id');
      if (pRows is List) {
        for (var r in pRows) {
          final sId = r['student_id']?.toString();
          if (sId != null && sId.isNotEmpty && !studentMap.containsKey(sId)) {
            studentMap[sId] = {
              'id': sId,
              'full_name': 'اسٹوڈنٹ',
              'email': '',
            };
          }
        }
      }
    } catch (_) {}

    final list = studentMap.values.toList();
    list.sort((a, b) => (a['full_name'] as String).compareTo(b['full_name'] as String));
    return list;
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
        'user_id': studentId,
        'class_id': classId,
        'status': 'approved',
        'created_at': DateTime.now().toIso8601String(),
      }, onConflict: 'student_id,class_id');
    } catch (_) {}

    // 2. enrollments میں بھی سٹیٹس
    try {
      await _supabase.from('enrollments').upsert({
        'student_id': studentId,
        'user_id': studentId,
        'class_id': classId,
        'payment_status': 'paid',
        'grace_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      }, onConflict: 'student_id,class_id');
    } catch (_) {}

    // 3. پروفائل کی تصدیق
    try {
      await _supabase
          .from('profiles')
          .update({
            'is_verified': true,
            'is_trial': false,
            'registered_class_id': classId,
          })
          .eq('id', studentId);
    } catch (_) {}

    // 4. RPCs
    try {
      await _supabase.rpc('staff_verify_student', params: {'p_student_id': studentId});
    } catch (_) {}
    try {
      await _supabase.rpc('staff_verify_student_paid', params: {'p_student_id': studentId});
    } catch (_) {}
  }

  /// نام یا ای میل سے اسٹوڈنٹس تلاش کریں — سرور-سائیڈ فلٹر، پوری
  /// profiles ٹیبل نہیں کھینچتا۔ دو الگ ilike کالز taکہ صارف کے ان پٹ
  /// میں کوما/بریکٹ ہونے پر بھی .or() فلٹر syntax نہ ٹوٹے۔
  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final results = await Future.wait([
        _supabase
            .from('profiles')
            .select('id, full_name, email, phone, role, is_verified, is_trial, trial_until')
            .ilike('full_name', '%$q%')
            .limit(20),
        _supabase
            .from('profiles')
            .select('id, full_name, email, phone, role, is_verified, is_trial, trial_until')
            .ilike('email', '%$q%')
            .limit(20),
      ]);

      final Map<String, Map<String, dynamic>> merged = {};
      for (final rows in results) {
        for (final r in (rows as List)) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = m['id']?.toString() ?? '';
          final role = m['role']?.toString().toLowerCase() ?? '';
          if (id.isNotEmpty && role != 'teacher' && role != 'admin') {
            merged[id] = m;
          }
        }
      }
      final list = merged.values.toList();
      list.sort((a, b) =>
          (a['full_name']?.toString() ?? '').compareTo(b['full_name']?.toString() ?? ''));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// کسی اسٹوڈنٹ کی تمام enrolled کلاسز (عنوان اور فیس کی حالت کے ساتھ)
  Future<List<Map<String, dynamic>>> getStudentEnrollments(String studentId) async {
    try {
      final rows = await _supabase
          .from('enrollments')
          .select('class_id, payment_status, grace_until')
          .or('student_id.eq.$studentId,user_id.eq.$studentId');
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return [];

      final classIds = list
          .map((r) => r['class_id']?.toString())
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet();
      if (classIds.isEmpty) return list;

      final classRows = await _supabase
          .from('classes')
          .select('id, title')
          .inFilter('id', classIds.toList());
      final titles = {
        for (final c in (classRows as List))
          c['id'].toString(): c['title']?.toString() ?? 'کلاس',
      };

      return list
          .map((r) => {
                ...r,
                'class_title': titles[r['class_id']?.toString()] ?? 'کلاس',
              })
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// اسٹوڈنٹ کا موبائل نمبر محفوظ/اپڈیٹ کریں
  Future<void> updateStudentPhone(String studentId, String phone) async {
    await _supabase
        .from('profiles')
        .update({'phone': phone.trim()})
        .eq('id', studentId);
  }

  /// ٹیچر کی اپنی کلاسز (Add-Student ڈائیلاگ میں کلاس منتخب کرنے کیلئے)
  Future<List<Map<String, dynamic>>> myClassesLite() async {
    final teacherId = _supabase.auth.currentUser?.id;
    if (teacherId == null) return [];
    try {
      final rows = await _supabase
          .from('classes')
          .select('id, title')
          .eq('teacher_id', teacherId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }
}
