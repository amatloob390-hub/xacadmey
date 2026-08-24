import 'dart:async';
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
  bool _pinVisible = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _togglePin() {
    _hideTimer?.cancel();
    setState(() => _pinVisible = !_pinVisible);
    if (_pinVisible) {
      _hideTimer = Timer(const Duration(seconds: 6), () {
        if (mounted) setState(() => _pinVisible = false);
      });
    }
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
                constraints: const BoxConstraints(maxWidth: 340),
                child: Column(
                  children: [
                    // --- CARD VISUAL (real ISO credit/debit card ratio, 85.6×53.98mm) ---
                    AspectRatio(
                      aspectRatio: 85.60 / 53.98,
                      child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF1A1A1A), color.withValues(alpha: 0.25)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.6),
                        boxShadow: [
                          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 26, spreadRadius: 1),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'XACADEMY',
                                style: TextStyle(
                                    color: color, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 14),
                              ),
                              Icon(Icons.card_membership_rounded, color: color, size: 22),
                            ],
                          ),
                          Text(
                            card.tier != null
                                ? L.t(card.tier!.labelUrdu, card.tier!.labelEn).toUpperCase()
                                : L.t('ممبرشپ کارڈ', 'MEMBERSHIP CARD'),
                            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          Text(
                            card.cardNumber.isEmpty ? '•••• •••• •••• ••••' : card.cardNumber,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.6),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(L.t('نام', 'NAME'),
                                        style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                    Text(card.nameOnCard,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(L.t('اجراء', 'ISSUED'),
                                      style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                  Text(_fmtDate(card.issueDate),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(L.t('میعاد', 'EXPIRES'),
                                      style: const TextStyle(color: Colors.white54, fontSize: 9)),
                                  Text(_fmtDate(card.expiryDate),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(L.t('سیکیورٹی کوڈ: ', 'SECURITY CODE: '),
                                  style: const TextStyle(color: Colors.white54, fontSize: 10)),
                              Text(
                                card.pin.isEmpty
                                    ? '----'
                                    : (_pinVisible ? card.pin : '••••'),
                                style: TextStyle(
                                    color: color,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 3),
                              ),
                              if (card.pin.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: _togglePin,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      _pinVisible
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      size: 15,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
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
