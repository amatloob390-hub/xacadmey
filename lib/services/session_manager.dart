import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_service.dart';

/// سنگل ڈیوائس لاگ ان کا انتظام: نئی ڈیوائس رجسٹر کرنا اور
/// دوسری ڈیوائس فعال ہونے پر موجودہ کو خودکار لاگ آؤٹ کرنا۔
class SessionManager {
  // ایک ہی مشترکہ (singleton) انسٹینس تاکہ نگرانی ایک جگہ رہے
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  Timer? _pollingTimer;
  String? _myDeviceId;
  bool _isRegistered = false;

  /// کال بیک: جب یہ ڈیوائس کسی اور کی وجہ سے کِک ہو جائے۔
  void Function()? onForceLogout;

  /// لاگ ان کے فوراً بعد یا ایپ کھلنے پر کال کریں۔
  Future<void> start() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _myDeviceId = await DeviceService.getDeviceId();
    _isRegistered = false;

    // 1. پہلے اس ڈیوائس کی ID کو دیتابیس میں رجسٹر کریں
    try {
      await _supabase.from('sessions').upsert({
        'user_id': userId,
        'active_device_id': _myDeviceId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id').timeout(const Duration(seconds: 5));
      _isRegistered = true;
    } catch (_) {
      try {
        await _supabase.rpc('register_device', params: {
          'p_device_id': _myDeviceId,
        }).timeout(const Duration(seconds: 5));
        _isRegistered = true;
      } catch (_) {}
    }

    // 2. رجسٹریشن مکمل ہونے کے بعد ہی Realtime اور Polling نگرانی شروع کریں
    _listenForDeviceChange();
    _startPolling();
  }

  void _listenForDeviceChange() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _sub?.cancel();
    _sub = _supabase
        .from('sessions')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .listen((rows) {
      if (!_isRegistered || rows.isEmpty) return;
      final activeDeviceId = rows.first['active_device_id'] as String?;
      if (activeDeviceId != null &&
          _myDeviceId != null &&
          _myDeviceId!.isNotEmpty &&
          activeDeviceId != _myDeviceId) {
        _forceLogout();
      }
    }, onError: (_) {
      // عارضی کنکشن خرابی نظرانداز کریں
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // پولنگ (5 سیکنڈ): صرف تب کمپیئر کرے جب لوکل ڈیوائس دیتابیس میں سیٹ ہو چکی ہو
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_isRegistered) return;
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      try {
        final res = await _supabase
            .from('sessions')
            .select('active_device_id')
            .eq('user_id', userId)
            .maybeSingle();

        if (res != null) {
          final activeDeviceId = res['active_device_id'] as String?;
          if (activeDeviceId != null &&
              _myDeviceId != null &&
              _myDeviceId!.isNotEmpty &&
              activeDeviceId != _myDeviceId) {
            _forceLogout();
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _forceLogout() async {
    _isRegistered = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    await _sub?.cancel();
    _sub = null;

    onForceLogout?.call();
    await _supabase.auth.signOut();
  }

  Future<void> dispose() async {
    _isRegistered = false;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    await _sub?.cancel();
    _sub = null;
  }
}
