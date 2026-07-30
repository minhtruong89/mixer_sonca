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
  static const bool flagDebugDetailsScan = false;

  @override
  void initState() {
    super.initState();
    // Auto start scanning when entering this page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleViewModel>().scanDevices();
    });
  }

  String _formatManufacturerData(Map<int, List<int>> mData) {
    if (mData.isEmpty) return "None";
    final buffer = StringBuffer();
    mData.forEach((key, bytes) {
      final hexKey = "0x${key.toRadixString(16).padLeft(4, '0').toUpperCase()}";
      final hexBytes = bytes.map((b) => "0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}").join(" ");
      buffer.write("$hexKey: [$hexBytes] ");
    });
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();
    final devices = viewModel.devices;

    return SafeArea(
      child: Stack(
        children: [
          // Top Bar Actions (Refresh button & Settings)
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: viewModel.isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, color: Colors.white, size: 26),
                  onPressed: viewModel.isScanning
                      ? null
                      : () {
                          viewModel.scanDevices();
                        },
                ),
                IconButton(
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
              ],
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
                        separatorBuilder: (context, index) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          final isSelected = _focusedDevice?.id == device.id;
                          
                          // Extract last 4 clean hex chars of MAC address for the suffix (e.g. F3D6)
                          String cleanedId = device.id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
                          String idSuffix = "";
                          if (cleanedId.length >= 4) {
                            idSuffix = cleanedId.substring(cleanedId.length - 4).toUpperCase();
                          } else {
                            idSuffix = cleanedId.toUpperCase();
                          }

                          final modelDisplayName = device.identity?.productionName?.isNotEmpty == true
                              ? device.identity!.productionName!
                              : device.soncaName;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_focusedDevice?.id == device.id) {
                                      _focusedDevice = null;
                                    } else {
                                      _focusedDevice = device;
                                    }
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
                                      
                                      // ID suffix and Production Name
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
                                              modelDisplayName,
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
                              ),
                              
                              // Details Box (displayed when device is selected / focused)
                              if (isSelected)
                                Container(
                                  margin: const EdgeInsets.only(top: 4.0),
                                  padding: const EdgeInsets.all(10.0),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[950],
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.grey[850]!, width: 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "DETAILS:",
                                        style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                                      ),
                                      const SizedBox(height: 4),
                                      if(flagDebugDetailsScan)...[
                                        Text("• ID / MAC: ${device.id}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• Adv Name: ${device.name.isNotEmpty ? device.name : 'N/A'}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• Sonca Model: ${device.soncaName}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• RSSI: ${device.rssi} dBm | TxPower: ${device.txPower} | Connectable: ${device.isConnectable}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• Service UUIDs: ${device.serviceUuids.isNotEmpty ? device.serviceUuids.join(', ') : 'None'}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• Mfgr Data: ${_formatManufacturerData(device.manufacturerData)}", style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace')),
                                      ],
                                      if (device.identity != null) ...[
                                        Text("• Identity Company ID: ${device.identity!.companyId} (0x${device.identity!.companyId.toRadixString(16).toUpperCase()})", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• Production Model: ${device.identity!.productionModel}", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• Production Name: ${device.identity!.productionName ?? 'N/A'}", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• UI Version: ${device.identity!.uiVersion}", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• FW Version: ${device.identity!.fwVersion}", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                        Text("• Build At: ${device.identity!.buildAtFormatted} (${device.identity!.buildAt})", style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
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
