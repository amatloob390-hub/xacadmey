import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/teacher_service.dart';

class CreateClassDialog extends StatefulWidget {
  final TeacherService service;
  final Map<String, dynamic>? existing; // موجود ہو تو ایڈٹ موڈ
  const CreateClassDialog({super.key, required this.service, this.existing});

  @override
  State<CreateClassDialog> createState() => _CreateClassDialogState();
}

class _CreateClassDialogState extends State<CreateClassDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  DateTime _scheduledAt = _roundToNextHour();
  int _durationMin = 60;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  static DateTime _roundToNextHour() {
    final now = DateTime.now().add(const Duration(hours: 1));
    return DateTime(now.year, now.month, now.day, now.hour);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e['title'] as String? ?? '';
      _linkCtrl.text = e['zoom_link'] as String? ?? '';
      _durationMin = e['duration_min'] as int? ?? 60;
      final s = DateTime.tryParse(e['scheduled_at'] ?? '');
      if (s != null) _scheduledAt = s;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _linkCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(minutes: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await widget.service.updateClass(
          classId: widget.existing!['id'] as String,
          title: _titleCtrl.text.trim(),
          zoomLink: _linkCtrl.text.trim(),
          scheduledAt: _scheduledAt,
          durationMin: _durationMin,
        );
      } else {
        await widget.service.createClass(
          title: _titleCtrl.text.trim(),
          zoomLink: _linkCtrl.text.trim(),
          scheduledAt: _scheduledAt,
          durationMin: _durationMin,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEdit
              ? L.t('کلاس اپڈیٹ ہو گئی ✅', 'Class updated ✅')
              : L.t('کلاس بن گئی ✅', 'Class created ✅')),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(L.t('کلاس محفوظ نہیں ہو سکی۔', 'Could not save the class.'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Icon(Icons.video_call,
                            color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            _isEdit
                                ? L.t('کلاس ایڈٹ کریں', 'Edit Class')
                                : L.t('نئی کلاس بنائیں', 'New Class'),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed:
                            _saving ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  TextFormField(
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: L.t('کلاس کا عنوان', 'Class title'),
                      hintText: L.t('مثلاً: ریاضی — باب ۳', 'e.g. Maths — Ch 3'),
                      prefixIcon: const Icon(Icons.title),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? L.t('عنوان ضروری ہے', 'Title is required')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _linkCtrl,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: L.t('زوم لنک', 'Zoom link'),
                      hintText: 'https://zoom.us/j/...',
                      prefixIcon: const Icon(Icons.link),
                      helperText: L.t('یہ لنک اسٹوڈنٹس کو کبھی نظر نہیں آئے گا',
                          'Students will never see this link'),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return L.t('زوم لنک درج کریں', 'Enter the Zoom link');
                      }
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.isAbsolute || !v.contains('http')) {
                        return L.t('درست لنک درج کریں (http سے شروع)',
                            'Enter a valid link (starts with http)');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child:
                        Text(L.t('دورانیہ', 'Duration'), style: theme.textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [30, 45, 60, 90, 120].map((m) {
                      return ChoiceChip(
                        label: Text('$m ${L.t('منٹ', 'min')}'),
                        selected: _durationMin == m,
                        onSelected: (_) => setState(() => _durationMin = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(L.t('تاریخ اور وقت', 'Date & time'),
                        style: theme.textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDateTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_fmtDate(_scheduledAt),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(_fmtTime(_scheduledAt),
                                    style:
                                        TextStyle(color: Colors.grey.shade700)),
                              ],
                            ),
                          ),
                          const Icon(Icons.edit, size: 18),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_saving
                          ? L.t('محفوظ ہو رہا ہے...', 'Saving...')
                          : L.t('کلاس محفوظ کریں', 'Save Class')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const _weekdaysUr = ['پیر', 'منگل', 'بدھ', 'جمعرات', 'جمعہ', 'ہفتہ', 'اتوار'];
  static const _monthsUr = [
    'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
    'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
  ];
  static const _weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _fmtDate(DateTime d) {
    final wd = AppLang.ur ? _weekdaysUr[d.weekday - 1] : _weekdaysEn[d.weekday - 1];
    final mo = AppLang.ur ? _monthsUr[d.month - 1] : _monthsEn[d.month - 1];
    return '$wd, ${d.day} $mo ${d.year}';
  }

  String _fmtTime(DateTime d) {
    final hour12 = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final period = AppLang.ur
        ? (d.hour < 12 ? 'صبح' : 'شام')
        : (d.hour < 12 ? 'AM' : 'PM');
    final min = d.minute.toString().padLeft(2, '0');
    return '$hour12:$min $period';
  }
}
