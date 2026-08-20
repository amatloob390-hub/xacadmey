import 'package:flutter/material.dart';

/// گہرے/نیومورفک انداز کی چمکتی ٹائل — آئیکن کے گرد نرم neon چمک، نیچے لیبل۔
/// AppBar کے نیچے ایک افقی قطار کے طور پر استعمال ہوتی ہے۔
class NeonIconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool selected;

  const NeonIconTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF10B981),
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? const Color(0xFF0B1220) : const Color(0xFFEFF4F8);
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: color.withValues(alpha: selected ? 0.9 : 0.35),
                  width: selected ? 1.6 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: selected ? 0.55 : 0.32),
                    blurRadius: selected ? 16 : 10,
                    spreadRadius: selected ? 1 : 0,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.4,
                color: labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ٹائلز کی افقی، سکرول ہونے والی قطار — گہرے rounded بار میں۔
class NeonIconTileBar extends StatelessWidget {
  final List<NeonIconTile> tiles;

  const NeonIconTileBar({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 92,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: tiles,
              ),
            ),
          );
        },
      ),
    );
  }
}
