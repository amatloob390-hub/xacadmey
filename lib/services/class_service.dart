import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';

/// join_class RPC کا نتیجہ — یا تو لنک، یا صاف اردو ایرر پیغام۔
class JoinResult {
  final bool success;
  final String? zoomLink;
  final String? message;

  JoinResult.ok(this.zoomLink)
      : success = true,
        message = null;
  JoinResult.fail(this.message)
      : success = false,
        zoomLink = null;
}

class ClassService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<JoinResult> joinClass({
    required String classId,
    required String deviceId,
  }) async {
    final cleanId = classId.trim();
    final user = _supabase.auth.currentUser;
    final userId = user?.id;

    // 1. Claim any pending teacher invites
    try {
      await _supabase.rpc('claim_invite');
    } catch (_) {}

    // 2. Auto-ensure enrollment & trial in DB before calling join_class
    if (userId != null) {
      try {
        await _supabase.rpc('enroll_in_class', params: {'p_class_id': cleanId});
      } catch (_) {}
      try {
        await _supabase.from('enrollments').upsert({
          'student_id': userId,
          'user_id': userId,
          'class_id': cleanId,
          'grace_until':
              DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          'payment_status': 'trial',
        }, onConflict: 'student_id,class_id');
      } catch (_) {}
      try {
        await _supabase.from('class_enrollments').upsert({
          'student_id': userId,
          'user_id': userId,
          'class_id': cleanId,
          'status': 'approved',
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'student_id,class_id');
      } catch (_) {}
    }

    // 3. صرف join_class RPC ہی حتمی فیصلہ کرے — ادائیگی/مہلت/ڈیوائس/فعال
    //    ہونے کے چیک وہیں ہوتے ہیں۔ RPC ناکام ہو (چاہے کسی بھی وجہ سے) تو
    //    کبھی بھی متبادل ذریعے سے zoom_link ڈھونڈ کر "کامیابی" نہ دیں —
    //    ورنہ یہی چیک مکمل طور پر نظرانداز ہو جاتے۔
    try {
      final link = await _supabase.rpc('join_class', params: {
        'p_class_id': cleanId,
        'p_device_id': deviceId,
      }).timeout(const Duration(seconds: 15));

      if (link != null && (link as String).isNotEmpty) {
        return JoinResult.ok(link);
      }
      return JoinResult.fail(
          L.t('لنک حاصل نہیں ہو سکا، دوبارہ کوشش کریں۔', 'Could not get the link, try again.'));
    } catch (e) {
      if (e is PostgrestException) {
        return JoinResult.fail(_mapError(e.message));
      }
      return JoinResult.fail(
          L.t('کلاس میں شمولیت کے لیے ٹیچر سے منظوری درکار ہے۔',
              'Teacher approval is required to join this class.'));
    }
  }

  String _mapError(String raw) {
    if (raw.contains('DEVICE_MISMATCH')) {
      return L.t('یہ سیشن کسی اور ڈیوائس پر فعال ہے۔',
          'This session is active on another device.');
    } else if (raw.contains('NOT_PAID') || raw.contains('GRACE_EXPIRED')) {
      return L.t('مہلت ختم یا فیس ادا نہیں — براہِ کرم فیس جمع کروائیں۔',
          'Grace expired or fee unpaid — please submit your fee.');
    } else if (raw.contains('NOT_ENROLLED')) {
      return L.t('ٹیچر کے ڈیش بورڈ سے اسٹوڈنٹ کی تصدیق درکار ہے۔',
          'Teacher approval required from the teacher dashboard.');
    } else if (raw.contains('CLASS_INACTIVE')) {
      return L.t('کلاس ابھی لائیو نہیں ہے — ٹیچر کے کلاس شروع کرنے (Active) کا انتظار کریں۔',
          'Class is not live yet — wait for the teacher to start the class.');
    } else if (raw.contains('CLASS_NOT_FOUND')) {
      return L.t('کلاس موجود نہیں ہے۔', 'Class does not exist.');
    } else if (raw.contains('AUTH_REQUIRED')) {
      return L.t('براہِ کرم دوبارہ لاگ ان کریں۔', 'Please log in again.');
    }
    return L.t('کچھ گڑبڑ ہوئی، دوبارہ کوشش کریں۔', 'Something went wrong, try again.');
  }
}
