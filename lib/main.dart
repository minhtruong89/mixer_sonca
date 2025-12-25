import 'package:flutter/material.dart';
import 'package:mixer_sonca/app.dart';
import 'package:mixer_sonca/injection.dart';
import 'package:mixer_sonca/core/services/config_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  setupInjection();
  
  // Download config file on startup
  await getIt<ConfigService>().loadConfig();
  
  runApp(const MyApp());
}
