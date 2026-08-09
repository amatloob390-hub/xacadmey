import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../services/student_service.dart';

/// اسٹوڈنٹ دستیاب کلاسز دیکھ کر خود انرول ہو سکتا ہے۔
class BrowseClasses extends StatefulWidget {
  const BrowseClasses({super.key});

  @override
  State<BrowseClasses> createState() => _BrowseClassesState();
}

class _BrowseClassesState extends State<BrowseClasses> {
  final StudentService _service = StudentService();
  late Future<List<AvailableClass>> _future;
  final Set<String> _enrolling = {};

  @override
  void initState() {
    super.initState();
    _future = _service.getAvailableClasses();
  }

  void _refresh() => setState(() => _future = _service.getAvailableClasses());

  Future<void> _enroll(AvailableClass c) async {
    setState(() => _enrolling.add(c.id));
    try {
      await _service.enroll(c.id);
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('"${c.title}" میں انرول ہو گئے — ۷ دن کی مہلت فعال۔',
              'Enrolled in "${c.title}" — 7-day grace active.')),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enrolling.remove(c.id));
        final raw = e is PostgrestException ? e.message : e.toString();
        final msg = raw.contains('ENROLLMENT_CLOSED')
            ? L.t('یہ کلاس ۷ دن سے جاری ہے — اب نیا انرولمنٹ بند ہے۔',
                'This class has been running 7 days — new enrollment is now closed.')
            : L.t('انرول نہیں ہو سکا، دوبارہ کوشش کریں۔',
                'Could not enroll, please try again.');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('دستیاب کلاسز', 'Available Classes'))),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<AvailableClass>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _msg(L.t('کلاسز لوڈ نہیں ہو سکیں۔', 'Could not load classes.'));
            }
            final list = snapshot.data ?? [];
            if (list.isEmpty) {
              return _msg(L.t('اس وقت کوئی نئی کلاس دستیاب نہیں۔',
                  'No new classes available right now.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              itemBuilder: (_, i) => _card(list[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _card(AvailableClass c) {
    final busy = _enrolling.contains(c.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(c.title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (c.isActive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(L.t('🟢 لائیو', '🟢 Live'),
                        style: const TextStyle(color: Colors.green, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                '${L.t('وقت', 'Time')}: ${_fmt(c.scheduledAt)}  •  ${c.durationMin} ${L.t('منٹ', 'min')}',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : () => _enroll(c),
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_task),
                label: Text(busy
                    ? L.t('انرول ہو رہا ہے...', 'Enrolling...')
                    : L.t('انرول کریں', 'Enroll')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _msg(String m) =>
      ListView(children: [const SizedBox(height: 120), Center(child: Text(m))]);

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}
