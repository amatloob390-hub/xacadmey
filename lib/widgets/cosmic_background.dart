import 'package:flutter/material.dart';
import '../app_theme.dart';

/// پس منظر میں دھیمی روشنی کے دو گول "glow" دھبے — پوری ایپ میں ایک ہی
/// جدید/کائناتی ماحول کیلئے استعمال ہوں۔ رنگ ہمیشہ منتخب تھیم کے
/// primary/secondary سے آتے ہیں، اس لیے ہر تھیم پریسیٹ کے ساتھ خودکار میل کھاتا ہے۔
class CosmicBackground extends StatelessWidget {
  final Widget child;
  final ThemePreset theme;

  const CosmicBackground({super.key, required this.child, required this.theme});

  @override
  Widget build(BuildContext context) {
    final glowAlpha = theme.isDark ? 0.28 : 0.10;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: theme.bgColor),
        Positioned(
          top: -90,
          right: -70,
          child: _Glow(color: theme.primaryColor, size: 280, alpha: glowAlpha),
        ),
        Positioned(
          bottom: -110,
          left: -90,
          child: _Glow(color: theme.secondaryColor, size: 320, alpha: glowAlpha),
        ),
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  final double size;
  final double alpha;

  const _Glow({required this.color, required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
