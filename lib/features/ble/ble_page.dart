import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/widgets/app_scaffold.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';

import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_constants.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_service.dart';
import 'package:mixer_sonca/features/ble/protocol/models/protocol_definition.dart';
import 'package:mixer_sonca/features/ble/protocol/dynamic_command_builder.dart';
import 'package:mixer_sonca/features/ble/widgets/mixer_slider.dart';
import 'package:mixer_sonca/injection.dart';
class BlePage extends StatefulWidget {
  const BlePage({super.key});

  @override
  State<BlePage> createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  bool _isDropdownOpen = false;
  String? _currentOverlayArea;

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
          Container(color: Colors.black),

          // Main Content Layers
          Column(
            children: [
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    // Area 1 (Mixed Sliders) - Left Side
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(left: 10, right: 5, bottom: 5),
                        child: Consumer<BleViewModel>(builder: (context, viewModel, child) {
                          final section = getIt<MixerService>().getItemsForSection("Area 1");
                          
                          if (section != null) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: section.items.values.map((item) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: _buildDynamicControl(context, item, viewModel),
                                  );
                                }).toList(),
                              ),
                            );
                          }
                          return const Center(child: Text("Area 1 empty", style: TextStyle(color: Colors.white24)));
                        }),
                      ),
                    ),

                    // Area 2 (Selection Area) - Right Side
                    Container(
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
                                       child: Text("Loading Area 2...", style: TextStyle(color: Colors.white54)),
                                     );
                                  }
                             }),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold, 
                          color: Colors.greenAccent,
                        ),
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
                        : Icon(
                            Icons.bluetooth_searching, 
                            color: viewModel.selectedDevice != null ? Colors.greenAccent : Colors.white
                          ),
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

          // Overlay Layer
          if (_currentOverlayArea != null)
            _buildOverlayArea(context, viewModel),
        ],
      ),
      // Disable default FAB
      floatingActionButton: null, 
    );
  }

  Widget _buildDynamicControl(BuildContext context, DisplayItem item, BleViewModel viewModel) {
    // 1. Radio Group
    final stateKey = "${item.command}_${item.paramName ?? ''}";

    // 1. Radio Group
    if (item.control.isRadio) {
      final rawValue = viewModel.getControlValue(stateKey, defaultValue: null);
      final currentValue = _getMappedDisplayValue(item, rawValue);

      return Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Label "Ngõ vào" on left
          children: [
            GestureDetector(
              onTap: item.event?.click != null 
                ? () => setState(() => _currentOverlayArea = item.event!.click)
                : null,
              child: Text(
                item.label, 
                style: TextStyle(
                  color: Colors.white, 
                  fontStyle: item.event?.click != null ? FontStyle.italic : FontStyle.normal,
                  decoration: item.event?.click != null ? TextDecoration.underline : TextDecoration.none,
                  fontWeight: FontWeight.bold, 
                  fontSize: 16
                )
              ),
            ),
            const SizedBox(height: 4),
            // Align options to the right
            Align(
              alignment: Alignment.centerRight,
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: item.control.options.map((option) {
                    final isSelected = currentValue == option.value;
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
                              style: TextStyle(
                                color: isSelected ? Colors.greenAccent : Colors.white, 
                                fontSize: 18
                              ),
                            ),
                          ),
                          Radio<String>(
                            value: option.value,
                            groupValue: currentValue,
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
      final isSwitchedOn = viewModel.getControlValue(stateKey, defaultValue: 0) == 1;

       return Padding(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: item.event?.click != null 
                ? () => setState(() => _currentOverlayArea = item.event!.click)
                : null,
              child: Text(
                item.label, 
                style: TextStyle(
                  color: Colors.white, 
                  fontStyle: item.event?.click != null ? FontStyle.italic : FontStyle.normal,
                  decoration: item.event?.click != null ? TextDecoration.underline : TextDecoration.none,
                  fontWeight: FontWeight.bold
                )
              ),
            ),
            Switch(
              value: isSwitchedOn,
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
    // 3. Vertical Slider (Mixer Style)
    else if (item.control.isVerticalSlider) {
      // For mixer sliders, we look for _mute and _volume in indexList
      // If indexList is empty, we fallback to item.paramName (no mute)
      String? muteParam;
      String? volumeParam;
      
      if (item.indexList.isNotEmpty) {
        for (final p in item.indexList) {
          if (p.endsWith('_mute')) muteParam = p;
          if (p.endsWith('_volume')) volumeParam = p;
        }
      } else {
        volumeParam = item.paramName;
      }

      final volumeStateKey = "${item.command}_${volumeParam ?? ''}";
      final muteStateKey = muteParam != null ? "${item.command}_$muteParam" : null;

      final volumeValue = (volumeParam != null) 
          ? viewModel.getControlValue(volumeStateKey, defaultValue: 50).toDouble() 
          : 50.0;
      final isMuted = (muteParam != null) 
          ? viewModel.getControlValue(muteStateKey!, defaultValue: 0) == 1 
          : false;
      
      return MixerSlider(
        label: item.label,
        value: volumeValue,
        isMuted: isMuted,
        showMute: muteParam != null,
        min: item.control.minValue,
        max: item.control.maxValue,
        onLabelTap: item.event?.click != null 
          ? () => setState(() => _currentOverlayArea = item.event!.click)
          : null,
        onChanged: (val) {
          if (volumeParam != null) {
            _handleDynamicControlChange(item, val.toInt(), viewModel, paramOverride: volumeParam);
          }
        },
        onMuteChanged: (muted) {
          if (muteParam != null) {
            _handleDynamicControlChange(item, muted ? 1 : 0, viewModel, paramOverride: muteParam);
          }
        },
      );
    }
    
    // Default fallback
    return ListTile(
      title: Text(item.label, style: const TextStyle(color: Colors.white)),
      subtitle: Text('Unknown type: ${item.control.typeDisplay}', style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildOverlayArea(BuildContext context, BleViewModel viewModel) {
      return Container(
        color: Colors.black.withOpacity(0.95), // Deep dark overlay
        child: Stack(
          children: [
            // Left Content (Same width as Area 1)
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              right: MediaQuery.of(context).size.width * (Platform.isIOS ? 0.35 : 0.28) + 5, // Leave right part empty (Area 2 width + margin)
              child: Consumer<BleViewModel>(builder: (context, viewModel, child) {
                  final section = getIt<MixerService>().getItemsForSection(_currentOverlayArea!);
                  
                  if (section != null) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: section.items.values.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _buildDynamicControl(context, item, viewModel),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }
                  return const Center(child: Text("Area not found", style: TextStyle(color: Colors.white24)));
              }),
            ),

            // Home Icon (Bottom Right)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () => setState(() => _currentOverlayArea = null),
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.white24, width: 1),
                ),
                child: const Icon(Icons.home, color: Colors.white),
              ),
            ),
          ],
        ),
      );
  }

  Future<void> _handleDynamicControlChange(DisplayItem item, dynamic value, BleViewModel viewModel, {String? paramOverride}) async {
      final protocolService = getIt<ProtocolService>();
      final paramName = paramOverride ?? item.paramName ?? '';
      
      if (paramName.isEmpty) return;

      // 1. Find Command Definition
      CommandDefinition? cmdDef;
      
      if (item.command.isNotEmpty) {
        cmdDef = protocolService.getCommandByName(item.category, item.command);
      }
      
      // Fallback search by parameter name (less precise)
      cmdDef ??= protocolService.findCommand(item.category, paramName);
      
      if (cmdDef == null) {
        debugPrint('Error: Could not find command for category ${item.category} and param $paramName (Cmd: ${item.command})');
        return;
      }

      // Update Local State in ViewModel immediately for visual feedback
      final stateKey = "${item.command}_$paramName";
      viewModel.updateControlValue(stateKey, value);
      
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
      
      debugPrint('\nUI Change: ${item.label} ($paramName) -> $finalValue (Cmd: ${item.category}.${cmdDef.name})');

      if (viewModel.selectedDevice == null) {
        ScaffoldMessenger.of(context).clearSnackBars();
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
            paramName: finalValue
          },
        );
        
        await viewModel.sendProtocolCommand(command);
        
      } catch (e) {
        debugPrint('Error sending dynamic command: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
  }

  /// Helper to map raw protocol values (integers) to UI display strings.
  /// Also handles default values (e.g., Bluetooth if 0).
  String? _getMappedDisplayValue(DisplayItem item, dynamic rawValue) {
    if (item.control.isRadio) {
      final protocolService = getIt<ProtocolService>();
      final paramName = item.paramName ?? '';
      
      // 1. Find Command Definition to get the valueMap
      CommandDefinition? cmdDef;
      if (item.command.isNotEmpty) {
        cmdDef = protocolService.getCommandByName(item.category, item.command);
      }
      cmdDef ??= protocolService.findCommand(item.category, paramName);

      if (cmdDef != null && cmdDef.valueMap != null) {
        // Find string value in map: { "1": "Bluetooth", "2": "LineIn" ... }
        final mappedValue = cmdDef.valueMap![rawValue?.toString()];
        if (mappedValue != null) return mappedValue;
      }

      // 2. Defaulting Logic
      // If rawValue is 0, null, or not in map, try to default to 'Bluetooth' 
      // if it exists in the radio options for this item.
      if (rawValue == 0 || rawValue == null || (rawValue is String && rawValue.isEmpty)) {
         for (var option in item.control.options) {
            if (option.value.toLowerCase() == 'bluetooth') {
               return option.value;
            }
         }
      }

      // 3. Fallback to first option if still not determined
      return item.control.options.firstOrNull?.value;
    }
    
    // For other controls, return as is (stringified)
    return rawValue?.toString();
  }

}
