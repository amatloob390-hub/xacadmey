import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_lang.dart';
import '../services/teacher_service.dart';
import '../widgets/create_class_dialog.dart';
import '../widgets/add_student_dialog.dart';
import '../widgets/logout_button.dart';
import '../widgets/landing_button.dart';
import '../widgets/user_banner.dart';
import '../widgets/theme_selector.dart';
import '../widgets/app_drawer.dart';
import '../widgets/dashboard_analytics_card.dart';
import 'profile_screen.dart';
import 'social_links_screen.dart';
import 'student_approvals.dart';
import 'attendance_report.dart';
import 'pending_payments.dart';
import 'pending_students.dart';
import 'manage_roles.dart';

class TeacherDashboard extends StatefulWidget {
  /// 'teacher' | 'admin' | 'manager'
  final String role;
  const TeacherDashboard({super.key, this.role = 'teacher'});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final TeacherService _service = TeacherService();

  // وسیع (isFixed) لے آؤٹ میں فی الحال کھلا پین — سائیڈ بار سب صفحات پر برقرار
  // رہنے کیلئے Navigator.push کی بجائے یہاں سے کنٹرول ہوتا ہے۔
  TeacherPane _pane = TeacherPane.dashboard;

  // teacher/admin کلاسز بنا/ایڈٹ کر سکتے اور رول دے سکتے ہیں؛ manager نہیں۔
  bool get _canManageClasses =>
      widget.role == 'teacher' || widget.role == 'admin';
  bool get _canAssignRoles =>
      widget.role == 'teacher' || widget.role == 'admin';

  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final rows = await _service.myClasses();
      if (!mounted) return;
      setState(() {
        _classes = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _toggle(int index, bool active) async {
    final id = _classes[index]['id'] as String;
    setState(() => _classes[index]['is_active'] = active);
    try {
      await _service.setActive(id, active);
    } catch (_) {
      if (!mounted) return;
      setState(() => _classes[index]['is_active'] = !active);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('تبدیلی محفوظ نہیں ہوئی، دوبارہ کوشش کریں۔',
              'Change not saved, please try again.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    // وسیع لے آؤٹ میں AppBar کے quick-icons بھی سائیڈ بار پین ہی بدلیں
    // (Navigator.push نہیں) تاکہ سائیڈ بار برقرار رہے۔ تنگ لے آؤٹ میں
    // پرانا مکمل صفحہ push والا رویہ برقرار رہتا ہے۔
    void goTo(TeacherPane pane, VoidCallback pushFallback) {
      if (isWide) {
        setState(() => _pane = pane);
      } else {
        pushFallback();
      }
    }

    final mainContent = Column(
      children: [
        const UserBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: _buildBody(),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      drawer: isWide
          ? null
          : AppDrawer(
              isTeacher: true,
              role: widget.role,
              onAddStudent: _openAddStudentDialog,
              onRefresh: _load,
            ),
      appBar: AppBar(
        leading: isWide
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, size: 26),
                  tooltip: L.t('سائیڈ بار / مینو کھولیں', 'Open Sidebar / Menu'),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: Text(L.t('ٹیچر کمانڈ سینٹر و ڈیش بورڈ', 'Teacher Command Center & Dashboard')),
        actions: [
          const LandingButton(),
          const LanguageToggle(),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: L.t('تازہ کریں', 'Refresh'),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: Colors.teal),
            tooltip: L.t('اسٹوڈنٹ شامل کریں', 'Add Student'),
            onPressed: _openAddStudentDialog,
          ),
          IconButton(
            icon: const Icon(Icons.how_to_reg, color: Colors.green),
            tooltip: L.t('نئی تصدیقیں', 'Student Approvals'),
            onPressed: () => goTo(
                TeacherPane.approvals,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StudentApprovalsScreen()))),
          ),
          IconButton(
            icon: const Icon(Icons.payments_outlined),
            tooltip: L.t('ادائیگیاں', 'Payments'),
            onPressed: () => goTo(
                TeacherPane.payments,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PendingPayments()))),
          ),
          IconButton(
            icon: const Icon(Icons.timelapse),
            tooltip: L.t('زیرِ التوا فیس', 'Pending Fees'),
            onPressed: () => goTo(
                TeacherPane.pendingFees,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PendingStudents()))),
          ),
          if (_canAssignRoles)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Color(0xFFB9B2FF)),
              tooltip: L.t('رول اور مینیجرز', 'Roles & Managers'),
              onPressed: () => goTo(
                  TeacherPane.roles,
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ManageRolesScreen(
                              isAdmin: widget.role == 'admin')))),
            ),
          if (_canAssignRoles)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: L.t('سوشل میڈیا لنکس', 'Social links'),
              onPressed: () => goTo(
                  TeacherPane.social,
                  () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SocialLinksScreen()))),
            ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: L.t('پروفائل', 'Profile'),
            onPressed: () => goTo(
                TeacherPane.profile,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()))),
          ),
          const ThemeSelectorButton(),
          const LogoutButton(),
        ],
      ),
      floatingActionButton: _canManageClasses && (!isWide || _pane == TeacherPane.dashboard)
          ? FloatingActionButton.extended(
              onPressed: _openCreateDialog,
              backgroundColor: Colors.teal,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(L.t('نئی کلاس بنائیں۔', 'New Class'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 290,
                  child: AppDrawer(
                    isFixed: true,
                    isTeacher: true,
                    role: widget.role,
                    onAddStudent: _openAddStudentDialog,
                    onRefresh: _load,
                    selectedTeacherPane: _pane,
                    onSelectTeacherPane: (p) => setState(() => _pane = p),
                  ),
                ),
                Expanded(child: _buildPaneContent(mainContent)),
              ],
            )
          : mainContent,
    );
  }

  /// وسیع لے آؤٹ میں سائیڈ بار سے منتخب پین کا مواد — سائیڈ بار ہر پین پر
  /// برقرار رہتا ہے، صفحہ بدلنے پر مکمل route push نہیں ہوتا۔
  Widget _buildPaneContent(Widget dashboardContent) {
    switch (_pane) {
      case TeacherPane.dashboard:
        return dashboardContent;
      case TeacherPane.approvals:
        return const StudentApprovalsScreen();
      case TeacherPane.payments:
        return const PendingPayments();
      case TeacherPane.pendingFees:
        return const PendingStudents();
      case TeacherPane.roles:
        return ManageRolesScreen(isAdmin: widget.role == 'admin');
      case TeacherPane.social:
        return const SocialLinksScreen();
      case TeacherPane.profile:
        return const ProfileScreen();
    }
  }

  Widget _buildAnalyticsSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                L.t('کلاس اینالیٹکس و کارکردگی', 'Class Analytics & Overview'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _openAddStudentDialog,
                icon: const Icon(Icons.person_add, size: 16),
                label: Text(L.t('اسٹوڈنٹ شامل کریں', 'Add Student')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 650;
              final totalClasses = _classes.length;
              final activeClasses = _classes
                  .where((c) => (c['is_active'] as bool? ?? false))
                  .length;
              final totalDurationMin = _classes.fold<int>(
                  0, (sum, c) => sum + (c['duration_min'] as int? ?? 60));
              final totalHours = (totalDurationMin / 60.0).toStringAsFixed(1);
              final activeRatio = totalClasses > 0 ? (activeClasses / totalClasses) : 0.0;
              final activePercent = '${(activeRatio * 100).toInt()}%';

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isWide ? (constraints.maxWidth * 0.48 - 10) : constraints.maxWidth,
                    child: RadialGaugeCard(
                      title: L.t('کلاسز کا وقت', 'Class Duration'),
                      valueText: '$totalHours ${L.t('گھنٹے', 'hrs')}',
                      subtext: '$totalClasses ${L.t('کلاسز کا شیڈول وقت', 'Scheduled classes time')}',
                      progress: totalClasses > 0
                          ? (totalDurationMin / (totalClasses * 60.0)).clamp(0.1, 1.0)
                          : 0.1,
                      primaryColor: const Color(0xFF10B981),
                      icon: Icons.video_call_outlined,
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth * 0.48 - 10) : constraints.maxWidth,
                    child: RadialGaugeCard(
                      title: L.t('فعال کلاسز کا تناسب', 'Active Classes Rate'),
                      valueText: activePercent,
                      subtext: '$activeClasses ${L.t('میں سے', 'out of')} $totalClasses ${L.t('کلاسز لائیو / فعال', 'classes active')}',
                      progress: activeRatio.clamp(0.05, 1.0),
                      primaryColor: const Color(0xFF10B981),
                      icon: Icons.groups_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // Quick Action Hub Buttons Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickActionButton(
                  icon: Icons.how_to_reg,
                  color: Colors.green,
                  label: L.t('نئی تصدیقیں', 'Approvals'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentApprovalsScreen())),
                ),
                const SizedBox(width: 10),
                _quickActionButton(
                  icon: Icons.receipt_long_outlined,
                  color: Colors.purple,
                  label: L.t('فیس ادائیگیاں', 'Pending Claims'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingPayments())),
                ),
                const SizedBox(width: 10),
                _quickActionButton(
                  icon: Icons.person_remove_outlined,
                  color: Colors.amber.shade900,
                  label: L.t('زیرِ التوا فیس و ٹرائلز', 'Trial Grace Management'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingStudents())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return _messageList(L.t('ڈیٹا لوڈ نہیں ہو سکا — نیچے کھینچ کر دوبارہ کوشش کریں۔',
          'Could not load data — pull down to retry.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildAnalyticsSection(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  L.t('آپ کی فعال کلاسز', 'Your Active Classes'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_canManageClasses)
                  TextButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add_circle_outline, color: Colors.teal),
                    label: Text(L.t('نئی کلاس بنائیں', 'Create Class'), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_classes.isEmpty)
              _messageList(_canManageClasses
                  ? L.t('ابھی کوئی کلاس نہیں — نئی کلاس بنائیں۔', 'No classes yet — create one.')
                  : L.t('اوپر بٹنوں سے اسٹوڈنٹ شامل/تصدیق اور ادائیگیاں دیکھیں۔',
                      'Use the buttons above to add/verify students and view payments.'))
            else if (isWide)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.1,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                itemCount: _classes.length,
                itemBuilder: (context, i) => _ClassCard(
                  data: _classes[i],
                  onToggle: (active) => _toggle(i, active),
                  onEdit: () => _openEditDialog(_classes[i]),
                  onDelete: () => _confirmDelete(_classes[i]['id']),
                ),
              )
            else
              ..._classes.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return _ClassCard(
                  data: item,
                  onToggle: (active) => _toggle(i, active),
                  onEdit: () => _openEditDialog(item),
                  onDelete: () => _confirmDelete(item['id']),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _messageList(String msg) => Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: Colors.grey)),
      );

  Future<void> _openAddStudentDialog() async {
    await showDialog(
      context: context,
      builder: (_) => const AddStudentDialog(),
    );
  }

  Future<void> _openCreateDialog() async {
    await showDialog(
      context: context,
      builder: (_) => CreateClassDialog(service: _service),
    );
    _load();
  }

  Future<void> _openEditDialog(Map<String, dynamic> existing) async {
    await showDialog(
      context: context,
      builder: (_) => CreateClassDialog(service: _service, existing: existing),
    );
    _load();
  }

  Future<void> _confirmDelete(String classId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L.t('کلاس ڈیلیٹ کریں؟', 'Delete class?')),
        content: Text(L.t('یہ عمل واپس نہیں ہو سکتا۔', 'This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('منسوخ', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.t('ڈیلیٹ', 'Delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteClass(classId);
      _load();
    }
  }
}

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClassCard({
    required this.data,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = data['is_active'] as bool? ?? false;
    final title = data['title'] as String? ?? '—';
    final scheduled = DateTime.tryParse(data['scheduled_at'] ?? '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0C2738), const Color(0xFF132A4B)]
              : [const Color(0xFFE0F2FE), const Color(0xFFF0FDFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isActive
              ? const Color(0xFF10B981)
              : (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFF93C5FD)),
          width: isActive ? 2.0 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.22)
                : const Color(0xFF2563EB).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isActive ? L.t('لائیو', 'Live') : L.t('بند', 'Off'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isActive ? const Color(0xFF10B981) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Switch(
                    value: isActive,
                    onChanged: onToggle,
                    activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                    activeThumbColor: const Color(0xFF10B981),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (scheduled != null)
                      Text(
                        '${L.t('وقت', 'Time')}: ${scheduled.day}/${scheduled.month} ${scheduled.hour}:${scheduled.minute.toString().padLeft(2, '0')}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.cast_for_education_rounded, color: Color(0xFF10B981), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.link, color: Color(0xFF10B981)),
                tooltip: L.t('کلاس کا لنک کاپی کریں', 'Copy class link'),
                onPressed: () {
                  final link = '${Uri.base.origin}/?class=${data['id']}';
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(L.t(
                        'کلاس کا لنک کاپی ہو گیا — طلبہ کو بھیجیں۔',
                        'Class link copied — share it with students.')),
                    backgroundColor: const Color(0xFF059669),
                  ));
                },
              ),
              IconButton(
                icon: const Icon(Icons.people_outline, color: Colors.blueAccent),
                tooltip: L.t('حاضری رپورٹ', 'Attendance'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceReport(
                      classId: data['id'],
                      classTitle: data['title'] ?? 'Class',
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, color: Colors.orange),
                tooltip: L.t('ایڈٹ کریں', 'Edit'),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                tooltip: L.t('ڈیلیٹ', 'Delete'),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
