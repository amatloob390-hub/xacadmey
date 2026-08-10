import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';

/// لاگ اِن یوزر کا نام اور ای میل دکھانے والا بینر
/// (ٹیچر ڈیش بورڈ اور اسٹوڈنٹ کلاس لسٹ دونوں میں استعمال ہوتا ہے)
///
/// نام سب سے پہلے profiles table سے لیا جاتا ہے (سب سے قابلِ اعتماد ذریعہ)،
/// پھر user_metadata، پھر ای میل کا پہلا حصہ۔
class UserBanner extends StatefulWidget {
  const UserBanner({super.key});

  @override
  State<UserBanner> createState() => _UserBannerState();
}

class _UserBannerState extends State<UserBanner> {
  final _supabase = Supabase.instance.client;
  String? _name;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    String? name;
    String? role;

    // ۱) profiles table سے full_name اور role
    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .maybeSingle();
      role = (row?['role'] as String?)?.trim();
      name = _realName(row?['full_name'] as String?);
    } catch (_) {}

    // ۲) user_metadata سے full_name
    name ??= _realName(user.userMetadata?['full_name'] as String?);

    if (mounted) {
      setState(() {
        _name = name;
        _role = role;
      });
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
    if (user == null) return const SizedBox.shrink();

    final email = user.email ?? '';
    final isStaff =
        _role == 'teacher' || _role == 'admin' || _role == 'manager';
    final fallback = isStaff
        ? L.t('اُستادِ محترم', 'Respected Teacher')
        : L.t('معزز طالبِ علم', 'Dear Student');
    final displayName =
        (_name != null && _name!.isNotEmpty) ? _name! : fallback;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Text(
                  displayName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${L.t('خوش آمدید', 'Welcome')}، $displayName',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
