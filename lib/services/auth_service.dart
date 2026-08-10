import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_manager.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SessionManager _sessionManager = SessionManager();

  SessionManager get sessionManager => _sessionManager;

  /// نیا اکاؤنٹ (اسٹوڈنٹ غیر-تصدیق شدہ حالت میں بنے گا)۔
  /// [plan] = 'trial' | 'paid' | 'premier'؛ [classId] ہو تو اُسی class میں enroll۔
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String plan = 'trial',
    String? classId,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    final user = response.user;
    if (user != null) {
      // Profile — is_verified=false (teacher approval درکار)
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': fullName,
          'email': email,
          'is_verified': false,
          'role': 'student',
          'plan': plan,
        }, onConflict: 'id');
      } catch (_) {}

      // Admin notification entry (verification queue)
      try {
        await _supabase.from('verification_requests').insert({
          'user_id': user.id,
          'email': email,
          'full_name': fullName,
          'status': 'pending',
        });
      } catch (_) {}

      // link سے آیا ہو تو اُسی class میں enroll کر دیں
      if (classId != null && classId.isNotEmpty) {
        try {
          await _supabase.from('enrollments').upsert({
            'student_id': user.id,
            'user_id': user.id,
            'class_id': classId,
            'grace_until': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'payment_status': 'pending',
          }, onConflict: 'student_id,class_id');
        } catch (_) {}

        try {
          await _supabase.from('class_enrollments').upsert({
            'student_id': user.id,
            'user_id': user.id,
            'class_id': classId,
            'status': 'pending',
            'created_at': DateTime.now().toIso8601String(),
          }, onConflict: 'student_id,class_id');
        } catch (_) {}

        try {
          await _supabase.rpc('enroll_in_class', params: {'p_class_id': classId});
        } catch (_) {}
      }

      // اگر ٹیچر نے اس ای میل کو پہلے دعوت دی ہو تو خودکار verify + enroll
      try {
        await _supabase.rpc('claim_invite');
      } catch (_) {}
    }
  }

  /// لاگ ان + ایڈمن تصدیق چیک (xacademy321@gmail.com) + سنگل ڈیوائس رجسٹریشن
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user != null) {
      // Profile se is_verified aur role چیک کریں
      try {
        final profile = await _supabase
            .from('profiles')
            .select('is_verified, role, is_trial, trial_until')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          final isVerified = profile['is_verified'];
          final role = (profile['role'] as String?) ?? 'student';

          // صرف اگر is_verified واضع طور پر false ہو، تب ہی بلاک کریں
          if (role == 'student' && isVerified == false) {
            await signOut();
            throw const AuthException(
              'PENDING_ADMIN_VERIFICATION: آپ کا اکاؤنٹ ابھی تصدیق کا منتظر ہے۔ ٹیچر سے تصدیق کروانے کے بعد ہی لاگ اِن ممکن ہوگا۔',
            );
          }

          // ٹرائل کے ساتھ منظور شدہ اسٹوڈنٹ: مدت ختم ہو تو بلاک کریں
          if (role == 'student' && isVerified == true && profile['is_trial'] == true) {
            final trialUntilStr = profile['trial_until'] as String?;
            final trialUntil =
                trialUntilStr != null ? DateTime.tryParse(trialUntilStr) : null;
            if (trialUntil != null && DateTime.now().isAfter(trialUntil)) {
              await signOut();
              throw const AuthException(
                'TRIAL_EXPIRED: آپ کی ٹرائل مدت ختم ہو چکی ہے۔ رسائی جاری رکھنے کے لیے براہِ کرم فیس جمع کروائیں۔',
              );
            }
          }
        }
      } catch (e) {
        if (e is AuthException) rethrow;
      }
    }

    try {
      await _sessionManager.start();
    } catch (_) {}
  }

  /// یوزر کا رول حاصل کریں (نیویگیشن کیلئے)
  Future<String> getRole() async {
    final userId = _supabase.auth.currentUser!.id;
    final data = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();
    return data['role'] as String;
  }

  Future<void> signOut() async {
    await _sessionManager.dispose();
    await _supabase.auth.signOut();
  }
}
