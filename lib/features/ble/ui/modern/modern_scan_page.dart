import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/ui/modern/modern_settings_screen.dart';

class ModernScanPage extends StatefulWidget {
  const ModernScanPage({super.key});

  @override
  State<ModernScanPage> createState() => _ModernScanPageState();
}

class _ModernScanPageState extends State<ModernScanPage> {
  BleDevice? _focusedDevice;

  @override
  void initState() {
    super.initState();
    // Auto start scanning when entering this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleViewModel>().scanDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();
    final devices = viewModel.devices;

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
                const SizedBox(height: 80),
                const Text(
                  'Chọn thiết bị',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Device List
                Expanded(
                  child: devices.isEmpty
                    ? Center(
                        child: viewModel.isScanning
                          ? const CircularProgressIndicator(color: Colors.red)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Không tìm thấy thiết bị', style: TextStyle(color: Colors.white54)),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => viewModel.scanDevices(),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                                  child: const Text('Quét lại', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        itemCount: devices.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          final isSelected = _focusedDevice?.id == device.id;
                          
                          // Extract last 4 chars of ID for the suffix
                          String idSuffix = "";
                          if (device.id.length >= 4) {
                            idSuffix = device.id.substring(device.id.length - 4).toUpperCase();
                          } else {
                            idSuffix = device.id.toUpperCase();
                          }
                          // Remove colons if any
                          idSuffix = idSuffix.replaceAll(':', '');
                          if (idSuffix.length > 4) {
                            idSuffix = idSuffix.substring(idSuffix.length - 4);
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _focusedDevice = device;
                              });
                            },
                            child: Container(
                              height: 80,
                              decoration: ShapeDecoration(
                                color: Colors.grey[900], // Dark grey background
                                shape: BeveledRectangleBorder(
                                  side: BorderSide(color: Colors.grey[800]!, width: 1),
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Icon side
                                  Container(
                                    width: 60,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.speaker,
                                      color: isSelected ? Colors.white : Colors.white54,
                                      size: 32,
                                    ),
                                  ),
                                  // Divider
                                  Container(
                                    width: 1,
                                    height: double.infinity,
                                    color: Colors.grey[800],
                                  ),
                                  const SizedBox(width: 16),
                                  
                                  // Name and underline
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.soncaName,
                                          style: TextStyle(
                                            color: isSelected ? Colors.white : Colors.white70,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (isSelected)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            height: 2,
                                            width: 40,
                                            color: Colors.red,
                                          ),
                                      ],
                                    ),
                                  ),
                                  
                                  // ID suffix and model
                                  Padding(
                                    padding: const EdgeInsets.only(right: 16.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          idSuffix,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          device.soncaName, // Model is usually the name
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                ),
                
                // Connect Button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton(
                    onPressed: _focusedDevice == null
                        ? null
                        : () async {
                            if (viewModel.isConnecting) return;
                            try {
                              await viewModel.connectToDevice(_focusedDevice!);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Kết nối thất bại')),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.red.withOpacity(0.5),
                      disabledForegroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: viewModel.isConnecting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Connect',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
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
