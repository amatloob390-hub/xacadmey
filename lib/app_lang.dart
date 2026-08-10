import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// عالمی زبان کنٹرولر — اردو (default) یا انگریزی، منتخب زبان محفوظ رہتی ہے۔
class AppLang {
  static final ValueNotifier<bool> isUrdu = ValueNotifier<bool>(true);
  static const _key = 'app_lang_urdu';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    isUrdu.value = prefs.getBool(_key) ?? true;
  }

  static Future<void> toggle() async {
    isUrdu.value = !isUrdu.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, isUrdu.value);
  }

  static bool get ur => isUrdu.value;
  static TextDirection get dir => ur ? TextDirection.rtl : TextDirection.ltr;
}

/// دو زبانوں کا مختصر ہیلپر: L.t('اردو', 'English')
/// انگریزی میں ہر لفظ کا پہلا حرف Capital (Title Case) کرے گا۔
class L {
  static String t(String urdu, String english) {
    if (AppLang.ur) return urdu;
    if (english.trim().isEmpty) return english;

    return english.split(' ').map((word) {
      if (word.isEmpty) return word;
      // Skip URLs, brackets, or numbers
      if (word.startsWith('http') || word.contains('@')) return word;
      if (word.length == 1) return word.toUpperCase();
      
      // Capitalize first character if it is a letter
      final firstChar = word[0].toUpperCase();
      return '$firstChar${word.substring(1)}';
    }).join(' ');
  }
}

/// زبان بدلنے کا بٹن (AppBar میں رکھیں)
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLang.isUrdu,
      builder: (context, isUrdu, _) {
        return ValueListenableBuilder<ThemePreset>(
          valueListenable: AppTheme.currentTheme,
          builder: (context, theme, _) {
            return InkWell(
              onTap: () => AppLang.toggle(),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.textColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_rounded, size: 18, color: theme.textColor),
                    const SizedBox(width: 6),
                    Text(
                      isUrdu ? 'EN (English)' : 'اردو (Urdu)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                        fontFamily: isUrdu ? null : 'NotoNastaliqUrdu',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Compact icon-only language toggle for mobile headers
class CompactLanguageToggle extends StatelessWidget {
  const CompactLanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLang.isUrdu,
      builder: (context, isUrdu, _) {
        return ValueListenableBuilder<ThemePreset>(
          valueListenable: AppTheme.currentTheme,
          builder: (context, theme, _) {
            return InkWell(
              onTap: () => AppLang.toggle(),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.textColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.language_rounded, size: 16, color: theme.textColor),
                    const SizedBox(width: 4),
                    Text(
                      isUrdu ? 'EN' : 'اردو',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                        fontFamily: isUrdu ? null : 'NotoNastaliqUrdu',
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

