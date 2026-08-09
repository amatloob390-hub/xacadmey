import 'app.dart';
import 'app_mode.dart';

/// ایڈمن/اسٹاف ایپ کا entry point۔
/// بنائیں:  flutter build web -t lib/main_admin.dart -o build/admin
/// چلائیں:  flutter run   -t lib/main_admin.dart -d chrome
Future<void> main() => bootstrap(AppMode.staff);
