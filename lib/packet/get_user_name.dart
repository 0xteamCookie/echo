import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class UserSettings {
  static const String _nameKey = kPrefUserName;

  static Future<String> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nameKey) ?? '';
  }

  static Future<void> setName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nameKey, name);
  }
}
