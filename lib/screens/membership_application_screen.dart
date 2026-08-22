import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../membership_cards.dart';
import '../pending_membership.dart';
import '../services/payment_service.dart';
import 'auth_screen.dart';

// Conditional import: on web use dart:html directly, on native use stub
import '../utils/web_file_picker_stub.dart'
    if (dart.library.html) '../utils/web_file_picker.dart';

const _bg = Color(0xFFFAFAF8);
const _slate = Color(0xFF1E293B);
const _slateMuted = Color(0xFF64748B);

/// منتخب کردہ membership card کیلئے تفصیلات کا صفحہ — پہلے پوچھا جاتا ہے
/// "کیا آپ پہلے سے کارڈ ہولڈر ہیں؟":
/// - ہاں: موجودہ کارڈ کی تفصیل (نام، نمبر، جاری/میعاد، PIN) درج کریں —
///   ٹیچر تصدیق کرے گا۔
/// - نہیں: فیس سلپ اپلوڈ کریں — تصدیق کے بعد نیا کارڈ خودکار جاری ہوگا،
///   1 سال کیلئے۔
class MembershipApplicationScreen extends StatefulWidget {
  final MembershipCard card;
  final bool isLoggedIn;
  const MembershipApplicationScreen(
      {super.key, required this.card, required this.isLoggedIn});

  @override
  State<MembershipApplicationScreen> createState() =>
      _MembershipApplicationScreenState();
}

class _MembershipApplicationScreenState
    extends State<MembershipApplicationScreen> {
  bool? _isExistingHolder;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();
  final _nameOnCardCtrl = TextEditingController();
  final _cardNumberCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  DateTime? _issueDate;
  DateTime? _expiryDate;

  Uint8List? _receiptBytes;

  @override
  void dispose() {
    _nameOnCardCtrl.dispose();
    _cardNumberCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _onPickReceipt() {
    if (kIsWeb) {
      pickFileOnWeb().then((bytes) {
        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() => _receiptBytes = bytes);
        }
      });
    } else {
      _pickReceiptNative();
    }
  }

  Future<void> _pickReceiptNative() async {
    try {
      final result = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          if (mounted) setState(() => _receiptBytes = bytes);
          return;
        }
      }
    } catch (_) {}
    try {
      final picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.isNotEmpty && mounted) setState(() => _receiptBytes = bytes);
      }
    } catch (_) {}
  }

  Future<void> _pickDate({required bool isIssue}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isIssue) {
          _issueDate = picked;
        } else {
          _expiryDate = picked;
        }
      });
    }
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return L.t('تاریخ منتخب کریں', 'Select date');
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _submit() async {
    if (_isExistingHolder == true && !_formKey.currentState!.validate()) return;
    if (_isExistingHolder == true && (_issueDate == null || _expiryDate == null)) {
      _showMsg(
          L.t('براہِ کرم اجراء اور میعاد کی تاریخ منتخب کریں',
              'Please select the issue and expiry dates'),
          isError: true);
      return;
    }

    setState(() => _saving = true);
    final isLoggedInNow = Supabase.instance.client.auth.currentUser != null;

    try {
      if (isLoggedInNow) {
        await PaymentService().submitCardApplication(
          cardKey: widget.card.key,
          cardFee: widget.card.fee,
          isExistingHolder: _isExistingHolder == true,
          nameOnCard: _isExistingHolder == true ? _nameOnCardCtrl.text.trim() : null,
          cardNumber: _isExistingHolder == true ? _cardNumberCtrl.text.trim() : null,
          issueDate: _isExistingHolder == true ? _issueDate : null,
          expiryDate: _isExistingHolder == true ? _expiryDate : null,
          pin: _isExistingHolder == true ? _pinCtrl.text.trim() : null,
          receiptImageBase64: _isExistingHolder != true && _receiptBytes != null
              ? base64Encode(_receiptBytes!)
              : null,
        );
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(L.t('درخواست جمع ہو گئی — ٹیچر کی تصدیق کا انتظار کریں۔',
                'Request submitted — awaiting teacher approval.')),
            backgroundColor: Colors.green.shade700,
          ));
        }
      } else {
        // ابھی لاگ اِن نہیں — signup مکمل ہونے تک ڈیٹا محفوظ رکھیں، وہاں
        // نئے اکاؤنٹ کیلئے خودکار جمع ہو جائے گا۔
        PendingMembership.cardKey = widget.card.key;
        PendingMembership.cardFee = widget.card.fee;
        PendingMembership.isExistingHolder = _isExistingHolder == true;
        if (_isExistingHolder == true) {
          PendingMembership.nameOnCard = _nameOnCardCtrl.text.trim();
          PendingMembership.cardNumber = _cardNumberCtrl.text.trim();
          PendingMembership.issueDate = _issueDate;
          PendingMembership.expiryDate = _expiryDate;
          PendingMembership.pin = _pinCtrl.text.trim();
        } else {
          PendingMembership.receiptBytes = _receiptBytes;
        }
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AuthScreen(initialIsSignUp: true),
          ));
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        _showMsg(L.t('جمع نہیں ہو سکی، دوبارہ کوشش کریں۔', 'Could not submit, please try again.'),
            isError: true);
      }
    }
  }

  void _showMsg(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        foregroundColor: _slate,
        title: Text(L.t(c.labelUrdu, c.labelEn),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: c.color.withValues(alpha: 0.5)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 14,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.card_membership_rounded, color: c.color, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(L.t(c.labelUrdu, c.labelEn),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 16, color: _slate)),
                            Text(L.t('روپے ${c.fee.toInt()}', 'Rs ${c.fee.toInt()}'),
                                style: const TextStyle(color: _slateMuted, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  L.t('کیا آپ پہلے سے کارڈ ہولڈر ہیں؟',
                      'Are you already a card holder?'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _slate),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _choiceButton(
                        label: L.t('جی ہاں', 'Yes'),
                        selected: _isExistingHolder == true,
                        onTap: () => setState(() => _isExistingHolder = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _choiceButton(
                        label: L.t('نہیں، نیا apply کروں', 'No, apply for a card'),
                        selected: _isExistingHolder == false,
                        onTap: () => setState(() => _isExistingHolder = false),
                      ),
                    ),
                  ],
                ),
                if (_isExistingHolder == true) ...[
                  const SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _field(_nameOnCardCtrl, L.t('کارڈ پر نام', 'Name on card')),
                        const SizedBox(height: 12),
                        _field(_cardNumberCtrl, L.t('کارڈ نمبر', 'Card number')),
                        const SizedBox(height: 12),
                        _dateField(
                          label: L.t('اجراء کی تاریخ', 'Issue date'),
                          value: _fmtDate(_issueDate),
                          onTap: () => _pickDate(isIssue: true),
                        ),
                        const SizedBox(height: 12),
                        _dateField(
                          label: L.t('میعاد ختم ہونے کی تاریخ', 'Expiry date'),
                          value: _fmtDate(_expiryDate),
                          onTap: () => _pickDate(isIssue: false),
                        ),
                        const SizedBox(height: 12),
                        _field(_pinCtrl, L.t('PIN', 'PIN'), obscure: true),
                      ],
                    ),
                  ),
                ] else if (_isExistingHolder == false) ...[
                  const SizedBox(height: 24),
                  Text(
                    L.t('ادائیگی کی رسید اپلوڈ کریں — تصدیق کے بعد نیا کارڈ 1 سال کیلئے خودکار جاری ہو جائے گا۔',
                        'Upload your payment receipt — once approved, a new card is auto-issued, valid for 1 year.'),
                    style: const TextStyle(fontSize: 13, color: _slateMuted, height: 1.6),
                  ),
                  const SizedBox(height: 14),
                  if (_receiptBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_receiptBytes!,
                          height: 130, width: double.infinity, fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 10),
                  ],
                  OutlinedButton.icon(
                    onPressed: _onPickReceipt,
                    icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                    label: Text(_receiptBytes == null
                        ? L.t('رسید اپ لوڈ کریں', 'Upload receipt')
                        : L.t('تصویر تبدیل کریں', 'Change photo')),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: c.color,
                        side: BorderSide(color: c.color),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape:
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ],
                if (_isExistingHolder != null) ...[
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: c.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(
                              _isExistingHolder == true
                                  ? L.t('کارڈ رجسٹر کریں', 'Register Card')
                                  : L.t('کارڈ کیلئے درخواست دیں', 'Apply for Card'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choiceButton(
      {required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? widget.card.color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? widget.card.color : const Color(0xFFE2E8F0),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: selected ? widget.card.color : _slateMuted,
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {bool obscure = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: _slate),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        labelStyle: const TextStyle(color: _slateMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.card.color, width: 1.6),
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? L.t('یہ خانہ ضروری ہے', 'This field is required') : null,
    );
  }

  Widget _dateField({required String label, required String value, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: label,
          labelStyle: const TextStyle(color: _slateMuted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          suffixIcon: Icon(Icons.calendar_month_outlined, color: widget.card.color),
        ),
        child: Text(value, style: const TextStyle(color: _slate)),
      ),
    );
  }
}
