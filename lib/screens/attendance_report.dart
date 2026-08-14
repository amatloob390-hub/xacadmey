import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/attendance_service.dart';

class AttendanceReport extends StatefulWidget {
  final String classId;
  final String classTitle;

  const AttendanceReport({
    super.key,
    required this.classId,
    required this.classTitle,
  });

  @override
  State<AttendanceReport> createState() => _AttendanceReportState();
}

class _AttendanceReportState extends State<AttendanceReport> {
  final AttendanceService _service = AttendanceService();
  late Future<_ReportData> _future;
  DateTime _date = DateTime.now(); // منتخب دن (default آج)

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReportData> _load() async {
    final results = await Future.wait([
      _service.getSummary(widget.classId, date: _date),
      _service.getAttendance(widget.classId, date: _date),
    ]);
    return _ReportData(
      summary: results[0] as AttendanceSummary,
      records: results[1] as List<AttendanceRecord>,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() {
        _date = d;
        _future = _load();
      });
    }
  }

  Future<void> _exportCsv(List<AttendanceRecord> records) async {
    try {
      await _service.exportCsv(
          classTitle: widget.classTitle, records: records);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(L.t('ایکسپورٹ ناکام، دوبارہ کوشش کریں۔',
                'Export failed, please try again.'))));
      }
    }
  }

  bool get _isToday {
    final n = DateTime.now();
    return _date.year == n.year && _date.month == n.month && _date.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${L.t('حاضری', 'Attendance')}: ${widget.classTitle}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: L.t('دن منتخب کریں', 'Pick a day'),
            onPressed: _pickDate,
          ),
          FutureBuilder<_ReportData>(
            future: _future,
            builder: (context, snapshot) {
              final ready = snapshot.hasData &&
                  (snapshot.data?.records.isNotEmpty ?? false);
              return IconButton(
                icon: const Icon(Icons.download),
                tooltip: L.t('CSV ایکسپورٹ', 'Export CSV'),
                onPressed:
                    ready ? () => _exportCsv(snapshot.data!.records) : null,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ReportData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _msg(L.t('رپورٹ لوڈ نہیں ہو سکی۔', 'Could not load the report.'));
            }
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _dateBar(),
                const SizedBox(height: 8),
                _summaryCard(data.summary),
                const SizedBox(height: 12),
                if (data.records.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Center(
                        child: Text(L.t('اس دن کوئی حاضری نہیں ہوئی۔',
                            'No attendance on this day.'))),
                  )
                else
                  ...data.records.asMap().entries.map(
                        (e) => _recordTile(e.key + 1, e.value),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dateBar() => InkWell(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.event, size: 18, color: Colors.indigo),
              const SizedBox(width: 8),
              Text(
                '${L.t('دن', 'Day')}: ${_date.day}/${_date.month}/${_date.year}'
                '${_isToday ? ' (${L.t('آج', 'Today')})' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(L.t('بدلیں', 'Change'),
                  style: const TextStyle(color: Colors.indigo)),
            ],
          ),
        ),
      );

  Widget _summaryCard(AttendanceSummary s) {
    final absent =
        (s.totalEnrolled - s.totalPresent).clamp(0, s.totalEnrolled);
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat(L.t('کل انرول', 'Enrolled'), '${s.totalEnrolled}', Colors.blue),
            _stat(L.t('حاضر', 'Present'), '${s.totalPresent}', Colors.green),
            _stat(L.t('غیر حاضر', 'Absent'), '$absent', Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 13)),
        ],
      );

  Widget _recordTile(int index, AttendanceRecord r) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          leading: CircleAvatar(child: Text('$index')),
          title: Text(r.fullName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (r.email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    r.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              Text('${L.t('جوائن کیا', 'Joined')}: ${_fmt(r.joinedAt)}'),
            ],
          ),
          trailing: const Icon(Icons.check_circle, color: Colors.green),
        ),
      );

  Widget _msg(String m) =>
      ListView(children: [const SizedBox(height: 120), Center(child: Text(m))]);

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}

class _ReportData {
  final AttendanceSummary summary;
  final List<AttendanceRecord> records;
  _ReportData({required this.summary, required this.records});
}
