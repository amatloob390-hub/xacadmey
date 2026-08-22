import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_manager.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SessionManager _sessionManager = SessionManager();

  SessionManager get sessionManager => _sessionManager;

  /// نیا اکاؤنٹ (اسٹوڈنٹ غیر-تصدیق شدہ حالت میں بنے گا)۔
  /// [plan] = 'trial' | 'paid' | 'premier'؛ [classId] ہو تو اُسی class میں enroll۔
  /// [phone] موبائل نمبر (اب signup پر ہی خود اسٹوڈنٹ بھرتا ہے)۔
  /// [receiptImageBase64] صرف 'paid' پلان کیلئے — فیس سلپ کی تصویر۔
  /// [membershipCard]/[membershipFee] صرف 'premier' پلان کیلئے — منتخب کردہ کارڈ۔
  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    String plan = 'trial',
    String? classId,
    String? phone,
    String? receiptImageBase64,
    String? membershipCard,
    double? membershipFee,
  }) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'plan': plan,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (classId != null && classId.isNotEmpty) 'registered_class_id': classId,
        if (classId != null && classId.isNotEmpty) 'class_id': classId,
      },
    );

    final user = response.user;
    if (user != null) {
      // 'trial' منتخب کرنے والا فوراً 7 دن کیلئے خودکار تصدیق شدہ — ٹیچر
      // منظوری کی ضرورت نہیں۔ باقی (paid/premier) is_verified=false ہی
      // رہتے ہیں — فیس سلپ جمع کروانے اور ٹیچر منظوری کے منتظر۔
      final isTrialPlan = plan == 'trial';

      // Profile
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'full_name': fullName,
          'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          'is_verified': isTrialPlan,
          'is_trial': isTrialPlan,
          if (isTrialPlan)
            'trial_until':
                DateTime.now().add(const Duration(days: 7)).toIso8601String(),
          'role': 'student',
          'plan': plan,
          if (classId != null && classId.isNotEmpty) 'registered_class_id': classId,
        }, onConflict: 'id');
      } catch (_) {}

      // خودکار ٹرائل — SECURITY DEFINER RPC (self_start_trial) حتمی/مستند
      // ذریعہ ہے، اوپر والا upsert صرف فوری/optimistic قدر کیلئے۔
      if (isTrialPlan) {
        try {
          await _supabase.rpc('self_start_trial', params: {'p_days': 7});
        } catch (_) {}
      }

      // Admin notification entry (verification queue) — صرف paid/premier
      // کیلئے، چونکہ trial کو کسی منظوری کی ضرورت نہیں۔
      if (!isTrialPlan) {
        try {
          await _supabase.from('verification_requests').insert({
            'user_id': user.id,
            'email': email,
            'full_name': fullName,
            'status': 'pending',
            if (phone != null && phone.isNotEmpty) 'phone': phone,
            if (plan == 'paid' &&
                receiptImageBase64 != null &&
                receiptImageBase64.isNotEmpty)
              'receipt_image': receiptImageBase64,
            if (plan == 'premier' && membershipCard != null)
              'membership_card': membershipCard,
            if (plan == 'premier' && membershipFee != null)
              'membership_fee': membershipFee,
          });
        } catch (_) {}
      }

      // link سے آیا ہو تو اُسی class میں enroll کر دیں
      if (classId != null && classId.isNotEmpty) {
        // کلاس خود ٹیچر کی طرف سے "Free" مارک ہو تو کوئی فیس درکار نہیں —
        // پلان (trial/paid) سے قطع نظر یہ enrollment ہمیشہ paid/approved۔
        bool classIsFree = false;
        try {
          final row = await _supabase
              .from('classes')
              .select('is_free')
              .eq('id', classId)
              .maybeSingle();
          classIsFree = row?['is_free'] == true;
        } catch (_) {}

        try {
          await _supabase.from('enrollments').upsert({
            'student_id': user.id,
            'user_id': user.id,
            'class_id': classId,
            'grace_until': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'payment_status':
                classIsFree ? 'paid' : (isTrialPlan ? 'trial' : 'pending'),
          }, onConflict: 'student_id,class_id');
        } catch (_) {}

        try {
          await _supabase.from('class_enrollments').upsert({
            'student_id': user.id,
            'user_id': user.id,
            'class_id': classId,
            'status': (classIsFree || isTrialPlan) ? 'approved' : 'pending',
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
      String role = 'student';
      // Profile se is_verified aur role چیک کریں
      try {
        final profile = await _supabase
            .from('profiles')
            .select('is_verified, role, is_trial, trial_until')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          final isVerified = profile['is_verified'];
          role = (profile['role'] as String?) ?? 'student';

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
        // پروفائل/تصدیق چیک ناکام ہو (نیٹ ورک/RLS مسئلہ) تو خاموشی سے
        // آگے نہ بڑھیں — ورنہ غیر-تصدیق شدہ/ٹرائل-ختم اسٹوڈنٹ کا چیک
        // نظرانداز ہو کر لاگ اِن ہو جاتا۔ صریح خطا دیں تاکہ صارف دوبارہ
        // کوشش کرے۔
        await signOut();
        throw const AuthException(
          'VERIFICATION_CHECK_FAILED: تصدیق چیک نہیں ہو سکی، دوبارہ کوشش کریں۔',
        );
      }

      // Membership card کی میعاد ختم ہونے پر رسائی بند — الگ try/catch
      // (خاموش ناکامی) تاکہ card-issuance migration نہ چلی ہو تب بھی
      // عام طلبہ کا لاگ اِن متاثر نہ ہو۔
      if (role == 'student') {
        try {
          final cardRow = await _supabase
              .from('verification_requests')
              .select('card_expiry_date')
              .eq('user_id', user.id)
              .eq('status', 'approved')
              .not('card_expiry_date', 'is', null)
              .order('card_expiry_date', ascending: false)
              .limit(1)
              .maybeSingle();
          final expiryStr = cardRow?['card_expiry_date'] as String?;
          final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
          if (expiry != null && DateTime.now().isAfter(expiry)) {
            await signOut();
            throw const AuthException(
              'MEMBERSHIP_EXPIRED: آپ کے membership card کی میعاد ختم ہو چکی ہے۔ دوبارہ رسائی کیلئے تجدید کروائیں۔',
            );
          }
        } catch (e) {
          if (e is AuthException) rethrow;
        }
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
