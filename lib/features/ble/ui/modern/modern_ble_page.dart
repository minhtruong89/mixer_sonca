import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/ui/theme_view_model.dart';
import 'package:mixer_sonca/core/services/theme_service.dart';

class ModernBlePage extends StatelessWidget {
  const ModernBlePage({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Cài đặt',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          // Temporarily adding a button here to easily switch back to Classic while testing
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              final tvm = context.read<ThemeViewModel>();
              tvm.setThemeMode(AppThemeMode.classic);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Text(
                'Bluetooth là bắt buộc để điều khiển loa.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Vui lòng đảm bảo rằng Bluetooth được hỗ trợ và đã bật.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (viewModel.isScanning)
                const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                )
              else
                ElevatedButton(
                  onPressed: () {
                    viewModel.scanDevices();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cho phép Bluetooth',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
