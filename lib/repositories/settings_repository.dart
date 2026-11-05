import 'package:shared_preferences/shared_preferences.dart';

/// On-device settings, kept out of the state class.
class SettingsRepository {
  static const _dayKey = 'selected_day';

  Future<int?> loadDay() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dayKey);
  }

  Future<void> saveDay(int day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dayKey, day);
  }
}
