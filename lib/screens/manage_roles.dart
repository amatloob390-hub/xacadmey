import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/staff_service.dart';

/// صرف Teacher/Admin: کسی کو رول دے (Manager / Sub-admin بنائے) اور موجودہ staff دیکھے۔
class ManageRolesScreen extends StatefulWidget {
  final bool isAdmin;
  const ManageRolesScreen({super.key, required this.isAdmin});

  @override
  State<ManageRolesScreen> createState() => _ManageRolesScreenState();
}

class _ManageRolesScreenState extends State<ManageRolesScreen> {
  final StaffService _service = StaffService();
  final _emailCtrl = TextEditingController();
  String _role = 'manager';
  bool _busy = false;

  List<Map<String, dynamic>> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStaff() async {
    setState(() => _loading = true);
    try {
      final rows = await _service.listStaff();
      if (!mounted) return;
      setState(() {
        _staff = rows;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _snack(L.t('درست ای میل درج کریں', 'Enter a valid email'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _service.setUserRole(email: email, role: _role);
      if (!mounted) return;
      _emailCtrl.clear();
      _snack(L.t('رول تفویض ہو گیا۔', 'Role assigned.'));
      _loadStaff();
    } catch (e) {
      final raw = e.toString();
      String msg;
      if (raw.contains('USER_NOT_FOUND')) {
        msg = L.t('یہ ای میل رجسٹرڈ نہیں ملی۔', 'No registered user with this email.');
      } else if (raw.contains('ADMIN_ONLY')) {
        msg = L.t('admin رول صرف admin دے سکتا ہے۔', 'Only an admin can assign the admin role.');
      } else if (raw.contains('NOT_ALLOWED')) {
        msg = L.t('آپ کو اجازت نہیں۔', 'You are not allowed.');
      } else {
        msg = L.t('تفویض نہیں ہو سکی، دوبارہ کوشش کریں۔', 'Could not assign, try again.');
      }
      _snack(msg, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // teacher صرف manager/student دے سکتا ہے؛ admin کے پاس teacher/admin بھی
    final roleItems = <String>['manager', 'student', if (widget.isAdmin) ...['teacher', 'admin']];

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('رول اور مینیجرز', 'Roles & Managers')),
        actions: [
          IconButton(onPressed: _loadStaff, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L.t('کسی کو رول دیں', 'Assign a role'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: L.t('یوزر ای میل', 'User email'),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: InputDecoration(
                      labelText: L.t('رول', 'Role'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    items: roleItems
                        .map((r) => DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                        .toList(),
                    onChanged: (v) => setState(() => _role = v ?? 'manager'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _assign,
                      icon: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(L.t('رول تفویض کریں', 'Assign role')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(L.t('موجودہ اسٹاف', 'Current staff'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_staff.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(L.t('کوئی اسٹاف نہیں۔', 'No staff yet.')),
            )
          else
            ..._staff.map((s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: const Icon(Icons.badge, color: Colors.indigo),
                    ),
                    title: Text(s['full_name'] as String? ?? '—'),
                    subtitle: Text(s['email'] as String? ?? ''),
                    trailing: Chip(label: Text(_roleLabel(s['role'] as String? ?? ''))),
                  ),
                )),
        ],
      ),
    );
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'manager':
        return L.t('مینیجر / سب-ایڈمن', 'Manager / Sub-admin');
      case 'teacher':
        return L.t('ٹیچر', 'Teacher');
      case 'admin':
        return L.t('ایڈمن', 'Admin');
      case 'student':
        return L.t('اسٹوڈنٹ', 'Student');
      default:
        return r;
    }
  }
}
