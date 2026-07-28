import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ui/theme_view_model.dart';
import 'package:mixer_sonca/core/services/theme_service.dart';

class ModernSettingsScreen extends StatelessWidget {
  const ModernSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  backgroundColor: Colors.grey[900],
                  title: const Text('Chọn giao diện', style: TextStyle(color: Colors.white)),
                  content: Consumer<ThemeViewModel>(
                    builder: (context, tvm, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<AppThemeMode>(
                            title: const Text('Classic (Landscape)', style: TextStyle(color: Colors.white)),
                            value: AppThemeMode.classic,
                            groupValue: tvm.currentMode,
                            onChanged: (value) {
                              if (value != null) {
                                tvm.setThemeMode(value);
                                Navigator.pop(context);
                                Navigator.pop(context);
                              }
                            },
                            activeColor: Colors.red,
                            fillColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) return Colors.red;
                              return Colors.white54;
                            }),
                          ),
                          RadioListTile<AppThemeMode>(
                            title: const Text('Modern (Portrait)', style: TextStyle(color: Colors.white)),
                            value: AppThemeMode.modern,
                            groupValue: tvm.currentMode,
                            onChanged: (value) {
                              if (value != null) {
                                tvm.setThemeMode(value);
                                Navigator.pop(context);
                              }
                            },
                            activeColor: Colors.red,
                            fillColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                              if (states.contains(WidgetState.selected)) return Colors.red;
                              return Colors.white54;
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }
            );
          },
          child: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Cài Đặt Ứng Dụng',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const Spacer(),
            
            // (Empty space since title moved to appbar)

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
      ),
    );
  }
}
