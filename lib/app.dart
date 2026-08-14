import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_lang.dart';
import 'app_mode.dart';
import 'app_theme.dart';
import 'config.dart';
import 'pending_class.dart';
import 'screens/auth_gate.dart';

/// دونوں entry points (admin/student) اِسی فنکشن سے ایپ چلاتے ہیں۔
Future<void> bootstrap(AppMode mode) async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    String? c = Uri.base.queryParameters['class'] ?? Uri.base.queryParameters['class_id'];
    if (c == null || c.isEmpty) {
      final frag = Uri.base.fragment;
      if (frag.contains('class=') || frag.contains('class_id=')) {
        final qIdx = frag.indexOf('?');
        if (qIdx != -1) {
          final params = Uri.splitQueryString(frag.substring(qIdx + 1));
          c = params['class'] ?? params['class_id'];
        }
      }
    }
    if (c != null && c.trim().isNotEmpty) PendingClass.id = c.trim();
  } catch (_) {}

  // Run Supabase, AppLang, and AppTheme init in parallel for fast startup
  await Future.wait([
    Supabase.initialize(
      url: AppConfig.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConfig.supabaseAnonKey,
    ).catchError((e) {
      debugPrint('Supabase init error: $e');
      return Supabase.instance;
    }),
    AppLang.load().catchError((e) {
      debugPrint('AppLang.load skipped: $e');
    }),
    AppTheme.load().catchError((e) {
      debugPrint('AppTheme.load skipped: $e');
    }),
  ]);

  runApp(XacademyApp(mode: mode));
}

class XacademyApp extends StatelessWidget {
  final AppMode mode;
  const XacademyApp({super.key, required this.mode});

  String get _title {
    switch (mode) {
      case AppMode.staff:
        return 'Xacademy Admin';
      case AppMode.student:
        return 'Xacademy Student';
      case AppMode.combined:
        return 'Xacademy';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppLang.isUrdu,
      builder: (context, urdu, _) {
        return ValueListenableBuilder<ThemePreset>(
          valueListenable: AppTheme.currentTheme,
          builder: (context, theme, _) {
            final fontFamily = urdu ? 'NotoNastaliqUrdu' : null;
            final scheme = ColorScheme.fromSeed(
              seedColor: theme.primaryColor,
              primary: theme.primaryColor,
              secondary: theme.secondaryColor,
              brightness: theme.isDark ? Brightness.dark : Brightness.light,
            );

            final base = ThemeData(
              useMaterial3: true,
              colorScheme: scheme,
              scaffoldBackgroundColor: theme.bgColor,
              fontFamily: fontFamily,
              fontFamilyFallback: const ['Roboto', 'Arial', 'sans-serif'],
              appBarTheme: AppBarTheme(
                backgroundColor: theme.cardColor,
                foregroundColor: theme.textColor,
                elevation: 0,
                scrolledUnderElevation: 0,
                centerTitle: false,
                titleTextStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
                iconTheme: IconThemeData(color: theme.textColor),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: theme.cardColor,
                titleTextStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
                contentTextStyle: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 14,
                  color: theme.subtextColor,
                  height: urdu ? 1.8 : 1.5,
                ),
              ),
              cardTheme: CardThemeData(
                elevation: 0,
                color: theme.cardColor,
                surfaceTintColor: Colors.transparent,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: theme.isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: theme.isDark
                    ? const Color(0xFF1E293B)
                    : const Color(0xFFF1F5F9),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                labelStyle: TextStyle(fontFamily: fontFamily, color: theme.subtextColor),
                hintStyle: TextStyle(fontFamily: fontFamily, color: theme.subtextColor),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: theme.primaryColor, width: 1.6)),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  textStyle: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: theme.primaryColor,
                  side: BorderSide(color: theme.primaryColor),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              chipTheme: ChipThemeData(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                side: BorderSide.none,
                labelStyle: TextStyle(fontFamily: fontFamily),
              ),
              scrollbarTheme: ScrollbarThemeData(
                thumbVisibility: WidgetStateProperty.all(true),
                thickness: WidgetStateProperty.all(9),
                radius: const Radius.circular(5),
                thumbColor: WidgetStateProperty.all(theme.primaryColor.withValues(alpha: 0.6)),
              ),
            );

            return MaterialApp(
              title: _title,
              debugShowCheckedModeBanner: false,
              theme: urdu
                  ? base.copyWith(
                      textTheme: _withHeight(base.textTheme, 1.8),
                      primaryTextTheme: _withHeight(base.primaryTextTheme, 1.8),
                    )
                  : base,
              builder: (context, child) => Directionality(
                textDirection: AppLang.dir,
                child: child!,
              ),
              home: KeyedSubtree(
                key: ValueKey<String>('${urdu}_${theme.id}'),
                child: AuthGate(mode: mode),
              ),
            );
          },
        );
      },
    );
  }

  static TextTheme _withHeight(TextTheme t, double h) {
    TextStyle? f(TextStyle? s) =>
        s?.copyWith(height: h, fontFamily: 'NotoNastaliqUrdu');
    return t.copyWith(
      displayLarge: f(t.displayLarge),
      displayMedium: f(t.displayMedium),
      displaySmall: f(t.displaySmall),
      headlineLarge: f(t.headlineLarge),
      headlineMedium: f(t.headlineMedium),
      headlineSmall: f(t.headlineSmall),
      titleLarge: f(t.titleLarge),
      titleMedium: f(t.titleMedium),
      titleSmall: f(t.titleSmall),
      bodyLarge: f(t.bodyLarge),
      bodyMedium: f(t.bodyMedium),
      bodySmall: f(t.bodySmall),
      labelLarge: f(t.labelLarge),
      labelMedium: f(t.labelMedium),
      labelSmall: f(t.labelSmall),
    );
  }
}
