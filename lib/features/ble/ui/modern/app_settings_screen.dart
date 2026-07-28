import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:mixer_sonca/features/ble/ui/theme_view_model.dart';
import 'package:mixer_sonca/core/services/theme_service.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Left Action Icon
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            
            // Main Content
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  const Text(
                    'Cài Đặt Ứng Dụng',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // App Version
                  const Text(
                    'App Version',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.hasData ? snapshot.data!.version : '...';
                      return Text(
                        version,
                        style: const TextStyle(color: Colors.white, fontSize: 18),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // App Theme
                  const Text(
                    'App Theme',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  
                  Consumer<ThemeViewModel>(
                    builder: (context, tvm, child) {
                      final isClassic = tvm.currentMode == AppThemeMode.classic;
                      final isModern = tvm.currentMode == AppThemeMode.modern;
                      
                      return Column(
                        children: [
                          GestureDetector(
                            onTap: () => tvm.setThemeMode(context, AppThemeMode.classic),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 32.0),
                              child: Text(
                                'Classic',
                                style: TextStyle(
                                  color: isClassic ? Colors.greenAccent : Colors.white,
                                  fontSize: 18,
                                  fontWeight: isClassic ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => tvm.setThemeMode(context, AppThemeMode.modern),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 32.0),
                              child: Text(
                                'Modern',
                                style: TextStyle(
                                  color: isModern ? Colors.greenAccent : Colors.white,
                                  fontSize: 18,
                                  fontWeight: isModern ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
