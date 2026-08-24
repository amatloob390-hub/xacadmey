import 'package:flutter/material.dart';
import '../app_lang.dart';
import '../membership_cards.dart';
import '../screens/membership_application_screen.dart';

TextStyle _ts({
  required double fontSize,
  FontWeight fontWeight = FontWeight.normal,
  Color? color,
  double? height,
}) {
  return TextStyle(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? const Color(0xFF1E293B),
    height: height ?? (AppLang.ur ? 2.0 : 1.6),
    fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
  );
}

/// گہرے، چمکدار (glow-border) premium academy-membership کارڈز کا
/// picker — لینڈنگ پیج کے Premier بٹن اور اسٹوڈنٹ ڈیش بورڈ کے "Get Card"
/// بٹن دونوں سے کھلتا ہے، تاکہ enrolled اسٹوڈنٹ کو کارڈ لینے کیلئے
/// لینڈنگ پیج پر جانے کی ضرورت نہ رہے۔
void showMembershipCardPicker(BuildContext context, {required bool isLoggedIn}) {
  const cardBg = Color(0xFF2E2E31);
  const sheetBg = Color(0xFF1F1F22);
  // ہر کارڈ کا برانڈ رنگ اب اُس کے اپنے tier کے رنگ کے مطابق ہے (نیچے
  // c.color استعمال ہوتا ہے) — پہلے سب کیلئے ایک ہی رنگ تھا۔

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Directionality(
        textDirection: AppLang.ur ? TextDirection.rtl : TextDirection.ltr,
        child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        decoration: const BoxDecoration(
          color: sheetBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ScrollConfiguration(
          // ویب/ڈیسک ٹاپ پر Flutter خودکار طور پر ہر scrollable کے گرد
          // اپنا platform scrollbar لگا دیتا ہے — نیچے کا اپنا Scrollbar
          // اُس کے ساتھ ٹکرا کر دو scrollbars یا غلط جگہ بنا سکتا تھا،
          // اسی لیے خودکار والا یہاں بند کر دیا۔
          behavior: ScrollConfiguration.of(ctx).copyWith(scrollbars: false),
          child: Scrollbar(
            thumbVisibility: true,
            radius: const Radius.circular(8),
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 46,
                  height: 46,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded,
                      color: Colors.white70, size: 24),
                ),
              ),
              Text(
                L.t('Membership card منتخب کریں', 'Choose a Membership Card'),
                textAlign: TextAlign.center,
                style: _ts(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                L.t('ہر کارڈ کی الگ ممبرشپ فیس ہے۔',
                    'Each card has its own membership fee.'),
                textAlign: TextAlign.center,
                style: _ts(fontSize: 13, color: Colors.white.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final cardWidth = (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: spacing,
                    runSpacing: spacing,
                    children: MembershipCard.all.map((c) {
                      return SizedBox(
                        width: cardWidth,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => MembershipApplicationScreen(
                                  card: c,
                                  isLoggedIn: isLoggedIn,
                                ),
                              ));
                            },
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [cardBg, c.color.withValues(alpha: 0.38)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: c.color.withValues(alpha: 0.8), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.color.withValues(alpha: 0.3),
                                    blurRadius: 14,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.card_membership_rounded, color: c.color, size: 20),
                                  const SizedBox(height: 6),
                                  Text(
                                    L.t(c.labelUrdu, c.labelEn).toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: _ts(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: c.color,
                                        height: AppLang.ur ? 1.7 : 1.15),
                                  ),
                                  Text(
                                    L.t('ممبرشپ', 'MEMBERSHIP'),
                                    textAlign: TextAlign.center,
                                    style: _ts(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(alpha: 0.8),
                                        height: AppLang.ur ? 1.7 : 1.15),
                                  ),
                                  const SizedBox(height: 8),
                                  ...c.features(AppLang.ur).take(2).map((f) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.check_circle_rounded,
                                                color: c.color, size: 11),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                f,
                                                style: _ts(
                                                    fontSize: 9.5,
                                                    height: AppLang.ur ? 1.8 : 1.2,
                                                    color: Colors.white.withValues(alpha: 0.7)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  const SizedBox(height: 4),
                                  Text(
                                    L.t('روپے ${c.fee.toInt()}', 'Rs ${c.fee.toInt()}'),
                                    style: _ts(
                                        fontSize: 16, fontWeight: FontWeight.w900, color: c.color),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: c.color.withValues(alpha: 0.6)),
                                    ),
                                    child: Text(
                                      L.t('منتخب کریں', 'SELECT'),
                                      textAlign: TextAlign.center,
                                      style: _ts(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: c.color),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
            ),
          ),
          ),
        ),
        ),
      );
    },
  );
}
