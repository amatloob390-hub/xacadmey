import 'package:flutter/material.dart';

/// مستقل "منتخب" جیسا ظاہری انداز — سبز/فیروزی بارڈر، ہلکا گریڈیئنٹ اور
/// نرم چمک — سائیڈ بار کی منتخب ٹائل اور پروفائل کے انفو باکس والا انداز۔
/// پوری ایپ میں کارڈز/ٹائلز کو یکساں بنانے کیلئے استعمال ہو۔
class TealBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color accent;

  const TealBox({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.margin,
    this.borderRadius = 16,
    this.accent = const Color(0xFF10B981),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0C2738), const Color(0xFF132A4B)]
              : [const Color(0xFFE0F2FE), const Color(0xFFF0FDFA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
