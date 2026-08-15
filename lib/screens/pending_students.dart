import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../services/pending_student_service.dart';
import '../widgets/teal_box.dart';
import 'pending_payments.dart';

class PendingStudents extends StatefulWidget {
  const PendingStudents({super.key});

  @override
  State<PendingStudents> createState() => _PendingStudentsState();
}

class _PendingStudentsState extends State<PendingStudents> {
  final PendingStudentService _service = PendingStudentService();
  late Future<List<PendingStudent>> _future;
  List<PendingStudent>? _localList;

  @override
  void initState() {
    super.initState();
    _future = _loadPending();
  }

  Future<List<PendingStudent>> _loadPending() async {
    final list = await _service.getPending();
    _localList = List<PendingStudent>.from(list);
    return _localList!;
  }

  void _refresh() => setState(() => _future = _loadPending());

  Future<void> _daysDialog(PendingStudent s, {required bool isExtend}) async {
    final ctrl = TextEditingController(text: isExtend ? '3' : '7');
    final title = isExtend
        ? L.t('مہلت بڑھائیں', 'Extend grace')
        : L.t('نئی مہلت مقرر کریں', 'Set new grace');

    final days = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${s.studentName} — $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${L.t('کلاس', 'Class')}: ${s.classTitle}'),
            const SizedBox(height: 12),
            TealBox(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isExtend
                      ? L.t('کتنے دن مزید؟', 'How many more days?')
                      : L.t('کتنے دن (آج سے)؟', 'How many days (from today)?'),
                  helperText: isExtend
                      ? L.t('موجودہ مہلت میں جُڑ جائیں گے', 'Added to current grace')
                      : L.t('0 = فوراً بلاک', '0 = block immediately'),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [3, 7, 15]
                  .map((d) => ActionChip(
                        label: Text('$d ${L.t('دن', 'd')}'),
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                        side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                        onPressed: () => Navigator.pop(context, d),
                      ))
                  .toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(L.t('منسوخ', 'Cancel'))),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(ctrl.text.trim()) ?? 0),
            child: Text(L.t('تصدیق', 'Confirm')),
          ),
        ],
      ),
    );

    if (days == null) return;

    if (isExtend) {
      await _service.extendGracePeriod(
          studentId: s.studentId, classId: s.classId, days: days);
    } else {
      await _service.setGracePeriod(
          studentId: s.studentId, classId: s.classId, days: days);
    }

    if (mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isExtend
              ? L.t('$days دن کی توسیع ہو گئی۔', 'Extended by $days days.')
              : L.t('$days دن کی نئی مہلت مقرر ہوئی۔', 'New grace of $days days set.'))));
    }
  }

  Future<void> _confirmRemoveStudent(PendingStudent s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L.t('اسٹوڈنٹ کو لسٹ سے ہٹائیں؟', 'Remove Student?')),
        content: Text(L.t(
          'کیا آپ ${s.studentName} کو اس کلاس سے ہٹانا چاہتے ہیں؟',
          'Do you want to remove ${s.studentName} from this class?',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('منسوخ', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.t('ہٹائیں', 'Remove')),
          ),
        ],
      ),
    );

    if (ok == true) {
      // Instantly remove locally from list so card disappears immediately
      if (_localList != null) {
        setState(() {
          _localList!.removeWhere((item) => item.studentId == s.studentId);
          _future = Future.value(List<PendingStudent>.from(_localList!));
        });
      }

      await _service.removeStudent(studentId: s.studentId, classId: s.classId);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('${s.studentName} کو کامیابی سے ہٹا دیا گیا۔',
              '${s.studentName} removed successfully.')),
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
              L.t('زیرِ التوا فیس والے اسٹوڈنٹس', 'Students with Pending Fees'),
              style: _ts(fontSize: 18, fontWeight: FontWeight.bold, theme: theme),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.payments_outlined, color: Color(0xFF10B981)),
                tooltip: L.t('فیس کی درخواستیں دیکھیں', 'View Submitted Payments'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PendingPayments()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: L.t('تازہ کریں', 'Refresh'),
                onPressed: _refresh,
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FutureBuilder<List<PendingStudent>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Center(
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
                                color: theme.primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.sentiment_satisfied_alt_rounded,
                                size: 48,
                                color: theme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              L.t('کسی اسٹوڈنٹ کی فیس زیرِ التوا نہیں', 'No Pending Fees'),
                              style: _ts(fontSize: 18, fontWeight: FontWeight.bold, theme: theme),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              L.t('تمام اسٹوڈنٹس کی فیس ادا شدہ یا فعال ہے۔',
                                  'All students are up-to-date with fee requirements.'),
                              textAlign: TextAlign.center,
                              style: _ts(fontSize: 14, color: theme.subtextColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 24, 20),
                    children: [
                      // Top Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  L.t('مہلت کی مانیٹرنگ', 'Grace Period Monitoring'),
                                  textAlign: TextAlign.center,
                                  style: _ts(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  L.t('${list.length} اسٹوڈنٹس کی مہلت باقی ہے',
                                      '${list.length} student(s) with grace time'),
                                  textAlign: TextAlign.center,
                                  style: _ts(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      ...list.map((s) => _card(s, theme)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(PendingStudent s, ThemePreset theme) {
    final blocked = s.isBlocked;
    final label = blocked
        ? L.t('🔒 بلاک (مہلت ختم)', '🔒 Blocked (grace expired)')
        : L.t('⏳ ${s.remaining.inDays} دن ${s.remaining.inHours % 24} گھنٹے باقی',
            '⏳ ${s.remaining.inDays}d ${s.remaining.inHours % 24}h left');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.isDark
              ? [const Color(0xFF0C2738), const Color(0xFF132A4B)]
              : [const Color(0xFFE0F2FE), const Color(0xFFF0FDFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.studentName,
                textAlign: TextAlign.center,
                style: _ts(fontSize: 16, fontWeight: FontWeight.bold, theme: theme),
              ),
              const SizedBox(height: 3),
              Text(
                '${L.t('کلاس', 'Class')}: ${s.classTitle}',
                textAlign: TextAlign.center,
                style: _ts(fontSize: 13, color: theme.subtextColor),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (blocked ? Colors.red : Colors.orange).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: blocked ? Colors.red : Colors.orange,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: _ts(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: blocked ? Colors.red : Colors.orange,
                      ),
                    ),
                  ),
                  if (blocked) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _confirmRemoveStudent(s),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade400),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.delete_outline, color: Colors.red, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              L.t('اسٹوڈنٹ ہٹائیں', 'Remove Student'),
                              style: _ts(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Positioned(
            left: AppLang.ur ? 0 : null,
            right: AppLang.ur ? null : 0,
            top: 0,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: theme.textColor, size: 20),
              padding: EdgeInsets.zero,
              color: theme.cardColor,
              onSelected: (choice) {
                if (choice == 'payments') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PendingPayments()),
                  );
                } else if (choice == 'remove') {
                  _confirmRemoveStudent(s);
                } else {
                  _daysDialog(s, isExtend: choice == 'extend');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'payments',
                  child: Row(
                    children: [
                      const Icon(Icons.payments_outlined, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Text(L.t('فیس درخواست اور تصدیق', 'View & Approve Payment'),
                          style: _ts(fontSize: 13, theme: theme)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'extend',
                  child: Text(L.t('مہلت بڑھائیں (+ دن)', 'Extend grace (+ days)'),
                      style: _ts(fontSize: 13, theme: theme)),
                ),
                PopupMenuItem(
                  value: 'set',
                  child: Text(L.t('نئی مہلت مقرر کریں', 'Set new grace'),
                      style: _ts(fontSize: 13, theme: theme)),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Text(L.t('اسٹوڈنٹ ہٹائیں', 'Remove Student'),
                          style: _ts(fontSize: 13, color: Colors.red, theme: theme)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
