import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../services/payment_service.dart';

// Conditional import: on web use dart:html directly, on native use stub
import '../utils/web_file_picker_stub.dart'
    if (dart.library.html) '../utils/web_file_picker.dart';

class SubmitPaymentDialog extends StatefulWidget {
  final String classId, classTitle;
  const SubmitPaymentDialog(
      {super.key, required this.classId, required this.classTitle});

  @override
  State<SubmitPaymentDialog> createState() => _SubmitPaymentDialogState();
}

class _SubmitPaymentDialogState extends State<SubmitPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _txnCtrl = TextEditingController();
  String _method = 'jazzcash';
  bool _saving = false;

  Uint8List? _imageBytes;

  Map<String, String> get _methods => {
        'jazzcash': L.t('جاز کیش', 'JazzCash'),
        'easypaisa': L.t('ایزی پیسہ', 'EasyPaisa'),
        'bank': L.t('بینک ٹرانسفر', 'Bank Transfer'),
        'other': L.t('دیگر', 'Other'),
      };

  @override
  void dispose() {
    _amountCtrl.dispose();
    _txnCtrl.dispose();
    super.dispose();
  }

  /// Called from onTap — must stay synchronous on web so the browser's
  /// user-gesture chain remains unbroken before the file dialog opens.
  void _onPickTap() {
    if (kIsWeb) {
      // Web: use dart:html <input type="file"> — opens synchronously in same gesture
      pickFileOnWeb().then((bytes) {
        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() => _imageBytes = bytes);
        }
      });
    } else {
      _pickNative();
    }
  }

  Future<void> _pickNative() async {
    // Native: try FilePicker first, then ImagePicker
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          if (mounted) setState(() => _imageBytes = bytes);
          return;
        }
      }
    } catch (e) {
      debugPrint('FilePicker info: $e');
    }

    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          setState(() => _imageBytes = bytes);
        }
      }
    } catch (e) {
      debugPrint('ImagePicker info: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      String? receiptBase64;
      if (_imageBytes != null && _imageBytes!.isNotEmpty) {
        receiptBase64 = base64Encode(_imageBytes!);
      }

      await PaymentService().submitPayment(
        classId: widget.classId,
        amount: double.parse(_amountCtrl.text.trim()),
        method: _method,
        txnReference: _txnCtrl.text.trim(),
        receiptImage: receiptBase64,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('ادائیگی جمع ہو گئی — ٹیچر کی تصدیق کا انتظار کریں۔',
              'Payment submitted — awaiting teacher approval.')),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final isAuth = e.toString().contains('NOT_LOGGED_IN');
        final baseMsg = isAuth
            ? L.t('سیشن ختم ہو گیا — دوبارہ لاگ اِن کر کے کوشش کریں۔',
                'Session expired — please log in again and retry.')
            : L.t('جمع نہیں ہو سکی، دوبارہ کوشش کریں۔',
                'Could not submit, please try again.');
        // TEMP diagnostic: show the raw error too so we can see exactly why
        // the insert failed. Remove this once the payment issue is fixed.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 12),
            content: Text('$baseMsg\n\n[debug] $e')));
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

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemePreset>(
      valueListenable: AppTheme.currentTheme,
      builder: (context, theme, _) {
        final inputFill = theme.isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                L.t('فیس جمع کروائیں', 'Submit Fee'),
                style: _ts(fontSize: 16, fontWeight: FontWeight.bold, theme: theme),
              ),
              Text(
                widget.classTitle,
                style: _ts(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryColor,
                  theme: theme,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _method,
                    dropdownColor: theme.cardColor,
                    style: _ts(fontSize: 15, theme: theme),
                    iconEnabledColor: theme.primaryColor,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFill,
                      labelText: L.t('ادائیگی کا طریقہ', 'Payment method'),
                      labelStyle: _ts(fontSize: 14, color: theme.subtextColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.primaryColor, width: 1.6),
                      ),
                    ),
                    items: _methods.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, style: _ts(fontSize: 15, theme: theme)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _method = v!),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: _ts(fontSize: 15, theme: theme),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFill,
                      labelText: L.t('رقم (روپے)', 'Amount (Rs)'),
                      labelStyle: _ts(fontSize: 14, color: theme.subtextColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.primaryColor, width: 1.6),
                      ),
                    ),
                    validator: (v) => (v == null || double.tryParse(v) == null)
                        ? L.t('درست رقم درج کریں', 'Enter a valid amount')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _txnCtrl,
                    style: _ts(fontSize: 15, theme: theme),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputFill,
                      labelText: L.t('ٹرانزیکشن آئی ڈی / رسید نمبر',
                          'Transaction ID / Receipt no.'),
                      labelStyle: _ts(fontSize: 14, color: theme.subtextColor),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: theme.primaryColor, width: 1.6),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? L.t('ٹرانزیکشن آئی ڈی ضروری ہے', 'Transaction ID is required')
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // --- RECEIPT UPLOAD: SizedBox wrapping ElevatedButton for full-width click ---
                  if (_imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        _imageBytes!,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 6),
                        Text(
                          L.t('رسید کی تصویر منتخب ہو گئی ✅',
                              'Receipt Image Selected ✅'),
                          style: _ts(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _onPickTap,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                      label: Text(
                        _imageBytes == null
                            ? L.t('رسید / اسکرین شاٹ اپ لوڈ کریں',
                                'Upload Receipt / Screenshot')
                            : L.t('تصویر تبدیل کریں', 'Change Photo'),
                        style: _ts(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: Text(
                L.t('منسوخ', 'Cancel'),
                style: _ts(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.subtextColor,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      L.t('جمع کروائیں', 'Submit'),
                      style: _ts(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}
