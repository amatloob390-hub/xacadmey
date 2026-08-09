import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../services/auth_service.dart';

/// AppBar میں رکھنے کیلئے لاگ آؤٹ بٹن (تصدیق کے ساتھ)
class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(L.t('لاگ آؤٹ کریں؟', 'Log out?')),
        content: Text(
            L.t('کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟', 'Are you sure you want to log out?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(L.t('منسوخ', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(L.t('لاگ آؤٹ', 'Log out'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: L.t('لاگ آؤٹ', 'Log out'),
      onPressed: () => _confirmLogout(context),
    );
  }
}
