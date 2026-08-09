import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../app_theme.dart';

class ThemeSelectorDialog extends StatelessWidget {
  const ThemeSelectorDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const ThemeSelectorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePreset>(
      valueListenable: AppTheme.currentTheme,
      builder: (context, activeTheme, _) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.palette_rounded, color: Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  L.t('تھیم منتخب کریں (6 تھیمز)', 'Select Theme (6 Themes)'),
                  style: TextStyle(
                    fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L.t(
                    '4 ڈارک تھیمز اور 2 لائٹ تھیمز — کسی بھی تھیم پر کلک کریں یا چیٹ میں apply 1 سے apply 6 لکھیں۔',
                    '4 Dark Themes & 2 Light Themes — Click any theme or type apply 1 to apply 6 in chat.',
                  ),
                  style: TextStyle(
                    fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 16),
                ...AppTheme.presets.map((p) {
                  final isSelected = p.id == activeTheme.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        AppTheme.setTheme(p.id);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: p.bgColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? p.primaryColor
                                : (p.isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1)),
                            width: isSelected ? 2.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 2 Color Swatches
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: p.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: p.secondaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                L.t(p.nameUrdu, p.nameEnglish),
                                style: TextStyle(
                                  fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: p.textColor,
                                ),
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: p.primaryColor,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                L.t('بند کریں', 'Close'),
                style: TextStyle(
                  fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ThemeSelectorButton extends StatelessWidget {
  const ThemeSelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.palette_outlined, color: Color(0xFFD97706)),
      tooltip: L.t('تھیمز (6 تھیمز)', 'Themes (6 Themes)'),
      onPressed: () => ThemeSelectorDialog.show(context),
    );
  }
}
