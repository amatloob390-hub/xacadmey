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
    try {
      final link = await _supabase.rpc('join_class', params: {
        'p_class_id': classId,
        'p_device_id': deviceId,
      }).timeout(const Duration(seconds: 20));

      if (link == null || (link as String).isEmpty) {
        return JoinResult.fail(
            L.t('لنک حاصل نہیں ہو سکا، دوبارہ کوشش کریں۔', 'Could not get the link, try again.'));
      }
      return JoinResult.ok(link);
    } on TimeoutException catch (_) {
      return JoinResult.fail(
          L.t('نیٹ ورک سست ہے — دوبارہ کوشش کریں۔', 'Network is slow — please try again.'));
    } on PostgrestException catch (e) {
      return JoinResult.fail(_mapError(e.message));
    } catch (_) {
      return JoinResult.fail(
          L.t('نیٹ ورک مسئلہ — انٹرنیٹ چیک کریں۔', 'Network problem — check your internet.'));
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
      return L.t('آپ اس کلاس میں انرول نہیں ہیں۔', 'You are not enrolled in this class.');
    } else if (raw.contains('CLASS_INACTIVE')) {
      return L.t('کلاس ابھی شروع نہیں ہوئی، تھوڑی دیر بعد کوشش کریں۔',
          'Class has not started yet, try again shortly.');
    } else if (raw.contains('CLASS_NOT_FOUND')) {
      return L.t('کلاس موجود نہیں ہے۔', 'Class does not exist.');
    } else if (raw.contains('AUTH_REQUIRED')) {
      return L.t('براہِ کرم دوبارہ لاگ ان کریں۔', 'Please log in again.');
    }
    return L.t('کچھ گڑبڑ ہوئی، دوبارہ کوشش کریں۔', 'Something went wrong, try again.');
  }
}
