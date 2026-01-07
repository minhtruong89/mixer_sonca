import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/widgets/app_scaffold.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/core/models/mixer_define.dart';

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
      title: '',
      // We use a Stack to float our custom UI over the main content
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main Content Layer
          // Main Content removed
          const SizedBox.shrink(),

          // Fixed Header: Bluetooth Button and Dropdown (Top Right)
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status and Action Button Row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (viewModel.selectedDevice == null)
                      Text(
                        'Chưa kết nối',
                        style: Theme.of(context).textTheme.titleMedium,
                      )
                    else
                      Text(
                        viewModel.selectedDevice!.soncaName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(width: 16),
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
                  ],
                ),
                
                // The Dropdown List (Visible only when open)
                if (_isDropdownOpen) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: MediaQuery.of(context).size.width * (Platform.isIOS ? 0.4 : 0.31),
                    constraints: const BoxConstraints(maxHeight: 500),
                    decoration: BoxDecoration(
                      color: Colors.black,
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
                          ListTile(
                            title: const Text('Không tìm thấy thiết bị', style: TextStyle(color: Colors.white)),
                            trailing: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.blue),
                              onPressed: () => viewModel.scanDevices(),
                            ),
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
                                    color: Colors.black87,
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const CircleAvatar(
                                              backgroundColor: Colors.blueGrey,
                                              radius: 16,
                                              child: Icon(Icons.bluetooth, color: Colors.white, size: 16),
                                            ),
                                            const SizedBox(width: 10),
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

          // Scrollable Mixer Area (Below the button)
          if (!_isDropdownOpen && viewModel.displayMixerCurrent.isNotEmpty)
            Positioned(
              top: 75, // Below the button
              right: 5,
              bottom: 5,
              child: Container(
                width: MediaQuery.of(context).size.width * (Platform.isIOS ? 0.35 : 0.28),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Builder(
                        builder: (context) {
                          debugPrint('BlePage: Rendering ${viewModel.displayMixerCurrent.length} mixer items');
                          for (var item in viewModel.displayMixerCurrent) {
                            debugPrint('  - ${item.name} (children: ${item.children.length}, displayType: ${item.displayType})');
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      // We iterate through the GLOBAL children
                      for (var item in viewModel.displayMixerCurrent) 
                        if (item.children.isNotEmpty)
                          // Group (like INPUT_LINE)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    "${item.name} ", 
                                    style: const TextStyle(color: Colors.white, fontSize: 16)
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: item.children.map((child) => _buildMixerItem(context, child, viewModel)).toList(),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          // Simple item (like MIC_FBX)
                          _buildMixerItem(context, item, viewModel),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      // Disable default FAB
      floatingActionButton: null, 
    );
  }

  Widget _buildMixerItem(BuildContext context, MixerDefine item, BleViewModel viewModel) {
    return InkWell(
      onTap: () {
        if (item.displayType == 1) {
          // Radio button - need to handle mutual exclusion
          // For now, just toggle
          viewModel.toggleMixerItem(item);
        } else {
          viewModel.toggleMixerItem(item);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              item.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            if (item.displayType == 1) 
              // Radio button
              Icon(
                item.itemValue == 1 ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: item.itemValue == 1 ? Colors.greenAccent : Colors.grey,
                size: 28,
              )
            else if (item.displayType == 2)
              // Switch button
              Transform.scale(
                scale: 0.9,
                child: Switch(
                  value: item.itemValue == 1,
                  activeColor: Colors.white,
                  activeTrackColor: Colors.greenAccent,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey,
                  onChanged: (val) {
                    viewModel.setMixerItemValue(item, val ? 1 : 0);
                  },
                ),
              )
            else
              // Type 0 or other - show value
              Text(
                "[${item.itemValue}]", 
                style: const TextStyle(color: Colors.grey, fontSize: 14)
              ),
          ],
        ),
      ),
    );
  }
}
