import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';

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
      // SECURITY DEFINER RPC — RLS سے بالاتر ہو کر staff کو زیرِ التوا
      // students لوٹاتا ہے (سیدھی profiles query RLS کی وجہ سے خالی آتی تھی)۔
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

  /// "منظوری دیں" پر منظوری کی قسم پوچھیں: فیس سلپ (مکمل) یا 7 دن ٹرائل۔
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
                  child: Text(L.t('7 دن کی ٹرائل کلاسز',
                      '7-day trial classes')),
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
      // staff RPC — teacher/admin/manager سب تصدیق کر سکتے ہیں (RLS محفوظ)
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t(
          'نئے اسٹوڈنٹس کی تصدیق',
          'Student Approvals',
        )),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPendingStudents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingStudents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            size: 64, color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                          L.t(
                            'کوئی اسٹوڈنٹ تصدیق کے لیے التوا میں نہیں۔',
                            'No pending student approvals.',
                          ),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _pendingStudents.length,
                  itemBuilder: (context, i) {
                    final item = _pendingStudents[i];
                    final name = item['full_name'] ?? '—';
                    final email = item['email'] ?? '—';
                    final id = item['id'] as String;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.indigo.shade100,
                                  child: const Icon(Icons.person,
                                      color: Colors.indigo),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16),
                                      ),
                                      Text(email,
                                          style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 13),
                                    minimumSize: const Size(0, 34),
                                  ),
                                  icon: const Icon(Icons.verified, size: 16),
                                  label: Text(L.t('منظوری دیں', 'Approve')),
                                  onPressed: () => _chooseApproval(id, email),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side:
                                        BorderSide(color: Colors.red.shade300),
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    textStyle: const TextStyle(fontSize: 13),
                                    minimumSize: const Size(0, 34),
                                  ),
                                  icon: const Icon(Icons.cancel_outlined,
                                      size: 16),
                                  label: Text(L.t('منسوخ', 'Reject')),
                                  onPressed: () => _rejectStudent(id, email),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
