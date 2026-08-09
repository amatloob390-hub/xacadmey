import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/pending_student_service.dart';

class PendingStudents extends StatefulWidget {
  const PendingStudents({super.key});

  @override
  State<PendingStudents> createState() => _PendingStudentsState();
}

class _PendingStudentsState extends State<PendingStudents> {
  final PendingStudentService _service = PendingStudentService();
  late Future<List<PendingStudent>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getPending();
  }

  void _refresh() => setState(() => _future = _service.getPending());

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
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isExtend
                    ? L.t('کتنے دن مزید؟', 'How many more days?')
                    : L.t('کتنے دن (آج سے)؟', 'How many days (from today)?'),
                helperText: isExtend
                    ? L.t('موجودہ مہلت میں جُڑ جائیں گے', 'Added to current grace')
                    : L.t('0 = فوراً بلاک', '0 = block immediately'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [3, 7, 15]
                  .map((d) => ActionChip(
                        label: Text('$d ${L.t('دن', 'd')}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(L.t('زیرِ التوا فیس والے اسٹوڈنٹس', 'Students with Pending Fees'))),
      body: FutureBuilder<List<PendingStudent>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
                child: Text(L.t('کسی اسٹوڈنٹ کی فیس زیرِ التوا نہیں۔',
                    'No students have pending fees.')));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            itemBuilder: (_, i) => _card(list[i]),
          );
        },
      ),
    );
  }

  Widget _card(PendingStudent s) {
    final blocked = s.isBlocked;
    final label = blocked
        ? L.t('🔒 بلاک (مہلت ختم)', '🔒 Blocked (grace expired)')
        : L.t('⏳ ${s.remaining.inDays} دن ${s.remaining.inHours % 24} گھنٹے باقی',
            '⏳ ${s.remaining.inDays}d ${s.remaining.inHours % 24}h left');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(s.studentName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${L.t('کلاس', 'Class')}: ${s.classTitle}'),
            Text(label,
                style: TextStyle(
                    color: blocked ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (choice) => _daysDialog(s, isExtend: choice == 'extend'),
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'extend',
                child: Text(L.t('مہلت بڑھائیں (+ دن)', 'Extend grace (+ days)'))),
            PopupMenuItem(
                value: 'set', child: Text(L.t('نئی مہلت مقرر کریں', 'Set new grace'))),
          ],
        ),
      ),
    );
  }
}
