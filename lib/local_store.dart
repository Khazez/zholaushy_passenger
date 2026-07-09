import 'package:shared_preferences/shared_preferences.dart';

/// Кросс-платформенная замена dart:html window.localStorage.
/// init() должен быть вызван и дождаться завершения до runApp().
class LocalStore {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static String? getString(String key) => _prefs?.getString(key);

  static void setString(String key, String value) {
    _prefs?.setString(key, value);
  }

  static void remove(String key) {
    _prefs?.remove(key);
  }
}
