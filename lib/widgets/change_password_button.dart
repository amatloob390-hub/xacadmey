import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';

/// پاس ورڈ بدلنے کا ڈائیلاگ کھولیں (کہیں سے بھی استعمال ہو سکتا ہے)۔
Future<void> showChangePasswordDialog(BuildContext context) => showDialog(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );

/// AppBar میں رکھنے کیلئے "پاس ورڈ بدلیں" بٹن۔
/// موجودہ لاگ اِن سیشن استعمال کر کے نیا پاس ورڈ سیٹ کرتا ہے
/// (اِس کے بعد اگلی بار عام لاگ اِن اُسی پاس ورڈ سے ہوگا)۔
class ChangePasswordButton extends StatelessWidget {
  const ChangePasswordButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.lock_reset),
      tooltip: L.t('پاس ورڈ بدلیں', 'Change Password'),
      onPressed: () => showChangePasswordDialog(context),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _pass1 = TextEditingController();
  final _pass2 = TextEditingController();
  bool _obscure = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _pass1.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p1 = _pass1.text.trim();
    final p2 = _pass2.text.trim();

    if (p1.length < 6) {
      setState(() => _error =
          L.t('پاس ورڈ کم از کم 6 حروف کا ہونا چاہیے۔', 'Password must be at least 6 characters.'));
      return;
    }
    if (p1 != p2) {
      setState(() => _error =
          L.t('دونوں پاس ورڈ ایک جیسے نہیں ہیں۔', 'Passwords do not match.'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: p1),
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L.t('پاس ورڈ تبدیل ہو گیا ✅ اگلی بار اِسی سے لاگ اِن کریں۔',
            'Password changed ✅ Use it to log in next time.')),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = L.t('پاس ورڈ تبدیل نہیں ہوا، دوبارہ کوشش کریں۔',
            'Could not change password, please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L.t('پاس ورڈ بدلیں', 'Change Password')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pass1,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: L.t('نیا پاس ورڈ', 'New password'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass2,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: L.t('پاس ورڈ دوبارہ', 'Confirm password'),
              prefixIcon: const Icon(Icons.lock_outline),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(L.t('منسوخ', 'Cancel')),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(L.t('محفوظ کریں', 'Save')),
        ),
      ],
    );
  }
}
