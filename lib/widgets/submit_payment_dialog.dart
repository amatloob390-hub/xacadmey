import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_lang.dart';
import '../app_theme.dart';
import '../services/payment_service.dart';

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

  Future<void> _pickReceiptImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.isNotEmpty) {
          setState(() {
            _imageBytes = bytes;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('ImagePicker info: $e');
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.single.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          setState(() {
            _imageBytes = bytes;
          });
        }
      }
    } catch (e) {
      debugPrint('FilePicker info: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await PaymentService().submitPayment(
        classId: widget.classId,
        amount: double.parse(_amountCtrl.text.trim()),
        method: _method,
        txnReference: _txnCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('ادائیگی جمع ہو گئی — ٹیچر کی تصدیق کا انتظار کریں۔',
              'Payment submitted — awaiting teacher approval.')),
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(L.t('جمع نہیں ہو سکی، دوبارہ کوشش کریں۔',
                'Could not submit, please try again.'))));
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
          title: Text(
            '${L.t('فیس جمع کروائیں', 'Submit Fee')}: ${widget.classTitle}',
            style: _ts(fontSize: 18, fontWeight: FontWeight.bold, theme: theme),
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

                  // --- RECEIPT IMAGE UPLOAD SECTION ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                    ),
                    child: Column(
                      children: [
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
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF10B981), size: 18),
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
                          const SizedBox(height: 6),
                        ],
                        OutlinedButton.icon(
                          onPressed: _pickReceiptImage,
                          icon: Icon(Icons.add_a_photo_outlined, size: 20, color: theme.primaryColor),
                          label: Text(
                            _imageBytes == null
                                ? L.t('رسید / اسکرین شاٹ اپ لوڈ کریں',
                                    'Upload Receipt / Screenshot')
                                : L.t('تصویر تبدیل کریں', 'Change Photo'),
                            style: _ts(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.primaryColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.primaryColor,
                            side: BorderSide(color: theme.primaryColor, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
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
