import 'package:supabase_flutter/supabase_flutter.dart';

/// اسٹوڈنٹ کی ایک کلاس کا صاف ماڈل (لنک کے بغیر)
class StudentClass {
  final String id;
  final String title;
  final DateTime scheduledAt;
  final int durationMin;
  final bool isActive;
  final String paymentStatus;
  final DateTime graceUntil;

  StudentClass.fromMap(Map<String, dynamic> m)
      : id = m['class_id'] as String,
        title = m['title'] as String,
        scheduledAt = DateTime.parse(m['scheduled_at'] as String),
        durationMin = m['duration_min'] as int,
        isActive = m['is_active'] as bool,
        paymentStatus = m['payment_status'] as String,
        graceUntil = DateTime.parse(m['grace_until'] as String);

  /// ۷ دن کی مفت مہلت کی تاریخ حاصل کریں
  DateTime get effectiveGraceUntil {
    // ۷ دن کی مہلت کا حساب (scheduledAt یا graceUntil کے مطابق)
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

  AvailableClass.fromMap(Map<String, dynamic> m)
      : id = m['class_id'] as String,
        title = m['title'] as String,
        scheduledAt = DateTime.parse(m['scheduled_at'] as String),
        durationMin = m['duration_min'] as int,
        isActive = m['is_active'] as bool;
}

class StudentService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<StudentClass>> getMyClasses() async {
    // 1. Primary: RPC call
    try {
      final rows = await _supabase.rpc('get_my_classes') as List?;
      if (rows != null && rows.isNotEmpty) {
        return rows
            .map((r) => StudentClass.fromMap(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // 2. Fallback: Direct Table Query on class_enrollments / enrollments
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final Map<String, Map<String, dynamic>> classMetaMap = {};

      try {
        final eRows = await _supabase
            .from('class_enrollments')
            .select('class_id, created_at, status')
            .eq('student_id', userId)
            .neq('status', 'rejected');
        for (var r in (eRows as List)) {
          final cId = r['class_id']?.toString();
          if (cId != null && cId.isNotEmpty) {
            classMetaMap[cId] = {
              'payment_status': r['status'] == 'approved' ? 'paid' : 'pending',
              'grace_until': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            };
          }
        }
      } catch (_) {}

      try {
        final eRows2 = await _supabase
            .from('enrollments')
            .select('class_id, grace_until, payment_status')
            .eq('student_id', userId);
        for (var r in (eRows2 as List)) {
          final cId = r['class_id']?.toString();
          if (cId != null && cId.isNotEmpty) {
            classMetaMap[cId] = {
              'payment_status': r['payment_status'] ?? 'pending',
              'grace_until': r['grace_until'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            };
          }
        }
      } catch (_) {}

      if (classMetaMap.isNotEmpty) {
        final classIds = classMetaMap.keys.toList();
        final cRows = await _supabase
            .from('classes')
            .select('id, title, scheduled_at, duration_min, is_active')
            .inFilter('id', classIds);

        List<StudentClass> result = [];
        for (var c in (cRows as List)) {
          final cId = c['id'].toString();
          final meta = classMetaMap[cId] ?? {};
          result.add(StudentClass.fromMap({
            'class_id': cId,
            'title': c['title'] ?? 'کلاس',
            'scheduled_at': c['scheduled_at'] ?? DateTime.now().toIso8601String(),
            'duration_min': c['duration_min'] ?? 60,
            'is_active': c['is_active'] ?? false,
            'payment_status': meta['payment_status'] ?? 'pending',
            'grace_until': meta['grace_until'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          }));
        }
        if (result.isNotEmpty) return result;
      }
    } catch (_) {}

    return [];
  }

  /// دستیاب کلاسز جن میں اسٹوڈنٹ ابھی انرول نہیں
  Future<List<AvailableClass>> getAvailableClasses() async {
    final rows = await _supabase.rpc('get_available_classes') as List;
    return rows
        .map((r) => AvailableClass.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// اسٹوڈنٹ کو کلاس میں انرول کرے (۷ دن مہلت خودکار)
  Future<void> enroll(String classId) async {
    await _supabase.rpc('enroll_in_class', params: {'p_class_id': classId});
  }
}
