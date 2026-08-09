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
    final rows = await _supabase.rpc('get_my_classes') as List;
    return rows
        .map((r) => StudentClass.fromMap(r as Map<String, dynamic>))
        .toList();
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
