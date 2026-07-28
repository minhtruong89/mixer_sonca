import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/ui/modern/modern_settings_screen.dart';

class ModernPermissionPage extends StatelessWidget {
  final VoidCallback onPermissionsGranted;

  const ModernPermissionPage({super.key, required this.onPermissionsGranted});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();

    return SafeArea(
      child: Stack(
        children: [
          // Top Right Action Icon
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const ModernSettingsScreen(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          ),
          
          // Main Content
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 100), // Khoảng cách đẩy chữ xuống
                const Text(
                  'Cài đặt',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                Expanded(
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
                            onPressed: () async {
                              await viewModel.scanDevices();
                              // Check if permissions and bluetooth are now OK
                              final isOk = await viewModel.checkPermissionsAndBluetooth();
                              if (isOk) {
                                onPermissionsGranted();
                              }
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
