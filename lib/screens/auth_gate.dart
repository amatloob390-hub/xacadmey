import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../app_mode.dart';
import '../services/auth_service.dart';
import '../widgets/logout_button.dart';
import 'landing_screen.dart';
import 'teacher_dashboard.dart';
import 'student_class_list.dart';

const _staffRoles = {'teacher', 'admin', 'manager'};

class AuthGate extends StatelessWidget {
  /// کون سی ایپ چل رہی ہے — combined/staff/student
  final AppMode mode;
  const AuthGate({super.key, this.mode = AppMode.combined});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LandingScreen();
        }
        return _RoleRouter(mode: mode);
      },
    );
  }
}

class _RoleRouter extends StatefulWidget {
  final AppMode mode;
  const _RoleRouter({required this.mode});

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  final AuthService _auth = AuthService();
  late Future<String> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = _auth.getRole();
    // ایپ ری اسٹارٹ کے بعد سیشن بحال ہو تو نگرانی دوبارہ شروع
    _auth.sessionManager.start();
    _auth.sessionManager.onForceLogout = () async {
      await _auth.signOut();
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(
                  child: Text(L.t('رول لوڈ نہیں ہو سکا۔', 'Could not load role.'))));
        }
        final role = snapshot.data ?? 'student';
        final isStaff = _staffRoles.contains(role);

        switch (widget.mode) {
          // ایڈمن/اسٹاف ایپ — صرف staff اندر آئے
          case AppMode.staff:
            if (isStaff) return TeacherDashboard(role: role);
            return _WrongAppScreen(
              message: L.t(
                'یہ ایڈمن ایپ ہے۔ اسٹوڈنٹ لاگ اِن کے لیے اسٹوڈنٹ ایپ استعمال کریں۔',
                'This is the admin app. Students should use the student app.',
              ),
            );

          // اسٹوڈنٹ ایپ — صرف students اندر آئیں
          case AppMode.student:
            if (!isStaff) return const StudentClassList();
            return _WrongAppScreen(
              message: L.t(
                'یہ اسٹوڈنٹ ایپ ہے۔ اسٹاف لاگ اِن کے لیے ایڈمن ایپ استعمال کریں۔',
                'This is the student app. Staff should use the admin app.',
              ),
            );

          // مشترکہ (ڈیولپمنٹ) — رول کے مطابق روٹنگ
          case AppMode.combined:
            if (isStaff) return TeacherDashboard(role: role);
            return const StudentClassList();
        }
      },
    );
  }
}

/// غلط ایپ میں لاگ اِن ہونے پر پیغام + لاگ آؤٹ
class _WrongAppScreen extends StatelessWidget {
  final String message;
  const _WrongAppScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('غلط ایپ', 'Wrong app')),
        actions: const [LogoutButton()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.info_outline, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}
