import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/widgets/app_scaffold.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';

class BlePage extends StatefulWidget {
  const BlePage({super.key});

  @override
  State<BlePage> createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    // Initialize listener on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleViewModel>().init();
    });
  }

  void _toggleScan() {
    final viewModel = context.read<BleViewModel>();
    
    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });

    if (_isDropdownOpen) {
      // Start scanning when opening
      viewModel.scanDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();

    return AppScaffold(
      title: 'BLE Scanner',
      // We use a Stack to float our custom UI over the main content
      body: Stack(
        children: [
          // Main Content Layer
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (viewModel.selectedDevice == null)
                  Text(
                    'Chưa kết nối',
                    style: Theme.of(context).textTheme.headlineSmall,
                  )
                else ...[
                  Text(
                    'Đã kết nối',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    viewModel.selectedDevice!.soncaName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(viewModel.selectedDevice!.id),
                ],
              ],
            ),
          ),

          // Custom "Floating" UI Layer (Top Right)
          Positioned(
            top: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // The Action Button
                FloatingActionButton(
                  onPressed: _toggleScan,
                  backgroundColor: viewModel.isScanning ? Colors.grey : Colors.blue,
                  child: viewModel.isScanning 
                    ? const SizedBox(
                        width: 24, 
                        height: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : const Icon(Icons.bluetooth_searching),
                ),
                
                // The Dropdown List (Visible only when open)
                if (_isDropdownOpen) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: 350,
                    constraints: const BoxConstraints(maxHeight: 500),
                    decoration: BoxDecoration(
                      color: Colors.black, // Dark background for the whole list container
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        ListTile(
                          dense: true,
                          title: Text(
                             viewModel.isScanning ? 'Scanning...' : 'Devices Found',
                             style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.close, size: 20, color: Colors.white),
                            onPressed: () => setState(() => _isDropdownOpen = false),
                          ),
                        ),
                        const Divider(height: 1, color: Colors.grey),
                        
                        // Device List
                        if (viewModel.devices.isEmpty && !viewModel.isScanning)
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('Không tìm thấy thiết bị'),
                          )
                        else
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 440),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: viewModel.devices.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
                              itemBuilder: (context, index) {
                                final device = viewModel.devices[index];
                                final mfgData = device.manufacturerData.entries.map((e) => "ID: <0x${e.key.toRadixString(16).padLeft(4, '0')}> 0x${e.value.map((v) => v.toRadixString(16).padLeft(2, '0')).join('').toUpperCase()}").join('\n');
                                
                                return InkWell(
                                  onTap: () {
                                    if (viewModel.isConnecting) return;
                                    
                                    if (viewModel.selectedDevice?.id == device.id) {
                                      viewModel.disconnectDevice();
                                    } else {
                                      viewModel.connectToDevice(device);
                                    }
                                    setState(() => _isDropdownOpen = false);
                                  },
                                  child: Container(
                                    color: Colors.black87, // Dark background like the picture
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            // Icon
                                            const CircleAvatar(
                                              backgroundColor: Colors.blueGrey,
                                              radius: 16,
                                              child: Icon(Icons.bluetooth, color: Colors.white, size: 16),
                                            ),
                                            const SizedBox(width: 10),
                                            // Name and ID
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    device.soncaName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                                                  ),
                                                  Text(
                                                    device.id,
                                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Action Button
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              color: (viewModel.selectedDevice?.id == device.id) 
                                                  ? Colors.red.shade900 
                                                  : (viewModel.connectingDeviceId == device.id) 
                                                      ? Colors.orange.shade900 
                                                      : Colors.blueGrey.shade800,
                                              child: viewModel.connectingDeviceId == device.id
                                                ? const SizedBox(
                                                    width: 12, height: 12, 
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                                                  )
                                                : Text(
                                                    (viewModel.selectedDevice?.id == device.id) ? 'DISCONNECT' : 'CONNECT',
                                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                                  ),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              (viewModel.selectedDevice?.id == device.id) ? "CONNECTED" : (device.isConnectable ? "CONNECTABLE" : "NOT CONNECTABLE"),
                                              style: TextStyle(
                                                color: (viewModel.selectedDevice?.id == device.id) ? Colors.greenAccent : Colors.white70, 
                                                fontSize: 12,
                                                fontWeight: (viewModel.selectedDevice?.id == device.id) ? FontWeight.bold : FontWeight.normal
                                              ),
                                            ),
                                            const Spacer(),
                                            Icon(Icons.signal_cellular_alt, color: Colors.grey.shade400, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${device.rssi} dBm",
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        if (mfgData.isNotEmpty) ...[
                                           const SizedBox(height: 8),
                                           Text(
                                            "Manufacturer Data:",
                                            style: TextStyle(color: Colors.blue.shade200, fontSize: 12),
                                           ),
                                           Text(
                                            mfgData,
                                            style: const TextStyle(color: Colors.white60, fontSize: 11, fontFamily: 'monospace'),
                                           ),
                                        ],
                                        if (device.serviceUuids.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              "Service UUIDs: ${device.serviceUuids.join(', ')}",
                                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ]
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      // Disable default FAB
      floatingActionButton: null, 
    );
  }
}
