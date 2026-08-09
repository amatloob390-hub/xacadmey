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
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SizedBox(height: 8),
                Center(
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.teal,
                    child: Text(
                      displayName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 36),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(displayName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
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
                const SizedBox(height: 28),
                FilledButton.icon(
                  icon: const Icon(Icons.lock_reset),
                  label: Text(L.t('پاس ورڈ بدلیں', 'Change Password')),
                  onPressed: () => showChangePasswordDialog(context),
                ),
              ],
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        subtitle: Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
