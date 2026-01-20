import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixer_sonca/app.dart';
import 'package:mixer_sonca/injection.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_service.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  setupInjection();

  // Load protocol definition from URL
  final protocolService = getIt<ProtocolService>();
  await protocolService.loadProtocolDefinition();

  // Initialize dynamic enum values from JSON
  AppModeValue.initializeFromProtocol(protocolService);
  EqFilterTypeValue.initializeFromProtocol(protocolService);

  // Download display file on startup and mapping with protocol define
  await getIt<MixerService>().loadDisplayConfig();

  
  runApp(const MyApp());
}
