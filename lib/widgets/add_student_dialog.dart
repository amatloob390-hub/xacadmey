import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/staff_service.dart';

/// ٹیچر/مینیجر: نیا اسٹوڈنٹ ای میل سے شامل کرے۔
///  • اگر ای میل پہلے سے رجسٹرڈ ہو → فوراً verify + enroll
///  • ورنہ دعوت محفوظ ہو، signup پر خودکار فعال
class AddStudentDialog extends StatefulWidget {
  const AddStudentDialog({super.key});

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final StaffService _service = StaffService();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  List<Map<String, dynamic>> _classes = [];
  String? _classId; // منتخب کلاس (اختیاری)
  bool _loadingClasses = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final rows = await _service.myClassesLite();
      if (!mounted) return;
      setState(() {
        _classes = rows;
        _loadingClasses = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final result = await _service.inviteStudent(
        email: _emailCtrl.text.trim(),
        fullName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        classId: _classId,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      final msg = result == 'EXISTING_VERIFIED'
          ? L.t('اسٹوڈنٹ شامل اور تصدیق ہو گیا۔',
              'Student added and verified.')
          : L.t('دعوت بھیج دی گئی — جب یہ ای میل رجسٹر ہوگی تو خودکار فعال ہو جائے گی۔',
              'Invite saved — the student is auto-activated when they register with this email.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      final raw = e.toString();
      final msg = raw.contains('NOT_ALLOWED')
          ? L.t('آپ کو اجازت نہیں۔', 'You are not allowed.')
          : L.t('شامل نہیں ہو سکا، دوبارہ کوشش کریں۔',
              'Could not add, please try again.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L.t('نیا اسٹوڈنٹ شامل کریں', 'Add Student')),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: L.t('اسٹوڈنٹ ای میل', 'Student email'),
                prefixIcon: const Icon(Icons.email_outlined),
              ),
              validator: (v) => (v == null || !v.contains('@'))
                  ? L.t('درست ای میل درج کریں', 'Enter a valid email')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: L.t('نام (اختیاری)', 'Name (optional)'),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingClasses)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_classes.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _classId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: L.t('کلاس (اختیاری)', 'Class (optional)'),
                  prefixIcon: const Icon(Icons.class_outlined),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(L.t('کوئی کلاس نہیں', 'No class')),
                  ),
                  ..._classes.map((c) => DropdownMenuItem<String>(
                        value: c['id'] as String,
                        child: Text(c['title'] as String? ?? '—',
                            overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) => setState(() => _classId = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(L.t('منسوخ', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(L.t('شامل کریں', 'Add')),
        ),
      ],
    );
  }
}
