import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/services/theme_service.dart';
import 'package:mixer_sonca/features/ble/ui/theme_view_model.dart';
import 'package:mixer_sonca/features/ble/ui/classic/classic_ble_page.dart';
import 'package:mixer_sonca/features/ble/ui/modern/modern_ble_page.dart';

class HomeSwitchPage extends StatelessWidget {
  const HomeSwitchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeViewModel>(
      builder: (context, themeViewModel, child) {
        if (themeViewModel.currentMode == AppThemeMode.modern) {
          return const ModernBlePage();
        } else {
          return const ClassicBlePage();
        }
      },
    );
  }
}
