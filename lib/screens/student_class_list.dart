import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/student_service.dart';
import '../widgets/join_class_button.dart';
import '../widgets/logout_button.dart';
import '../widgets/landing_button.dart';
import '../widgets/submit_payment_dialog.dart';
import '../widgets/user_banner.dart';
import '../widgets/theme_selector.dart';
import 'profile_screen.dart';
import 'ai_chat_screen.dart';

class StudentClassList extends StatefulWidget {
  const StudentClassList({super.key});

  @override
  State<StudentClassList> createState() => _StudentClassListState();
}

class _StudentClassListState extends State<StudentClassList> {
  final StudentService _service = StudentService();
  late Future<List<StudentClass>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getMyClasses();
  }

  Future<void> _refresh() async {
    setState(() => _future = _service.getMyClasses());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('میری کلاسز', 'My Classes')),
        actions: [
          const LandingButton(),
          const LanguageToggle(),
          const ThemeSelectorButton(),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.teal),
            tooltip: L.t('AI مدد', 'AI Help'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AiChatScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: L.t('پروفائل', 'Profile'),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
          const LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          const UserBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<StudentClass>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _messageList(
                  L.t('کلاسز لوڈ نہیں ہو سکیں۔', 'Could not load classes.'));
            }
            final classes = snapshot.data ?? [];
            if (classes.isEmpty) {
              return _messageList(L.t('آپ ابھی کسی کلاس میں انرول نہیں ہیں۔',
                  'You are not enrolled in any class yet.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: classes.length,
              itemBuilder: (_, i) => _StudentClassCard(
                item: classes[i],
                onChanged: _refresh,
              ),
            );
          },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageList(String msg) => ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(msg)),
        ],
      );
}

class _StudentClassCard extends StatelessWidget {
  final StudentClass item;
  final VoidCallback onChanged;
  const _StudentClassCard({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isActive
              ? const Color(0xFF10B981).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: item.isActive ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: item.isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item.isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        L.t('لائیو', 'Live'),
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.access_time_rounded, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                '${L.t('وقت', 'Time')}: ${_fmt(item.scheduledAt)}  •  ${item.durationMin} ${L.t('منٹ', 'min')}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAction(context),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (item.isBlocked) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                L.t('🔒 رسائی بند — مہلت ختم ہو گئی', '🔒 Access closed — grace expired'),
                style: const TextStyle(color: Colors.red)),
          ),
          const SizedBox(height: 8),
          _submitPaymentButton(context),
        ],
      );
    }

    if (item.withinGrace) {
      final days = item.graceLeft.inDays;
      final hours = item.graceLeft.inHours % 24;
      return Column(
        children: [
          Text(
              L.t('⏳ مفت مہلت: $days دن $hours گھنٹے باقی',
                  '⏳ Free grace: $days d $hours h left'),
              style: const TextStyle(color: Colors.orange)),
          const SizedBox(height: 8),
          if (item.canJoin)
            JoinClassButton(classId: item.id)
          else
            Text(L.t('کلاس ابھی شروع نہیں ہوئی', 'Class has not started yet')),
          const SizedBox(height: 8),
          _submitPaymentButton(context),
        ],
      );
    }

    if (!item.isActive) {
      return Text(L.t('کلاس ابھی شروع نہیں ہوئی', 'Class has not started yet'));
    }
    return JoinClassButton(classId: item.id);
  }

  Widget _submitPaymentButton(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.receipt_long),
        label: Text(L.t('فیس جمع کروائیں', 'Submit Fee')),
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) =>
                SubmitPaymentDialog(classId: item.id, classTitle: item.title),
          );
          onChanged();
        },
      );

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}
