import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// ہر ڈیوائس کیلئے ایک مستقل منفرد آئی ڈی بناتا اور محفوظ رکھتا ہے۔
/// یہ ویب اور موبائل دونوں پر یکساں چلتا ہے (سنگل کوڈ بیس اصول)۔
class DeviceService {
  static const _key = 'local_device_id';

  /// اگر آئی ڈی پہلے سے موجود ہے تو وہی واپس، ورنہ نئی بنا کر محفوظ کرے۔
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);

    if (id == null || id.isEmpty) {
      // 0x7FFFFFFF ویب پر محفوظ ہے (1 << 32 ویب پر 0 بن جاتا ہے — بگ)
      final r = Random();
      final rand1 = r.nextInt(0x7FFFFFFF);
      final rand2 = r.nextInt(0x7FFFFFFF);
      id = '${DateTime.now().microsecondsSinceEpoch}_${rand1}_$rand2';
      await prefs.setString(_key, id);
    }
    return id;
  }
}
