import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../app_lang.dart';
import '../services/payment_service.dart';

// Conditional import: on web use dart:html directly, on native use stub
import '../utils/web_file_picker_stub.dart'
    if (dart.library.html) '../utils/web_file_picker.dart';

/// پہلے سے لاگ اِن اسٹوڈنٹ کیلئے — لینڈنگ پیج کے "Paid" بٹن سے فیس سلپ
/// جمع کروانے کا مختصر ڈائیلاگ (کسی مخصوص class سے منسلک نہیں)۔
class AccountFeeSlipDialog extends StatefulWidget {
  const AccountFeeSlipDialog({super.key});

  @override
  State<AccountFeeSlipDialog> createState() => _AccountFeeSlipDialogState();
}

class _AccountFeeSlipDialogState extends State<AccountFeeSlipDialog> {
  Uint8List? _imageBytes;
  bool _saving = false;

  void _onPickTap() {
    if (kIsWeb) {
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
    } catch (_) {}

    try {
      final picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.isNotEmpty && mounted) {
          setState(() => _imageBytes = bytes);
        }
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      await PaymentService().submitAccountUpgradeRequest(
        receiptImageBase64:
            _imageBytes != null ? base64Encode(_imageBytes!) : null,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(L.t('درخواست جمع ہو گئی — ٹیچر کی تصدیق کا انتظار کریں۔',
              'Request submitted — awaiting teacher approval.')),
          backgroundColor: Colors.green.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        final isAuth = e.toString().contains('NOT_LOGGED_IN');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(isAuth
              ? L.t('سیشن ختم ہو گیا — دوبارہ لاگ اِن کریں۔',
                  'Session expired — please log in again.')
              : L.t('جمع نہیں ہو سکی، دوبارہ کوشش کریں۔',
                  'Could not submit, please try again.')),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(L.t('فیس سلپ جمع کروائیں', 'Submit Fee Slip'),
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              L.t('اپنی رسید/اسکرین شاٹ اپلوڈ کریں تاکہ ٹیچر تصدیق کر سکے۔',
                  'Upload your receipt/screenshot so the teacher can verify it.'),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 14),
            if (_imageBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(_imageBytes!,
                    height: 120, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _saving ? null : _onPickTap,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(_imageBytes == null
                  ? L.t('رسید اپ لوڈ کریں', 'Upload receipt')
                  : L.t('تصویر تبدیل کریں', 'Change photo')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(L.t('منسوخ', 'Cancel')),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(L.t('جمع کروائیں', 'Submit')),
        ),
      ],
    );
  }
}
