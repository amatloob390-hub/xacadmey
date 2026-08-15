import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/staff_service.dart';
import 'teal_box.dart';

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

  Future<void> _submitDirectEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('برائے کرم درست ای میل درج کریں', 'Please enter a valid email')),
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
      await _service.directEnrollByEmail(
        email: cleanEmail,
        classId: _classId!,
        fullName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : null,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t(
          '$cleanEmail کو کلاس میں شامل اور تصدیق کر دیا گیا۔ 🎉',
          '$cleanEmail successfully added and verified for the class. 🎉',
        )),
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('شامل نہیں ہو سکا: $e', 'Could not add: $e')),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  Future<void> _submitEnrollExisting() async {
    // If user typed an email directly in search
    if (_searchQuery.contains('@')) {
      await _submitDirectEmail(_searchQuery);
      return;
    }

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
    await _submitDirectEmail(_emailCtrl.text);
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            L.t('اسٹوڈنٹ شامل کریں', 'Add Student'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
                        L.t('سائن اپ شدہ اسٹوڈنٹ', 'Registered Student'),
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
                        L.t('ای میل سے نیا شامل کریں', 'Add via Email'),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SEARCH FIELD FOR NAME / EMAIL
                      TealBox(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextFormField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            labelText: L.t('نام یا ای میل سے تلاش کریں...', 'Search name or email...'),
                            hintText: 'e.g. talha2@gmail.com',
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
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (q) => setState(() => _searchQuery = q.trim().toLowerCase()),
                        ),
                      ),
                      const SizedBox(height: 14),

                      if (_classes.isNotEmpty) ...[
                        TealBox(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: DropdownButtonFormField<String>(
                            value: _classId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: L.t('کلاس منتخب کریں', 'Select Class'),
                              prefixIcon: const Icon(Icons.class_outlined, color: Colors.teal),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            items: _classes.map((c) => DropdownMenuItem<String>(
                                  value: c['id'] as String,
                                  child: Text(c['title'] as String? ?? '—', overflow: TextOverflow.ellipsis),
                                )).toList(),
                            onChanged: (v) => setState(() => _classId = v),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      if (filteredStudents.isEmpty && _searchQuery.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                L.t('ای میل درج کی گئی:', 'Email Entered:'),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _searchQuery,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                onPressed: _busy ? null : () => _submitDirectEmail(_searchQuery),
                                icon: const Icon(Icons.person_add_alt_1),
                                label: Text(L.t('اس ای میل کو کلاس میں شامل کریں', 'Enroll This Email in Class')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else if (filteredStudents.isNotEmpty) ...[
                        TealBox(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: DropdownButtonFormField<String>(
                            value: filteredStudents.any((s) => s['id'] == _selectedStudentId)
                                ? _selectedStudentId
                                : (filteredStudents.first['id'] as String?),
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: L.t('اسٹوڈنٹ منتخب کریں', 'Select Student'),
                              prefixIcon: const Icon(Icons.person_pin_outlined, color: Colors.teal),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
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
                        ),
                      ],
                    ],
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TealBox(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: L.t('اسٹوڈنٹ کی ای میل *', 'Student Email *'),
                              hintText: 'student@gmail.com',
                              prefixIcon: const Icon(Icons.email_outlined, color: Colors.teal),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return L.t('ای میل درج کریں', 'Please enter email');
                              }
                              if (!v.contains('@')) {
                                return L.t('درست ای میل درج کریں', 'Enter valid email');
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        TealBox(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: L.t('اسٹوڈنٹ کا نام (اختیاری)', 'Student Name (optional)'),
                              prefixIcon: const Icon(Icons.badge_outlined, color: Colors.teal),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (_classes.isNotEmpty)
                          TealBox(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButtonFormField<String>(
                              value: _classId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: L.t('کلاس میں شامل کریں', 'Select Class'),
                                prefixIcon: const Icon(Icons.class_outlined, color: Colors.teal),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              items: _classes.map((c) => DropdownMenuItem<String>(
                                    value: c['id'] as String,
                                    child: Text(c['title'] as String? ?? '—', overflow: TextOverflow.ellipsis),
                                  )).toList(),
                              onChanged: (v) => setState(() => _classId = v),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(L.t('منسوخ', 'Cancel')),
        ),
        ElevatedButton.icon(
          onPressed: _busy
              ? null
              : (_mode == 0 ? _submitEnrollExisting : _submitInviteNew),
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 18),
          label: Text(
            _busy
                ? L.t('جاری ہے...', 'Saving...')
                : L.t('کلاس میں شامل کریں', 'Enroll in Class'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          ),
        ),
      ],
    );
  }
}
