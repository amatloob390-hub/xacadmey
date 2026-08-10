import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../app_theme.dart';

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
    try {
      final res = await _supabase.rpc('list_pending_students');

      if (mounted) {
        setState(() {
          _pendingStudents = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseApproval(String userId, String studentEmail) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text(L.t('منظوری کی قسم منتخب کریں', 'Choose approval type')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'paid'),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.green.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(L.t('فیس سلپ کے ساتھ (مکمل رکنیت)',
                      'With fee slip (full membership)')),
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
    try {
      await _supabase.rpc(
        trial ? 'staff_verify_student_trial' : 'staff_verify_student_paid',
        params: trial
            ? {'p_student_id': userId, 'p_days': 7}
            : {'p_student_id': userId},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(trial
              ? L.t('$studentEmail کو 7 دن کی ٹرائل کے ساتھ منظور کر دیا گیا۔',
                  '$studentEmail approved with a 7-day trial.')
              : L.t('$studentEmail کو (فیس سلپ) منظور کر دیا گیا۔',
                  '$studentEmail approved (with fee slip).')),
          backgroundColor: Colors.green.shade700,
        ));
        _loadPendingStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('تصدیق میں مسئلہ: $e', 'Error approving: $e')),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  Future<void> _rejectStudent(String userId, String studentEmail) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L.t('رجسٹریشن مسترد کریں؟', 'Reject registration?')),
        content: Text(L.t(
          '$studentEmail کا اکاؤنٹ مستقل حذف ہو جائے گا۔ یہ عمل واپس نہیں ہو سکتا۔',
          '$studentEmail\'s account will be permanently deleted. This cannot be undone.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('واپس', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.t('مسترد کریں', 'Reject'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _supabase.rpc('staff_reject_student', params: {
        'p_student_id': userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t(
            '$studentEmail کی رجسٹریشن مسترد کر دی گئی۔',
            '$studentEmail has been rejected.',
          )),
          backgroundColor: Colors.orange.shade800,
        ));
        _loadPendingStudents();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('مسترد کرنے میں مسئلہ: $e', 'Error rejecting: $e')),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 6),
        ));
      }
    }
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
              L.t('نئے اسٹوڈنٹس کی تصدیق', 'Student Approvals'),
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
              constraints: const BoxConstraints(maxWidth: 480),
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
                                      'All new student registrations are verified.'),
                                  textAlign: TextAlign.center,
                                  style: _ts(fontSize: 14, color: theme.subtextColor),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                          itemCount: _pendingStudents.length,
                          itemBuilder: (context, i) {
                            final item = _pendingStudents[i];
                            final name = item['full_name'] ?? '—';
                            final email = item['email'] ?? '—';
                            final id = item['id'] as String;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
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
                                      CircleAvatar(
                                        backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                                        child: Icon(Icons.person_rounded, color: theme.primaryColor),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              name,
                                              textAlign: TextAlign.center,
                                              style: _ts(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                theme: theme,
                                              ),
                                            ),
                                            Text(
                                              email,
                                              textAlign: TextAlign.center,
                                              style: _ts(fontSize: 13, color: theme.subtextColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                        label: Text(L.t('منسوخ', 'Reject'),
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
