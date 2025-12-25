import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/theme/app_theme.dart';
import 'package:mixer_sonca/features/counter/counter_page.dart';
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
      ],
      child: MaterialApp(
        title: 'Sonca Mixer',
        theme: AppTheme.lightTheme,
        home: const CounterPage(),
      ),
    );
  }
}
