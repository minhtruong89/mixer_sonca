import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';
import 'package:mixer_sonca/injection.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_service.dart';
import 'package:mixer_sonca/features/ble/protocol/dynamic_command_builder.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_constants.dart';
import 'package:mixer_sonca/features/ble/protocol/models/protocol_definition.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class _ThrottleState {
  double lastValue;
  DateTime lastSentTime;
  int lastDirection;
  Timer? debounceTimer;

  _ThrottleState(this.lastValue, this.lastSentTime, this.lastDirection);
}

final Map<String, _ThrottleState> _modernThrottleStates = {};

class ModernSliderHelper {
  static const MethodChannel _hapticChannel = MethodChannel('com.mixer.sonca/haptic');

  static void triggerHaptic() async {
    try {
      await _hapticChannel.invokeMethod('vibrate');
      debugPrint('ModernSliderHelper: Native vibrate MethodChannel invoked!');
    } catch (e) {
      debugPrint('ModernSliderHelper: MethodChannel failed: $e');
      HapticFeedback.selectionClick();
    }
  }
  static void throttledSend(BuildContext context, DisplayItem item, dynamic value, String paramName) {
    final viewModel = context.read<BleViewModel>();
    final protocolService = getIt<ProtocolService>();
    
    CommandDefinition? cmdDef;
    if (item.command.isNotEmpty) {
      cmdDef = protocolService.getCommandByName(item.category, item.command);
    }
    cmdDef ??= protocolService.findCommand(item.category, paramName);
                   
    if (cmdDef == null) return;

    final stateKey = "${item.command}_$paramName";
    viewModel.updateControlValue(stateKey, value, notify: false);

    dynamic finalValue = value;
    final paramType = protocolService.getParameterType(item.category, cmdDef.id, paramName);
    if (paramType?.toLowerCase() == 'q8_8_le' && finalValue is! double) {
      finalValue = double.tryParse(finalValue.toString()) ?? 0.0;
    } else {
      final activeSchemaVersion = getIt<MixerService>().getSchemaVersionForActiveModel();
      if (activeSchemaVersion == 2 && finalValue is num) {
        finalValue = finalValue.round();
      }
    }

    if (finalValue is num) {
      final now = DateTime.now();
      final state = _modernThrottleStates[stateKey];
      
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
          if (now.difference(state.lastSentTime).inMilliseconds >= 70) {
            shouldSendNow = true;
          }
        } else {
          shouldSendNow = false;
        }
        
        state.lastValue = numValue;
        if (currentDirection != 0) {
          state.lastDirection = currentDirection;
        }
      } else {
        _modernThrottleStates[stateKey] = _ThrottleState(numValue, now, 0);
        shouldSendNow = true;
      }
      
      final currentState = _modernThrottleStates[stateKey]!;
      currentState.debounceTimer?.cancel();
      
      Future<void> sendCmd() async {
        currentState.lastSentTime = DateTime.now();
        debugPrint('\nUI Change: ${item.label} ($paramName) -> $finalValue (Cmd: ${item.category}.${cmdDef!.name})');
        try {
          final builder = getIt<DynamicCommandBuilder>();
          final cmds = builder.buildCommand(
            categoryName: item.category,
            cmdId: cmdDef.id,
            operation: CommandOperation.set,
            parameters: {paramName: finalValue},
          );
          for (var cmd in cmds) {
            await viewModel.sendProtocolCommand(cmd);
          }
        } catch (e) {
          debugPrint('Error sending modern cmd: $e');
        }
      }
      
      if (shouldSendNow) {
        sendCmd();
      } else {
        currentState.debounceTimer = Timer(const Duration(milliseconds: 60), sendCmd);
      }
    } else {
      // Not a num, send immediately
      Future<void>(() async {
        try {
          final builder = getIt<DynamicCommandBuilder>();
          final cmds = builder.buildCommand(
            categoryName: item.category,
            cmdId: cmdDef!.id,
            operation: CommandOperation.set,
            parameters: {paramName: finalValue},
          );
          for (var cmd in cmds) {
            await viewModel.sendProtocolCommand(cmd);
          }
        } catch (e) {
          debugPrint('Error sending non-num command: $e');
        }
      });
    }
  }

  static String formatDisplayValue(double currentValue, DisplayItem item) {
    final divide = item.control.displayDivide;
    final offset = item.control.displayOffset;
    final textOption = item.control.displayText;
    
    double calculated = (currentValue / divide) + offset;
    String displayVal;
    if (calculated % 1 == 0) {
      displayVal = calculated.toInt().toString();
    } else {
      displayVal = calculated.toStringAsFixed(1);
    }

    if (textOption == '%') {
      displayVal += '%';
    } else if (textOption.isNotEmpty) {
      displayVal += textOption;
    }
    
    return displayVal;
  }
}
