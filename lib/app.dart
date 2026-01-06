import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/theme/app_theme.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/ble_page.dart';
import 'package:mixer_sonca/features/counter/counter_logic.dart';
import 'package:mixer_sonca/injection.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => getIt<CounterViewModel>(),
        ),
        ChangeNotifierProvider(
          create: (_) => getIt<BleViewModel>(),
        ),
      ],
      child: MaterialApp(
        title: 'Sonca Mixer',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const BlePage(),
      ),
    );
  }
}
