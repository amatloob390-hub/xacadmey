import 'dart:typed_data';

/// لینڈنگ پیج پر membership card کی درخواست بھرنے کے بعد اگر صارف لاگ اِن
/// نہیں تھا، تو signup مکمل ہونے تک یہ ڈیٹا یہاں محفوظ رہتا ہے (تاکہ
/// AuthScreen کے signUp() کے فوراً بعد نئے اکاؤنٹ کیلئے جمع کرایا جا سکے)۔
class PendingMembership {
  static String? cardKey;
  static double? cardFee;
  static bool isExistingHolder = false;

  // Existing-holder فارم
  static String? nameOnCard;
  static String? cardNumber;
  static DateTime? issueDate;
  static DateTime? expiryDate;
  static String? pin;

  // نیا apply کرنے والے کی رسید
  static Uint8List? receiptBytes;

  static bool get hasPending => cardKey != null;

  static void clear() {
    cardKey = null;
    cardFee = null;
    isExistingHolder = false;
    nameOnCard = null;
    cardNumber = null;
    issueDate = null;
    expiryDate = null;
    pin = null;
    receiptBytes = null;
  }
}
