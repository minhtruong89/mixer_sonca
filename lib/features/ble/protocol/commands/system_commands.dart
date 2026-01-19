/// SYSTEM category command builders
library;

import '../protocol_constants.dart';
import '../command_payload.dart';

/// SYSTEM Category Commands (0x04)
class SystemCommands {
  /// Set app mode (CmdId 0x01)
  /// 
  /// Index mapping:
  /// - 1: app_mode (1=Bluetooth, 2=Line In, 3=Optical, 4=Sound Card, 5=HDMI, 6=USB)
  static CommandPayload setAppMode(AppMode mode) {
    return CommandPayload.fromPairs(
      category: CommandCategory.system,
      cmdId: SystemCommand.appMode.value,
      operation: CommandOperation.set,
      pairs: [
        IndexValuePair(1, mode.value),
      ],
    );
  }

  /// Get app mode (CmdId 0x01)
  static CommandPayload getAppMode() {
    return CommandPayload(
      category: CommandCategory.system,
      cmdId: SystemCommand.appMode.value,
      operation: CommandOperation.get,
      data: [1, 1], // Count=1, Index=1
    );
  }

  /// Set master volume (CmdId 0x02)
  /// 
  /// Index mapping:
  /// - 1: dac_gain (int16)
  /// - 2: dac_mute (0=unmute, 1=mute)
  static CommandPayload setMasterVolume({int? dacGain, int? dacMute}) {
    final pairs = <IndexValuePair>[];
    
    if (dacGain != null) {
      pairs.add(IndexValuePair(1, dacGain));
    }
    if (dacMute != null) {
      pairs.add(IndexValuePair(2, dacMute));
    }

    return CommandPayload.fromPairs16(
      category: CommandCategory.system,
      cmdId: SystemCommand.masterVolume.value,
      operation: CommandOperation.set,
      pairs: pairs,
    );
  }

  /// Get master volume (CmdId 0x02)
  static CommandPayload getMasterVolume({bool getDacGain = true, bool getDacMute = true}) {
    final indices = <int>[];
    if (getDacGain) indices.add(1);
    if (getDacMute) indices.add(2);

    return CommandPayload(
      category: CommandCategory.system,
      cmdId: SystemCommand.masterVolume.value,
      operation: CommandOperation.get,
      data: [indices.length, ...indices],
    );
  }
}
