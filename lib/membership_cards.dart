import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_lang.dart';

/// Premier پلان کے membership card tiers — لینڈنگ پیج کے picker اور
/// signup فارم دونوں میں استعمال ہوتے ہیں (ایک ہی جگہ سے فیس/لیبل بدلیں)۔
class MembershipCard {
  final String key;
  final String labelUrdu;
  final String labelEn;
  final double fee;
  final Color color;

  /// null = لامحدود کورسز۔
  final int? courseLimit;

  /// خالی = کوئی خاندانی رعایت شامل نہیں۔
  final String familyAccessUrdu;
  final String familyAccessEn;

  const MembershipCard({
    required this.key,
    required this.labelUrdu,
    required this.labelEn,
    required this.fee,
    required this.color,
    this.courseLimit,
    this.familyAccessUrdu = '',
    this.familyAccessEn = '',
  });

  /// کارڈ کے فوائد — لینڈنگ پیج اور application اسکرین دونوں یہیں سے لیتے ہیں۔
  List<String> features(bool urdu) {
    final courseText = courseLimit != null
        ? (urdu ? '$courseLimit کورسز تک رسائی' : 'Access to $courseLimit courses')
        : (urdu ? 'لامحدود کورسز تک رسائی' : 'Unlimited course access');
    final list = <String>[courseText];
    if (familyAccessEn.isNotEmpty) {
      list.add(urdu
          ? 'خاندان بھی شامل: $familyAccessUrdu'
          : 'Family included: $familyAccessEn');
    }
    list.add(urdu ? 'کارڈ 1 سال کیلئے کارآمد' : 'Card valid for 1 year');
    return list;
  }

  static const List<MembershipCard> all = [
    MembershipCard(
      key: 'silver',
      labelUrdu: 'سلور کارڈ',
      labelEn: 'Silver Card',
      fee: 25000,
      color: Color(0xFF9CA3AF),
      courseLimit: 3,
    ),
    MembershipCard(
      key: 'gold',
      labelUrdu: 'گولڈ کارڈ',
      labelEn: 'Gold Card',
      fee: 35000,
      color: Color(0xFFF59E0B),
      courseLimit: 5,
    ),
    MembershipCard(
      key: 'platinum',
      labelUrdu: 'پلاٹینم کارڈ',
      labelEn: 'Platinum Card',
      fee: 50000,
      color: Color(0xFF60A5FA),
      familyAccessUrdu: 'بیوی اور بچے',
      familyAccessEn: 'wife and children',
    ),
    MembershipCard(
      key: 'gold_platinum',
      labelUrdu: 'گولڈ پلاٹینم کارڈ',
      labelEn: 'Gold Platinum Card',
      fee: 75000,
      color: Color(0xFFD4AF37),
      familyAccessUrdu: 'بہن بھائی، بیوی اور بچے',
      familyAccessEn: 'siblings, wife, and children',
    ),
  ];

  static MembershipCard? byKey(String? key) {
    if (key == null) return null;
    for (final c in all) {
      if (c.key == key) return c;
    }
    return null;
  }
}

/// دیے گئے اسٹوڈنٹ کا فعال (approved اور میعاد کے اندر) membership card
/// tier — پروفائل بیج دکھانے کیلئے۔ کوئی کارڈ نہ ہو یا میعاد ختم ہو چکی
/// ہو تو null۔
Future<MembershipCard?> fetchActiveMembershipTier(
    SupabaseClient supabase, String userId) async {
  try {
    final row = await supabase
        .from('verification_requests')
        .select('membership_card, card_expiry_date')
        .eq('user_id', userId)
        .eq('status', 'approved')
        .not('membership_card', 'is', null)
        .order('card_issue_date', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    final expiry = DateTime.tryParse((row['card_expiry_date'] as String?) ?? '');
    if (expiry != null && DateTime.now().isAfter(expiry)) return null;
    return MembershipCard.byKey(row['membership_card'] as String?);
  } catch (_) {
    return null;
  }
}

/// tier-رنگ کا چھوٹا بیج — پروفائل اور اسٹوڈنٹ کی تفصیل میں دونوں طرف
/// (اسٹوڈنٹ اور ٹیچر) دکھایا جاتا ہے۔
class MembershipBadge extends StatelessWidget {
  final MembershipCard tier;
  const MembershipBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tier.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tier.color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_membership_rounded, size: 13, color: tier.color),
          const SizedBox(width: 5),
          Text(
            AppLang.ur ? tier.labelUrdu : tier.labelEn,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: tier.color),
          ),
        ],
      ),
    );
  }
}
