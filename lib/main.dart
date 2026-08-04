import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixer_sonca/app.dart';
import 'package:mixer_sonca/core/services/theme_service.dart';
import 'package:mixer_sonca/injection.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_service.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  final prefs = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => prefs);
  
  final savedMode = prefs.getString('app_theme_mode');
  MixerService.themeMode = savedMode == 'modern' ? 1 : 0;
  if (savedMode == 'modern') {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } else {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
  
  setupInjection();

  // Load protocol definition from URL
  final protocolService = getIt<ProtocolService>();
  await protocolService.loadProtocolDefinition();

  // Initialize dynamic enum values from JSON
  AppModeValue.initializeFromProtocol(protocolService);
  EqFilterTypeValue.initializeFromProtocol(protocolService);

  // Download display file on startup and mapping with protocol define
  MixerService.themeMode = savedMode == 'modern' ? AppThemeMode.modern.value : AppThemeMode.classic.value;
  getIt<MixerService>().initLastModelIdx();
  await getIt<MixerService>().loadDisplayConfig();

  runApp(const MyApp());
}
