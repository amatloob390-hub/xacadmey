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
    final roleItems = <String>['manager', 'student', if (widget.isAdmin) ...['teacher', 'admin']];

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('رول اور مینیجرز', 'Roles & Managers')),
        actions: [
          IconButton(onPressed: _loadStaff, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        L.t('کسی کو رول دیں', 'Assign a role'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: L.t('یوزر ای میل', 'User email'),
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: InputDecoration(
                          labelText: L.t('رول', 'Role'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        items: roleItems
                            .map((r) => DropdownMenuItem(
                                  value: r,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Text(_roleLabel(r), textAlign: TextAlign.center),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _role = v ?? 'manager'),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _busy ? null : _assign,
                          icon: _busy
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            L.t('رول تفویض کریں', 'Assign role'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                L.t('موجودہ اسٹاف', 'Current staff'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_staff.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    L.t('کوئی اسٹاف نہیں۔', 'No staff yet.'),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ..._staff.map((s) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.teal.withValues(alpha: 0.15),
                              child: const Icon(Icons.badge, color: Colors.teal),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    s['full_name'] as String? ?? '—',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    s['email'] as String? ?? '',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Chip(
                              backgroundColor: Colors.teal.withValues(alpha: 0.12),
                              side: BorderSide(color: Colors.teal.shade300),
                              label: Text(
                                _roleLabel(s['role'] as String? ?? ''),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
            ],
          ),
        ),
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
