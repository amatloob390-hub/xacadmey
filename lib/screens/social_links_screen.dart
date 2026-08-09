import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/site_settings_service.dart';

/// Teacher/Admin: landing page کے social media links سیٹ کریں۔
class SocialLinksScreen extends StatefulWidget {
  const SocialLinksScreen({super.key});

  @override
  State<SocialLinksScreen> createState() => _SocialLinksScreenState();
}

class _SocialLinksScreenState extends State<SocialLinksScreen> {
  final SiteSettingsService _service = SiteSettingsService();
  final Map<String, TextEditingController> _ctrls = {
    for (final p in SiteSettingsService.platforms) p: TextEditingController(),
  };
  bool _loading = true;
  bool _saving = false;

  static const _meta = {
    'facebook': ('Facebook', Icons.facebook, 'https://facebook.com/...'),
    'instagram': ('Instagram', Icons.camera_alt_outlined, 'https://instagram.com/...'),
    'youtube': ('YouTube', Icons.play_circle_outline, 'https://youtube.com/@...'),
    'tiktok': ('TikTok', Icons.music_note_outlined, 'https://tiktok.com/@...'),
    'whatsapp': ('WhatsApp', Icons.chat_outlined, 'https://wa.me/92300...'),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await _service.load();
      for (final p in SiteSettingsService.platforms) {
        _ctrls[p]!.text = data[p] ?? '';
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.save(
        {for (final p in SiteSettingsService.platforms) p: _ctrls[p]!.text},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('لنکس محفوظ ہو گئے ✅ landing page پر نظر آئیں گے۔',
            'Links saved ✅ They will appear on the landing page.')),
        backgroundColor: Colors.green.shade700,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('محفوظ نہیں ہو سکا: $e', 'Could not save: $e')),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 6),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L.t('سوشل میڈیا لنکس', 'Social media links'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  L.t('یہ لنکس آپ کے landing page کے footer میں دکھائے جائیں گے۔ خالی چھوڑیں تو وہ آئیکن چھپ جائے گا۔',
                      'These links show in your landing page footer. Leave blank to hide that icon.'),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 18),
                for (final p in SiteSettingsService.platforms) ...[
                  TextField(
                    controller: _ctrls[p],
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: _meta[p]!.$1,
                      prefixIcon: Icon(_meta[p]!.$2),
                      hintText: _meta[p]!.$3,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 6),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_saving
                      ? L.t('محفوظ ہو رہا ہے...', 'Saving...')
                      : L.t('محفوظ کریں', 'Save')),
                ),
              ],
            ),
    );
  }
}
