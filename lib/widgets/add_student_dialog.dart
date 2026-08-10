import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/staff_service.dart';

/// ٹیچر/مینیجر: اسٹوڈنٹ کو کلاس میں اینرول کرے یا ای میل سے شامل کرے۔
///  • سائن اپ شدہ اسٹوڈنٹس تلاش (نام / ای میل) اور کلاس میں اینرول کرے
///  • نیا اسٹوڈنٹ ای میل سے شامل کرے
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
  final _searchCtrl = TextEditingController();

  int _mode = 0; // 0: سائن اپ شدہ اسٹوڈنٹ شامل کریں, 1: نیا ای میل دعوتی

  List<Map<String, dynamic>> _registeredStudents = [];
  List<Map<String, dynamic>> _classes = [];

  String? _selectedStudentId;
  String? _classId;
  String _searchQuery = '';

  bool _loadingData = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _service.getRegisteredStudents(),
        _service.myClassesLite(),
      ]);
      if (!mounted) return;
      setState(() {
        _registeredStudents = results[0];
        _classes = results[1];

        if (_registeredStudents.isNotEmpty) {
          _selectedStudentId = _registeredStudents.first['id'] as String?;
        }
        if (_classes.isNotEmpty) {
          _classId = _classes.first['id'] as String?;
        }
        _loadingData = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEnrollExisting() async {
    if (_selectedStudentId == null || _selectedStudentId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('برائے کرم اسٹوڈنٹ منتخب کریں', 'Please select a student')),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }
    if (_classId == null || _classId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('برائے کرم کلاس منتخب کریں', 'Please select a class')),
        backgroundColor: Colors.orange.shade800,
      ));
      return;
    }

    setState(() => _busy = true);
    try {
      await _service.enrollStudentInClass(
        studentId: _selectedStudentId!,
        classId: _classId!,
      );
      if (!mounted) return;
      Navigator.pop(context, true);

      final studentMap = _registeredStudents.firstWhere(
        (s) => s['id'] == _selectedStudentId,
        orElse: () => {'full_name': 'اسٹوڈنٹ'},
      );
      final sName = studentMap['full_name'] ?? studentMap['email'] ?? 'اسٹوڈنٹ';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t(
          '$sName کو کامیابی سے کلاس میں شامل کر دیا گیا۔',
          '$sName successfully added to class.',
        )),
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('شامل نہیں ہو سکا، دوبارہ کوشش کریں۔', 'Could not add, please try again.')),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  Future<void> _submitInviteNew() async {
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
          ? L.t('اسٹوڈنٹ شامل اور تصدیق ہو گیا۔', 'Student added and verified.')
          : L.t(
              'دعوت بھیج دی گئی — جب یہ ای میل رجسٹر ہوگی تو خودکار فعال ہو جائے گی۔',
              'Invite saved — the student is auto-activated when they register with this email.',
            );
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
          : L.t('شامل نہیں ہو سکا، دوبارہ کوشش کریں۔', 'Could not add, please try again.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _registeredStudents.where((s) {
      if (_searchQuery.isEmpty) return true;
      final name = (s['full_name'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) || email.contains(_searchQuery);
    }).toList();

    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(L.t('اسٹوڈنٹ شامل کریں', 'Add Student')),
          const SizedBox(height: 12),
          // Toggle Tabs between Registered Student vs New Email Invite
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _mode = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _mode == 0 ? Colors.teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        L.t('سائن اپ شدہ اسٹوڈنٹ شامل کریں', 'Add Registered Student'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _mode == 0 ? Colors.white : Colors.teal.shade900,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _mode = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _mode == 1 ? Colors.teal : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        L.t('نیا ای میل دعوتی', 'New Email Invite'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _mode == 1 ? Colors.white : Colors.teal.shade900,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: _loadingData
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : _mode == 0
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // SEARCH FIELD FOR NAME / EMAIL
                      TextFormField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: L.t('نام یا ای میل سے تلاش کریں...', 'Search by name or email...'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onChanged: (q) => setState(() => _searchQuery = q.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 14),

                      if (filteredStudents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                L.t('کوئی اسٹوڈنٹ نہیں ملا۔', 'No matching student found.'),
                                style: const TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                icon: const Icon(Icons.person_add_alt_1, size: 16),
                                label: Text(L.t('ای میل سے نیا اسٹوڈنٹ شامل کریں', 'Invite new student via email')),
                                onPressed: () => setState(() => _mode = 1),
                              ),
                            ],
                          ),
                        )
                      else
                        DropdownButtonFormField<String>(
                          initialValue: filteredStudents.any((s) => s['id'] == _selectedStudentId)
                              ? _selectedStudentId
                              : (filteredStudents.first['id'] as String?),
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: L.t('اسٹوڈنٹ منتخب کریں', 'Select Student'),
                            prefixIcon: const Icon(Icons.person_pin_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: filteredStudents.map((s) {
                            final name = s['full_name']?.toString() ?? 'اسٹوڈنٹ';
                            final email = s['email']?.toString() ?? '';
                            return DropdownMenuItem<String>(
                              value: s['id'] as String,
                              child: Text(
                                email.isNotEmpty ? '$name ($email)' : name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedStudentId = v),
                        ),
                      const SizedBox(height: 14),
                      if (_classes.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _classId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: L.t('کلاس میں شامل کریں', 'Select Class to Enroll'),
                            prefixIcon: const Icon(Icons.class_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _classes.map((c) => DropdownMenuItem<String>(
                                value: c['id'] as String,
                                child: Text(c['title'] as String? ?? '—', overflow: TextOverflow.ellipsis),
                              )).toList(),
                          onChanged: (v) => setState(() => _classId = v),
                        ),
                    ],
                  )
                : Form(
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_classes.isNotEmpty)
                          DropdownButtonFormField<String>(
                            initialValue: _classId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: L.t('کلاس (اختیاری)', 'Class (optional)'),
                              prefixIcon: const Icon(Icons.class_outlined),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(L.t('کوئی کلاس نہیں', 'No class')),
                              ),
                              ..._classes.map((c) => DropdownMenuItem<String>(
                                    value: c['id'] as String,
                                    child: Text(c['title'] as String? ?? '—', overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _classId = v),
                          ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(L.t('منسوخ', 'Cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _busy ? null : (_mode == 0 ? _submitEnrollExisting : _submitInviteNew),
          child: _busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_mode == 0
                  ? L.t('کلاس میں شامل کریں', 'Add to Class')
                  : L.t('دعوت بھیجیں', 'Send Invite')),
        ),
      ],
    );
  }
}
