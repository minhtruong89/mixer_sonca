import 'dart:io';
import 'dart:async';
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
import 'package:mixer_sonca/features/ble/widgets/eq_band_slider.dart';
import 'package:mixer_sonca/features/ble/widgets/eq_band_dialog.dart';
import 'package:mixer_sonca/injection.dart';

class BlePage extends StatefulWidget {
  const BlePage({super.key});

  @override
  State<BlePage> createState() => _BlePageState();
}

class _BlePageState extends State<BlePage> {
  bool _isDropdownOpen = false;
  String? _currentOverlayArea;
  
  // Debouncers for slider updates to reduce BLE traffic
  final Map<String, Timer?> _debouncers = {};

  @override
  void initState() {
    super.initState();
    // Initialize listener on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BleViewModel>().init();
    });
  }

  @override
  void dispose() {
    for (var timer in _debouncers.values) {
      timer?.cancel();
    }
    _debouncers.clear();
    super.dispose();
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
      resizeToAvoidBottomInset: false,
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
                        margin: const EdgeInsets.only(left: 10, right: 5, bottom: 20),
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
                      margin: const EdgeInsets.only(right: 5, bottom: 20),
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
                        padding: const EdgeInsets.only(top: 40, left: 12, right: 12, bottom: 12),
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
                ? () => _navigateToArea(item.event!.click)
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
              child: IntWidthWrapper(
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
    // 2. Dropdown List
    else if (item.control.isDropdown) {
      final rawValue = viewModel.getControlValue(stateKey, defaultValue: null);
      final currentValue = _getMappedDisplayValue(item, rawValue);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: item.event?.click != null 
                ? () => _navigateToArea(item.event!.click)
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
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: currentValue,
                  isExpanded: true,
                  dropdownColor: Colors.grey[900],
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  items: item.control.options.map((option) {
                    return DropdownMenuItem<String>(
                      value: option.value,
                      child: Text(
                        option.label,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      _handleDynamicControlChange(item, val, viewModel);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }
    // 3. Normal Button
    else if (item.control.isNormalButton) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
               _handleDynamicControlChange(item, 1, viewModel);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              item.label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }
    // 4. Switch Button
    else if (item.control.isSwitch) {
      final isSwitchedOn = viewModel.getControlValue(stateKey, defaultValue: 0) == 1;

       return Padding(
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: item.event?.click != null 
                  ? () => _navigateToArea(item.event!.click)
                  : null,
                child: Text(
                  item.label, 
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white, 
                    fontStyle: item.event?.click != null ? FontStyle.italic : FontStyle.normal,
                    decoration: item.event?.click != null ? TextDecoration.underline : TextDecoration.none,
                    fontWeight: FontWeight.bold
                  )
                ),
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
    // 5. Vertical Slider (Mixer Style)
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
          ? () => _navigateToArea(item.event!.click)
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
      final section = getIt<MixerService>().getItemsForSection(_currentOverlayArea!);
      
      if (section == null) {
          return const SizedBox.shrink();
      }

      if (section.areaFormat == "EQ Area") {
          return Container(
               color: Colors.black.withOpacity(0.95),
               child: Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                   children: [
                       // Top bar with Back Button and Name
                       Padding(
                           padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 2),
                           child: Row(
                               children: [
                                   IconButton(
                                       icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                                       onPressed: () {
                                           if (section.backArea != null && section.backArea != "Area MAIN") {
                                               _navigateToArea(section.backArea);
                                           } else {
                                               _navigateToArea(null);
                                           }
                                       }
                                   ),
                                   const SizedBox(width: 8),
                                   Expanded(
                                       child: Text(
                                           section.description, 
                                           overflow: TextOverflow.ellipsis,
                                           style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                                       ),
                                   ),
                               ]
                           )
                       ),
                       // Full width sliders
                       Expanded(
                           child: _buildEqSliders(context, section, viewModel),
                       )
                   ]
               )
           );
      }

      return Container(
        color: Colors.black.withOpacity(0.95), // Deep dark overlay
        child: Stack(
          children: [
            // Left Content (Scrollable Sliders)
            Positioned(
              left: 0,
              top: 10,
              bottom: 20,
              right: MediaQuery.of(context).size.width * (Platform.isIOS ? 0.24 : 0.17) + 5,
              child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10),
                 child: SingleChildScrollView(
                   scrollDirection: Axis.horizontal,
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: section.items.values
                        .where((item) => !item.control.isSwitch)
                        .map((item) {
                       return Padding(
                         padding: const EdgeInsets.only(right: 12),
                         child: _buildDynamicControl(context, item, viewModel),
                       );
                     }).toList(),
                   ),
                 ),
               ),
            ),

            // Right Side Content (Switches & Navigation Buttons)
            Positioned(
              top: 10,
              right: 10,
              width: MediaQuery.of(context).size.width * (Platform.isIOS ? 0.24 : 0.17) - 10,
              child: Builder(builder: (context) {
                    final switches = section.items.values.where((item) => item.control.isSwitch).toList();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Switches moved from the left list
                        ...switches.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 12.0, right: 10.0),
                              child: _buildDynamicControl(context, item, viewModel),
                            )),

                        if (switches.isNotEmpty && section.buttons.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12.0, right: 10.0),
                            child: Divider(color: Colors.white24, height: 1),
                          ),

                        // Navigation Buttons
                        ...section.buttons.values.map((btn) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0, right: 10.0),
                            child: InkWell(
                              onTap: () {
                                 if (btn.event?.click != null) {
                                    _navigateToArea(btn.event!.click);
                                 }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        btn.label,
                                        textAlign: TextAlign.right,
                                        softWrap: true,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.tune,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
              }),
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: () => _navigateToArea(null),
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.white24, width: 1),
                    ),
                    child: const Icon(Icons.home, color: Colors.white),
                  ),
                  if (viewModel.selectedDevice != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      viewModel.selectedDevice!.soncaName,
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
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
      // Special handling for Radio/Dropdown options that might need value mapping (String -> ID)
      if ((item.control.isRadio || item.control.isDropdown) && value is String) {
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
        _showCenterSnackBar("Vui lòng kết nối thiết bị");
        return;
      }

      // Debounce the BLE command sending
      _debouncers[stateKey]?.cancel();
      final cmdId = cmdDef.id; // Capture for closure safety
      _debouncers[stateKey] = Timer(const Duration(milliseconds: 50), () async {
        try {
          final builder = getIt<DynamicCommandBuilder>();
          final command = builder.buildCommand(
            categoryName: item.category,
            cmdId: cmdId,
            operation: CommandOperation.set,
            parameters: {
              paramName: finalValue
            },
          );
          
          await viewModel.sendProtocolCommand(command);
          
        } catch (e) {
          debugPrint('Error sending dynamic command: $e');
        }
      });
  }

  /// Helper to map raw protocol values (integers) to UI display strings.
  /// Also handles default values (e.g., Bluetooth if 0).
  String? _getMappedDisplayValue(DisplayItem item, dynamic rawValue) {
    if (item.control.isRadio || item.control.isDropdown) {
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

  Widget _buildEqSliders(BuildContext context, DisplaySection section, BleViewModel viewModel) {
     final totalBands = section.totalEQBand ?? 10;
     final commandName = section.command ?? '';
     
     // default parsing from control
     final defaultTypeEnum = int.tryParse(section.control?.rawConfig['type']?.toString() ?? '0') ?? 0;
     final defaultF0 = section.control?.rawConfig['f0']?.toString() ?? '0';
     final defaultQ = int.tryParse(section.control?.rawConfig['Q']?.toString() ?? '0') ?? 0;
     final minGain = double.tryParse(section.control?.rawConfig['minGain']?.toString() ?? '-6.0') ?? -6.0;
     final maxGain = double.tryParse(section.control?.rawConfig['maxGain']?.toString() ?? '6.0') ?? 6.0;

     // Calculate Q in double from Q6.10
     final double qValue = defaultQ / 1024.0;
     
     final protocolService = getIt<ProtocolService>();
     String categoryName = '';
     for (var cat in protocolService.definition?.categories.values ?? <CategoryDefinition>[]) {
       if (cat.getCommandByName(commandName) != null) {
          categoryName = cat.name;
          break;
       }
     }
     
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 10),
       child: SingleChildScrollView(
         scrollDirection: Axis.horizontal,
         child: Row(
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: List.generate(totalBands, (index) {
              
              final stateKey = "${commandName}_band${index}_gain";
              
              // Raw gain from BLE is int16 (Q8.8). 0 = 0.0, 256 = 1.0, -256 = -1.0
              final rawGain = viewModel.getControlValue(stateKey, defaultValue: 0);
              double currentGain;
              if (rawGain is int) {
                 currentGain = rawGain / 256.0;
              } else if (rawGain is double) {
                 currentGain = rawGain;
              } else {
                 currentGain = 0.0;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Builder(
                  builder: (context) {
                    String bandF0Value = defaultF0;
                    if (section.bandF0 != null && index < section.bandF0!.length) {
                      bandF0Value = section.bandF0![index];
                    }

                    int baseF0 = int.tryParse(bandF0Value) ?? 0;
                    final rawF0 = viewModel.getControlValue("${commandName}_band${index}_f0", defaultValue: baseF0);
                    int currentF0 = (rawF0 is int) ? rawF0 : baseF0;

                    final rawQ = viewModel.getControlValue("${commandName}_band${index}_Q", defaultValue: defaultQ);
                    double currentQ = (rawQ is int) ? (rawQ / 1024.0) : qValue;

                    final rawType = viewModel.getControlValue("${commandName}_band${index}_type", defaultValue: defaultTypeEnum);
                    int currentType = (rawType is int) ? rawType : defaultTypeEnum;

                    String displayF0Text = "${currentF0}Hz";
                    if (currentF0 >= 1000 && currentF0 % 1000 == 0) {
                       displayF0Text = "${currentF0 ~/ 1000}KHz";
                    }

                    // Prepare filter types array for the dialog
                    Map<String, int> filterTypes = {};
                    if (protocolService.isLoaded && protocolService.definition != null) {
                       for (var entry in protocolService.definition!.eqFilterTypes.entries) {
                          filterTypes[entry.key] = entry.value.value;
                       }
                    }

                    return EqBandSlider(
                      bandIndex: index,
                      f0Text: displayF0Text,
                  qText: currentQ.toStringAsFixed(1),
                  gainText: "${currentGain > 0 ? '+' : ''}${currentGain.toStringAsFixed(1)}dB",
                  gain: currentGain,
                  minGain: minGain,
                  maxGain: maxGain,
                  filterType: currentType,
                  onHeaderTapped: () async {
                    final result = await showDialog<Map<String, dynamic>>(
                      context: context,
                      builder: (ctx) => EqBandDialog(
                        bandIndex: index,
                        initialGain: currentGain,
                        initialFreq: currentF0,
                        initialQ: currentQ,
                        initialType: currentType,
                        filterTypes: filterTypes,
                      ),
                    );

                    if (result != null) {
                      _handleEqBandMultipleChange(categoryName, commandName, index, result, viewModel);
                    }
                  },
                  onGainChanged: (val) {
                     _handleEqBandChange(categoryName, commandName, index, 'gain', val, viewModel);
                  },
                );
                  },
                ),
              );
           }).toList(),
         ),
       ),
     );
  }

  Future<void> _handleEqBandChange(String categoryName, String commandName, int band, String fieldParam, double value, BleViewModel viewModel) async {
    if (categoryName.isEmpty || commandName.isEmpty) return;

    debugPrint('\n_handleEqBandChange');
    
    final stateKey = "${commandName}_band${band}_$fieldParam";
    
    int rawValue = 0;
    if (fieldParam == 'gain') {
       rawValue = (value * 256.0).round();
    }
    
    viewModel.updateControlValue(stateKey, rawValue);

    debugPrint('\nEQ Change: Band $band - $fieldParam -> $rawValue (Cmd: $categoryName.$commandName)');

    if (viewModel.selectedDevice == null) {
      _showCenterSnackBar("Vui lòng kết nối thiết bị");
      return; 
    }

    // Debounce the BLE command sending
    _debouncers[stateKey]?.cancel();
    
    final protocolService = getIt<ProtocolService>();
    final cmdDef = protocolService.getCommandByName(categoryName, commandName);
    if (cmdDef == null) return;
    
    final cmdId = cmdDef.id; // Capture for closure safety
    _debouncers[stateKey] = Timer(const Duration(milliseconds: 50), () async {
      try {
         final builder = getIt<DynamicCommandBuilder>();
         final protocolService = getIt<ProtocolService>();
         // Re-verify definition inside timer or use captured ID
         final command = builder.buildEqCommand(
           categoryName: categoryName,
           cmdId: cmdId,
           band: band,
           fields: {
              fieldParam: rawValue,
           },
         );

         await viewModel.sendProtocolCommand(command);
      } catch (e) {
         debugPrint('Error sending EQ band command: $e');
      }
    });
  }

  Future<void> _handleEqBandMultipleChange(String categoryName, String commandName, int band, Map<String, dynamic> changes, BleViewModel viewModel) async {
     if (categoryName.isEmpty || commandName.isEmpty) return;

     debugPrint('\n_handleEqBandMultipleChange '  + changes.entries.length.toString());
     
     // 1. Process and format all values for state and payload
     Map<String, dynamic> rawFields = {};
     
     for (var entry in changes.entries) {
        final fieldParam = entry.key;
        final value = entry.value;
        
        final stateKey = "${commandName}_band${band}_$fieldParam";
        
        int rawValue = 0;
        if (fieldParam == 'gain') {
           rawValue = (value * 256.0).round();
        } else if (fieldParam == 'Q') {
           rawValue = (value * 1024.0).round();
        } else if (fieldParam == 'f0' || fieldParam == 'type') {
           rawValue = (value is double) ? value.toInt() : (value as int);
        }
        
        viewModel.updateControlValue(stateKey, rawValue);
        rawFields[fieldParam] = rawValue;
        
        debugPrint('\nEQ Multiple Change: Band $band - $fieldParam -> $rawValue (Cmd: $categoryName.$commandName)');
     }

     if (viewModel.selectedDevice == null) {
       _showCenterSnackBar("Vui lòng kết nối thiết bị");
       return; 
     }

     try {
        final builder = getIt<DynamicCommandBuilder>();
        final protocolService = getIt<ProtocolService>();
        final cmdDef = protocolService.getCommandByName(categoryName, commandName);
        if (cmdDef == null) return;

        final command = builder.buildEqCommand(
          categoryName: categoryName,
          cmdId: cmdDef.id,
          band: band,
          fields: rawFields,
        );

        await viewModel.sendProtocolCommand(command);
     } catch (e) {
        debugPrint('Error sending batched EQ band command: $e');
     }
  }

  void _navigateToArea(String? areaName) {
    if (areaName == null) {
      setState(() => _currentOverlayArea = null);
      final viewModel = context.read<BleViewModel>();
      if (viewModel.selectedDevice != null) {
        viewModel.fetchInitialStates();
      }
      return;
    }
    
    final section = getIt<MixerService>().getItemsForSection(areaName);
    if (section == null) {
      _showCenterSnackBar("Chưa định nghĩa");
      return;
    }

    // Trigger data fetch if it's an Overlay Area and we are connected
    if (section.areaType == "Overlay Area") 
    {
      debugPrint('Protocol: Overlay Area "$areaName" called.');
      final viewModel = context.read<BleViewModel>();
      if (viewModel.selectedDevice != null) {
        debugPrint('Overlay Area "$areaName" Fetching data...');
        viewModel.fetchSectionStates(areaName);
      }
    }
    
    setState(() => _currentOverlayArea = areaName);
  }

  void _showCenterSnackBar(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
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
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IntWidthWrapper extends StatelessWidget {
  final Widget child;
  const IntWidthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(child: child);
  }
}
