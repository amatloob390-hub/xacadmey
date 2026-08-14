import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/profile_screen.dart';
import '../services/auth_service.dart';
import 'theme_selector.dart';

class StudentDrawer extends StatefulWidget {
  final VoidCallback? onOpenAiAssistant;

  const StudentDrawer({
    super.key,
    this.onOpenAiAssistant,
  });

  @override
  State<StudentDrawer> createState() => _StudentDrawerState();
}

class _StudentDrawerState extends State<StudentDrawer> {
  final _supabase = Supabase.instance.client;
  String? _name;
  String? _email;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _email = user.email;
    String? name;
    String? role;

    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name, role')
          .eq('id', user.id)
          .maybeSingle();
      role = (row?['role'] as String?)?.trim();
      name = (row?['full_name'] as String?)?.trim();
    } catch (_) {}

    name ??= (user.userMetadata?['full_name'] as String?)?.trim();

    if (mounted) {
      setState(() {
        _name = name;
        _role = role;
      });
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L.t('لاگ آؤٹ کریں؟', 'Log out?')),
        content: Text(
          L.t('کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟',
              'Are you sure you want to log out?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('منسوخ', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              L.t('لاگ آؤٹ', 'Log out'),
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLang.isUrdu,
      builder: (context, isUrdu, _) {
        return ValueListenableBuilder<ThemePreset>(
          valueListenable: AppTheme.currentTheme,
          builder: (context, theme, _) {
            final displayName = (_name != null && _name!.isNotEmpty)
                ? _name!
                : L.t('معزز طالبِ علم', 'Dear Student');
            final emailText = _email ?? '';
            final roleText = _role == 'teacher'
                ? L.t('ٹیچر', 'Teacher')
                : _role == 'admin'
                    ? L.t('ایڈمن', 'Admin')
                    : L.t('طالبِ علم', 'Student');

            final isDark = theme.isDark;
            final drawerBg = theme.cardColor;
            final textColor = theme.textColor;
            final subtextColor = theme.subtextColor;

            return Drawer(
              backgroundColor: drawerBg,
              child: SafeArea(
                child: Column(
                  children: [
                    // Header Section with Gradient
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white,
                                child: Text(
                                  displayName.substring(0, 1).toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  roleText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (emailText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              emailText,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Navigation and Action Items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        children: [
                          // 1. Home / Landing
                          _buildDrawerTile(
                            icon: Icons.home_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: L.t('مرکزی صفحہ (ہوم)', 'Home & Website'),
                            subtitle: L.t('اکیڈمی کا مرکزی صفحہ دیکھیں',
                                'Visit academy main website'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LandingScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 6),

                          // 2. Dashboard / Classes
                          _buildDrawerTile(
                            icon: Icons.school_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: L.t('ڈیش بورڈ اور کلاسز', 'My Dashboard & Classes'),
                            subtitle: L.t('تمام فعال کورسز اور لائیو کلاسز',
                                'Active courses and live classes'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            isSelected: true,
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(height: 6),

                          // 3. AI Teaching Assistant
                          _buildDrawerTile(
                            icon: Icons.auto_awesome_rounded,
                            iconColor: Colors.teal,
                            title: L.t('AI تدریسی اسسٹنٹ', 'AI Teaching Assistant'),
                            subtitle: L.t('سبق کا خلاصہ، اہم نکات اور فوری کوئز',
                                'Lecture summary & quick quiz'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: Colors.teal.withValues(alpha: 0.5)),
                              ),
                              child: const Text(
                                'AI',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              if (widget.onOpenAiAssistant != null) {
                                widget.onOpenAiAssistant!();
                              }
                            },
                          ),
                          const SizedBox(height: 6),

                          // 4. AI Chat Screen
                          _buildDrawerTile(
                            icon: Icons.psychology_rounded,
                            iconColor: Colors.purple,
                            title: L.t('AI اسٹڈی چیٹ', 'AI Study Chat'),
                            subtitle: L.t('تعلیمی سوالات کے فوری جوابات حاصل کریں',
                                'Get instant academic explanations'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AiChatScreen()),
                              );
                            },
                          ),
                          const SizedBox(height: 6),

                          // 5. Profile Screen
                          _buildDrawerTile(
                            icon: Icons.account_circle_rounded,
                            iconColor: const Color(0xFF6366F1),
                            title: L.t('میری پروفائل', 'My Profile'),
                            subtitle: L.t('اکاؤنٹ معلومات اور پاس ورڈ سیٹنگز',
                                'Account info & password settings'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ProfileScreen()),
                              );
                            },
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Divider(height: 1),
                          ),

                          // Settings Title
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            child: Text(
                              L.t('سیٹنگز اور ترجیحات', 'Settings & Preferences'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: subtextColor,
                              ),
                            ),
                          ),

                          // 6. Language Toggle Tile
                          _buildDrawerTile(
                            icon: Icons.language_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: isUrdu ? 'اردو (Urdu)' : 'English',
                            subtitle: isUrdu
                                ? 'Switch to English'
                                : 'اردو میں تبدیل کریں',
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                isUrdu ? 'EN' : 'اردو',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            onTap: () => AppLang.toggle(),
                          ),
                          const SizedBox(height: 6),

                          // 7. Theme Selector Tile
                          _buildDrawerTile(
                            icon: Icons.palette_rounded,
                            iconColor: const Color(0xFFEC4899),
                            title: L.t('تھیم اور رنگ تبدیل کریں', 'Change Theme & Colors'),
                            subtitle: isUrdu ? theme.nameUrdu : theme.nameEnglish,
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            trailing: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.primaryColor,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                            ),
                            onTap: () => ThemeSelectorDialog.show(context),
                          ),
                        ],
                      ),
                    ),

                    // 8. Logout Button at bottom
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      child: _buildDrawerTile(
                        icon: Icons.logout_rounded,
                        iconColor: Colors.red,
                        title: L.t('لاگ آؤٹ', 'Log out'),
                        subtitle: L.t('اکاؤنٹ سے باہر نکلیں', 'Sign out of your account'),
                        textColor: Colors.red,
                        subtextColor: Colors.red.withValues(alpha: 0.7),
                        isDark: isDark,
                        onTap: () => _confirmLogout(context),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subtextColor,
    required bool isDark,
    required VoidCallback onTap,
    Widget? trailing,
    bool isSelected = false,
  }) {
    return Material(
      color: isSelected
          ? iconColor.withValues(alpha: isDark ? 0.2 : 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: iconColor.withValues(alpha: 0.5), width: 1.2)
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
