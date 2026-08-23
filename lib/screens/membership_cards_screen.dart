import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../membership_cards.dart';
import '../widgets/teal_box.dart';

/// ٹیچر کیلئے — جاری شدہ (approved) membership cards کی فہرست: کارڈ نمبر،
/// tier، اجراء/میعاد کی تاریخ، اور فعال/ختم حیثیت۔ نئے کارڈ کی درخواستیں
/// یہاں نہیں — وہ "Student Approvals" میں منظوری کے منتظر ہوتی ہیں؛ منظور
/// ہونے کے بعد ہی وہ یہاں آتی ہیں۔
class MembershipCardsScreen extends StatefulWidget {
  const MembershipCardsScreen({super.key});

  @override
  State<MembershipCardsScreen> createState() => _MembershipCardsScreenState();
}

class _IssuedCard {
  final String fullName;
  final String email;
  final String phone;
  final MembershipCard? tier;
  final String cardNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final bool isExistingHolder;

  _IssuedCard({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.tier,
    required this.cardNumber,
    required this.issueDate,
    required this.expiryDate,
    required this.isExistingHolder,
  });

  bool get isExpired => expiryDate != null && DateTime.now().isAfter(expiryDate!);
}

class _MembershipCardsScreenState extends State<MembershipCardsScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<_IssuedCard>> _future;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _statusFilter = 'all'; // all | active | expired

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _future = _load());

  Future<List<_IssuedCard>> _load() async {
    final rows = await _supabase
        .from('verification_requests')
        .select(
            'full_name, email, phone, membership_card, membership_fee, card_number, card_issue_date, card_expiry_date, is_existing_card_holder')
        .not('membership_card', 'is', null)
        .eq('status', 'approved')
        .order('card_issue_date', ascending: false);

    return rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return _IssuedCard(
        fullName: (m['full_name'] as String?)?.trim().isNotEmpty == true
            ? m['full_name'] as String
            : 'اسٹوڈنٹ',
        email: (m['email'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        tier: MembershipCard.byKey(m['membership_card'] as String?),
        cardNumber: (m['card_number'] as String?) ?? '',
        issueDate: DateTime.tryParse((m['card_issue_date'] as String?) ?? ''),
        expiryDate: DateTime.tryParse((m['card_expiry_date'] as String?) ?? ''),
        isExistingHolder: m['is_existing_card_holder'] == true,
      );
    }).toList();
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '—';
    return '${d.day}/${d.month}/${d.year}';
  }

  TextStyle _ts({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    ThemePreset? theme,
  }) {
    final defaultColor = theme != null ? theme.textColor : const Color(0xFF0F172A);
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? defaultColor,
      height: AppLang.ur ? 1.8 : 1.5,
      fontFamily: AppLang.ur ? 'NotoNastaliqUrdu' : null,
    );
  }

  Widget _filterChip(String value, String label, ThemePreset theme) {
    final selected = _statusFilter == value;
    return ChoiceChip(
      label: Text(label, style: _ts(fontSize: 12.5, fontWeight: FontWeight.bold, theme: theme)),
      selected: selected,
      selectedColor: theme.primaryColor.withValues(alpha: 0.2),
      side: BorderSide(color: selected ? theme.primaryColor : Colors.grey.shade400),
      onSelected: (_) => setState(() => _statusFilter = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePreset>(
      valueListenable: AppTheme.currentTheme,
      builder: (context, theme, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: theme.cardColor,
            elevation: 2,
            title: Text(
              L.t('جاری شدہ ممبرشپ کارڈز', 'Issued Membership Cards'),
              style: _ts(fontSize: 18, fontWeight: FontWeight.bold, theme: theme),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: L.t('تازہ کریں', 'Refresh'),
                onPressed: _refresh,
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: FutureBuilder<List<_IssuedCard>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final all = snapshot.data ?? [];

                  if (all.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.card_membership_rounded,
                                size: 48, color: theme.primaryColor),
                            const SizedBox(height: 14),
                            Text(
                              L.t('ابھی کوئی کارڈ جاری نہیں ہوا',
                                  'No cards issued yet'),
                              style: _ts(fontSize: 16, fontWeight: FontWeight.bold, theme: theme),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              L.t(
                                  'Membership card کی درخواستیں "Student Approvals" میں منظوری کے منتظر ہوتی ہیں — منظور ہونے پر یہاں دکھیں گی۔',
                                  'Card applications wait for approval in "Student Approvals" — once approved, they appear here.'),
                              textAlign: TextAlign.center,
                              style: _ts(fontSize: 13, color: theme.subtextColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  var filtered = all.where((c) {
                    if (_statusFilter == 'active') return !c.isExpired;
                    if (_statusFilter == 'expired') return c.isExpired;
                    return true;
                  }).toList();
                  if (_query.isNotEmpty) {
                    filtered = filtered
                        .where((c) =>
                            c.fullName.toLowerCase().contains(_query) ||
                            c.email.toLowerCase().contains(_query) ||
                            c.cardNumber.toLowerCase().contains(_query))
                        .toList();
                  }

                  return ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 24, 20),
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        style: _ts(fontSize: 14, theme: theme),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.cardColor,
                          hintText: L.t('نام، ای میل یا کارڈ نمبر سے تلاش کریں',
                              'Search by name, email, or card number'),
                          hintStyle: _ts(fontSize: 14, color: theme.subtextColor),
                          prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: Icon(Icons.close, color: theme.subtextColor, size: 18),
                                  onPressed: () => _searchCtrl.clear(),
                                ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: theme.primaryColor, width: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _filterChip('all', L.t('سب', 'All'), theme),
                          _filterChip('active', L.t('فعال', 'Active'), theme),
                          _filterChip('expired', L.t('ختم شدہ', 'Expired'), theme),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              L.t('کوئی نتیجہ نہیں ملا', 'No matching cards found'),
                              style: _ts(fontSize: 14, color: theme.subtextColor),
                            ),
                          ),
                        ),
                      ...filtered.map((c) => _cardTile(c, theme)),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _cardTile(_IssuedCard c, ThemePreset theme) {
    final tierColor = c.tier?.color ?? theme.primaryColor;
    final expired = c.isExpired;
    final daysLeft = c.expiryDate?.difference(DateTime.now()).inDays;

    return TealBox(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.card_membership_rounded, color: tierColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.fullName,
                        style: _ts(fontSize: 15, fontWeight: FontWeight.bold, theme: theme)),
                    Text(c.email, style: _ts(fontSize: 12, color: theme.subtextColor)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (expired ? Colors.red : const Color(0xFF10B981)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: expired ? Colors.red : const Color(0xFF10B981)),
                ),
                child: Text(
                  expired
                      ? L.t('ختم شدہ', 'Expired')
                      : L.t('فعال', 'Active'),
                  style: _ts(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: expired ? Colors.red : const Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: tierColor.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _infoBit(
                  L.t('کارڈ', 'Card'),
                  c.tier != null ? L.t(c.tier!.labelUrdu, c.tier!.labelEn) : '—',
                  theme),
              _infoBit(L.t('کارڈ نمبر', 'Card No.'),
                  c.cardNumber.isEmpty ? '—' : c.cardNumber, theme),
              _infoBit(L.t('اجراء', 'Issued'), _fmtDate(c.issueDate), theme),
              _infoBit(L.t('میعاد', 'Expires'), _fmtDate(c.expiryDate), theme),
              if (!expired && daysLeft != null)
                _infoBit(L.t('باقی دن', 'Days left'), '$daysLeft', theme),
              if (c.isExistingHolder)
                _infoBit(L.t('ماخذ', 'Source'), L.t('پہلے سے ہولڈر', 'Existing holder'), theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoBit(String label, String value, ThemePreset theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: _ts(fontSize: 10.5, color: theme.subtextColor)),
        Text(value, style: _ts(fontSize: 13, fontWeight: FontWeight.bold, theme: theme)),
      ],
    );
  }
}
