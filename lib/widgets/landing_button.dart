import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../screens/landing_screen.dart';

/// AppBar میں رکھنے کیلئے "ہوم/ویب سائٹ" بٹن — مرکزی landing page کھولتا ہے۔
class LandingButton extends StatelessWidget {
  const LandingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: L.t('مرکزی صفحہ', 'Home page'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LandingScreen()),
        );
      },
    );
  }
}
