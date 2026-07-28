import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  classic(0),
  modern(1);

  final int value;
  const AppThemeMode(this.value);
}

class ThemeService {
  final SharedPreferences _prefs;

  ThemeService(this._prefs);

  static const String _themeKey = 'app_theme_mode';

  AppThemeMode getThemeMode() {
    final mode = _prefs.getString(_themeKey);
    if (mode == AppThemeMode.modern.name) {
      return AppThemeMode.modern;
    }
    return AppThemeMode.classic; // default
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
  }
}
