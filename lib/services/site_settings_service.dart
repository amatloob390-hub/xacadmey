import 'package:supabase_flutter/supabase_flutter.dart';

/// سائٹ کی سیٹنگز (social media links) — teacher سیٹ کرتا ہے، landing دکھاتی ہے۔
class SiteSettingsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const platforms = ['facebook', 'instagram', 'youtube', 'tiktok', 'whatsapp'];

  Future<Map<String, String>> load() async {
    final row = await _supabase
        .from('site_settings')
        .select('facebook, instagram, youtube, tiktok, whatsapp')
        .eq('id', 1)
        .maybeSingle();
    final out = <String, String>{};
    for (final p in platforms) {
      out[p] = (row?[p] as String?) ?? '';
    }
    return out;
  }

  Future<void> save(Map<String, String> links) async {
    final data = <String, dynamic>{'updated_at': DateTime.now().toIso8601String()};
    for (final p in platforms) {
      final v = (links[p] ?? '').trim();
      data[p] = v.isEmpty ? null : v;
    }
    await _supabase.from('site_settings').update(data).eq('id', 1);
  }
}
