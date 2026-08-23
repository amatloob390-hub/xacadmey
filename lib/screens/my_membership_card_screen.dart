import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../membership_cards.dart';

/// اسٹوڈنٹ کا اپنا جاری شدہ membership card — کارڈ نمبر، tier، اجراء/میعاد
/// کی تاریخ، اور ٹیچر کا مقرر کردہ سیکیورٹی کوڈ (کارڈ پر "پرنٹ شدہ" دکھایا
/// جاتا ہے)۔
class MyMembershipCardScreen extends StatefulWidget {
  const MyMembershipCardScreen({super.key});

  @override
  State<MyMembershipCardScreen> createState() => _MyMembershipCardScreenState();
}

class _MyCardData {
  final String nameOnCard;
  final MembershipCard? tier;
  final String cardNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String pin;

  _MyCardData({
    required this.nameOnCard,
    required this.tier,
    required this.cardNumber,
    required this.issueDate,
    required this.expiryDate,
    required this.pin,
  });

  bool get isExpired => expiryDate != null && DateTime.now().isAfter(expiryDate!);
}

class _MyMembershipCardScreenState extends State<MyMembershipCardScreen> {
  final _supabase = Supabase.instance.client;
  late Future<_MyCardData?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_MyCardData?> _load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final row = await _supabase
          .from('verification_requests')
          .select(
              'full_name, name_on_card, membership_card, card_number, card_issue_date, card_expiry_date, card_pin')
          .eq('user_id', user.id)
          .eq('status', 'approved')
          .not('membership_card', 'is', null)
          .order('card_issue_date', ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      return _MyCardData(
        nameOnCard: (row['name_on_card'] as String?)?.trim().isNotEmpty == true
            ? row['name_on_card'] as String
            : (row['full_name'] as String? ?? ''),
        tier: MembershipCard.byKey(row['membership_card'] as String?),
        cardNumber: (row['card_number'] as String?) ?? '',
        issueDate: DateTime.tryParse((row['card_issue_date'] as String?) ?? ''),
        expiryDate: DateTime.tryParse((row['card_expiry_date'] as String?) ?? ''),
        pin: (row['card_pin'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  String _fmtDate(DateTime? d) => d == null ? '—' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0A0A0A);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(L.t('میرا ممبرشپ کارڈ', 'My Membership Card')),
      ),
      body: FutureBuilder<_MyCardData?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final card = snapshot.data;
          if (card == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.card_membership_rounded, size: 56, color: Colors.white38),
                    const SizedBox(height: 16),
                    Text(
                      L.t('ابھی کوئی کارڈ جاری نہیں ہوا', 'No card issued yet'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      L.t('لینڈنگ پیج سے Premier کارڈ کیلئے درخواست دیں۔',
                          'Apply for a Premier card from the landing page.'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          }

          final color = card.tier?.color ?? const Color(0xFF10B981);
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // --- CARD VISUAL ---
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF1A1A1A), color.withValues(alpha: 0.25)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.6),
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 26, spreadRadius: 1),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'XACADEMY',
                                style: TextStyle(
                                    color: color, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 15),
                              ),
                              Icon(Icons.card_membership_rounded, color: color, size: 26),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            card.tier != null
                                ? L.t(card.tier!.labelUrdu, card.tier!.labelEn).toUpperCase()
                                : L.t('ممبرشپ کارڈ', 'MEMBERSHIP CARD'),
                            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            card.cardNumber.isEmpty ? '•••• •••• •••• ••••' : card.cardNumber,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(L.t('نام', 'NAME'),
                                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                    Text(card.nameOnCard,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(L.t('میعاد', 'EXPIRES'),
                                      style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                  Text(_fmtDate(card.expiryDate),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Text(L.t('سیکیورٹی کوڈ: ', 'SECURITY CODE: '),
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              Text(
                                card.pin.isEmpty ? '••••' : card.pin,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 4),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: (card.isExpired ? Colors.red : const Color(0xFF10B981)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: card.isExpired ? Colors.red : const Color(0xFF10B981)),
                      ),
                      child: Text(
                        card.isExpired
                            ? L.t('میعاد ختم ہو چکی — تجدید کروائیں', 'Expired — please renew')
                            : '${L.t('فعال', 'Active')} — ${L.t('اجراء', 'Issued')} ${_fmtDate(card.issueDate)}',
                        style: TextStyle(
                            color: card.isExpired ? Colors.red : const Color(0xFF10B981),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
