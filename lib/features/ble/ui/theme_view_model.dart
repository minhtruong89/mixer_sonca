import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixer_sonca/core/services/theme_service.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';

class ThemeViewModel extends ChangeNotifier {
  final ThemeService _themeService;

  AppThemeMode _currentMode;

  ThemeViewModel({required ThemeService themeService})
      : _themeService = themeService,
        _currentMode = themeService.getThemeMode() {
    _applyOrientation(_currentMode);
  }

  AppThemeMode get currentMode => _currentMode;

  void setThemeMode(AppThemeMode mode) {
    if (_currentMode != mode) {
      _currentMode = mode;
      _themeService.setThemeMode(mode);
      MixerService.themeMode = mode.value;
      _applyOrientation(mode);
      notifyListeners();
    }
  }

  void _applyOrientation(AppThemeMode mode) {
    if (mode == AppThemeMode.modern) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }
}
