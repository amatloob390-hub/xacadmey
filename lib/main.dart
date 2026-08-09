import 'app.dart';
import 'app_mode.dart';

/// مشترکہ ایپ (ڈیولپمنٹ) — رول کے مطابق admin یا student دکھاتی ہے۔
/// الگ ایپس کے لیے: main_admin.dart اور main_student.dart دیکھیں۔
Future<void> main() => bootstrap(AppMode.combined);
