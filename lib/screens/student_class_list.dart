import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../pending_class.dart';
import '../services/student_service.dart';
import '../widgets/dashboard_analytics_card.dart';
import '../widgets/join_class_button.dart';
import '../widgets/logout_button.dart';
import '../widgets/landing_button.dart';
import '../widgets/submit_payment_dialog.dart';
import '../widgets/user_banner.dart';
import '../widgets/theme_selector.dart';
import '../widgets/student_drawer.dart';
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

  void _openAiOverlay(String contextTitle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.teal, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Teaching Assistant — $contextTitle',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.teal.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, color: Colors.teal),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                L.t('AI اسسنائٹ لائیو سبق کو سمرائز اور اہم نکات سمجھانے کیلئے تیار ہے۔',
                                    'AI Teaching Assistant is ready to explain and summarize key lecture points.'),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.edit_note, size: 16, color: Colors.teal),
                            label: Text(L.t('Mark as Note', 'Mark as Note')),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(L.t('لیکچر نوٹس میں سیو ہو گیا 📝', 'Saved to Lecture Notes 📝')),
                              ));
                            },
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.psychology, size: 16, color: Colors.purple),
                            label: Text(L.t('Ask AI Assistant to Explain', 'Ask AI Assistant to Explain')),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.summarize, size: 16, color: Colors.blue),
                            label: Text(L.t('لیکچر کا خلاصہ (Summary)', 'Lecture Summary')),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        L.t('فوری سوالات (Quick Q&A):', 'Quick Questions:'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: Colors.teal),
                        title: Text(L.t('اس سبق کے بنیادی نکات کیا ہیں؟', 'What are the main concepts of this lesson?')),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
                      ),
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: Colors.teal),
                        title: Text(L.t('مجھے اس ٹاپک کا ایک آسان کوئز دیں۔', 'Give me a quick quiz on this topic.')),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiChatScreen())),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: StudentDrawer(
        onOpenAiAssistant: () => _openAiOverlay('XAcademy Tutors'),
      ),
      appBar: AppBar(
        title: Text(L.t('میری کلاسز اور ڈیش بورڈ', 'My Dashboard & Classes')),
        actions: [
          const LandingButton(),
          const LanguageToggle(),
          const ThemeSelectorButton(),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.teal),
            tooltip: L.t('AI Teaching Assistant', 'AI Teaching Assistant'),
            onPressed: () => _openAiOverlay('XAcademy Tutors'),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
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

                      final analyticsWidget = Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  L.t('ڈیش بورڈ اینالیٹکس', 'Dashboard Analytics'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.timelapse, size: 14, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Text(
                                        L.t('ہفتہ وار جائزہ', 'Weekly View'),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Analytics Gauges Row / Wrap
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: RadialGaugeCard(
                                    title: L.t('کلاس وقت', 'Class Time'),
                                    valueText: '2.5 hrs',
                                    subtext: L.t('کل وقت: 12 hrs', 'Total Time: 12 hrs'),
                                    progress: 0.65,
                                    primaryColor: const Color(0xFF10B981),
                                    icon: Icons.timer_outlined,
                                  ),
                                ),
                                SizedBox(
                                  width: 260,
                                  child: RadialGaugeCard(
                                    title: L.t('حاضری کا تناسب', 'Attendance Rate'),
                                    valueText: '95%',
                                    subtext: L.t('19 میں سے 20 کلاسز', '19 out of 20 classes'),
                                    progress: 0.95,
                                    primaryColor: const Color(0xFF10B981),
                                    icon: Icons.pie_chart_outline,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      if (classes.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            analyticsWidget,
                            _emptyState(),
                          ],
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          analyticsWidget,
                          const SizedBox(height: 16),
                          Text(
                            L.t('میری کلاسز اور لیکچرز', 'My Classes & Lectures'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 14),
                          ...classes.map((c) => _StudentClassCard(
                                item: c,
                                onChanged: _refresh,
                                onOpenAi: _openAiOverlay,
                              )),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          padding: const EdgeInsets.all(28),
          margin: const EdgeInsets.only(top: 20),
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
                L.t('آپ ابھی کسی کلاس میں شامل نہیں ہیں۔',
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
  final Function(String title) onOpenAi;

  const _StudentClassCard({
    required this.item,
    required this.onChanged,
    required this.onOpenAi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top Status Badge (Live Tag)
              if (item.isActive) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF34D399), width: 1.4),
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
                        L.t('لائیو کلاس', 'Live Class'),
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],

              // AI Teaching Assistant Floating Action Overlay
              InkWell(
                onTap: () => onOpenAi(item.title),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade900.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purpleAccent, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Colors.purpleAccent),
                      const SizedBox(width: 6),
                      Text(
                        L.t('Ask AI Assistant', 'Ask AI Assistant'),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                ),
                child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF6EE7B7)),
                        const SizedBox(width: 6),
                        Text(
                          '${L.t('وقت', 'Time')}: ${_fmt(item.scheduledAt)}  •  ${item.durationMin} ${L.t('منٹ', 'min')}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Actions & Grace Information
          _buildAction(context),
        ],
      ),
    );
  }

  Widget _buildAction(BuildContext context) {
    if (item.isBlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: Text(
              L.t('🔒 رسائی بند — مہلت ختم ہو گئی', '🔒 Access closed — grace expired'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          _submitPaymentButton(context),
        ],
      );
    }

    if (item.withinGrace) {
      final days = item.graceLeft.inDays;
      final hours = item.graceLeft.inHours % 24;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade300, width: 1.2),
            ),
            child: Text(
              L.t('⏳ مفت مہلت: $days دن $hours گھنٹے باقی', '⏳ Free grace: $days d $hours h left'),
              style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (item.canJoin) Expanded(child: JoinClassButton(classId: item.id)),
              const SizedBox(width: 8),
              _submitPaymentButton(context),
            ],
          ),
        ],
      );
    }

    if (!item.isActive) {
      return Text(
        L.t('کلاس ابھی شروع نہیں ہوئی', 'Class has not started yet'),
        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600),
      );
    }
    return JoinClassButton(classId: item.id);
  }

  Widget _submitPaymentButton(BuildContext context) => OutlinedButton.icon(
        icon: const Icon(Icons.receipt_long, color: Colors.white, size: 16),
        label: Text(
          L.t('فیس جمع کروائیں', 'Submit Fee'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white, width: 1.6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
