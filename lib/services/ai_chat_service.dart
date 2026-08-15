import 'package:supabase_flutter/supabase_flutter.dart';

/// گفتگو کا ایک پیغام — role: 'user' یا 'assistant'۔
class ChatMessage {
  final String role;
  final String content;
  const ChatMessage(this.role, this.content);

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// AI سپورٹ ایجنٹ — Supabase Edge Function (ai-chat) کو call کرتا ہے۔
/// API key کبھی app میں نہیں آتی؛ صرف server (function) پر ہوتی ہے۔
class AiChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// پوری گفتگو (history) بھیجتا ہے تاکہ AI کو سیاق و سباق یاد رہے۔
  /// آخری پیغام لازماً user کا ہونا چاہیے۔
  Future<String> ask(List<ChatMessage> history) async {
    final res = await _supabase.functions.invoke(
      'ai-chat',
      body: {'messages': history.map((m) => m.toJson()).toList()},
    );

    final data = res.data;
    if (data is Map) {
      if (data['reply'] is String && (data['reply'] as String).isNotEmpty) {
        return data['reply'] as String;
      }
      if (data['error'] != null) {
        throw Exception(data['error'].toString());
      }
    }
    throw Exception('empty response');
  }
}
