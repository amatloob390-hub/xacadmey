import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../services/staff_service.dart';
import '../widgets/teal_box.dart';

/// آسانی سے پڑھا جا سکنے والا رینڈم پاس ورڈ (0/O، 1/I/l جیسے مبہم حروف
/// نکال کر) — تاکہ ٹیچر اسے آواز سے یا لکھ کر اسٹوڈنٹ کو صحیح بتا سکے۔
String _generatePassword() {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
  final rand = Random.secure();
  return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
}

/// ٹیچر/ایڈمن: نام یا ای میل سے اسٹوڈنٹ تلاش کریں اور تفصیلات دیکھیں
/// (نام، ای میل، موبائل، enrolled کلاسز، تصدیق/ٹرائل کی حالت)۔
class SearchStudentsScreen extends StatefulWidget {
  const SearchStudentsScreen({super.key});

  @override
  State<SearchStudentsScreen> createState() => _SearchStudentsScreenState();
}

class _SearchStudentsScreenState extends State<SearchStudentsScreen> {
  final StaffService _service = StaffService();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  bool _searching = false;
  bool _searched = false;
  String? _searchError;
  // ہر نئی تلاش کا ترتیبی نمبر — سست/پرانی درخواست کا جواب دیر سے آئے تو
  // اسے نظرانداز کریں تاکہ نتائج غلط ترتیب میں اسکرین پر نہ آئیں۔
  int _searchToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final query = q.trim();
    final myToken = ++_searchToken;

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _searched = false;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final rows = await _service.searchStudents(query);
      // اگر اس دوران کوئی نئی تلاش شروع ہو چکی، تو یہ (پرانا) جواب نظرانداز کریں۔
      if (!mounted || myToken != _searchToken) return;
      setState(() {
        _results = rows;
        _searching = false;
        _searched = true;
      });
    } catch (e) {
      if (!mounted || myToken != _searchToken) return;
      setState(() {
        _results = [];
        _searching = false;
        _searched = true;
        _searchError = e.toString();
      });
    }
  }

  void _openDetails(Map<String, dynamic> student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudentDetailsSheet(
        student: student,
        service: _service,
        onPhoneUpdated: (newPhone) {
          setState(() {
            final id = student['id'];
            final idx = _results.indexWhere((s) => s['id'] == id);
            if (idx != -1) _results[idx]['phone'] = newPhone;
          });
        },
      ),
    );
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
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            elevation: 2,
            title: Text(
              L.t('اسٹوڈنٹ تلاش کریں', 'Search Students'),
              style: _ts(fontSize: 18, fontWeight: FontWeight.bold, theme: theme),
            ),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TealBox(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        onChanged: _onChanged,
                        decoration: InputDecoration(
                          hintText: L.t('نام یا ای میل لکھیں…', 'Type a name or email…'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _results = [];
                                      _searched = false;
                                    });
                                  },
                                )
                              : null,
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _searching
                          ? const Center(child: CircularProgressIndicator())
                          : !_searched
                              ? Center(
                                  child: Text(
                                    L.t('نام یا ای میل لکھ کر تلاش شروع کریں',
                                        'Start typing a name or email to search'),
                                    style: _ts(fontSize: 14, color: theme.subtextColor),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : _searchError != null
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          '${L.t('تلاش ناکام ہوئی', 'Search failed')}\n\n${_searchError!}',
                                          style: _ts(fontSize: 13, color: Colors.red),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    )
                              : _results.isEmpty
                                  ? Center(
                                      child: Text(
                                        L.t('کوئی اسٹوڈنٹ نہیں ملا', 'No student found'),
                                        style: _ts(fontSize: 14, color: theme.subtextColor),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 8, 0),
                                      itemCount: _results.length,
                                      itemBuilder: (context, i) {
                                        final s = _results[i];
                                        final name = s['full_name']?.toString() ?? 'اسٹوڈنٹ';
                                        final email = s['email']?.toString() ?? '';
                                        final verified = s['is_verified'] == true;
                                        return TealBox(
                                          margin: const EdgeInsets.only(bottom: 10),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          child: InkWell(
                                            onTap: () => _openDetails(s),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  backgroundColor:
                                                      theme.primaryColor.withValues(alpha: 0.15),
                                                  child: Icon(Icons.person_rounded,
                                                      color: theme.primaryColor),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(name,
                                                          style: _ts(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.bold,
                                                              theme: theme)),
                                                      if (email.isNotEmpty)
                                                        Text(email,
                                                            style: _ts(
                                                                fontSize: 12,
                                                                color: theme.subtextColor)),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  verified
                                                      ? Icons.verified_rounded
                                                      : Icons.hourglass_top_rounded,
                                                  color: verified
                                                      ? const Color(0xFF10B981)
                                                      : Colors.orange,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StudentDetailsSheet extends StatefulWidget {
  final Map<String, dynamic> student;
  final StaffService service;
  final ValueChanged<String> onPhoneUpdated;

  const _StudentDetailsSheet({
    required this.student,
    required this.service,
    required this.onPhoneUpdated,
  });

  @override
  State<_StudentDetailsSheet> createState() => _StudentDetailsSheetState();
}

class _StudentDetailsSheetState extends State<_StudentDetailsSheet> {
  late final TextEditingController _phoneCtrl;
  bool _editingPhone = false;
  bool _savingPhone = false;
  late Future<List<Map<String, dynamic>>> _enrollmentsFuture;

  bool _resettingPassword = false;
  String? _newPasswordShown; // successful reset ہونے کے بعد یہاں دکھایا جاتا ہے

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.student['phone']?.toString() ?? '');
    _enrollmentsFuture =
        widget.service.getStudentEnrollments(widget.student['id']?.toString() ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmResetPassword() async {
    final name = widget.student['full_name']?.toString() ?? 'اسٹوڈنٹ';
    final suggested = _generatePassword();
    final ctrl = TextEditingController(text: suggested);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(L.t('پاس ورڈ ری سیٹ کریں؟', 'Reset password?')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L.t(
                '$name کا پرانا پاس ورڈ فوراً کام کرنا بند کر دے گا۔ نیا پاس ورڈ نیچے ہے — اسٹوڈنٹ کو بتا دیں۔',
                "$name's old password will stop working immediately. The new password is below — share it with the student.",
              )),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(
                  labelText: L.t('نیا پاس ورڈ', 'New password'),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: L.t('نیا بنائیں', 'Generate new'),
                    onPressed: () => setDialogState(() => ctrl.text = _generatePassword()),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(L.t('منسوخ', 'Cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: ctrl.text.trim().length >= 6 ? () => Navigator.pop(ctx, true) : null,
              child: Text(L.t('ری سیٹ کریں', 'Reset')),
            ),
          ],
        ),
      ),
    );

    final newPassword = ctrl.text.trim();
    ctrl.dispose();
    if (confirmed != true) return;

    setState(() => _resettingPassword = true);
    try {
      await widget.service.resetStudentPassword(
        studentId: widget.student['id']?.toString() ?? '',
        newPassword: newPassword,
      );
      if (!mounted) return;
      setState(() {
        _resettingPassword = false;
        _newPasswordShown = newPassword;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _resettingPassword = false);
      final msg = e.toString();
      final friendly = msg.contains('NOT_ALLOWED')
          ? L.t('آپ کو اجازت نہیں۔', 'You are not allowed to do this.')
          : msg.contains('AUTH_REQUIRED')
              ? L.t('سیشن ختم ہو گیا — دوبارہ لاگ اِن کریں۔', 'Session expired — log in again.')
              : L.t(
                  'پاس ورڈ ری سیٹ نہیں ہو سکا۔ شاید یہ فیچر ابھی سرور پر فعال نہیں کیا گیا۔',
                  'Could not reset the password. This feature may not be enabled on the server yet.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 6),
        content: Text(friendly),
      ));
    }
  }

  Future<void> _savePhone() async {
    setState(() => _savingPhone = true);
    try {
      await widget.service.updateStudentPhone(
        widget.student['id']?.toString() ?? '',
        _phoneCtrl.text,
      );
      if (mounted) {
        widget.onPhoneUpdated(_phoneCtrl.text.trim());
        setState(() {
          _editingPhone = false;
          _savingPhone = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _savingPhone = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(L.t('محفوظ نہیں ہو سکا، دوبارہ کوشش کریں۔',
              'Could not save, please try again.')),
        ));
      }
    }
  }

  TextStyle _ts({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    required ThemePreset theme,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? theme.textColor,
      height: AppLang.ur ? 1.8 : 1.5,
      fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
    );
  }

  Widget _row(String label, String value, ThemePreset theme, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.subtextColor),
            const SizedBox(width: 8),
          ],
          Expanded(
            flex: 2,
            child: Text(label, style: _ts(fontSize: 13, color: theme.subtextColor, theme: theme)),
          ),
          Expanded(
            flex: 3,
            child: Text(value.isEmpty ? '—' : value,
                style: _ts(fontSize: 14, fontWeight: FontWeight.w600, theme: theme)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePreset>(
      valueListenable: AppTheme.currentTheme,
      builder: (context, theme, _) {
        final s = widget.student;
        final name = s['full_name']?.toString() ?? 'اسٹوڈنٹ';
        final email = s['email']?.toString() ?? '';
        final verified = s['is_verified'] == true;
        final isTrial = s['is_trial'] == true;
        final trialUntil = DateTime.tryParse(s['trial_until']?.toString() ?? '');

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.subtextColor.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.primaryColor.withValues(alpha: 0.15),
                      child: Icon(Icons.person_rounded, color: theme.primaryColor, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name,
                          style: _ts(fontSize: 18, fontWeight: FontWeight.bold, theme: theme)),
                    ),
                    Icon(
                      verified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                      color: verified ? const Color(0xFF10B981) : Colors.orange,
                    ),
                  ],
                ),
                const Divider(height: 28),
                _row(L.t('ای میل', 'Email'), email, theme, icon: Icons.email_outlined),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.phone_outlined, size: 18, color: theme.subtextColor),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: Text(L.t('موبائل', 'Mobile'),
                            style: _ts(fontSize: 13, color: theme.subtextColor, theme: theme)),
                      ),
                      Expanded(
                        flex: 3,
                        child: _editingPhone
                            ? TextField(
                                controller: _phoneCtrl,
                                autofocus: true,
                                keyboardType: TextInputType.phone,
                                style: _ts(fontSize: 14, fontWeight: FontWeight.w600, theme: theme),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: UnderlineInputBorder(),
                                ),
                              )
                            : Text(
                                _phoneCtrl.text.trim().isEmpty ? '—' : _phoneCtrl.text.trim(),
                                style:
                                    _ts(fontSize: 14, fontWeight: FontWeight.w600, theme: theme),
                              ),
                      ),
                      if (_savingPhone)
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        IconButton(
                          icon: Icon(_editingPhone ? Icons.check : Icons.edit_outlined,
                              size: 18, color: theme.primaryColor),
                          onPressed:
                              _editingPhone ? _savePhone : () => setState(() => _editingPhone = true),
                        ),
                    ],
                  ),
                ),
                _row(
                  L.t('حالت', 'Status'),
                  verified
                      ? (isTrial
                          ? L.t(
                              'ٹرائل${trialUntil != null ? ' — ${trialUntil.day}/${trialUntil.month}/${trialUntil.year} تک' : ''}',
                              'Trial${trialUntil != null ? ' — until ${trialUntil.day}/${trialUntil.month}/${trialUntil.year}' : ''}')
                          : L.t('تصدیق شدہ', 'Verified'))
                      : L.t('تصدیق زیرِ التوا', 'Pending verification'),
                  theme,
                  icon: Icons.info_outline,
                ),
                const SizedBox(height: 12),
                Text(L.t('Enrolled کلاسز', 'Enrolled Classes'),
                    style: _ts(fontSize: 14, fontWeight: FontWeight.bold, theme: theme)),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _enrollmentsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final rows = snapshot.data ?? [];
                    if (rows.isEmpty) {
                      return Text(
                        L.t('کوئی کلاس نہیں', 'No classes'),
                        style: _ts(fontSize: 13, color: theme.subtextColor, theme: theme),
                      );
                    }
                    return Column(
                      children: rows.map((r) {
                        final title = r['class_title']?.toString() ?? 'کلاس';
                        final status = r['payment_status']?.toString() ?? 'pending';
                        final paid = status == 'paid';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(title,
                                    style: _ts(
                                        fontSize: 13, fontWeight: FontWeight.w600, theme: theme)),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (paid ? const Color(0xFF10B981) : Colors.orange)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  paid ? L.t('ادا شدہ', 'Paid') : L.t('زیرِ التوا', 'Pending'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: paid ? const Color(0xFF10B981) : Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(L.t('اکاؤنٹ', 'Account'),
                    style: _ts(fontSize: 14, fontWeight: FontWeight.bold, theme: theme)),
                const SizedBox(height: 8),
                if (_newPasswordShown != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          L.t('نیا پاس ورڈ — اسٹوڈنٹ کو بتا دیں:', 'New password — share with the student:'),
                          style: _ts(fontSize: 12, color: theme.subtextColor, theme: theme),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _newPasswordShown!,
                          style: _ts(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                              theme: theme),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _resettingPassword ? null : _confirmResetPassword,
                    icon: _resettingPassword
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.lock_reset, size: 18, color: Colors.red),
                    label: Text(
                      L.t('پاس ورڈ ری سیٹ کریں (بھول گیا)', 'Reset Password (Forgot)'),
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
