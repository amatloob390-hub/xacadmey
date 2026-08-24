import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../membership_cards.dart';

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
  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final MembershipCard? tier;
  final String cardNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final bool isExistingHolder;
  final String pin;

  _IssuedCard({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.tier,
    required this.cardNumber,
    required this.issueDate,
    required this.expiryDate,
    required this.isExistingHolder,
    required this.pin,
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
            'id, user_id, full_name, email, phone, membership_card, membership_fee, card_number, card_issue_date, card_expiry_date, is_existing_card_holder, card_pin')
        .not('membership_card', 'is', null)
        .eq('status', 'approved')
        .order('card_issue_date', ascending: false);

    return rows.map((r) {
      final m = Map<String, dynamic>.from(r as Map);
      return _IssuedCard(
        id: m['id'] as String,
        userId: (m['user_id'] as String?) ?? '',
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
        pin: (m['card_pin'] as String?) ?? '',
      );
    }).toList();
  }

  Future<void> _editPin(_IssuedCard card) async {
    final ctrl = TextEditingController(text: card.pin);
    final newPin = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(L.t('سیکیورٹی کوڈ مقرر/تبدیل کریں', 'Set/Change Security Code')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${card.fullName} — ${card.cardNumber}'),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                onChanged: (_) => setDialogState(() {}),
                decoration: InputDecoration(
                  counterText: '',
                  labelText: L.t('4 ہندسوں کا کوڈ', '4-digit code'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L.t('منسوخ', 'Cancel')),
            ),
            ElevatedButton(
              onPressed: RegExp(r'^\d{4}$').hasMatch(ctrl.text.trim())
                  ? () => Navigator.pop(ctx, ctrl.text.trim())
                  : null,
              child: Text(L.t('محفوظ کریں', 'Save')),
            ),
          ],
        ),
      ),
    );
    if (newPin == null) return;
    try {
      await _supabase.from('verification_requests').update({'card_pin': newPin}).eq('id', card.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('سیکیورٹی کوڈ محفوظ ہو گیا۔', 'Security code saved.')),
          backgroundColor: Colors.green.shade700,
        ));
        _refresh();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('محفوظ نہیں ہو سکا، دوبارہ کوشش کریں۔',
              'Could not save, please try again.')),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  Future<void> _deleteCard(_IssuedCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(L.t('کارڈ حذف کریں؟', 'Delete this card?')),
        content: Text(L.t(
            '${card.fullName} — ${card.cardNumber.isEmpty ? '' : card.cardNumber} کا کارڈ ہمیشہ کیلئے حذف ہو جائے گا۔ یہ عمل واپس نہیں ہو سکتا۔',
            'This will permanently delete the card for ${card.fullName}'
            '${card.cardNumber.isEmpty ? '' : ' (${card.cardNumber})'}. This cannot be undone.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.t('منسوخ', 'Cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.t('حذف کریں', 'Delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _supabase.from('verification_requests').delete().eq('id', card.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('کارڈ حذف کر دیا گیا۔', 'Card deleted.')),
          backgroundColor: Colors.green.shade700,
        ));
        _refresh();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('حذف نہیں ہو سکا، دوبارہ کوشش کریں۔',
              'Could not delete, please try again.')),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
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
                      ...filtered.map((c) => _CardTile(
                            card: c,
                            theme: theme,
                            onEditPin: _editPin,
                            onDelete: _deleteCard,
                          )),
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

}

class _CardTile extends StatefulWidget {
  final _IssuedCard card;
  final ThemePreset theme;
  final Future<void> Function(_IssuedCard) onEditPin;
  final Future<void> Function(_IssuedCard) onDelete;

  const _CardTile({
    required this.card,
    required this.theme,
    required this.onEditPin,
    required this.onDelete,
  });

  @override
  State<_CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<_CardTile> {
  bool _pinVisible = false;
  Timer? _hideTimer;

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

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final theme = widget.theme;
    final tierColor = c.tier?.color ?? theme.primaryColor;
    final expired = c.isExpired;
    final daysLeft = c.expiryDate?.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
              IconButton(
                onPressed: () => widget.onDelete(c),
                icon: const Icon(Icons.delete_outline, size: 19, color: Colors.red),
                tooltip: L.t('کارڈ حذف کریں', 'Delete card'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // --- CARD VISUAL: real-world credit/debit card size (85.6×53.98mm
          // ISO ID-1, scaled to ~340dp wide) — not stretched to list width.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: AspectRatio(
                aspectRatio: 85.60 / 53.98,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1A1A1A), tierColor.withValues(alpha: 0.30)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tierColor.withValues(alpha: 0.8), width: 1.6),
                    boxShadow: [
                      BoxShadow(color: tierColor.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 1),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('XACADEMY',
                              style: TextStyle(
                                  color: tierColor, fontWeight: FontWeight.w900, letterSpacing: 1.6, fontSize: 11)),
                          Icon(Icons.card_membership_rounded, color: tierColor, size: 18),
                        ],
                      ),
                      Text(
                        c.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      Text(
                        c.tier != null ? L.t(c.tier!.labelUrdu, c.tier!.labelEn).toUpperCase() : '—',
                        style: TextStyle(color: tierColor, fontWeight: FontWeight.w800, fontSize: 11.5),
                      ),
                      Text(
                        c.cardNumber.isEmpty ? '•••• •••• •••• ••••' : c.cardNumber,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      Text(L.t('میعاد: ', 'EXPIRES: ') + _fmtDate(c.expiryDate),
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Text(L.t('سیکیورٹی کوڈ: ', 'SECURITY CODE: '),
                              style: const TextStyle(color: Colors.white54, fontSize: 9)),
                          Text(
                            c.pin.isEmpty ? '----' : (_pinVisible ? c.pin : '••••'),
                            style: TextStyle(
                                color: tierColor, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.5),
                          ),
                          if (c.pin.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: _togglePin,
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Icon(
                                  _pinVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  size: 13,
                                  color: tierColor,
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
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _infoBit(L.t('اجراء', 'Issued'), _fmtDate(c.issueDate), theme),
              if (!expired && daysLeft != null)
                _infoBit(L.t('باقی دن', 'Days left'), '$daysLeft', theme),
              if (c.isExistingHolder)
                _infoBit(L.t('ماخذ', 'Source'), L.t('پہلے سے ہولڈر', 'Existing holder'), theme),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => widget.onEditPin(c),
              icon: Icon(Icons.edit_outlined, size: 15, color: tierColor),
              label: Text(
                c.pin.isEmpty ? L.t('کوڈ مقرر کریں', 'Set code') : L.t('تبدیل کریں', 'Edit'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: tierColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
