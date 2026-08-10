import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../pending_class.dart';
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
    _checkPendingClassAndLoad();
  }

  Future<void> _checkPendingClassAndLoad() async {
    final pId = PendingClass.id;
    if (pId != null && pId.isNotEmpty) {
      PendingClass.id = null;
      try {
        await _service.enroll(pId);
      } catch (_) {}
    }
    _future = _service.getMyClasses();
    if (mounted) setState(() {});
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
                    return _emptyState();
                  }
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        itemCount: classes.length,
                        itemBuilder: (_, i) => _StudentClassCard(
                          item: classes[i],
                          onChanged: _refresh,
                        ),
                      ),
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

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
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
                  const Icon(Icons.school_outlined, size: 56, color: Color(0xFF10B981)),
                  const SizedBox(height: 16),
                  Text(
                    L.t('آپ ابھی کسی کلاس میں انرول نہیں ہیں۔',
                        'You are not enrolled in any class yet.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    L.t('دوبارہ لوڈ کرنے کے لیے نیچے بٹن دبائیں۔',
                        'Press the button below to reload.'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(L.t('کلاسز دوبارہ لوڈ کریں', 'Reload Classes')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _messageList(String msg) => ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              msg,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
}

class _StudentClassCard extends StatelessWidget {
  final StudentClass item;
  final VoidCallback onChanged;
  const _StudentClassCard({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top Status Badge (Live Tag)
          if (item.isActive)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF34D399), width: 1.4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34D399),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    L.t('لائیو', 'Live'),
                    style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // School Icon Header
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 14),

          // Class Title (Centered)
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),

          // Time & Duration (Centered)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_rounded, size: 18, color: Color(0xFF6EE7B7)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${L.t('وقت', 'Time')}: ${_fmt(item.scheduledAt)}  •  ${item.durationMin} ${L.t('منٹ', 'min')}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Actions & Grace Information (Centered)
          _buildAction(context),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (item.isBlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: Text(
              L.t('🔒 رسائی بند — مہلت ختم ہو گئی', '🔒 Access closed — grace expired'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          _submitPaymentButton(context),
        ],
      );
    }

    if (item.withinGrace) {
      final days = item.graceLeft.inDays;
      final hours = item.graceLeft.inHours % 24;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade300, width: 1.2),
            ),
            child: Text(
              L.t('⏳ مفت مہلت: $days دن $hours گھنٹے باقی', '⏳ Free grace: $days d $hours h left'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(height: 14),
          if (item.canJoin)
            JoinClassButton(classId: item.id)
          else
            Text(
              L.t('کلاس ابھی شروع نہیں ہوئی', 'Class has not started yet'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 12),
          _submitPaymentButton(context),
        ],
      );
    }

    if (!item.isActive) {
      return Text(
        L.t('کلاس ابھی شروع نہیں ہوئی', 'Class has not started yet'),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
      );
    }
    return JoinClassButton(classId: item.id);
  }

  Widget _submitPaymentButton(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.receipt_long, color: Colors.white),
        label: Text(
          L.t('فیس جمع کروائیں', 'Submit Fee'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white, width: 1.8),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () async {
          await showDialog(
            context: context,
            builder: (_) => SubmitPaymentDialog(classId: item.id, classTitle: item.title),
          );
          onChanged();
        },
      );

  String _fmt(DateTime d) =>
      '${d.day}/${d.month}  ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}
