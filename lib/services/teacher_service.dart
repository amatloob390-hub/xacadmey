import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// ٹیچر کی اپنی کلاسز (ایک بار لوڈ — Real-time پر انحصار نہیں، زیادہ مضبوط)
  Future<List<Map<String, dynamic>>> myClasses() async {
    final teacherId = _supabase.auth.currentUser!.id;
    final rows = await _supabase
        .from('classes')
        .select()
        .eq('teacher_id', teacherId)
        .order('scheduled_at', ascending: true)
        .timeout(const Duration(seconds: 20));
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> createClass({
    required String title,
    required String zoomLink,
    required DateTime scheduledAt,
    int durationMin = 60,
    bool isFree = false,
  }) async {
    final teacherId = _supabase.auth.currentUser!.id;
    await _supabase.from('classes').insert({
      'title': title,
      'teacher_id': teacherId,
      'zoom_link': zoomLink,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_min': durationMin,
      'is_active': false,
      'is_free': isFree,
    });
  }

  Future<void> updateClass({
    required String classId,
    required String title,
    required String zoomLink,
    required DateTime scheduledAt,
    required int durationMin,
    bool isFree = false,
  }) async {
    await _supabase.from('classes').update({
      'title': title,
      'zoom_link': zoomLink,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_min': durationMin,
      'is_free': isFree,
    }).eq('id', classId);
  }

  Future<void> setActive(String classId, bool active) async {
    await _supabase
        .from('classes')
        .update({'is_active': active}).eq('id', classId);
  }

  Future<void> deleteClass(String classId) async {
    await _supabase.from('classes').delete().eq('id', classId);
  }
}
