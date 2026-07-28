import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixer_sonca/core/services/theme_service.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/injection.dart';

class ThemeViewModel extends ChangeNotifier {
  final ThemeService _themeService;

  AppThemeMode _currentMode;

  ThemeViewModel({required ThemeService themeService})
      : _themeService = themeService,
        _currentMode = themeService.getThemeMode() {
    _applyOrientation(_currentMode);
  }

  AppThemeMode get currentMode => _currentMode;

  Future<void> setThemeMode(BuildContext context, AppThemeMode mode) async {
    if (_currentMode != mode) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.red)),
      );

      _currentMode = mode;
      await _themeService.setThemeMode(mode);
      MixerService.themeMode = mode.value;
      _applyOrientation(mode);
      
      // Reload display config for the new theme
      await getIt<MixerService>().loadDisplayConfig();

      notifyListeners();
      
      // Close loading and pop all routes to return to HomeSwitchPage
      Navigator.of(context, rootNavigator: true).pop(); // dismiss dialog
      Navigator.of(context).popUntil((route) => route.isFirst);
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
