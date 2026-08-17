import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../services/auth_service.dart';

/// AppBar میں avatar + نام + ڈراپ ڈاؤن (Profile / Logout) — ایک ساتھ۔
class ProfileMenuButton extends StatefulWidget {
  final VoidCallback onProfileTap;
  const ProfileMenuButton({super.key, required this.onProfileTap});

  @override
  State<ProfileMenuButton> createState() => _ProfileMenuButtonState();
}

class _ProfileMenuButtonState extends State<ProfileMenuButton> {
  final _supabase = Supabase.instance.client;
  String? _name;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    String? name;
    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      name = _realName(row?['full_name'] as String?);
    } catch (_) {}
    name ??= _realName(user.userMetadata?['full_name'] as String?);
    if (mounted) setState(() => _name = name);
  }

  static String? _realName(String? n) {
    if (n == null) return null;
    final t = n.trim();
    if (t.isEmpty) return null;
    const placeholders = {'نیا صارف', 'صارف', 'new user', 'user'};
    if (placeholders.contains(t.toLowerCase())) return null;
    return t;
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L.t('لاگ آؤٹ کریں؟', 'Log out?')),
        content: Text(L.t('کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟',
            'Are you sure you want to log out?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('منسوخ', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.t('لاگ آؤٹ', 'Log out'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final email = user?.email ?? '';
    final displayName =
        _name ?? (email.contains('@') ? email.split('@').first : L.t('صارف', 'User'));

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 44),
      onSelected: (v) {
        if (v == 'profile') widget.onProfileTap();
        if (v == 'logout') _confirmLogout(context);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.account_circle_outlined, size: 18),
              const SizedBox(width: 10),
              Text(L.t('پروفائل', 'Profile')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 18, color: Colors.red),
              const SizedBox(width: 10),
              Text(L.t('لاگ آؤٹ', 'Log out'), style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: const Color(0xFF10B981),
            child: Text(
              displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18),
        ],
      ),
    );
  }
}
