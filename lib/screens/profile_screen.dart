import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../widgets/change_password_button.dart';

/// یوزر کی پروفائل — نام، ای میل، رول، اور پاس ورڈ بدلنے کا آپشن۔
/// (ٹیچر اور اسٹوڈنٹ دونوں کیلئے مشترک)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name, email, role, is_verified')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _profile = row;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return L.t('ایڈمن', 'Admin');
      case 'teacher':
        return L.t('ٹیچر', 'Teacher');
      case 'manager':
        return L.t('مینیجر', 'Manager');
      default:
        return L.t('اسٹوڈنٹ', 'Student');
    }
  }

  /// placeholder (جیسے "نیا صارف"/"User") کو اصل نام نہ سمجھیں
  static String? _realName(String? n) {
    if (n == null) return null;
    final t = n.trim();
    if (t.isEmpty) return null;
    const placeholders = {'نیا صارف', 'صارف', 'new user', 'user'};
    if (placeholders.contains(t.toLowerCase())) return null;
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final email = _profile?['email'] as String? ?? user?.email ?? '';
    final name = _realName(_profile?['full_name'] as String?);
    final role = _profile?['role'] as String?;
    final isStaff = role == 'teacher' || role == 'admin' || role == 'manager';
    final fallback = isStaff
        ? L.t('اُستادِ محترم', 'Respected Teacher')
        : L.t('معزز طالبِ علم', 'Dear Student');
    final displayName = name ?? fallback;

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('پروفائل', 'Profile')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 24, 20),
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFF0C2738),
                          child: Text(
                            displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _InfoTile(
                      icon: Icons.email_outlined,
                      label: L.t('ای میل', 'Email'),
                      value: email.isNotEmpty ? email : '—',
                    ),
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      label: L.t('رول', 'Role'),
                      value: _roleLabel(role),
                    ),
                    _InfoTile(
                      icon: Icons.verified_user_outlined,
                      label: L.t('تصدیق شدہ', 'Verified'),
                      value: (_profile?['is_verified'] == true)
                          ? L.t('ہاں', 'Yes')
                          : L.t('نہیں', 'No'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.lock_reset),
                        label: Text(
                          L.t('پاس ورڈ بدلیں', 'Change Password'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () => showChangePasswordDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0C2738), const Color(0xFF132A4B)]
              : [const Color(0xFFE0F2FE), const Color(0xFFF0FDFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF10B981), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
