import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
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
  final Map<String, _ThrottleState> _throttleStates = {};
  
  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

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
    for (var state in _throttleStates.values) {
      state.debounceTimer?.cancel();
    }
    _throttleStates.clear();
    _toastTimer?.cancel();
    if (_toastEntry != null) {
      _toastEntry!.remove();
      _toastEntry = null;
    }
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

    /*
    // If device disconnected while overlay is open, clear it
    if (viewModel.selectedDevice == null && _currentOverlayArea != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentOverlayArea = null;
          });
        }
      });
    }
    */

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

          // Load Config Progress Bar Overlay
          if (viewModel.showLoadProgressBar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildLoadProgressBar(context, viewModel),
            ),
        ],
      ),
      // Disable default FAB
      floatingActionButton: null, 
    );
  }

  Widget _buildLoadProgressBar(BuildContext context, BleViewModel viewModel) {
    final progress = viewModel.loadProgress.clamp(0.0, 1.0);
    final failedSet = viewModel.loadFailedSegments.toSet();
    final isDone = !viewModel.isLoadingConfig && progress >= 1.0;
    final hasFailed = failedSet.isNotEmpty;
    final total = viewModel.totalBatches;
    final completed = viewModel.completedBatches;

    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isDone
                    ? (hasFailed ? '⚠ Hoàn thành ($completed/$total, ${failedSet.length} lỗi)' : '✓ Sync hoàn thành ($total batches)')
                    : 'Đang sync config... $completed/$total (${(progress * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  color: isDone ? (hasFailed ? Colors.orangeAccent : Colors.greenAccent) : Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isDone && !hasFailed)
                const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
              if (isDone && hasFailed)
                const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          // Segmented progress bar: Stack of background + green fill + red markers
          LayoutBuilder(
            builder: (context, constraints) {
              final barW = constraints.maxWidth;
              const barH = 10.0;
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  width: barW,
                  height: barH,
                  child: Stack(
                    children: [
                      // 1. Dark background track
                      Container(
                        width: barW,
                        height: barH,
                        color: Colors.white10,
                      ),
                      // 2. Green filled portion
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: barW * progress,
                        height: barH,
                        color: const Color(0xFF00C853),
                      ),
                      // 3. Red markers for failed segments (drawn on top)
                      if (total > 0 && failedSet.isNotEmpty)
                        ...failedSet.map((segIndex) {
                          final segW = barW / total;
                          final x = segIndex * segW;
                          return Positioned(
                            left: x,
                            top: 0,
                            child: Container(
                              width: segW,
                              height: barH,
                              color: const Color(0xFFFF5252),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
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
              behavior: HitTestBehavior.opaque,
              onTap: item.event?.click != null 
                ? () => _navigateToArea(item.event!.click)
                : null,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    item.label, 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 16
                    )
                  ),
                  if (item.event?.click != null) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.open_in_new,
                      color: Colors.greenAccent,
                      size: 14,
                    ),
                  ],
                ],
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
              behavior: HitTestBehavior.opaque,
              onTap: item.event?.click != null 
                ? () => _navigateToArea(item.event!.click)
                : null,
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Text(
                    item.label, 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 16
                    )
                  ),
                  if (item.event?.click != null) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.open_in_new,
                      color: Colors.greenAccent,
                      size: 14,
                    ),
                  ],
                ],
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
                behavior: HitTestBehavior.opaque,
                onTap: item.event?.click != null 
                  ? () => _navigateToArea(item.event!.click)
                  : null,
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Flexible(
                      child: Text(
                        item.label, 
                        softWrap: true,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold
                        )
                      ),
                    ),
                    if (item.event?.click != null) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.open_in_new,
                        color: Colors.greenAccent,
                        size: 14,
                      ),
                    ],
                  ],
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
        // Find mute if it exists
        for (final p in item.indexList) {
          if (p.endsWith('_mute')) {
            muteParam = p;
            break;
          }
        }
        // Volume (or gain/etc) is the other one (or the only one)
        volumeParam = item.indexList.firstWhere(
          (p) => p != muteParam, 
          orElse: () => item.indexList[0]
        );
      } else {
        volumeParam = item.paramName;
      }

      final volumeStateKey = "${item.command}_${volumeParam ?? ''}";
      final muteStateKey = muteParam != null ? "${item.command}_$muteParam" : null;

      final volumeValue = (volumeParam != null) 
          ? viewModel.getControlValue(volumeStateKey, defaultValue: (item.control.minValue + item.control.maxValue) / 2).toDouble() 
          : (item.control.minValue + item.control.maxValue) / 2;
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
        displayDivide: item.control.displayDivide,
        displayOffset: item.control.displayOffset,
        displayText: item.control.displayText,
        onLabelTap: item.event?.click != null 
          ? () => _navigateToArea(item.event!.click)
          : null,
        onChanged: (val) {
          if (muteParam != null) {
            final muteStateKey = "${item.command}_$muteParam";
            if (viewModel.getControlValue(muteStateKey, defaultValue: 0) == 1) {
              _handleDynamicControlChange(item, 0, viewModel, paramOverride: muteParam);
            }
          }
          if (volumeParam != null) {
            _handleDynamicControlChange(item, val, viewModel, paramOverride: volumeParam);
          }
        },
        onMuteChanged: (muted) {
          if (muteParam != null) {
            _handleDynamicControlChange(item, muted ? 1 : 0, viewModel, paramOverride: muteParam);
          }
        },
      );
    }
    // 6. Compound Button
    else if (item.control.isCompound) {
      final buttons = item.controlList.entries.toList();
      buttons.sort((a, b) => a.key.compareTo(b.key));

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            ...buttons.map((entry) {
              final btnConfig = entry.value as Map<String, dynamic>;
              final label = btnConfig['label']?.toString() ?? '';
              
              return Container(
                width: 70, // Fixed width for buttons
                height: 36,
                margin: const EdgeInsets.only(right: 4.0),
                child: ElevatedButton(
                  onPressed: () => _handleCompoundClick(item, btnConfig, viewModel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: Colors.white24, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
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
                                   TextButton(
                                       onPressed: () => _resetEqToDefault(section, viewModel),
                                       child: const Text('Default', style: TextStyle(color: Colors.greenAccent, fontSize: 16)),
                                   ),
                                   ...section.valueFilters.entries.map((entry) => TextButton(
                                       onPressed: () => _applyEqPreset(section, entry.key, entry.value, viewModel),
                                       child: Text(entry.key, style: const TextStyle(color: Colors.orangeAccent, fontSize: 16)),
                                   )),
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

       final double rightSideRatio = Platform.isIOS ? 0.30 : 0.22;
       
       return Container(
         color: Colors.black.withOpacity(0.95), // Deep dark overlay
         child: Stack(
           children: [
             // Left Content (Scrollable Sliders)
             Positioned(
               left: 0,
               top: 10,
               bottom: 20,
               right: MediaQuery.of(context).size.width * rightSideRatio + 5,
              child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 10),
                 child: SingleChildScrollView(
                   scrollDirection: Axis.horizontal,
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: section.items.values
                        .where((item) => !item.control.isSwitch && !item.control.isDropdown)
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
               bottom: 10,
               width: MediaQuery.of(context).size.width * rightSideRatio - 10,
              child: SingleChildScrollView(
                child: Builder(builder: (context) {
                    final rightSideItems = section.items.values
                        .where((item) => item.control.isSwitch || item.control.isDropdown)
                        .toList();

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Switches and Dropdowns moved from the left list
                        ...rightSideItems.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 6.0, right: 10.0),
                              child: _buildDynamicControl(context, item, viewModel),
                            )),

                        if (rightSideItems.isNotEmpty && section.buttons.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6.0, right: 10.0),
                            child: Divider(color: Colors.white24, height: 1),
                          ),

                        // Navigation Buttons
                        ...section.buttons.values.map((btn) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0, right: 10.0),
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

  Future<void> _handleCompoundClick(DisplayItem item, Map<String, dynamic> btnConfig, BleViewModel viewModel) async {
    if (item.category == "SYSTEM") {
       final name = btnConfig['name']?.toString();
       if (name != null) {
          await _handleDynamicControlChange(item, 1, viewModel, paramOverride: name);
          
          if (name == 'reset_config') {
             // Delay to allow device to process reset
             await Future.delayed(const Duration(milliseconds: 500));
             
             final mixerService = getIt<MixerService>();
             final mainAreaSections = mixerService.getSectionNamesByType("Main Area");
             
             for (final section in mainAreaSections) {
                await viewModel.fetchSectionStates(section);
             }
             
             _showCenterSnackBar("Đã đồng bộ lại sau khi Reset");
          }
       }
    } else if (item.category == "CODING") {
       final event = btnConfig['event']?.toString();
        if (event == "_saveConfigToFile") {
           final now = DateTime.now();
           final formatter = DateFormat('yyyy_MM_dd_HH_mm');
           final timestamp = formatter.format(now);
           final defaultFileName = "HC_$timestamp";
           final textController = TextEditingController(text: defaultFileName);

           if (!mounted) return;

            final inputName = await showDialog<String>(
               context: context,
               builder: (ctx) => Dialog(
                  backgroundColor: const Color(0xFF2C2C2C),
                  shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                     side: const BorderSide(color: Colors.white10, width: 0.5),
                  ),
                  child: ConstrainedBox(
                     constraints: BoxConstraints(
                        maxWidth: 340,
                        maxHeight: MediaQuery.of(ctx).size.height - MediaQuery.of(ctx).viewInsets.bottom - 16,
                     ),
                     child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(ctx).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                           physics: const ClampingScrollPhysics(),
                           child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                    const Row(
                                       children: [
                                          Icon(Icons.save_outlined, color: Colors.greenAccent, size: 24),
                                          SizedBox(width: 8),
                                          Text(
                                             'Lưu cấu hình',
                                             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                          ),
                                       ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                       'Nhập tên file cấu hình:',
                                       style: TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                       controller: textController,
                                       autofocus: true,
                                       style: const TextStyle(color: Colors.white, fontSize: 16),
                                       decoration: InputDecoration(
                                          hintText: 'Tên file',
                                          hintStyle: const TextStyle(color: Colors.white30),
                                          suffixText: '.json',
                                          suffixStyle: const TextStyle(color: Colors.white54, fontSize: 14),
                                          filled: true,
                                          fillColor: Colors.white.withOpacity(0.05),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          enabledBorder: OutlineInputBorder(
                                             borderRadius: BorderRadius.circular(8),
                                             borderSide: const BorderSide(color: Colors.white24, width: 1),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                             borderRadius: BorderRadius.circular(8),
                                             borderSide: const BorderSide(color: Colors.greenAccent, width: 1.5),
                                          ),
                                       ),
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                       mainAxisAlignment: MainAxisAlignment.end,
                                       children: [
                                          TextButton(
                                             onPressed: () => Navigator.of(ctx).pop(),
                                             child: const Text(
                                                'Hủy',
                                                style: TextStyle(color: Colors.white54, fontSize: 16),
                                             ),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton(
                                             onPressed: () {
                                                final val = textController.text.trim();
                                                Navigator.of(ctx).pop(val.isNotEmpty ? val : null);
                                             },
                                             child: const Text(
                                                'Lưu',
                                                style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                                             ),
                                          ),
                                       ],
                                    ),
                                 ],
                              ),
                           ),
                        ),
                     ),
                  ),
               ),
            );

           textController.dispose();

           if (inputName == null) {
              return;
           }

           final filePath = await viewModel.saveConfigToFile(customFileName: inputName);
           if (filePath != null && mounted) {
              showDialog(
                 context: context,
                 builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2C),
                    shape: RoundedRectangleBorder(
                       borderRadius: BorderRadius.circular(12),
                       side: const BorderSide(color: Colors.white10, width: 0.5),
                    ),
                    title: const Row(
                       children: [
                          Icon(Icons.check_circle, color: Colors.greenAccent, size: 24),
                          SizedBox(width: 8),
                          Text(
                             'Đã lưu cấu hình',
                             style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                       ],
                    ),
                    content: Text(
                       'Đường dẫn file:\n$filePath',
                       style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    actions: [
                       TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text(
                             'OK',
                             style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                       ),
                    ],
                 ),
              );
           }
        } else if (event == "_loadConfigToFile") {
          await viewModel.loadConfigToFile();
          if (viewModel.loadFailedCommands.isNotEmpty && mounted) {
             showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                   backgroundColor: const Color(0xFF2C2C2C),
                   shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white10, width: 0.5),
                   ),
                   title: const Row(
                      children: [
                         Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 24),
                         SizedBox(width: 8),
                         Text(
                            'Lỗi đồng bộ cấu hình',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                         ),
                      ],
                   ),
                   content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                         shrinkWrap: true,
                         itemCount: viewModel.loadFailedCommands.length,
                         itemBuilder: (context, index) {
                            return Padding(
                               padding: const EdgeInsets.symmetric(vertical: 4.0),
                               child: Row(
                                  children: [
                                     const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                                     const SizedBox(width: 8),
                                     Expanded(
                                        child: Text(
                                           viewModel.loadFailedCommands[index],
                                           style: const TextStyle(color: Colors.white70, fontSize: 14),
                                        ),
                                     ),
                                  ],
                               ),
                            );
                         },
                      ),
                   ),
                   actions: [
                      TextButton(
                         onPressed: () => Navigator.of(ctx).pop(),
                         child: const Text(
                            'Đóng',
                            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 16),
                         ),
                      ),
                   ],
                ),
             );
          }
       }
    }
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
      
      final cmdId = cmdDef.id; // Resolve ID early

      // 2. Build parameter map & Resolve Value
      dynamic finalValue = value;

      // Check for Q8.8 type from protocol and ensure double for correct encoding
      final paramType = protocolService.getParameterType(item.category, cmdId, paramName);
      if (paramType?.toLowerCase() == 'q8_8_le' && finalValue is! double) {
        finalValue = double.tryParse(finalValue.toString()) ?? 0.0;
      }
      
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

      // Smart Throttle / Debounce logic
      if (finalValue is num) {
        final now = DateTime.now();
        final state = _throttleStates[stateKey];
        
        bool shouldSendNow = false;
        int currentDirection = 0;
        double numValue = finalValue.toDouble();
        
        if (state != null) {
          if (numValue > state.lastValue) {
            currentDirection = 1;
          } else if (numValue < state.lastValue) {
            currentDirection = -1;
          }
          
          if (currentDirection != 0 && currentDirection == state.lastDirection) {
            // Linear movement (increasing or decreasing continuously)
            // Throttle: Send more frequently, e.g., every 40ms
            if (now.difference(state.lastSentTime).inMilliseconds >= 40) {
              shouldSendNow = true;
            }
          } else {
            // Direction changed (oscillating/gật lên xuống)
            // Wait longer, do standard debounce
            shouldSendNow = false;
          }
          
          state.lastValue = numValue;
          if (currentDirection != 0) {
            state.lastDirection = currentDirection;
          }
        } else {
          // First time
          _throttleStates[stateKey] = _ThrottleState(numValue, now, 0);
          shouldSendNow = true;
        }
        
        final currentState = _throttleStates[stateKey]!;
        currentState.debounceTimer?.cancel();
        
        Future<void> sendCmd() async {
          currentState.lastSentTime = DateTime.now();
          try {
            final builder = getIt<DynamicCommandBuilder>();
            final commands = builder.buildCommand(
              categoryName: item.category,
              cmdId: cmdId,
              operation: CommandOperation.set,
              parameters: {
                paramName: finalValue
              },
            );
            
            for (final command in commands) {
              await viewModel.sendProtocolCommand(command);
            }
          } catch (e) {
            debugPrint('Error sending dynamic command: $e');
          }
        }
        
        if (shouldSendNow) {
          sendCmd();
        } else {
          // Debounce for oscillation (60ms)
          currentState.debounceTimer = Timer(const Duration(milliseconds: 60), () {
            sendCmd();
          });
        }
      } else {
        // Fallback for non-numeric values
        _debouncers[stateKey]?.cancel();
        _debouncers[stateKey] = Timer(const Duration(milliseconds: 50), () async {
          try {
            final builder = getIt<DynamicCommandBuilder>();
            final commands = builder.buildCommand(
              categoryName: item.category,
              cmdId: cmdId,
              operation: CommandOperation.set,
              parameters: {
                paramName: finalValue
              },
            );
            
            for (final command in commands) {
              await viewModel.sendProtocolCommand(command);
            }
            
          } catch (e) {
            debugPrint('Error sending dynamic command: $e');
          }
        });
      }
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
     int defaultTypeEnum = 2; // Default to PEAKING (2)
     final typeValue = section.control?.rawConfig['type']?.toString();
     if (typeValue != null) {
        final parsedInt = int.tryParse(typeValue);
        if (parsedInt != null) {
           defaultTypeEnum = parsedInt;
        } else {
           // Try to resolve by name
           final protocolService = getIt<ProtocolService>();
           if (protocolService.isLoaded) {
              final filterType = protocolService.definition!.eqFilterTypes[typeValue.toUpperCase()];
              if (filterType != null) {
                 defaultTypeEnum = filterType.value;
              }
           }
        }
     }
     final defaultF0 = section.control?.rawConfig['f0']?.toString() ?? '0';
     final defaultQ = int.tryParse(section.control?.rawConfig['Q']?.toString() ?? '0') ?? 0;

     // Calculate Q in double from Q8.8 (previously Q6.10/1024.0)
     final double qValue = defaultQ / 256.0;
     
     final protocolService = getIt<ProtocolService>();
     String categoryName = '';
     Map<String, dynamic>? fieldLimits;
     
     for (var cat in protocolService.definition?.categories.values ?? <CategoryDefinition>[]) {
       final cmd = cat.getCommandByName(commandName);
       if (cmd != null) {
          categoryName = cat.name;
          // Get field limits from command index rule
          if (cmd.indexRule?.fieldLimit != null) {
             fieldLimits = {};
             cmd.indexRule!.fieldLimit!.forEach((key, limit) {
                fieldLimits![key] = {
                   'min': limit.min,
                   'max': limit.max,
                };
             });
          }
          break;
       }
     }

     final minGainLimit = fieldLimits?['gain']?['min'];
     final maxGainLimit = fieldLimits?['gain']?['max'];

     final minGain = double.tryParse(minGainLimit?.toString() ?? section.control?.rawConfig['minGain']?.toString() ?? '-6.0') ?? -6.0;
     final maxGain = double.tryParse(maxGainLimit?.toString() ?? section.control?.rawConfig['maxGain']?.toString() ?? '6.0') ?? 6.0;
     
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
                    int currentF0 = (rawF0 is int) ? rawF0 : (rawF0 is double ? rawF0.toInt() : baseF0);

                    final rawQ = viewModel.getControlValue("${commandName}_band${index}_Q", defaultValue: defaultQ);
                    double currentQ = (rawQ is int) ? (rawQ / 256.0) : (rawQ is double ? rawQ : qValue);

                    final rawType = viewModel.getControlValue("${commandName}_band${index}_type", defaultValue: defaultTypeEnum);
                    int currentType = (rawType is int) ? rawType : (rawType is double ? rawType.toInt() : defaultTypeEnum);

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
                        fieldLimits: fieldLimits,
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

  Future<void> _handleEqMultiBandChange(String categoryName, String commandName, Map<int, Map<String, dynamic>> bandChanges, BleViewModel viewModel) async {
     if (categoryName.isEmpty || commandName.isEmpty) return;

     if (viewModel.selectedDevice == null) {
       _showCenterSnackBar("Vui lòng kết nối thiết bị");
       return; 
     }

     try {
        final builder = getIt<DynamicCommandBuilder>();
        final protocolService = getIt<ProtocolService>();
        final cmdDef = protocolService.getCommandByName(categoryName, commandName);
        if (cmdDef == null) return;

        // Process and format all values for state and payload
        Map<int, Map<String, dynamic>> rawBands = {};
        
        bandChanges.forEach((band, fields) {
           Map<String, dynamic> rawFields = {};
           fields.forEach((fieldParam, value) {
              int rawValue = 0;
              if (fieldParam == 'gain') {
                 double val = (value is String) ? (double.tryParse(value) ?? 0.0) : (value as num).toDouble();
                 rawValue = (val * 256.0).round();
              } else if (fieldParam == 'Q') {
                 double val = (value is String) ? (double.tryParse(value) ?? 0.0) : (value as num).toDouble();
                 rawValue = (val * 256.0).round();
              } else if (fieldParam == 'f0' || fieldParam == 'type') {
                 rawValue = (value is String) ? (int.tryParse(value) ?? 0) : (value is double ? value.toInt() : value as int);
              } else {
                 rawValue = (value is double) ? value.toInt() : (value as int);
              }
              
              viewModel.updateControlValue("${commandName}_band${band}_$fieldParam", rawValue, notify: false);
              rawFields[fieldParam] = rawValue;
           });
           rawBands[band] = rawFields;
        });

        // Notify UI once after all state changes
        viewModel.notifyListeners();

        final commands = builder.buildMultiBandEqCommand(
          categoryName: categoryName,
          cmdId: cmdDef.id,
          bands: rawBands,
        );

        for (final command in commands) {
            await viewModel.sendProtocolCommand(command);
        }
     } catch (e) {
        debugPrint('Error sending batched multi-band EQ command: $e');
     }
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
         final commands = builder.buildEqCommand(
           categoryName: categoryName,
           cmdId: cmdId,
           band: band,
           fields: {
              fieldParam: rawValue,
           },
         );

         for (final command in commands) {
             await viewModel.sendProtocolCommand(command);
          }
      } catch (e) {
         debugPrint('Error sending EQ band command: $e');
      }
    });
  }

  Future<void> _handleEqBandMultipleChange(String categoryName, String commandName, int band, Map<String, dynamic> changes, BleViewModel viewModel) async {
     await _handleEqMultiBandChange(categoryName, commandName, {band: changes}, viewModel);
  }

  Future<void> _resetEqToDefault(DisplaySection section, BleViewModel viewModel) async {
     final totalBands = section.totalEQBand ?? 10;
     final commandName = section.command ?? '';
     
     // Get category name
     final protocolService = getIt<ProtocolService>();
     String categoryName = '';
     for (var cat in protocolService.definition?.categories.values ?? <CategoryDefinition>[]) {
       if (cat.getCommandByName(commandName) != null) {
          categoryName = cat.name;
          break;
       }
     }

     if (categoryName.isEmpty) return;

     // 1. Resolve default values from config
     int defaultTypeEnum = 2; // Default to PEAKING (2)
     final typeValue = section.control?.rawConfig['type']?.toString();
     if (typeValue != null) {
         final parsedInt = int.tryParse(typeValue);
         if (parsedInt != null) {
             defaultTypeEnum = parsedInt;
         } else if (protocolService.isLoaded) {
             final filterType = protocolService.definition!.eqFilterTypes[typeValue.toUpperCase()];
             if (filterType != null) defaultTypeEnum = filterType.value;
         }
     }

     final defaultQInt = int.tryParse(section.control?.rawConfig['Q']?.toString() ?? '0') ?? 0;
     final double defaultQ = defaultQInt / 256.0;
     
     final defaultGainInt = int.tryParse(section.control?.rawConfig['gain']?.toString() ?? '0') ?? 0;
     final double defaultGain = defaultGainInt / 256.0;
     
     final baseF0Str = section.control?.rawConfig['f0']?.toString() ?? '0';

     debugPrint('Protocol: Resetting EQ Area "${section.description}" to defaults...');

     // 2. Build map of all bands and update everything
     Map<int, Map<String, dynamic>> allBandChanges = {};
     for (int i = 0; i < totalBands; i++) {
         String bandF0Value = baseF0Str;
         if (section.bandF0 != null && i < section.bandF0!.length) {
             bandF0Value = section.bandF0![i];
         }
         int defaultF0 = int.tryParse(bandF0Value) ?? 0;

         allBandChanges[i] = {
             'gain': defaultGain,
             'f0': defaultF0,
             'Q': defaultQ,
             'type': defaultTypeEnum,
         };
     }

     await _handleEqMultiBandChange(categoryName, commandName, allBandChanges, viewModel);
     
     _showCenterSnackBar("Đã đặt lại về mặc định");
  }

  Future<void> _applyEqPreset(DisplaySection section, String presetName, List<Map<String, dynamic>> values, BleViewModel viewModel) async {
     final commandName = section.command ?? '';
     
     // Get category name
     final protocolService = getIt<ProtocolService>();
     String categoryName = '';
     for (var cat in protocolService.definition?.categories.values ?? <CategoryDefinition>[]) {
       if (cat.getCommandByName(commandName) != null) {
          categoryName = cat.name;
          break;
       }
     }

     if (categoryName.isEmpty) return;

     debugPrint('Protocol: Applying EQ Preset "$presetName" to Area "${section.description}"...');

     // Resolve type names to values
     final Map<String, int> typeMap = {};
     if (protocolService.isLoaded) {
        protocolService.definition!.eqFilterTypes.forEach((key, val) {
           typeMap[key.toUpperCase()] = val.value;
        });
     }

     Map<int, Map<String, dynamic>> allBandChanges = {};
     for (int i = 0; i < values.length; i++) {
         final data = values[i];
         
         final f0 = int.tryParse(data['f0']?.toString() ?? '0') ?? 0;
         
         // Parse gain and Q. If they are stored as raw integers (like "179"), divide by 256.0
         final gainValue = data['gain']?.toString() ?? '0';
         final double gain = (double.tryParse(gainValue) ?? 0) / (gainValue.contains('.') ? 1.0 : 256.0);
         
         final qValue = data['Q']?.toString() ?? '0';
         final double q = (double.tryParse(qValue) ?? 0) / (qValue.contains('.') ? 1.0 : 256.0);
         
         final typeValue = data['type']?.toString() ?? 'PEAKING';
         int typeEnum = 2; // Default PEAKING
         final parsedInt = int.tryParse(typeValue);
         if (parsedInt != null) {
            typeEnum = parsedInt;
         } else {
            typeEnum = typeMap[typeValue.toUpperCase()] ?? 2;
         }

         allBandChanges[i] = {
             'gain': gain,
             'f0': f0,
             'Q': q,
             'type': typeEnum,
         };
     }

     await _handleEqMultiBandChange(categoryName, commandName, allBandChanges, viewModel);
     
     _showCenterSnackBar("Đã áp dụng chế độ $presetName");
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
    
    _toastTimer?.cancel();
    if (_toastEntry != null) {
      _toastEntry!.remove();
      _toastEntry = null;
    }

    _toastEntry = OverlayEntry(
      builder: (context) => IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10, width: 0.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_toastEntry!);

    _toastTimer = Timer(const Duration(seconds: 2), () {
      if (_toastEntry != null) {
        _toastEntry!.remove();
        _toastEntry = null;
      }
    });
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

/// Custom painter for pixel-perfect segmented progress bar.
/// Each segment corresponds to one BLE batch. Failed segments are drawn red.
class _SegmentedProgressPainter extends CustomPainter {
  final int total;
  final int completed;
  final Set<int> failedSet;

  const _SegmentedProgressPainter({
    required this.total,
    required this.completed,
    required this.failedSet,
  });

  static const _green = Color(0xFF00C853);
  static const _red = Color(0xFFFF5252);
  static const _bg = Color(0x1AFFFFFF); // white10
  static const _gap = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    // Draw background
    paint.color = _bg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    if (completed <= 0) return;

    // Width per segment, accounting for 1px gaps between all segments
    final totalGaps = (total - 1) * _gap;
    final segWidth = (size.width - totalGaps) / total;

    for (int i = 0; i < completed; i++) {
      final x = i * (segWidth + _gap);
      paint.color = failedSet.contains(i) ? _red : _green;
      canvas.drawRect(
        Rect.fromLTWH(x, 0, segWidth, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SegmentedProgressPainter old) =>
      old.total != total ||
      old.completed != completed ||
      old.failedSet.length != failedSet.length;
}

class _ThrottleState {
  double lastValue;
  int lastDirection;
  DateTime lastSentTime;
  Timer? debounceTimer;
  
  _ThrottleState(this.lastValue, this.lastSentTime, this.lastDirection);
}
