import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreset {
  final int id;
  final String nameUrdu;
  final String nameEnglish;
  final bool isDark;
  final Color primaryColor;
  final Color secondaryColor;
  final Color bgColor;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;

  const ThemePreset({
    required this.id,
    required this.nameUrdu,
    required this.nameEnglish,
    required this.isDark,
    required this.primaryColor,
    required this.secondaryColor,
    required this.bgColor,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
  });
}

class AppTheme {
  static const _key = 'selected_theme_id';

  static final List<ThemePreset> presets = [
    // --- 4 DARK THEMES ---
    const ThemePreset(
      id: 1,
      nameUrdu: '1. ای آئی سائبر سائن (AI Cyber Cyan - Left Screen)',
      nameEnglish: '1. AI Cyber Cyan (Left Screen)',
      isDark: true,
      primaryColor: Color(0xFF00D2FF),
      secondaryColor: Color(0xFF2563EB),
      bgColor: Color(0xFF0F172A),
      cardColor: Color(0xFF1E293B),
      textColor: Color(0xFFFFFFFF),
      subtextColor: Color(0xFF93C5FD),
    ),
    const ThemePreset(
      id: 2,
      nameUrdu: '2. شاہی نیلا اور نیون سائن (Royal Blue & Neon Cyan)',
      nameEnglish: '2. Royal Blue & Neon Cyan',
      isDark: true,
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF06B6D4),
      bgColor: Color(0xFF111827),
      cardColor: Color(0xFF1F2937),
      textColor: Color(0xFFF1F5F9),
      subtextColor: Color(0xFF94A3B8),
    ),
    const ThemePreset(
      id: 3,
      nameUrdu: '3. الیکٹرک وائلٹ اور میجنٹا (Electric Violet & Magenta)',
      nameEnglish: '3. Electric Violet & Magenta',
      isDark: true,
      primaryColor: Color(0xFF7C3AED),
      secondaryColor: Color(0xFFEC4899),
      bgColor: Color(0xFF1E1B2E),
      cardColor: Color(0xFF2A243D),
      textColor: Color(0xFFF8FAFC),
      subtextColor: Color(0xFFA78BFA),
    ),
    const ThemePreset(
      id: 4,
      nameUrdu: '4. اوبسیڈین نائٹ اور منٹ گرین (Obsidian & Mint Green)',
      nameEnglish: '4. Obsidian & Mint Green',
      isDark: true,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF3B82F6),
      bgColor: Color(0xFF131F2F),
      cardColor: Color(0xFF1E2D42),
      textColor: Color(0xFFF8FAFC),
      subtextColor: Color(0xFF8D99AE),
    ),

    // --- 2 LIGHT THEMES ---
    const ThemePreset(
      id: 5,
      nameUrdu: '5. کلین وائٹ اور اوشن سیان (Clean White & Ocean Cyan)',
      nameEnglish: '5. Clean White & Ocean Cyan',
      isDark: false,
      primaryColor: Color(0xFF0284C7),
      secondaryColor: Color(0xFF0D9488),
      bgColor: Color(0xFFF8FAFC),
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF0F172A),
      subtextColor: Color(0xFF64748B),
    ),
    const ThemePreset(
      id: 6,
      nameUrdu: '6. وارم پرل اور کرمسن روز (Warm Pearl & Crimson Rose)',
      nameEnglish: '6. Warm Pearl & Crimson Rose',
      isDark: false,
      primaryColor: Color(0xFFE11D48),
      secondaryColor: Color(0xFFD97706),
      bgColor: Color(0xFFFAFAF9),
      cardColor: Color(0xFFFFFFFF),
      textColor: Color(0xFF1C1917),
      subtextColor: Color(0xFF78716C),
    ),
  ];

  static final ValueNotifier<ThemePreset> currentTheme =
      ValueNotifier<ThemePreset>(presets[3]);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getInt(_key) ?? 4;
    setTheme(savedId);
  }

  static Future<void> setTheme(int id) async {
    final found = presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets[0],
    );
    currentTheme.value = found;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, found.id);
  }
}
