import 'app.dart';
import 'app_mode.dart';

/// اسٹوڈنٹ ایپ کا entry point۔
/// بنائیں:  flutter build web -t lib/main_student.dart -o build/student
/// چلائیں:  flutter run   -t lib/main_student.dart -d chrome
Future<void> main() => bootstrap(AppMode.student);
