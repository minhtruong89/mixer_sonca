import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';
import 'package:mixer_sonca/features/ble/ui/modern/widgets/modern_vertical_slider.dart';
import 'package:mixer_sonca/features/ble/ui/modern/widgets/modern_horizontal_slider.dart';
import 'package:mixer_sonca/injection.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_service.dart';
import 'package:mixer_sonca/features/ble/protocol/dynamic_command_builder.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_constants.dart';
import 'package:mixer_sonca/features/ble/protocol/models/protocol_definition.dart';
import 'package:mixer_sonca/features/ble/ui/modern/modern_settings_screen.dart';

class ModernMainAreaPage extends StatefulWidget {
  const ModernMainAreaPage({super.key});

  @override
  State<ModernMainAreaPage> createState() => _ModernMainAreaPageState();
}

class _ModernMainAreaPageState extends State<ModernMainAreaPage> {
  // Store old values for mute functionality
  final Map<String, dynamic> _oldValues = {};
  bool _showPopTopArea = false;
  DisplayItem? _selectedPopItem;
  String? _selectedPopItemLabel;

  String _getPopTopItemDisplayValue(DisplayItem item, BleViewModel viewModel, ProtocolService protocolService) {
    if (item.command.isNotEmpty) {
      final stateKey = "${item.command}_${item.paramName ?? ''}";
      final rawVal = viewModel.getControlValue(stateKey);
      if (rawVal == null) return "";

      final typeValue = item.rawConfig['typeValue']?.toString();

      if (typeValue == "Options") {
        final cmdDef = protocolService.getCommandByName(item.category, item.command);
        final valueMap = cmdDef?.valueMap;
        if (valueMap != null) {
          final keyStr = (rawVal is num) ? rawVal.toInt().toString() : rawVal.toString();
          if (valueMap.containsKey(keyStr)) {
            return valueMap[keyStr]!;
          }
        }
        return rawVal.toString();
      } else {
        // Default boolean mapping
        final numVal = (rawVal is num) ? rawVal : int.tryParse(rawVal.toString());
        if (numVal != null) {
          return numVal > 0 ? "On" : "Off";
        }
        if (rawVal is bool) {
          return rawVal ? "On" : "Off";
        }
        return "Off";
      }
    }
    return item.name ?? item.label;
  }

  bool _getMuteState(DisplayButton? buttonDef, BleViewModel viewModel) {
    if (buttonDef == null) return false;
    final commandList = buttonDef.rawConfig['commandList'] as Map<String, dynamic>?;
    if (commandList == null) return false;

    for (var key in commandList.keys) {
      final cmdObj = commandList[key] as Map<String, dynamic>;
      final commandName = cmdObj['command'] as String;
      final index = cmdObj['index'] as String;
      final muteValue = cmdObj['muteValue'];

      final stateKey = "${commandName}_$index";
      final currentVal = viewModel.getControlValue(stateKey);
      if (currentVal != null && currentVal == muteValue) {
        return true;
      }
    }
    return false;
  }

  void _handleMuteToggle(DisplayButton buttonDef, BleViewModel viewModel) {
    final currentlyMuted = _getMuteState(buttonDef, viewModel);
    final nextMuteState = !currentlyMuted;

    final commandList = buttonDef.rawConfig['commandList'] as Map<String, dynamic>?;
    if (commandList == null) return;

    final protocolService = getIt<ProtocolService>();
    final builder = getIt<DynamicCommandBuilder>();

    // Group parameters by category and cmdId
    final Map<String, Map<int, Map<String, dynamic>>> groupedCmds = {};

    for (var key in commandList.keys) {
      final cmdObj = commandList[key] as Map<String, dynamic>;
      final commandName = cmdObj['command'] as String;
      final index = cmdObj['index'] as String;
      final muteValue = cmdObj['muteValue'];
      final unmuteValue = cmdObj['unmuteValue'];

      String categoryName = "";
      for (var cat in protocolService.definition?.categories.values ?? <CategoryDefinition>[]) {
        if (cat.getCommandByName(commandName) != null) {
          categoryName = cat.name;
          break;
        }
      }
      if (categoryName.isEmpty) continue;

      final stateKey = "${commandName}_$index";
      final cmdDef = protocolService.getCommandByName(categoryName, commandName);
      if (cmdDef == null) continue;

      dynamic valToSend;
      if (nextMuteState) {
        // Muting: store old value if available
        final currentVal = viewModel.getControlValue(stateKey);
        if (currentVal != null) {
          _oldValues[stateKey] = currentVal;
        }
        valToSend = muteValue;
      } else {
        // Unmuting: restore old value if requested
        valToSend = unmuteValue;
        if (unmuteValue == "oldValue") {
          valToSend = _oldValues[stateKey] ?? 0;
        }
      }

      // Convert to num if parameter type requires double/Q8_8_LE
      final paramType = protocolService.getParameterType(categoryName, cmdDef.id, index);
      if (paramType?.toLowerCase() == 'q8_8_le' && valToSend is! double) {
        valToSend = double.tryParse(valToSend.toString()) ?? 0.0;
      }

      debugPrint('\nUI Change: $key ($index) -> $valToSend (Cmd: $categoryName.$commandName)');

      viewModel.updateControlValue(stateKey, valToSend, notify: false);

      groupedCmds[categoryName] ??= {};
      groupedCmds[categoryName]![cmdDef.id] ??= {};
      groupedCmds[categoryName]![cmdDef.id]![index] = valToSend;
    }

    viewModel.notifyListeners();

    // Send the batched SET commands to BLE device
    for (final catEntry in groupedCmds.entries) {
      final categoryName = catEntry.key;
      for (final cmdEntry in catEntry.value.entries) {
        final cmdId = cmdEntry.key;
        final params = cmdEntry.value;

        final cmds = builder.buildCommand(
          categoryName: categoryName,
          cmdId: cmdId,
          operation: CommandOperation.set,
          parameters: params,
        );

        for (var cmd in cmds) {
          viewModel.sendProtocolCommand(cmd);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();
    final device = viewModel.selectedDevice;

    if (device == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("No device", style: TextStyle(color: Colors.white))));
    }

    // Extract last 4 chars of ID for the suffix
    String idSuffix = "";
    if (device.id.length >= 4) {
      idSuffix = device.id.substring(device.id.length - 4).toUpperCase();
    } else {
      idSuffix = device.id.toUpperCase();
    }
    idSuffix = idSuffix.replaceAll(':', '');
    if (idSuffix.length > 4) {
      idSuffix = idSuffix.substring(idSuffix.length - 4);
    }

    final section = getIt<MixerService>().getItemsForSection("Area Modern MUSIC MAIN");
    if (section == null) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: Text("Main Area config missing", style: TextStyle(color: Colors.white))));
    }

    // Parse items
    List<MapEntry<String, DisplayItem>> verticalSliders = [];
    List<MapEntry<String, DisplayItem>> horizontalSliders = [];

    for (var entry in section.items.entries) {
      if (entry.value.control.typeDisplay == 'modern vertical slider') {
        verticalSliders.add(entry);
      } else if (entry.value.control.typeDisplay == 'modern horizontal slider') {
        horizontalSliders.add(entry);
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Top Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          viewModel.disconnectDevice();
                          // ModernBlePage will automatically revert to scan page due to state change
                        },
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 16),
                        label: const Text('Chọn thiết bị khác', style: TextStyle(color: Colors.white70, fontSize: 16)),
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
                
                // Device Info
                const Text(
                  'Thiết bị',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  '${device.soncaName.toUpperCase()} $idSuffix',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Icon(Icons.speaker, color: Colors.white, size: 48),
                const SizedBox(height: 32),
                
                // Sliders area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      children: [
                        // Vertical Sliders
                        if (verticalSliders.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: verticalSliders.map((e) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                  child: ModernVerticalSlider(
                                    item: e.value,
                                    label: e.key,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        
                        const SizedBox(height: 48),
                        
                        // Horizontal Sliders
                        if (horizontalSliders.isNotEmpty)
                          ...horizontalSliders.map((e) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 24.0),
                              child: ModernHorizontalSlider(
                                item: e.value,
                                label: e.key,
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                
                // Pop Top Area (rendered directly above bottom buttons if active)
                if (_showPopTopArea)
                  Builder(
                    builder: (context) {
                      final popSection = getIt<MixerService>().getItemsForSection("Area Modern Area Summary");
                      if (popSection == null) return const SizedBox();
                      final protocolService = getIt<ProtocolService>();

                      final itemWidgets = <Widget>[];
                      popSection.items.forEach((label, item) {
                        final displayVal = _getPopTopItemDisplayValue(item, viewModel, protocolService);

                        itemWidgets.add(
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPopItem = item;
                                _selectedPopItemLabel = label;
                              });
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  displayVal,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      });

                      return Padding(
                        padding: const EdgeInsets.only(right: 20.0, bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (int i = 0; i < itemWidgets.length; i++) ...[
                              if (i > 0) const SizedBox(width: 24),
                              itemWidgets[i],
                            ],
                          ],
                        ),
                      );
                    },
                  ),

                // Bottom Buttons
                Builder(
                  builder: (context) {
                    final leftButtons = <Widget>[];
                    final rightButtons = <Widget>[];

                    section.buttons.forEach((name, btnConfig) {
                      final align = btnConfig.alignment;
                      Widget btnWidget;

                      if (name == 'Mute') {
                        final isMuted = _getMuteState(btnConfig, viewModel);
                        btnWidget = ElevatedButton(
                          onPressed: () => _handleMuteToggle(btnConfig, viewModel),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMuted ? Colors.red : Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Mute', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        );
                      } else if (name == 'Mixer') {
                        btnWidget = ElevatedButton(
                          onPressed: () {
                            // Navigate to Mixer Area (Area Modern MIXER)
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Mixer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                        );
                      } else if (name == 'Setting') {
                        btnWidget = ElevatedButton(
                          onPressed: () {
                            final targetArea = btnConfig.event?.click;
                            if (targetArea != null) {
                              final targetSection = getIt<MixerService>().getItemsForSection(targetArea);
                              if (targetSection?.areaType == "Pop Top Area") {
                                setState(() {
                                  _showPopTopArea = !_showPopTopArea;
                                  if (_showPopTopArea) {
                                    viewModel.fetchSectionStates(targetArea);
                                  }
                                });
                                return;
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showPopTopArea ? Colors.red : Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(Icons.tune, color: Colors.white, size: 20),
                        );
                      } else {
                        btnWidget = ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[800],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        );
                      }

                      if (align == 'left') {
                        if (leftButtons.isNotEmpty) leftButtons.add(const SizedBox(width: 12));
                        leftButtons.add(btnWidget);
                      } else {
                        if (rightButtons.isNotEmpty) rightButtons.add(const SizedBox(width: 12));
                        rightButtons.add(btnWidget);
                      }
                    });

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: leftButtons),
                          Row(children: rightButtons),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Select Overlay Screen when _selectedPopItem is selected
          if (_selectedPopItem != null)
            _buildSelectOverlay(context, viewModel, getIt<ProtocolService>()),
        ],
      ),
    );
  }

  Widget _buildSelectOverlay(BuildContext context, BleViewModel viewModel, ProtocolService protocolService) {
    final item = _selectedPopItem!;
    final label = _selectedPopItemLabel ?? item.label;
    final device = viewModel.selectedDevice;
    final deviceName = device?.soncaName.isNotEmpty == true ? device!.soncaName : "Speaker";

    final stateKey = "${item.command}_${item.paramName ?? ''}";
    final rawVal = viewModel.getControlValue(stateKey);

    final typeValue = item.rawConfig['typeValue']?.toString();
    final cmdDef = protocolService.getCommandByName(item.category, item.command);

    List<MapEntry<String, String>> options = [];
    String currentKey = "0";

    if (typeValue == "Options") {
      final valueMap = cmdDef?.valueMap;
      if (valueMap != null && valueMap.isNotEmpty) {
        options = valueMap.entries.map((e) => MapEntry(e.key, e.value)).toList();
      } else {
        options = [const MapEntry("0", "Option 1"), const MapEntry("1", "Option 2")];
      }
      if (rawVal != null) {
        currentKey = (rawVal is num) ? rawVal.toInt().toString() : rawVal.toString();
      }
    } else {
      // Default On / Off
      options = [const MapEntry("1", "On"), const MapEntry("0", "Off")];
      if (rawVal != null) {
        final numVal = (rawVal is num) ? rawVal : int.tryParse(rawVal.toString());
        if (numVal != null) {
          currentKey = numVal > 0 ? "1" : "0";
        } else if (rawVal is bool) {
          currentKey = rawVal ? "1" : "0";
        }
      }
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar with Back Arrow and Device Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedPopItem = null;
                          _selectedPopItemLabel = null;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Centered Titles
              Text(
                deviceName.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Select $label",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              // Options list
              Expanded(
                child: ListView.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final isSelected = opt.key == currentKey;

                    return GestureDetector(
                      onTap: () {
                        final valNum = int.tryParse(opt.key) ?? 0;
                        viewModel.updateControlValue(stateKey, valNum, notify: true);

                        if (cmdDef != null && item.paramName != null) {
                          final builder = getIt<DynamicCommandBuilder>();
                          final cmds = builder.buildCommand(
                            categoryName: item.category,
                            cmdId: cmdDef.id,
                            operation: CommandOperation.set,
                            parameters: {item.paramName!: valNum},
                          );
                          for (var cmd in cmds) {
                            viewModel.sendProtocolCommand(cmd);
                          }
                        }

                        setState(() {
                          _selectedPopItem = null;
                          _selectedPopItemLabel = null;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                opt.value,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(height: 6),
                                Container(
                                  width: 40,
                                  height: 2,
                                  color: Colors.red,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
