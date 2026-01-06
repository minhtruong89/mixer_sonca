import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixer_sonca/app.dart';
import 'package:mixer_sonca/injection.dart';
import 'package:mixer_sonca/core/services/config_service.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  
  setupInjection();
  
  // Download config file on startup
  //await getIt<ConfigService>().loadConfig();

  // Download and parse mixer define
  await getIt<MixerService>().loadMixerDefine();
  
  runApp(const MyApp());
}
