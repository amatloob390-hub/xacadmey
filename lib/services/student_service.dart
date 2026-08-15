import 'package:supabase_flutter/supabase_flutter.dart';

/// اسٹوڈنٹ کی ایک کلاس کا صاف اور کریش پروف ماڈل
class StudentClass {
  final String id;
  final String title;
  final DateTime scheduledAt;
  final int durationMin;
  final bool isActive;
  final String paymentStatus;
  final DateTime graceUntil;

  const StudentClass({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.durationMin,
    required this.isActive,
    required this.paymentStatus,
    required this.graceUntil,
  });

  factory StudentClass.fromMap(Map<String, dynamic> m) {
    final rawId = (m['class_id'] ?? m['id'] ?? '').toString().trim();
    final rawTitle =
        (m['title'] ?? m['class_title'] ?? 'آن لائن کلاس').toString().trim();
    final rawScheduled =
        DateTime.tryParse(m['scheduled_at']?.toString() ?? '') ?? DateTime.now();
    final rawDuration = (m['duration_min'] is num
        ? (m['duration_min'] as num).toInt()
        : int.tryParse(m['duration_min']?.toString() ?? '60') ?? 60);
    final rawActive = m['is_active'] == true ||
        m['is_active']?.toString().toLowerCase() == 'true' ||
        m['is_active'] == 1;
    final rawPayment =
        (m['payment_status'] ?? m['status'] ?? 'pending').toString();
    final rawGrace = DateTime.tryParse(m['grace_until']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 7));

    return StudentClass(
      id: rawId,
      title: rawTitle.isNotEmpty ? rawTitle : 'آن لائن کلاس',
      scheduledAt: rawScheduled,
      durationMin: rawDuration > 0 ? rawDuration : 60,
      isActive: rawActive,
      paymentStatus: rawPayment,
      graceUntil: rawGrace,
    );
  }

  /// ۷ دن کی مفت مہلت کی تاریخ حاصل کریں
  DateTime get effectiveGraceUntil {
    final sevenDaysGrace = scheduledAt.add(const Duration(days: 7));
    if (graceUntil.isBefore(sevenDaysGrace)) {
      return sevenDaysGrace;
    }
    return graceUntil;
  }

  bool get isPaid => paymentStatus == 'paid';
  bool get withinGrace => !isPaid && effectiveGraceUntil.isAfter(DateTime.now());
  bool get isBlocked => !isPaid && !withinGrace;
  bool get canAccess => isPaid || withinGrace;
  bool get canJoin => canAccess && isActive;
  Duration get graceLeft => effectiveGraceUntil.difference(DateTime.now());
}

/// دستیاب (ابھی غیر انرول) کلاس کا ماڈل
class AvailableClass {
  final String id;
  final String title;
  final DateTime scheduledAt;
  final int durationMin;
  final bool isActive;

  const AvailableClass({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.durationMin,
    required this.isActive,
  });

  factory AvailableClass.fromMap(Map<String, dynamic> m) {
    final rawId = (m['class_id'] ?? m['id'] ?? '').toString().trim();
    final rawTitle =
        (m['title'] ?? m['class_title'] ?? 'آن لائن کلاس').toString().trim();
    final rawScheduled =
        DateTime.tryParse(m['scheduled_at']?.toString() ?? '') ?? DateTime.now();
    final rawDuration = (m['duration_min'] is num
        ? (m['duration_min'] as num).toInt()
        : int.tryParse(m['duration_min']?.toString() ?? '60') ?? 60);
    final rawActive = m['is_active'] == true ||
        m['is_active']?.toString().toLowerCase() == 'true' ||
        m['is_active'] == 1;

    return AvailableClass(
      id: rawId,
      title: rawTitle.isNotEmpty ? rawTitle : 'آن لائن کلاس',
      scheduledAt: rawScheduled,
      durationMin: rawDuration > 0 ? rawDuration : 60,
      isActive: rawActive,
    );
  }
}

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<StudentClass>> getMyClasses() async {
    final user = _supabase.auth.currentUser;
    final userId = user?.id;

    // 1. Primary: RPC get_my_classes
    try {
      final rows = await _supabase.rpc('get_my_classes') as List?;
      if (rows != null && rows.isNotEmpty) {
        final list = rows
            .map((r) => StudentClass.fromMap(Map<String, dynamic>.from(r as Map)))
            .where((c) => c.id.isNotEmpty)
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}

    if (userId == null) return [];

    // 2. Comprehensive Multi-source Class ID Gatherer
    final Map<String, Map<String, dynamic>> classMetaMap = {};

    // 2a. Check user_metadata
    final metaClassId = (user?.userMetadata?['registered_class_id'] ??
            user?.userMetadata?['class_id'])
        ?.toString()
        .trim();
    if (metaClassId != null && metaClassId.isNotEmpty) {
      classMetaMap[metaClassId] = {
        'payment_status': 'pending',
        'grace_until':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      };
    }

    // 2b/2c/2d: تینوں آزاد fallback ماخذ ایک ساتھ (parallel) لائیں — سست
    // نیٹ ورک پر یکے بعد دیگرے (sequential) کالز مجموعی تاخیر کئی گنا بڑھا
    // دیتے تھے۔ نتیجہ اسی ترتیب میں merge ہوتا ہے (بعد والا پہلے کو override
    // کرے) تاکہ رویہ بالکل ویسا ہی رہے۔
    final results = await Future.wait([
      _fetchProfileClassId(userId),
      _fetchClassEnrollments(userId),
      _fetchEnrollments(userId),
    ]);
    // 2b (profiles): صرف اُن keys کیلئے جو 2a سے پہلے سے موجود نہ ہوں
    for (final entry in results[0].entries) {
      classMetaMap.putIfAbsent(entry.key, () => entry.value);
    }
    // 2c پھر 2d: زیادہ مستند enrollment ڈیٹا — پچھلے سب کو override کرے
    classMetaMap.addAll(results[1]);
    classMetaMap.addAll(results[2]);

    if (classMetaMap.isEmpty) return [];

    final classIds = classMetaMap.keys.toList();
    final Map<String, Map<String, dynamic>> classDataMap = {};

    // 3a. Try direct classes table query
    try {
      final cRows = await _supabase
          .from('classes')
          .select('id, title, scheduled_at, duration_min, is_active')
          .inFilter('id', classIds);

      if (cRows is List) {
        for (var c in cRows) {
          final id = c['id']?.toString().trim();
          if (id != null && id.isNotEmpty) {
            classDataMap[id] = Map<String, dynamic>.from(c as Map);
          }
        }
      }
    } catch (_) {}

    // 3b. If classes table was restricted by RLS, query get_available_classes RPC
    if (classDataMap.length < classIds.length) {
      try {
        final avail = await getAvailableClasses();
        for (var a in avail) {
          if (classIds.contains(a.id)) {
            classDataMap[a.id] = {
              'id': a.id,
              'title': a.title,
              'scheduled_at': a.scheduledAt.toIso8601String(),
              'duration_min': a.durationMin,
              'is_active': a.isActive,
            };
          }
        }
      } catch (_) {}
    }

    // 4. Construct resilient StudentClass list
    List<StudentClass> result = [];
    for (var cId in classIds) {
      final meta = classMetaMap[cId] ?? {};
      final cData = classDataMap[cId];

      result.add(StudentClass(
        id: cId,
        title: (cData?['title'] as String?) ?? 'آن لائن کلاس (Live Class)',
        scheduledAt: DateTime.tryParse(cData?['scheduled_at']?.toString() ?? '') ??
            DateTime.now(),
        durationMin: (cData?['duration_min'] is num
            ? (cData!['duration_min'] as num).toInt()
            : int.tryParse(cData?['duration_min']?.toString() ?? '60') ?? 60),
        // اگر class کا ڈیٹا ہی نہیں ملا (RLS/fallback گیپ) تو محفوظ طریقے سے
        // joinable مان لیں؛ لیکن اگر ڈیٹا مل گیا تو اصل is_active کی قدر
        // کا احترام کریں — ٹیچر کی بند کی ہوئی کلاس اب واقعی inactive
        // دکھے گی، ہمیشہ true نہیں۔
        isActive: (cData == null || cData['is_active'] == null)
            ? true
            : (cData['is_active'] == true ||
                cData['is_active'].toString().toLowerCase() == 'true'),
        paymentStatus: (meta['payment_status'] ?? 'pending').toString(),
        graceUntil: DateTime.tryParse(meta['grace_until']?.toString() ?? '') ??
            DateTime.now().add(const Duration(days: 7)),
      ));
    }

    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchProfileClassId(String userId) async {
    try {
      final prof = await _supabase
          .from('profiles')
          .select('registered_class_id, class_id')
          .eq('id', userId)
          .maybeSingle();
      final profClassId = (prof?['registered_class_id'] ?? prof?['class_id'])
          ?.toString()
          .trim();
      if (profClassId != null && profClassId.isNotEmpty) {
        return {
          profClassId: {
            'payment_status': 'pending',
            'grace_until':
                DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          },
        };
      }
    } catch (_) {}
    return {};
  }

  Future<Map<String, Map<String, dynamic>>> _fetchClassEnrollments(String userId) async {
    final out = <String, Map<String, dynamic>>{};
    try {
      final eRows = await _supabase
          .from('class_enrollments')
          .select('class_id, created_at, status')
          .or('student_id.eq.$userId,user_id.eq.$userId')
          .neq('status', 'rejected');
      if (eRows is List) {
        for (var r in eRows) {
          final cId = r['class_id']?.toString().trim();
          if (cId != null && cId.isNotEmpty) {
            out[cId] = {
              'payment_status': r['status'] == 'approved' ? 'paid' : 'pending',
              'grace_until': DateTime.now()
                  .add(const Duration(days: 7))
                  .toIso8601String(),
            };
          }
        }
      }
    } catch (_) {}
    return out;
  }

  Future<Map<String, Map<String, dynamic>>> _fetchEnrollments(String userId) async {
    final out = <String, Map<String, dynamic>>{};
    try {
      final eRows2 = await _supabase
          .from('enrollments')
          .select('class_id, grace_until, payment_status')
          .or('student_id.eq.$userId,user_id.eq.$userId');
      if (eRows2 is List) {
        for (var r in eRows2) {
          final cId = r['class_id']?.toString().trim();
          if (cId != null && cId.isNotEmpty) {
            out[cId] = {
              'payment_status': r['payment_status'] ?? 'pending',
              'grace_until': r['grace_until'] ??
                  DateTime.now()
                      .add(const Duration(days: 7))
                      .toIso8601String(),
            };
          }
        }
      }
    } catch (_) {}
    return out;
  }

  /// دستیاب کلاسز جن میں اسٹوڈنٹ ابھی انرول نہیں
  Future<List<AvailableClass>> getAvailableClasses() async {
    try {
      final rows = await _supabase.rpc('get_available_classes') as List?;
      if (rows != null) {
        return rows
            .map((r) =>
                AvailableClass.fromMap(Map<String, dynamic>.from(r as Map)))
            .where((c) => c.id.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// اسٹوڈنٹ کو کلاس میں انرول کرے (۷ دن مہلت خودکار)
  Future<void> enroll(String classId) async {
    final cleanId = classId.trim();
    if (cleanId.isEmpty) return;

    final user = _supabase.auth.currentUser;
    final userId = user?.id;

    // 1. RPC call
    try {
      await _supabase.rpc('enroll_in_class', params: {'p_class_id': cleanId});
    } catch (_) {}

    if (userId != null) {
      // 2. Direct upsert into enrollments table
      try {
        await _supabase.from('enrollments').upsert({
          'student_id': userId,
          'user_id': userId,
          'class_id': cleanId,
          'grace_until':
              DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          'payment_status': 'pending',
        }, onConflict: 'student_id,class_id');
      } catch (_) {}

      // 3. Direct upsert into class_enrollments table
      try {
        await _supabase.from('class_enrollments').upsert({
          'student_id': userId,
          'user_id': userId,
          'class_id': cleanId,
          'status': 'pending',
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'student_id,class_id');
      } catch (_) {}

      // 4. Update profiles table
      try {
        await _supabase.from('profiles').update({
          'registered_class_id': cleanId,
        }).eq('id', userId);
      } catch (_) {}

      // 5. Update user metadata in Supabase Auth
      try {
        await _supabase.auth.updateUser(UserAttributes(
          data: {
            'registered_class_id': cleanId,
            'class_id': cleanId,
          },
        ));
      } catch (_) {}
    }
  }
}
