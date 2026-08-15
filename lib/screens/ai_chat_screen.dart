import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/ai_chat_service.dart';

class ChatMsg {
  final String text;
  final bool fromUser;
  // ناکام/خطا کا پیغام — گفتگو کی history میں AI کو نہیں بھیجا جاتا۔
  final bool isError;
  ChatMsg(this.text, this.fromUser, {this.isError = false});
}

/// فری لانسنگ AI مدد — سوال پوچھیں، AI جواب دے۔
class AiChatScreen extends StatefulWidget {
  /// دیا جائے تو یہی list استعمال ہوتی ہے (parent کے پاس رہتی ہے) — تاکہ
  /// سائیڈ بار پین سوئچ ہونے پر AiChatScreen کی اپنی State نئی بننے کے
  /// باوجود گفتگو یاد رہے۔ نہ دیا جائے تو ہمیشہ کی طرح مقامی/عارضی۔
  final List<ChatMsg>? messages;
  const AiChatScreen({super.key, this.messages});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final AiChatService _service = AiChatService();
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final List<ChatMsg> _messages = widget.messages ?? [];
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMsg(text, true));
      _sending = true;
      _ctrl.clear();
    });
    _scrollDown();

    try {
      // پوری گفتگو بھیجیں (خطا کے bubbles نکال کر) تاکہ AI کو سیاق یاد رہے۔
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => ChatMessage(m.fromUser ? 'user' : 'assistant', m.text))
          .toList();
      final reply = await _service.ask(history);
      if (!mounted) return;
      setState(() => _messages.add(ChatMsg(reply, false)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(ChatMsg(
          L.t('معذرت، جواب نہیں مل سکا۔ دوبارہ کوشش کریں۔',
              'Sorry, could not get a reply. Please try again.'),
          false,
          isError: true)));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollDown();
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('AI مدد', 'AI Help')),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _emptyState()
                : Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 20, 22),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i]),
                    ),
                  ),
          ),
          if (_sending)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(L.t('AI سوچ رہا ہے…', 'AI is thinking…'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          _composer(),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 56, color: Colors.teal),
              const SizedBox(height: 14),
              Text(
                L.t('فری لانسنگ سے متعلق کچھ بھی پوچھیں',
                    'Ask anything about freelancing'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                L.t('مثلاً: "Fiverr پر پہلا gig کیسے بناؤں؟"',
                    'e.g. "How do I create my first gig on Fiverr?"'),
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _bubble(ChatMsg m) {
    final isUser = m.fromUser;
    final label = isUser ? L.t('آپ', 'You') : L.t('AI مدد', 'AI Help');
    final textColor = isUser ? Colors.white : Colors.black87;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isUser ? Icons.person : Icons.auto_awesome,
                  size: 14,
                  color: isUser ? Colors.teal : const Color(0xFF17193A)),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.82),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isUser ? Colors.teal : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: isUser
                  ? null
                  : Border.all(color: const Color(0xFFE6E6F0)),
            ),
            child: Text(m.text,
                style: TextStyle(color: textColor, height: 1.55)),
          ),
        ],
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: L.t('اپنا سوال لکھیں…', 'Type your question…'),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
