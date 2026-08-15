import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../screens/ai_chat_screen.dart';
import '../screens/landing_screen.dart';
import '../screens/manage_roles.dart';
import '../screens/pending_payments.dart';
import '../screens/pending_students.dart';
import '../screens/profile_screen.dart';
import '../screens/social_links_screen.dart';
import '../screens/student_approvals.dart';
import '../services/auth_service.dart';
import 'theme_selector.dart';

/// سائیڈ بار کا کون سا پین فی الحال کھلا ہے (isFixed وسیع لے آؤٹ میں
/// استعمال ہوتا ہے تاکہ صفحہ بدلنے پر بھی سائیڈ بار برقرار رہے)۔
/// ٹیچر اور اسٹوڈنٹ دونوں سائیڈ بار اسی ایک enum سے پین شیئر کرتے ہیں۔
enum TeacherPane { dashboard, approvals, payments, pendingFees, roles, social, profile, aiChat }

class AppDrawer extends StatefulWidget {
  final bool isTeacher;
  final bool isFixed;
  final String role;
  final VoidCallback? onOpenAiAssistant;
  final VoidCallback? onAddStudent;
  final VoidCallback? onRefresh;
  /// isFixed لے آؤٹ میں فی الحال منتخب پین — دیا گیا ہو تو نیویگیشن
  /// Navigator.push کی بجائے [onSelectTeacherPane] سے پین بدلتی ہے۔
  final TeacherPane? selectedTeacherPane;
  final ValueChanged<TeacherPane>? onSelectTeacherPane;

  const AppDrawer({
    super.key,
    this.isTeacher = false,
    this.isFixed = false,
    this.role = 'student',
    this.onOpenAiAssistant,
    this.onAddStudent,
    this.onRefresh,
    this.selectedTeacherPane,
    this.onSelectTeacherPane,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
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
        _role = role ?? widget.role;
      });
    }
  }

  void _nav(VoidCallback action) {
    if (!widget.isFixed) {
      Navigator.pop(context);
    }
    action();
  }

  /// isFixed (وسیع) لے آؤٹ میں pane بدلتا ہے تاکہ سائیڈ بار برقرار رہے؛
  /// ورنہ (موبائل ڈرار) پرانا Navigator.push رویہ استعمال کرتا ہے۔
  void _navTeacher(TeacherPane pane, VoidCallback pushFallback) {
    if (widget.isFixed && widget.onSelectTeacherPane != null) {
      widget.onSelectTeacherPane!(pane);
    } else {
      _nav(pushFallback);
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
            final effectiveRole = _role ?? widget.role;
            final isStaff = widget.isTeacher ||
                effectiveRole == 'teacher' ||
                effectiveRole == 'admin' ||
                effectiveRole == 'manager';

            final defaultFallback = isStaff
                ? L.t('اُستادِ محترم', 'Respected Teacher')
                : L.t('معزز طالبِ علم', 'Dear Student');
            final displayName = (_name != null && _name!.isNotEmpty)
                ? _name!
                : defaultFallback;
            final emailText = _email ?? '';

            final roleLabel = effectiveRole == 'admin'
                ? L.t('ایڈمن', 'Admin')
                : effectiveRole == 'teacher'
                    ? L.t('ٹیچر', 'Teacher')
                    : effectiveRole == 'manager'
                        ? L.t('مینیجر', 'Manager')
                        : L.t('طالبِ علم', 'Student');

            final isDark = theme.isDark;
            final drawerBg = theme.cardColor;
            final textColor = theme.textColor;
            final subtextColor = theme.subtextColor;
            final canManageRoles =
                effectiveRole == 'teacher' || effectiveRole == 'admin';

            final content = SafeArea(
              child: Column(
                children: [
                  // Header / User Profile Banner Section
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white,
                              child: Text(
                                displayName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 22,
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
                                roleLabel,
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
                          '${L.t('خوش آمدید', 'Welcome')}، $displayName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
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

                  // Scrollable Action Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 18, 10),
                      children: [
                        // 1. Home / Landing Website
                        _buildDrawerTile(
                          icon: Icons.home_rounded,
                          iconColor: const Color(0xFF2563EB),
                          title: L.t('مرکزی صفحہ (ہوم)', 'Home & Website'),
                          subtitle: L.t('اکیڈمی کا مرکزی صفحہ دیکھیں',
                              'Visit academy main website'),
                          textColor: textColor,
                          subtextColor: subtextColor,
                          isDark: isDark,
                          onTap: () => _nav(() => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LandingScreen()),
                              )),
                        ),
                        const SizedBox(height: 6),

                        if (!isStaff) ...[
                          // STUDENT NAVIGATION
                          // 2. Student Dashboard
                          _buildDrawerTile(
                            icon: Icons.school_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: L.t('ڈیش بورڈ اور کلاسز', 'My Dashboard & Classes'),
                            subtitle: L.t('تمام فعال کورسز اور لائیو کلاسز',
                                'Active courses and live classes'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            isSelected: !widget.isFixed ||
                                widget.selectedTeacherPane == null ||
                                widget.selectedTeacherPane == TeacherPane.dashboard,
                            onTap: () => _navTeacher(TeacherPane.dashboard, () {
                              if (!widget.isFixed) Navigator.pop(context);
                            }),
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
                            onTap: () => _nav(() {
                              if (widget.onOpenAiAssistant != null) {
                                widget.onOpenAiAssistant!();
                              }
                            }),
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
                            isSelected: widget.isFixed &&
                                widget.selectedTeacherPane == TeacherPane.aiChat,
                            onTap: () => _navTeacher(
                                TeacherPane.aiChat,
                                () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => const AiChatScreen()),
                                    )),
                          ),
                          const SizedBox(height: 6),
                        ] else ...[
                          // TEACHER / STAFF NAVIGATION
                          // 2. Teacher Dashboard
                          _buildDrawerTile(
                            icon: Icons.dashboard_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: L.t('کمانڈ سینٹر ڈیش بورڈ', 'Command Center'),
                            subtitle: L.t('کلاسز اور اینالیٹکس کا کنٹرول',
                                'Classes & overview analytics'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            isSelected: !widget.isFixed ||
                                widget.selectedTeacherPane == null ||
                                widget.selectedTeacherPane == TeacherPane.dashboard,
                            onTap: () => _navTeacher(TeacherPane.dashboard, () {
                              if (!widget.isFixed) Navigator.pop(context);
                            }),
                          ),
                          const SizedBox(height: 6),

                          // 3. Add Student
                          if (widget.onAddStudent != null)
                            _buildDrawerTile(
                              icon: Icons.person_add_alt_1_rounded,
                              iconColor: Colors.teal,
                              title: L.t('نیا اسٹوڈنٹ شامل کریں', 'Add New Student'),
                              subtitle: L.t('اسٹوڈنٹ کو براہِ راست انرول کریں',
                                  'Directly enroll student in class'),
                              textColor: textColor,
                              subtextColor: subtextColor,
                              isDark: isDark,
                              onTap: () => _nav(() {
                                widget.onAddStudent!();
                              }),
                            ),
                          if (widget.onAddStudent != null)
                            const SizedBox(height: 6),

                          // 4. Student Approvals
                          _buildDrawerTile(
                            icon: Icons.how_to_reg_rounded,
                            iconColor: Colors.green,
                            title: L.t('نئی تصدیقیں (Approvals)', 'Student Approvals'),
                            subtitle: L.t('رجسٹرڈ طلباء کی تصدیق اور کلاس تفویض',
                                'Verify registrations and assign class'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            isSelected: widget.isFixed &&
                                widget.selectedTeacherPane == TeacherPane.approvals,
                            onTap: () => _navTeacher(
                                TeacherPane.approvals,
                                () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const StudentApprovalsScreen()),
                                    )),
                          ),
                          const SizedBox(height: 6),

                          // 5. Payments
                          _buildDrawerTile(
                            icon: Icons.payments_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            title: L.t('ادائیگیاں اور رسیدیں', 'Payments & Receipts'),
                            subtitle: L.t('جمع شدہ فیسوں کا ریکارڈ دیکھیں',
                                'Review submitted fee receipts'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            isSelected: widget.isFixed &&
                                widget.selectedTeacherPane == TeacherPane.payments,
                            onTap: () => _navTeacher(
                                TeacherPane.payments,
                                () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const PendingPayments()),
                                    )),
                          ),
                          const SizedBox(height: 6),

                          // 6. Pending Fees
                          _buildDrawerTile(
                            icon: Icons.timelapse_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: L.t('زیرِ التوا فیس اور مہلت', 'Pending Fees & Grace'),
                            subtitle: L.t('مہلت ختم ہونے والے طلباء کی فہرست',
                                'Track students with expiring grace'),
                            textColor: textColor,
                            subtextColor: subtextColor,
                            isDark: isDark,
                            isSelected: widget.isFixed &&
                                widget.selectedTeacherPane == TeacherPane.pendingFees,
                            onTap: () => _navTeacher(
                                TeacherPane.pendingFees,
                                () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const PendingStudents()),
                                    )),
                          ),
                          const SizedBox(height: 6),

                          // 7. Roles & Managers
                          if (canManageRoles) ...[
                            _buildDrawerTile(
                              icon: Icons.admin_panel_settings_rounded,
                              iconColor: const Color(0xFF8B5CF6),
                              title: L.t('رول اور مینیجرز', 'Roles & Managers'),
                              subtitle: L.t('اسٹاف کے اختیارات اور رول تبدیل کریں',
                                  'Manage staff roles and access'),
                              textColor: textColor,
                              subtextColor: subtextColor,
                              isDark: isDark,
                              isSelected: widget.isFixed &&
                                  widget.selectedTeacherPane == TeacherPane.roles,
                              onTap: () => _navTeacher(
                                  TeacherPane.roles,
                                  () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ManageRolesScreen(
                                              isAdmin: widget.role == 'admin'),
                                        ),
                                      )),
                            ),
                            const SizedBox(height: 6),

                            // 8. Social links
                            _buildDrawerTile(
                              icon: Icons.share_rounded,
                              iconColor: const Color(0xFFEC4899),
                              title: L.t('سوشل میڈیا لنکس', 'Social Links'),
                              subtitle: L.t('اکیڈمی کے سوشل پیجز اور لنکس',
                                  'Manage academy social media channels'),
                              textColor: textColor,
                              subtextColor: subtextColor,
                              isDark: isDark,
                              isSelected: widget.isFixed &&
                                  widget.selectedTeacherPane == TeacherPane.social,
                              onTap: () => _navTeacher(
                                  TeacherPane.social,
                                  () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const SocialLinksScreen()),
                                      )),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],

                        // Profile Screen (Common)
                        _buildDrawerTile(
                          icon: Icons.account_circle_rounded,
                          iconColor: const Color(0xFF6366F1),
                          title: L.t('میری پروفائل', 'My Profile'),
                          subtitle: L.t('اکاؤنٹ معلومات اور پاس ورڈ سیٹنگز',
                              'Account info & password settings'),
                          textColor: textColor,
                          subtextColor: subtextColor,
                          isDark: isDark,
                          isSelected: widget.isFixed &&
                              widget.selectedTeacherPane == TeacherPane.profile,
                          onTap: () => _navTeacher(
                              TeacherPane.profile,
                              () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const ProfileScreen()),
                                  )),
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1),
                        ),

                        // Settings Header
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

                        // Language Toggle
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

                        // Theme Selector
                        _buildDrawerTile(
                          icon: Icons.palette_rounded,
                          iconColor: const Color(0xFFEC4899),
                          title: L.t('تھیم اور رنگ تبدیل کریں', 'Change Theme & Colors'),
                          subtitle: isUrdu
                              ? theme.nameUrdu
                              : theme.nameEnglish,
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

                        // Logout — end of the scrollable menu (not pinned)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            height: 1,
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        _buildDrawerTile(
                          icon: Icons.logout_rounded,
                          iconColor: Colors.red,
                          title: L.t('لاگ آؤٹ', 'Log out'),
                          subtitle: L.t('اکاؤنٹ سے باہر نکلیں', 'Sign out of your account'),
                          textColor: Colors.red,
                          subtextColor: Colors.red.withValues(alpha: 0.7),
                          isDark: isDark,
                          onTap: () => _confirmLogout(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            if (widget.isFixed) {
              return Container(
                decoration: BoxDecoration(
                  color: drawerBg,
                  border: Border(
                    // Inner border between sidebar and main content
                    right: isUrdu
                        ? BorderSide.none
                        : BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                    left: isUrdu
                        ? BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: content,
              );
            }

            return Drawer(
              backgroundColor: drawerBg,
              child: content,
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
