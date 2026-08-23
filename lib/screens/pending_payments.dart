import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../services/payment_service.dart';

class PendingPayments extends StatefulWidget {
  const PendingPayments({super.key});

  @override
  State<PendingPayments> createState() => _PendingPaymentsState();
}

class _PendingPaymentsState extends State<PendingPayments> {
  final PaymentService _service = PaymentService();
  late Future<List<PendingPayment>> _future;
  List<PendingPayment>? _localList; // local cached list for instant UI
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _loadPayments();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<PendingPayment>> _loadPayments() async {
    final list = await _service.getPending();
    _localList = List<PendingPayment>.from(list);
    return _localList!;
  }

  void _refresh() => setState(() => _future = _loadPayments());

  Future<void> _act(String id, bool approve) async {
    // Instantly remove from local list so UI updates immediately — restored
    // below if the server call actually fails, instead of lying about success.
    PendingPayment? removed;
    int removedIndex = -1;
    if (_localList != null) {
      removedIndex = _localList!.indexWhere((p) => p.paymentId == id);
      if (removedIndex != -1) {
        removed = _localList![removedIndex];
        setState(() {
          _localList!.removeAt(removedIndex);
          _future = Future.value(List<PendingPayment>.from(_localList!));
        });
      }
    }

    try {
      if (approve) {
        await _service.approve(id);
      } else {
        await _service.reject(id);
      }
      if (mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve
              ? L.t('ادائیگی منظور ہو گئی ✅', 'Payment approved ✅')
              : L.t('ادائیگی رد ہو گئی', 'Payment rejected')),
        ));
      }
    } catch (_) {
      // Server call genuinely failed — put the item back instead of
      // pretending the action succeeded.
      if (_localList != null && removed != null && removedIndex != -1) {
        setState(() {
          _localList!.insert(removedIndex, removed!);
          _future = Future.value(List<PendingPayment>.from(_localList!));
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(approve
              ? L.t('منظوری محفوظ نہیں ہو سکی، دوبارہ کوشش کریں۔',
                  'Could not save the approval, please try again.')
              : L.t('ردی محفوظ نہیں ہو سکی، دوبارہ کوشش کریں۔',
                  'Could not save the rejection, please try again.')),
        ));
      }
    }
  }

  void _showReceiptDialog(PendingPayment p, ThemePreset theme) {
    Widget contentWidget;
    final hasImage = p.receiptUrl != null && p.receiptUrl!.trim().isNotEmpty;
    if (hasImage) {
      try {
        final str = p.receiptUrl!.trim();
        if (str.startsWith('http://') || str.startsWith('https://')) {
          contentWidget = Image.network(
            str,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _errorImage(theme),
          );
        } else {
          final cleanBase64 = str.contains(',') ? str.split(',').last : str;
          final bytes = base64Decode(cleanBase64.trim());
          contentWidget = Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _errorImage(theme),
          );
        }
      } catch (_) {
        contentWidget = _errorImage(theme);
      }
    } else {
      contentWidget = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_rounded, size: 54, color: Color(0xFF10B981)),
            const SizedBox(height: 14),
            Text(
              L.t('اسٹوڈنٹ نے ٹرانزیکشن آئی ڈی سے فیس جمع کروائی ہے',
                  'Student submitted fee with Transaction ID'),
              textAlign: TextAlign.center,
              style: _ts(fontSize: 15, fontWeight: FontWeight.bold, theme: theme),
            ),
          ],
        ),
      );
    }

    final headerBlock = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${L.t('فیس تصدیق و رسید', 'Fee Verification')}: ${p.studentName}',
                  style: _ts(fontSize: 16, fontWeight: FontWeight.bold, theme: theme),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );

    final middleBlock = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
              // Highlighted Transaction ID / Reference Banner
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981), width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.t('ریفرنس نمبر / ٹرانزیکشن آئی ڈی', 'Reference / Transaction ID'),
                            style: _ts(fontSize: 12, color: theme.subtextColor),
                          ),
                          SelectableText(
                            p.txnReference.isEmpty ? L.t('درخواست جمع ہو گئی', 'Request Submitted') : p.txnReference,
                            style: _ts(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.txnReference.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20, color: Color(0xFF10B981)),
                        tooltip: L.t('کاپی کریں', 'Copy'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: p.txnReference));
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(L.t('ٹرانزیکشن آئی ڈی کاپی ہو گئی! 📋', 'Txn ID copied! 📋')),
                            duration: const Duration(seconds: 2),
                          ));
                        },
                      ),
                  ],
                ),
              ),

              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: hasImage
                      ? Stack(
                          fit: StackFit.passthrough,
                          children: [
                            GestureDetector(
                              onTap: () => _openZoomedImage(context, contentWidget),
                              child: contentWidget,
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: IgnorePointer(
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.zoom_in, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      : contentWidget,
                ),
              ),
              const SizedBox(height: 16),
        ],
      ),
    );

    final closeButtonBlock = Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            L.t('بند کریں', 'Close'),
            style: _ts(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.4),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              headerBlock,
              Flexible(child: middleBlock),
              closeButtonBlock,
            ],
          ),
        ),
      ),
    );
  }

  /// رسید/اسکرین شاٹ کو پورے اسکرین پر pinch/scroll سے zoom کر کے دیکھیں۔
  void _openZoomedImage(BuildContext context, Widget imageWidget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(child: imageWidget),
          ),
        ),
      ),
    );
  }

  Widget _errorImage(ThemePreset theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      color: theme.isDark ? Colors.black26 : Colors.grey.shade100,
      child: Text(
        L.t('تصویر لوڈ نہیں ہو سکی', 'Could not load image'),
        style: _ts(fontSize: 14, theme: theme),
      ),
    );
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
              L.t('زیرِ التوا ادائیگیاں', 'Pending Payments'),
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
              child: FutureBuilder<List<PendingPayment>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snapshot.data ?? [];
                  final filtered = _query.isEmpty
                      ? list
                      : list
                          .where((p) =>
                              p.studentName.toLowerCase().contains(_query) ||
                              p.classTitle.toLowerCase().contains(_query))
                          .toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: theme.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              L.t('کوئی زیرِ التوا ادائیگی نہیں', 'No Pending Payments'),
                              style: _ts(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                theme: theme,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              L.t('تمام فیس کی درخواستیں منظور ہو چکی ہیں۔',
                                  'All fee payment requests have been processed.'),
                              textAlign: TextAlign.center,
                              style: _ts(
                                fontSize: 14,
                                color: theme.subtextColor,
                              ),
                            ),
                            const SizedBox(height: 20),
                            OutlinedButton.icon(
                              onPressed: _refresh,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: Text(
                                L.t('دوبارہ چیک کریں', 'Check Again'),
                                style: _ts(fontSize: 14, fontWeight: FontWeight.bold, theme: theme),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.primaryColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 20, 24, 20),
                    children: [
                      // Banner Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF2563EB)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.payments_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    L.t('فیس ادائیگیوں کی تصدیق', 'Fee Payment Verification'),
                                    style: _ts(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    L.t('${list.length} درخواستیں زیرِ التوا ہیں',
                                        '${list.length} request(s) awaiting approval'),
                                    style: _ts(
                                      fontSize: 13,
                                      color: Colors.white.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextField(
                        controller: _searchCtrl,
                        style: _ts(fontSize: 14, theme: theme),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: theme.cardColor,
                          hintText: L.t('اسٹوڈنٹ تلاش کریں (نام)', 'Search student by name'),
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
                      const SizedBox(height: 14),

                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              L.t('کوئی نتیجہ نہیں ملا', 'No matching requests found'),
                              style: _ts(fontSize: 14, color: theme.subtextColor),
                            ),
                          ),
                        ),

                      ...filtered.map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: theme.isDark
                                    ? [const Color(0xFF0C2738), const Color(0xFF132A4B)]
                                    : [const Color(0xFFE0F2FE), const Color(0xFFF0FDFA)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                width: 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        p.studentName,
                                        style: _ts(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          theme: theme,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: theme.primaryColor, width: 1.2),
                                      ),
                                      child: Text(
                                        '${p.amount} ${L.t('روپے', 'Rs')}',
                                        style: _ts(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${L.t('کلاس', 'Class')}: ${p.classTitle}',
                                  style: _ts(fontSize: 14, color: theme.subtextColor),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet_outlined,
                                        size: 16, color: theme.subtextColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${L.t('طریقہ', 'Method')}: ${p.method}',
                                      style: _ts(fontSize: 13, color: theme.subtextColor),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF10B981)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              L.t('ریفرنس / ٹرانزیکشن آئی ڈی', 'Txn ID / Ref No'),
                                              style: _ts(fontSize: 10, color: theme.subtextColor),
                                            ),
                                            SelectableText(
                                              p.txnReference.isEmpty ? L.t('کوئی ریفرنس درج نہیں', 'No reference') : p.txnReference,
                                              style: _ts(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (p.txnReference.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 14),
                                          tooltip: L.t('کاپی کریں', 'Copy'),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: p.txnReference));
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                              content: Text(L.t('ٹرانزیکشن آئی ڈی کاپی ہو گئی! 📋', 'Txn ID copied! 📋')),
                                              duration: const Duration(seconds: 2),
                                            ));
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // VIEW RECEIPT / SCREENSHOT BUTTON
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showReceiptDialog(p, theme),
                                    icon: const Icon(Icons.image_outlined, size: 16),
                                    label: Text(
                                      L.t('🖼️ رسید / اسکرین شاٹ دیکھیں', 'View Receipt Screenshot'),
                                      style: _ts(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.primaryColor,
                                      side: BorderSide(color: theme.primaryColor, width: 1.4),
                                      padding: const EdgeInsets.symmetric(vertical: 7),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () => _act(p.paymentId, false),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(L.t('رد کریں', 'Reject'),
                                          style: _ts(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: () => _act(p.paymentId, true),
                                      icon: const Icon(Icons.check_circle_outline, size: 16),
                                      label: Text(
                                        L.t('منظور کریں', 'Approve'),
                                        style: _ts(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
