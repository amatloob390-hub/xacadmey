import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_lang.dart';
import '../membership_cards.dart';
import '../pending_class.dart';
import '../pending_membership.dart';
import '../services/auth_service.dart';
import '../services/payment_service.dart';

// Conditional import: on web use dart:html directly, on native use stub
import '../utils/web_file_picker_stub.dart'
    if (dart.library.html) '../utils/web_file_picker.dart';

class AuthScreen extends StatefulWidget {
  final bool initialIsSignUp;
  final String? initialPlan;
  final String? initialMembershipCard;
  const AuthScreen({
    super.key,
    this.initialIsSignUp = false,
    this.initialPlan,
    this.initialMembershipCard,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isLogin = true;
  bool _loading = false;
  String _plan = 'trial'; // 'trial' | 'paid' | 'premier'
  String? _className;

  // 'paid' پلان: فیس سلپ کی تصویر (اختیاری)۔
  Uint8List? _feeSlipBytes;

  // 'premier' پلان: منتخب کردہ membership card۔
  String? _membershipCard;

  @override
  void initState() {
    super.initState();
    if (widget.initialIsSignUp) {
      _isLogin = false;
    }
    if (widget.initialPlan != null) {
      _plan = widget.initialPlan!;
    }
    if (widget.initialMembershipCard != null) {
      _membershipCard = widget.initialMembershipCard;
    }
    if (PendingClass.id != null) {
      _isLogin = false; // class link سے آمد → رجسٹریشن
      _loadClassName();
    }
  }

  Future<void> _loadClassName() async {
    try {
      final row = await Supabase.instance.client
          .from('classes')
          .select('title')
          .eq('id', PendingClass.id!)
          .maybeSingle();
      final t = row?['title'] as String?;
      if (t != null && mounted) setState(() => _className = t);
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// Called from onTap — must stay synchronous on web so the browser's
  /// user-gesture chain remains unbroken before the file dialog opens.
  void _onPickFeeSlip() {
    if (kIsWeb) {
      pickFileOnWeb().then((bytes) {
        if (bytes != null && bytes.isNotEmpty && mounted) {
          setState(() => _feeSlipBytes = bytes);
        }
      });
    } else {
      _pickFeeSlipNative();
    }
  }

  Future<void> _pickFeeSlipNative() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null && bytes.isNotEmpty) {
          if (mounted) setState(() => _feeSlipBytes = bytes);
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
          setState(() => _feeSlipBytes = bytes);
        }
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isLogin && _plan == 'premier' && _membershipCard == null) {
      _showMsg(
          L.t('براہِ کرم membership card منتخب کریں', 'Please select a membership card'),
          isError: true);
      return;
    }

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await _auth.signIn(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        final selectedCard = MembershipCard.byKey(_membershipCard);
        await _auth.signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
          fullName: _nameCtrl.text.trim(),
          plan: _plan,
          classId: PendingClass.id,
          phone: _phoneCtrl.text.trim(),
          receiptImageBase64: (_plan == 'paid' && _feeSlipBytes != null)
              ? base64Encode(_feeSlipBytes!)
              : null,
          membershipCard: _plan == 'premier' ? _membershipCard : null,
          membershipFee: _plan == 'premier' ? selectedCard?.fee : null,
        );

        // اگر لینڈنگ پیج کے membership card application سے آئے ہیں تو اب
        // نئے (فوراً authenticated) اکاؤنٹ کیلئے وہ درخواست جمع کریں۔
        if (PendingMembership.hasPending) {
          try {
            await PaymentService().submitCardApplication(
              cardKey: PendingMembership.cardKey!,
              cardFee: PendingMembership.cardFee ?? 0,
              isExistingHolder: PendingMembership.isExistingHolder,
              nameOnCard: PendingMembership.nameOnCard,
              cardNumber: PendingMembership.cardNumber,
              issueDate: PendingMembership.issueDate,
              expiryDate: PendingMembership.expiryDate,
              pin: PendingMembership.pin,
              receiptImageBase64: PendingMembership.receiptBytes != null
                  ? base64Encode(PendingMembership.receiptBytes!)
                  : null,
            );
          } catch (_) {}
          PendingMembership.clear();
        }

        if (mounted) {
          _showMsg(L.t(
            'اکاؤنٹ رجسٹر ہو گیا! ٹرائل ختم ہونے پر ٹیچر کو فیس سلپ دکھا کر تصدیق کروائیں — پھر لاگ اِن اور کلاس جوائن ہو سکے گی۔',
            'Account registered! When your trial ends, show your fee slip to the teacher to get verified — then you can log in and join classes.'
          ));
          setState(() => _isLogin = true);
        }
      }
    } on AuthException catch (e) {
      _showMsg(_mapAuthError(e.message), isError: true);
    } catch (_) {
      _showMsg(
          L.t('کچھ گڑبڑ ہوئی، دوبارہ کوشش کریں۔', 'Something went wrong, try again.'),
          isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(String raw) {
    if (raw.contains('PENDING_ADMIN_VERIFICATION')) {
      return L.t(
        'آپ کا اکاؤنٹ ابھی تصدیق کا منتظر ہے۔ ٹیچر کو فیس سلپ دکھا کر تصدیق کروائیں، پھر لاگ اِن ہو سکے گا۔',
        'Your account is pending verification. Show your fee slip to the teacher to get verified, then you can log in.'
      );
    } else if (raw.contains('TRIAL_EXPIRED')) {
      return L.t(
        'آپ کی ٹرائل مدت ختم ہو چکی ہے۔ رسائی جاری رکھنے کے لیے ٹیچر کو فیس سلپ دکھا کر تصدیق کروائیں۔',
        'Your trial has ended. Show your fee slip to the teacher to continue access.'
      );
    } else if (raw.contains('MEMBERSHIP_EXPIRED')) {
      return L.t(
        'آپ کے membership card کی میعاد ختم ہو چکی ہے۔ دوبارہ رسائی کیلئے تجدید کروائیں۔',
        'Your membership card has expired. Please renew to regain access.'
      );
    } else if (raw.contains('Invalid login')) {
      return L.t('ای میل یا پاس ورڈ غلط ہے۔', 'Invalid email or password.');
    } else if (raw.contains('already registered')) {
      return L.t('یہ ای میل پہلے سے رجسٹرڈ ہے۔', 'This email is already registered.');
    } else if (raw.contains('at least 6')) {
      return L.t('پاس ورڈ کم از کم ۶ حروف کا ہو۔',
          'Password must be at least 6 characters.');
    } else if (raw.contains('VERIFICATION_CHECK_FAILED')) {
      return L.t('تصدیق چیک نہیں ہو سکی — دوبارہ کوشش کریں۔',
          'Could not verify your account — please try again.');
    }
    return L.t('ایتھنٹیکیشن میں مسئلہ پیش آیا۔', 'Authentication problem occurred.');
  }

  void _showMsg(String m, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Widget _planChip(String value, String label) {
    final selected = _plan == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _loading ? null : (_) => setState(() => _plan = value),
    );
  }

  /// 'paid' پلان کیلئے — فیس سلپ کی تصویر (اختیاری) اپلوڈ کا آپشن۔
  Widget _feeSlipSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.t('فیس سلپ (اختیاری)', 'Fee Slip (optional)'),
            style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            L.t('ابھی اپلوڈ کریں یا بعد میں ٹیچر کو دکھائیں۔',
                'Upload now, or show it to the teacher later.'),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_feeSlipBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_feeSlipBytes!,
                  height: 100, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _onPickFeeSlip,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(_feeSlipBytes == null
                  ? L.t('رسید اپ لوڈ کریں', 'Upload receipt')
                  : L.t('تصویر تبدیل کریں', 'Change photo')),
            ),
          ),
        ],
      ),
    );
  }

  /// 'premier' پلان کیلئے — membership card منتخب کریں (فیس کے ساتھ)۔
  Widget _membershipCardSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.t('Membership card منتخب کریں', 'Choose a membership card'),
            style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MembershipCard.all.map((c) {
              final selected = _membershipCard == c.key;
              return GestureDetector(
                onTap: _loading
                    ? null
                    : () => setState(() => _membershipCard = c.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 130,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? c.color.withValues(alpha: 0.15) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? c.color : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.card_membership_rounded,
                          color: c.color, size: 22),
                      const SizedBox(height: 6),
                      Text(
                        L.t(c.labelUrdu, c.labelEn),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        L.t('روپے ${c.fee.toInt()}', 'Rs ${c.fee.toInt()}'),
                        style: TextStyle(
                            color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget seg(String label, bool selected, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: _loading ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(label,
                  style: TextStyle(
                      color: selected ? Colors.white : Colors.grey.shade600,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        );

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF17193A), Color(0xFF2C2A63), Color(0xFFF4F5FB)],
                stops: [0.0, 0.30, 0.60],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        label: Text(L.t('ہوم پر واپس', 'Back to Home')),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                      const Spacer(),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white),
                        icon: const Icon(Icons.language, size: 20),
                        label: Text(AppLang.ur ? 'English' : 'اردو'),
                        onPressed: () => AppLang.toggle(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(colors: [
                                  Color(0xFF4A47CE),
                                  Color(0xFFF3B740)
                                ]),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: .3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8))
                                ],
                              ),
                              child: const Icon(Icons.school,
                                  color: Colors.white, size: 34),
                            ),
                            const SizedBox(height: 14),
                            const Text('Xacademy',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              L.t('لائیو آن لائن اسکلز اکیڈمی',
                                  'Live online skills academy'),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: .75),
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: .18),
                                      blurRadius: 30,
                                      offset: const Offset(0, 12))
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F0F8),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(children: [
                                        seg(L.t('لاگ اِن', 'Log In'), _isLogin,
                                            () => setState(
                                                () => _isLogin = true)),
                                        seg(L.t('نیا اکاؤنٹ', 'Sign Up'),
                                            !_isLogin,
                                            () => setState(
                                                () => _isLogin = false)),
                                      ]),
                                    ),
                                    const SizedBox(height: 18),
                                    if (!_isLogin) ...[
                                      if (_className != null)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(11),
                                          margin:
                                              const EdgeInsets.only(bottom: 14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECEBFB),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(children: [
                                            const Icon(Icons.video_call,
                                                color: Color(0xFF4A47CE)),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                '${L.t('کلاس: ', 'Class: ')}${_className!}',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF16182E)),
                                              ),
                                            ),
                                          ]),
                                        ),
                                      TextFormField(
                                        controller: _nameCtrl,
                                        decoration: InputDecoration(
                                          labelText:
                                              L.t('پورا نام', 'Full name'),
                                          prefixIcon:
                                              const Icon(Icons.person_outline),
                                        ),
                                        validator: (v) =>
                                            (v == null || v.trim().isEmpty)
                                                ? L.t('نام درج کریں',
                                                    'Enter your name')
                                                : null,
                                      ),
                                      const SizedBox(height: 14),
                                      TextFormField(
                                        controller: _phoneCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                          labelText: L.t(
                                              'موبائل نمبر', 'Mobile number'),
                                          prefixIcon:
                                              const Icon(Icons.phone_outlined),
                                        ),
                                        validator: (v) =>
                                            (v == null || v.trim().length < 7)
                                                ? L.t('درست موبائل نمبر درج کریں',
                                                    'Enter a valid mobile number')
                                                : null,
                                      ),
                                      const SizedBox(height: 14),
                                      Align(
                                        alignment:
                                            AlignmentDirectional.centerStart,
                                        child: Text(
                                            L.t('پلان منتخب کریں',
                                                'Choose a plan'),
                                            style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13)),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(spacing: 8, runSpacing: 8, children: [
                                        _planChip('trial',
                                            L.t('ٹرائل (7 دن)', 'Trial (7 days)')),
                                        _planChip('paid', L.t('پیڈ', 'Paid')),
                                        _planChip('premier',
                                            L.t('پریمیئر', 'Premier')),
                                      ]),
                                      const SizedBox(height: 14),
                                      if (_plan == 'paid') _feeSlipSection(),
                                      if (_plan == 'premier')
                                        _membershipCardSection(),
                                    ],
                                    TextFormField(
                                      controller: _emailCtrl,
                                      keyboardType:
                                          TextInputType.emailAddress,
                                      decoration: InputDecoration(
                                        labelText: L.t('ای میل', 'Email'),
                                        prefixIcon:
                                            const Icon(Icons.email_outlined),
                                      ),
                                      validator: (v) =>
                                          (v == null || !v.contains('@'))
                                              ? L.t('درست ای میل درج کریں',
                                                  'Enter a valid email')
                                              : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _passCtrl,
                                      obscureText: true,
                                      decoration: InputDecoration(
                                        labelText: L.t('پاس ورڈ', 'Password'),
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.length < 6)
                                              ? L.t('کم از کم ۶ حروف',
                                                  'At least 6 characters')
                                              : null,
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF4A47CE),
                                                Color(0xFF6E4AE2)
                                              ]),
                                        ),
                                        child: ElevatedButton(
                                          onPressed:
                                              _loading ? null : _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: _loading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white))
                                              : Text(_isLogin
                                                  ? L.t('لاگ اِن کریں',
                                                      'Log In')
                                                  : L.t('اکاؤنٹ بنائیں',
                                                      'Create Account')),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
