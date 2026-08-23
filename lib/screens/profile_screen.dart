import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../membership_cards.dart';
import '../widgets/change_password_button.dart';

// Conditional import: on web use dart:html directly, on native use stub
import '../utils/web_file_picker_stub.dart'
    if (dart.library.html) '../utils/web_file_picker.dart';

/// یوزر کی پروفائل — نام، ای میل، رول، موبائل نمبر (خود ترمیم کے قابل)،
/// پروفائل تصویر، اور پاس ورڈ بدلنے کا آپشن۔ (ٹیچر اور اسٹوڈنٹ دونوں کیلئے
/// مشترک)
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, dynamic>? _profile;
  bool _loading = true;

  final _phoneCtrl = TextEditingController();
  bool _editingPhone = false;
  bool _savingPhone = false;

  Uint8List? _avatarBytes;
  bool _uploadingAvatar = false;

  MembershipCard? _cardTier;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCardTier();
  }

  Future<void> _loadCardTier() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final tier = await fetchActiveMembershipTier(_supabase, user.id);
    if (mounted) setState(() => _cardTier = tier);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name, email, role, is_verified, phone, avatar_base64')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      setState(() {
        _profile = row;
        _phoneCtrl.text = (row?['phone'] as String?) ?? '';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _savePhone() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _savingPhone = true);
    try {
      await _supabase
          .from('profiles')
          .update({'phone': _phoneCtrl.text.trim()}).eq('id', user.id);
      if (mounted) {
        setState(() {
          _editingPhone = false;
          _savingPhone = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _savingPhone = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(L.t('محفوظ نہیں ہو سکا، دوبارہ کوشش کریں۔',
              'Could not save, please try again.')),
        ));
      }
    }
  }

  void _onPickAvatar() {
    if (kIsWeb) {
      pickFileOnWeb().then((bytes) {
        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() => _avatarBytes = bytes);
          _uploadAvatar(bytes);
        }
      });
    } else {
      _pickAvatarNative();
    }
  }

  Future<void> _pickAvatarNative() async {
    Uint8List? bytes;
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty) {
        bytes = result.files.first.bytes;
      }
    } catch (_) {}
    if (bytes == null) {
      try {
        final picker = ImagePicker();
        final XFile? image =
            await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (image != null) bytes = await image.readAsBytes();
      } catch (_) {}
    }
    if (bytes != null && bytes.isNotEmpty && mounted) {
      setState(() => _avatarBytes = bytes);
      _uploadAvatar(bytes);
    }
  }

  Future<void> _uploadAvatar(Uint8List bytes) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final b64 = base64Encode(bytes);
      await _supabase.from('profiles').update({'avatar_base64': b64}).eq('id', user.id);
      if (mounted) setState(() => _uploadingAvatar = false);
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(L.t('تصویر اپلوڈ نہیں ہو سکی، دوبارہ کوشش کریں۔',
              'Could not upload photo, please try again.')),
        ));
      }
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return L.t('ایڈمن', 'Admin');
      case 'teacher':
        return L.t('ٹیچر', 'Teacher');
      case 'manager':
        return L.t('مینیجر', 'Manager');
      default:
        return L.t('اسٹوڈنٹ', 'Student');
    }
  }

  /// placeholder (جیسے "نیا صارف"/"User") کو اصل نام نہ سمجھیں
  static String? _realName(String? n) {
    if (n == null) return null;
    final t = n.trim();
    if (t.isEmpty) return null;
    const placeholders = {'نیا صارف', 'صارف', 'new user', 'user'};
    if (placeholders.contains(t.toLowerCase())) return null;
    return t;
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final email = _profile?['email'] as String? ?? user?.email ?? '';
    final name = _realName(_profile?['full_name'] as String?);
    final role = _profile?['role'] as String?;
    final isStaff = role == 'teacher' || role == 'admin' || role == 'manager';
    final fallback = isStaff
        ? L.t('اُستادِ محترم', 'Respected Teacher')
        : L.t('معزز طالبِ علم', 'Dear Student');
    final displayName = name ?? fallback;
    final storedAvatarB64 = _profile?['avatar_base64'] as String?;

    Uint8List? avatarBytes = _avatarBytes;
    if (avatarBytes == null && storedAvatarB64 != null && storedAvatarB64.isNotEmpty) {
      try {
        avatarBytes = base64Decode(storedAvatarB64);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(L.t('پروفائل', 'Profile')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 24, 20),
                  children: [
                    const SizedBox(height: 8),
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF0D9488), Color(0xFF2563EB)],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: const Color(0xFF0C2738),
                              backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
                              child: avatarBytes == null
                                  ? Text(
                                      displayName.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: -4,
                            right: -4,
                            child: InkWell(
                              onTap: _uploadingAvatar ? null : _onPickAvatar,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: _uploadingAvatar
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_cardTier != null) ...[
                      const SizedBox(height: 8),
                      Center(child: MembershipBadge(tier: _cardTier!)),
                    ],
                    const SizedBox(height: 24),
                    _InfoTile(
                      icon: Icons.email_outlined,
                      label: L.t('ای میل', 'Email'),
                      value: email.isNotEmpty ? email : '—',
                    ),
                    _PhoneTile(
                      controller: _phoneCtrl,
                      editing: _editingPhone,
                      saving: _savingPhone,
                      onEdit: () => setState(() => _editingPhone = true),
                      onSave: _savePhone,
                    ),
                    _InfoTile(
                      icon: Icons.badge_outlined,
                      label: L.t('رول', 'Role'),
                      value: _roleLabel(role),
                    ),
                    _InfoTile(
                      icon: Icons.verified_user_outlined,
                      label: L.t('تصدیق شدہ', 'Verified'),
                      value: (_profile?['is_verified'] == true)
                          ? L.t('ہاں', 'Yes')
                          : L.t('نہیں', 'No'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.lock_reset),
                        label: Text(
                          L.t('پاس ورڈ بدلیں', 'Change Password'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () => showChangePasswordDialog(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0C2738), const Color(0xFF132A4B)]
              : [const Color(0xFFE0F2FE), const Color(0xFFF0FDFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF10B981), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// موبائل نمبر — خود ترمیم کے قابل (پہلے سے enrolled طلباء جن کے پاس یہ
/// خانہ خالی ہے، وہ یہاں سے بھر سکتے ہیں)۔
class _PhoneTile extends StatelessWidget {
  final TextEditingController controller;
  final bool editing;
  final bool saving;
  final VoidCallback onEdit;
  final VoidCallback onSave;

  const _PhoneTile({
    required this.controller,
    required this.editing,
    required this.saving,
    required this.onEdit,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0C2738), const Color(0xFF132A4B)]
              : [const Color(0xFFE0F2FE), const Color(0xFFF0FDFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1.4,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.phone_outlined, color: Color(0xFF10B981), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.t('موبائل نمبر', 'Mobile Number'),
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                editing
                    ? TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onSave(),
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: const InputDecoration(isDense: true, border: UnderlineInputBorder()),
                      )
                    : Text(
                        controller.text.trim().isEmpty ? '—' : controller.text.trim(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                if (editing) ...[
                  const SizedBox(height: 4),
                  Text(
                    L.t('محفوظ کرنے کیلئے ✓ دبائیں', 'Tap ✓ to save'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (saving)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
              icon: Icon(editing ? Icons.check : Icons.edit_outlined,
                  size: 18, color: const Color(0xFF10B981)),
              tooltip: editing ? L.t('محفوظ کریں', 'Save') : L.t('ترمیم کریں', 'Edit'),
              onPressed: editing ? onSave : onEdit,
            ),
        ],
      ),
    );
  }
}
