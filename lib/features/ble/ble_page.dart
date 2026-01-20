import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/widgets/app_scaffold.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';

import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_constants.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_service.dart';
import 'package:mixer_sonca/features/ble/protocol/dynamic_command_builder.dart';
import 'package:mixer_sonca/injection.dart';

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
          // Main Content Layer
          // Main Content removed
          Container(color: Colors.black),

          // Scrollable Area 2 (moved to background layer, using Column for relative positioning)
          Column(
            children: [
              SizedBox(height: 40), // Reserve space for Fixed Header
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: MediaQuery.of(context).size.width * (Platform.isIOS ? 0.35 : 0.28),
                    margin: const EdgeInsets.only(right: 5, bottom: 5),
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
                      border: Border.all(color: Colors.transparent, width: 0.5),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                           // Dynamic Content from JSON
                           Consumer<BleViewModel>(builder: (context, viewModel, child) {
                                final section = getIt<MixerService>().getItemsForSection("Area 2");
                                
                                if (section != null) {
                                   return Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                        ...section.items.values.map((item) => _buildDynamicControl(context, item, viewModel)).toList(),
                                     ],
                                   );
                                } else {
                                   return const Padding(
                                     padding: EdgeInsets.all(8.0),
                                     child: Text("Loading controls...", style: TextStyle(color: Colors.white54)),
                                   );
                                }
                           }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Fixed Header: Bluetooth Button and Dropdown (Top Right) - MOVED TO END FOR Z-INDEX
          Positioned(
            top: 7,
            right: 7,
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                      )
                    else
                      Text(
                        viewModel.selectedDevice!.soncaName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      onPressed: _toggleScan,
                      backgroundColor: viewModel.isScanning ? Colors.grey : Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.white24, width: 1),
                      ),
                      child: viewModel.isScanning 
                        ? const SizedBox(
                            width: 24, 
                            height: 24, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          )
                        : const Icon(Icons.bluetooth_searching, color: Colors.white),
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
                      color: Colors.grey[900], // Dark background for dropdown
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: Colors.white24, width: 0.5),
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
                        const Divider(height: 1, color: Colors.white24),
                        
                        // Device List
                        if (viewModel.devices.isEmpty && !viewModel.isScanning)
                          ListTile(
                            title: const Text('Không tìm thấy thiết bị', style: TextStyle(color: Colors.white70)),
                            trailing: IconButton(
                              icon: const Icon(Icons.refresh, color: Colors.blueAccent),
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
                              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
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
                                    color: Colors.transparent, 
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
                                              decoration: BoxDecoration(
                                                color: (viewModel.selectedDevice?.id == device.id) 
                                                    ? Colors.red.shade900 
                                                    : (viewModel.connectingDeviceId == device.id) 
                                                        ? Colors.orange.shade900 
                                                        : Colors.blueGrey.shade800,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
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


        ],
      ),
      // Disable default FAB
      floatingActionButton: null, 
    );
  }

  Widget _buildDynamicControl(BuildContext context, DisplayItem item, BleViewModel viewModel) {
    // 1. Radio Group
    if (item.control.isRadio) {
      // Find current selected value - for now we don't have bi-directional sync fully set up for reading values back 
      // from device state easily without a more complex state management.
      // We will just use a local state or visual indication for now.
      
      return Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Label "Ngõ vào" on left
          children: [
            Text(item.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            // Align options to the right
            Align(
              alignment: Alignment.centerRight,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: item.control.options.map((option) {
                    return InkWell(
                      onTap: () {
                         _handleDynamicControlChange(item, option.value, viewModel);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Text(
                              option.label, 
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                          Radio<String>(
                            value: option.value,
                            groupValue: null, // TODO: Bind state
                            onChanged: (val) {
                               if (val != null) {
                                 _handleDynamicControlChange(item, val, viewModel);
                               }
                            },
                            activeColor: Colors.greenAccent,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    } 
    // 2. Switch Button
    else if (item.control.isSwitch) {
       return Padding(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Switch(
              value: false, // TODO: Bind to actual state
              activeColor: Colors.white,
              activeTrackColor: Colors.greenAccent,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (val) {
                 _handleDynamicControlChange(item, val ? 1 : 0, viewModel);
              },
            ),
          ],
        ),
      );
    }
    
    // Default fallback
    return ListTile(
      title: Text(item.label, style: const TextStyle(color: Colors.white)),
      subtitle: Text('Unknown type: ${item.control.typeDisplay}', style: const TextStyle(color: Colors.grey)),
    );
  }

  Future<void> _handleDynamicControlChange(DisplayItem item, dynamic value, BleViewModel viewModel) async {
      final protocolService = getIt<ProtocolService>();
      
      // 1. Find Command ID from Category + Parameter Name
      final cmdDef = protocolService.findCommand(item.category, item.paramName);
      
      if (cmdDef == null) {
        debugPrint('Error: Could not find command for category ${item.category} and param ${item.paramName}');
        return;
      }
      
      // 2. Build parameter map & Resolve Value
      dynamic finalValue = value;
      // Special handling for Radio options that might need value mapping (String -> ID)
      if (item.control.isRadio && value is String) {
         if (cmdDef.valueMap != null) {
            for (var entry in cmdDef.valueMap!.entries) {
               if (entry.value.toString().toLowerCase() == value.toString().toLowerCase()) {
                  finalValue = int.tryParse(entry.key); // "2" -> 2
                  break;
               }
            }
         }
      }
      
      debugPrint('\nUI Change: ${item.label} -> $finalValue (Cmd: ${item.category}.${item.paramName})');

      if (viewModel.selectedDevice == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            // Center vertically using bottom margin
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height / 2 - 50,
            ),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  child: const Text(
                    "Vui lòng kết nối thiết bị",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }

      try {
        final builder = getIt<DynamicCommandBuilder>();
        final command = builder.buildCommand(
          categoryName: item.category,
          cmdId: cmdDef.id,
          operation: CommandOperation.set,
          parameters: {
             item.paramName: finalValue
          },
        );
        
        await viewModel.sendProtocolCommand(command);
        
      } catch (e) {
        debugPrint('Error sending dynamic command: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
  }

}
