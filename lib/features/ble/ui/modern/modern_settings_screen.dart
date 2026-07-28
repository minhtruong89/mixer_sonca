import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ui/theme_view_model.dart';
import 'package:mixer_sonca/core/services/theme_service.dart';
import 'package:mixer_sonca/features/ble/ui/modern/app_settings_screen.dart';

class ModernSettingsScreen extends StatelessWidget {
  const ModernSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Top Right Action Icon
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            
            // Main Content
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  const SizedBox(height: 100), // Khoảng cách đẩy chữ xuống
                  
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => const AppSettingsScreen(),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
                        ),
                      );
                    },
                    child: const Text(
                      'Cài Đặt Ứng Dụng',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                      ),
                    ),
                  ),

                  const Spacer(),
                  
                  // Footer
                  const Padding(
                    padding: EdgeInsets.only(bottom: 24.0),
                    child: Text(
                      '@MixGo Soncamedia',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
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
