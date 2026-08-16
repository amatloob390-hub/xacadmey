import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../widgets/teal_box.dart';

class StudentApprovalsScreen extends StatefulWidget {
  const StudentApprovalsScreen({super.key});

  @override
  State<StudentApprovalsScreen> createState() => _StudentApprovalsScreenState();
}

class _StudentApprovalsScreenState extends State<StudentApprovalsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _pendingStudents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingStudents();
  }

  Future<void> _loadPendingStudents() async {
    setState(() => _loading = true);
    final Map<String, Map<String, dynamic>> map = {};

    // 1. list_pending_students RPC
    try {
      final res = await _supabase.rpc('list_pending_students');
      if (res is List) {
        for (var r in res) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = m['id']?.toString() ??
              m['user_id']?.toString() ??
              m['student_id']?.toString() ??
              '';
          if (id.isNotEmpty) {
            map[id] = {
              'id': id,
              'full_name': m['full_name']?.toString() ??
                  m['student_name']?.toString() ??
                  'اسٹوڈنٹ',
              'email': m['email']?.toString() ?? '',
              'is_trial': m['is_trial'] == true,
            };
          }
        }
      }
    } catch (_) {}

    // 2. Direct profiles table query for all unverified or trial students
    try {
      final rows = await _supabase
          .from('profiles')
          .select('id, full_name, email, role, is_verified, is_trial, trial_until')
          .neq('role', 'teacher')
          .neq('role', 'admin');
      if (rows is List) {
        for (var r in rows) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = m['id']?.toString() ?? '';
          if (id.isNotEmpty) {
            final isVerified = m['is_verified'] == true;
            final isTrial = m['is_trial'] == true;
            // Add if not verified or in trial or not in map yet
            if (!isVerified || isTrial || !map.containsKey(id)) {
              map[id] ??= {
                'id': id,
                'full_name': m['full_name']?.toString() ?? 'اسٹوڈنٹ',
                'email': m['email']?.toString() ?? '',
                'is_trial': isTrial,
              };
            }
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _pendingStudents = map.values.toList();
        _loading = false;
      });
    }
  }

  Future<void> _chooseApproval(String userId, String studentEmail) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          L.t('منظوری کی قسم منتخب کریں', 'Choose approval type'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'paid'),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(L.t('فیس سلپ کے ساتھ (مکمل منظوری)',
                      'With fee slip (Full Approval)')),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'trial'),
            child: Row(
              children: [
                Icon(Icons.timelapse, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(L.t('7 دن کی ٹرائل کلاسز', '7-day trial classes')),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (choice == 'paid') {
      await _approveStudent(userId, studentEmail, trial: false);
    } else if (choice == 'trial') {
      await _approveStudent(userId, studentEmail, trial: true);
    }
  }

  Future<void> _approveStudent(String userId, String studentEmail,
      {required bool trial}) async {
    // "کامیابی" کا معیار: RPC یا براہِ راست profiles.is_verified اپڈیٹ —
    // یہی دو کالز طالبِ علم کے لاگ اِن/رسائی کے اہل ہونے کو حقیقتاً کنٹرول
    // کرتی ہیں۔ enrollments/class_enrollments صرف اضافی sync ہیں۔
    bool verified = false;
    try {
      await _supabase.rpc(
        trial ? 'staff_verify_student_trial' : 'staff_verify_student_paid',
        params: trial
            ? {'p_student_id': userId, 'p_days': 7}
            : {'p_student_id': userId},
      );
      verified = true;
    } catch (_) {}

    // Direct DB fallback to ensure instant sync
    try {
      await _supabase.from('profiles').update({
        'is_verified': true,
        'is_trial': trial,
        'trial_until': trial
            ? DateTime.now().add(const Duration(days: 7)).toIso8601String()
            : null,
      }).eq('id', userId);
      verified = true;
    } catch (_) {}

    try {
      await _supabase.from('enrollments').update({
        'payment_status': trial ? 'trial' : 'paid',
        'grace_until': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      }).eq('student_id', userId);
    } catch (_) {}

    try {
      await _supabase.from('class_enrollments').update({
        'status': 'approved',
      }).eq('student_id', userId);
    } catch (_) {}

    if (!mounted) return;

    if (verified) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(trial
            ? L.t('$studentEmail کو 7 دن کی ٹرائل کے ساتھ منظور کر دیا گیا۔ 🎉',
                '$studentEmail approved with 7-day trial. 🎉')
            : L.t('$studentEmail کو (فیس سلپ) منظور کر دیا گیا۔ 🎉',
                '$studentEmail approved (with fee slip). 🎉')),
        backgroundColor: Colors.green.shade700,
      ));
    } else {
      // دونوں کوششیں ناکام — جھوٹی "کامیابی" نہ دکھائیں، اصل خطا دکھائیں۔
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('منظوری محفوظ نہیں ہو سکی، دوبارہ کوشش کریں۔',
            'Could not save the approval, please try again.')),
        backgroundColor: Colors.red.shade700,
      ));
    }
    _loadPendingStudents();
  }

  Future<void> _rejectStudent(String userId, String studentEmail) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(L.t('رجسٹریشن مسترد کریں؟', 'Reject registration?')),
        content: Text(L.t(
          '$studentEmail کا اکاؤنٹ غیر فعال کر دیا جائے گا۔',
          '$studentEmail\'s account will be deactivated.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('واپس', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.t('مسترد کریں', 'Reject')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    bool rejected = false;
    try {
      await _supabase.rpc('staff_reject_student', params: {
        'p_student_id': userId,
      });
      rejected = true;
    } catch (_) {}

    try {
      await _supabase.from('profiles').update({
        'is_verified': false,
      }).eq('id', userId);
      rejected = true;
    } catch (_) {}

    if (!mounted) return;

    if (rejected) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t(
          '$studentEmail کی رجسٹریشن مسترد کر دی گئی۔',
          '$studentEmail has been rejected.',
        )),
        backgroundColor: Colors.orange.shade800,
      ));
    } else {
      // دونوں کوششیں ناکام — جھوٹی "کامیابی" نہ دکھائیں، اصل خطا دکھائیں۔
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('مسترد نہیں ہو سکا، دوبارہ کوشش کریں۔',
            'Could not reject, please try again.')),
        backgroundColor: Colors.red.shade700,
      ));
    }
    _loadPendingStudents();
  }

  TextStyle _ts({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    ThemePreset? theme,
  }) {
    final defaultColor = theme != null ? theme.textColor : const Color(0xFF0F172A);
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? defaultColor,
      height: AppLang.ur ? 1.8 : 1.5,
      fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePreset>(
      valueListenable: AppTheme.currentTheme,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: theme.bgColor,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            elevation: 2,
            title: Text(
              L.t('اسٹوڈنٹس کی تصدیق اور لسٹ', 'Student Approvals'),
              style: _ts(fontSize: 18, fontWeight: FontWeight.bold, theme: theme),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPendingStudents,
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _pendingStudents.isEmpty
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.all(24),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 48,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  L.t('کوئی اسٹوڈنٹ التوا میں نہیں', 'No Pending Approvals'),
                                  style: _ts(fontSize: 18, fontWeight: FontWeight.bold, theme: theme),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  L.t('تمام نئے اسٹوڈنٹس کی تصدیق مکمل ہو چکی ہے۔',
                                      'All student registrations are verified.'),
                                  textAlign: TextAlign.center,
                                  style: _ts(fontSize: 14, color: theme.subtextColor),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 24, 20),
                          itemCount: _pendingStudents.length,
                          itemBuilder: (context, i) {
                            final item = _pendingStudents[i];
                            final name = item['full_name'] ?? 'اسٹوڈنٹ';
                            final email = item['email'] ?? '—';
                            final id = item['id'] as String;

                            return TealBox(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              borderRadius: 18,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                                        child: Icon(Icons.person_rounded, color: theme.primaryColor),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: _ts(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                theme: theme,
                                              ),
                                            ),
                                            Text(
                                              email,
                                              style: _ts(fontSize: 13, color: theme.subtextColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.cancel_outlined, size: 16),
                                        label: Text(L.t('مسترد', 'Reject'),
                                            style: _ts(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                                        onPressed: () => _rejectStudent(id, email),
                                      ),
                                      const SizedBox(width: 10),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                        icon: const Icon(Icons.verified_rounded, size: 16),
                                        label: Text(
                                          L.t('منظوری دیں', 'Approve'),
                                          style: _ts(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                        onPressed: () => _chooseApproval(id, email),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        );
      },
    );
  }
}
