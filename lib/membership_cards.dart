import 'package:flutter/material.dart';

/// Premier پلان کے membership card tiers — لینڈنگ پیج کے picker اور
/// signup فارم دونوں میں استعمال ہوتے ہیں (ایک ہی جگہ سے فیس/لیبل بدلیں)۔
class MembershipCard {
  final String key;
  final String labelUrdu;
  final String labelEn;
  final double fee;
  final Color color;

  const MembershipCard({
    required this.key,
    required this.labelUrdu,
    required this.labelEn,
    required this.fee,
    required this.color,
  });

  static const List<MembershipCard> all = [
    MembershipCard(
      key: 'silver',
      labelUrdu: 'سلور کارڈ',
      labelEn: 'Silver Card',
      fee: 25000,
      color: Color(0xFF9CA3AF),
    ),
    MembershipCard(
      key: 'gold',
      labelUrdu: 'گولڈ کارڈ',
      labelEn: 'Gold Card',
      fee: 35000,
      color: Color(0xFFF59E0B),
    ),
    MembershipCard(
      key: 'platinum',
      labelUrdu: 'پلاٹینم کارڈ',
      labelEn: 'Platinum Card',
      fee: 50000,
      color: Color(0xFF60A5FA),
    ),
    MembershipCard(
      key: 'gold_platinum',
      labelUrdu: 'گولڈ پلاٹینم کارڈ',
      labelEn: 'Gold Platinum Card',
      fee: 75000,
      color: Color(0xFFD4AF37),
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
