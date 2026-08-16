import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/attendance_service.dart';
import '../widgets/teal_box.dart';

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
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 20, 12),
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dateBar() => InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(16),
        child: TealBox(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.event, size: 18, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                '${L.t('دن', 'Day')}: ${_date.day}/${_date.month}/${_date.year}'
                '${_isToday ? ' (${L.t('آج', 'Today')})' : ''}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(L.t('بدلیں', 'Change'),
                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

  Widget _summaryCard(AttendanceSummary s) {
    final absent =
        (s.totalEnrolled - s.totalPresent).clamp(0, s.totalEnrolled);
    return TealBox(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(L.t('کل انرول', 'Enrolled'), '${s.totalEnrolled}', const Color(0xFF2563EB)),
          _stat(L.t('حاضر', 'Present'), '${s.totalPresent}', const Color(0xFF10B981)),
          _stat(L.t('غیر حاضر', 'Absent'), '$absent', Colors.red),
        ],
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

  Widget _recordTile(int index, AttendanceRecord r) => TealBox(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
              child: Text('$index', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (r.email.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 2),
                      child: Text(
                        r.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  Text('${L.t('جوائن کیا', 'Joined')}: ${_fmt(r.joinedAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: Color(0xFF10B981)),
          ],
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
