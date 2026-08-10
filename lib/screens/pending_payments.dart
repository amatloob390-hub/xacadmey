import 'dart:convert';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _future = _service.getPending();
  }

  void _refresh() => setState(() => _future = _service.getPending());

  Future<void> _act(String id, bool approve) async {
    try {
      approve ? await _service.approve(id) : await _service.reject(id);
    } catch (_) {}

    if (mounted) {
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve
            ? L.t('ادائیگی منظور ہو گئی ✅', 'Payment approved ✅')
            : L.t('ادائیگی رد ہو گئی', 'Payment rejected')),
      ));
    }
  }

  void _showReceiptDialog(PendingPayment p, ThemePreset theme) {
    Widget contentWidget;
    if (p.receiptUrl != null && p.receiptUrl!.trim().isNotEmpty) {
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${L.t('ٹرانزیکشن آئی ڈی / رسید نمبر', 'Txn ID')}: ${p.txnReference}',
                style: _ts(fontSize: 14, fontWeight: FontWeight.bold, color: theme.primaryColor),
              ),
            ),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${L.t('رسید / اسکرین شاٹ', 'Receipt Screenshot')}: ${p.studentName}',
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
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: contentWidget,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
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
            ],
          ),
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
          backgroundColor: theme.bgColor,
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
              constraints: const BoxConstraints(maxWidth: 800),
              child: FutureBuilder<List<PendingPayment>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snapshot.data ?? [];
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
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

                      ...list.map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
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
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded,
                                        size: 16, color: theme.subtextColor),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        '${L.t('رسید / Txn ID', 'Txn ID')}: ${p.txnReference}',
                                        style: _ts(fontSize: 13, color: theme.subtextColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // VIEW RECEIPT / SCREENSHOT BUTTON
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _showReceiptDialog(p, theme),
                                    icon: const Icon(Icons.image_outlined, size: 18),
                                    label: Text(
                                      L.t('🖼️ رسید / اسکرین شاٹ دیکھیں', 'View Receipt Screenshot'),
                                      style: _ts(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: theme.primaryColor,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: theme.primaryColor,
                                      side: BorderSide(color: theme.primaryColor, width: 1.4),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
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
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: Text(L.t('رد کریں', 'Reject'),
                                          style: _ts(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red)),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: () => _act(p.paymentId, true),
                                      icon: const Icon(Icons.check_circle_outline, size: 18),
                                      label: Text(
                                        L.t('منظور کریں', 'Approve'),
                                        style: _ts(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
