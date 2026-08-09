import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';

class AttendanceRecord {
  final String studentId;
  final String fullName;
  final DateTime joinedAt;

  AttendanceRecord.fromMap(Map<String, dynamic> m)
      : studentId = m['student_id'] as String,
        fullName = m['full_name'] as String,
        joinedAt = DateTime.parse(m['joined_at'] as String);
}

class AttendanceSummary {
  final int totalEnrolled;
  final int totalPresent;

  AttendanceSummary.fromMap(Map<String, dynamic> m)
      : totalEnrolled = m['total_enrolled'] as int,
        totalPresent = m['total_present'] as int;
}

class AttendanceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static String dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// کسی مخصوص دن کی حاضری (date نہ دیں تو آج)
  Future<List<AttendanceRecord>> getAttendance(String classId,
      {DateTime? date}) async {
    final rows = await _supabase.rpc('get_class_attendance', params: {
      'p_class_id': classId,
      'p_date': date == null ? null : dateStr(date),
    }) as List;
    return rows
        .map((r) => AttendanceRecord.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceSummary> getSummary(String classId, {DateTime? date}) async {
    final rows = await _supabase.rpc('get_attendance_summary', params: {
      'p_class_id': classId,
      'p_date': date == null ? null : dateStr(date),
    }) as List;
    return AttendanceSummary.fromMap(rows.first as Map<String, dynamic>);
  }

  /// حاضری کو CSV میں بدل کر شیئر/ڈاؤن لوڈ کرتا ہے (ویب + موبائل)
  Future<void> exportCsv({
    required String classTitle,
    required List<AttendanceRecord> records,
  }) async {
    final rows = <List<dynamic>>[
      [L.t('نمبر', 'No.'), L.t('نام', 'Name'), L.t('جوائن کرنے کا وقت', 'Join time')],
      ...records.asMap().entries.map((e) => [
            e.key + 1,
            e.value.fullName,
            _fmtDate(e.value.joinedAt),
          ]),
    ];

    final csvString = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode('﻿$csvString'); // UTF-8 BOM برائے Excel

    final fileName =
        'attendance_${classTitle}_${DateTime.now().millisecondsSinceEpoch}.csv';

    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
      text: '$classTitle — ${L.t('حاضری رپورٹ', 'Attendance Report')}',
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}
