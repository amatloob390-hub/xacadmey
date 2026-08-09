import 'package:supabase_flutter/supabase_flutter.dart';

/// AI سپورٹ ایجنٹ — Supabase Edge Function (ai-chat) کو call کرتا ہے۔
/// API key کبھی app میں نہیں آتی؛ صرف server (function) پر ہوتی ہے۔
class AiChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> ask(String message) async {
    final res = await _supabase.functions.invoke(
      'ai-chat',
      body: {'message': message},
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
