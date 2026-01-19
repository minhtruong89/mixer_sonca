/// MIC category command builders
library;

import '../protocol_constants.dart';
import '../command_payload.dart';

/// MIC Category Commands (0x01)
class MicCommands {
  /// Set MIC volume (CmdId 0x01)
  /// 
  /// Index mapping:
  /// - 1: mic1_volume
  /// - 2: mic1_mute
  /// - 3: mic2_volume
  /// - 4: mic2_mute
  /// - 5: mic_master_volume
  static CommandPayload setVolume({
    int? mic1Volume,
    int? mic1Mute,
    int? mic2Volume,
    int? mic2Mute,
    int? masterVolume,
  }) {
    final pairs = <IndexValuePair>[];
    
    if (mic1Volume != null) pairs.add(IndexValuePair(1, mic1Volume));
    if (mic1Mute != null) pairs.add(IndexValuePair(2, mic1Mute));
    if (mic2Volume != null) pairs.add(IndexValuePair(3, mic2Volume));
    if (mic2Mute != null) pairs.add(IndexValuePair(4, mic2Mute));
    if (masterVolume != null) pairs.add(IndexValuePair(5, masterVolume));

    return CommandPayload.fromPairs(
      category: CommandCategory.mic,
      cmdId: MicCommand.volume.value,
      operation: CommandOperation.set,
      pairs: pairs,
    );
  }

  /// Set MIC effects volume (CmdId 0x02)
  /// 
  /// Index mapping:
  /// - 1: mic_bass_gain
  /// - 2: mic_middle_gain
  /// - 3: mic_treb_gain
  /// - 4: mic_echo_gain
  /// - 5: mic_echo_delay_gain
  /// - 6: mic_reverb_gain
  /// - 7: mic_bypass_gain
  /// - 8: mic_wired_gain
  static CommandPayload setEffectsVolume({
    int? bassGain,
    int? middleGain,
    int? trebGain,
    int? echoGain,
    int? echoDelayGain,
    int? reverbGain,
    int? bypassGain,
    int? wiredGain,
  }) {
    final pairs = <IndexValuePair>[];
    
    if (bassGain != null) pairs.add(IndexValuePair(1, bassGain));
    if (middleGain != null) pairs.add(IndexValuePair(2, middleGain));
    if (trebGain != null) pairs.add(IndexValuePair(3, trebGain));
    if (echoGain != null) pairs.add(IndexValuePair(4, echoGain));
    if (echoDelayGain != null) pairs.add(IndexValuePair(5, echoDelayGain));
    if (reverbGain != null) pairs.add(IndexValuePair(6, reverbGain));
    if (bypassGain != null) pairs.add(IndexValuePair(7, bypassGain));
    if (wiredGain != null) pairs.add(IndexValuePair(8, wiredGain));

    return CommandPayload.fromPairs16(
      category: CommandCategory.mic,
      cmdId: MicCommand.effectsVolume.value,
      operation: CommandOperation.set,
      pairs: pairs,
    );
  }

  /// Set MIC echo effects (CmdId 0x03)
  /// 
  /// Index mapping (EchoParam):
  /// - 1: fc
  /// - 2: attenuation
  /// - 3: delay
  /// - 4: reserved
  /// - 5: max_delay
  /// - 6: high_quality_enable
  /// - 7: dry
  /// - 8: wet
  static CommandPayload setEchoEffects({
    int? fc,
    int? attenuation,
    int? delay,
    int? maxDelay,
    int? highQualityEnable,
    int? dry,
    int? wet,
  }) {
    final pairs = <IndexValuePair>[];
    
    if (fc != null) pairs.add(IndexValuePair(1, fc));
    if (attenuation != null) pairs.add(IndexValuePair(2, attenuation));
    if (delay != null) pairs.add(IndexValuePair(3, delay));
    if (maxDelay != null) pairs.add(IndexValuePair(5, maxDelay));
    if (highQualityEnable != null) pairs.add(IndexValuePair(6, highQualityEnable));
    if (dry != null) pairs.add(IndexValuePair(7, dry));
    if (wet != null) pairs.add(IndexValuePair(8, wet));

    return CommandPayload.fromPairs16(
      category: CommandCategory.mic,
      cmdId: MicCommand.echoEffects.value,
      operation: CommandOperation.set,
      pairs: pairs,
    );
  }

  /// Set MIC reverb effects (CmdId 0x04)
  /// 
  /// Index mapping (ReverbParam):
  /// - 1: dry_scale
  /// - 2: wet_scale
  /// - 3: width_scale
  /// - 4: roomsize_scale
  /// - 5: damping_scale
  /// - 6: mono
  static CommandPayload setReverbEffects({
    int? dryScale,
    int? wetScale,
    int? widthScale,
    int? roomsizeScale,
    int? dampingScale,
    int? mono,
  }) {
    final pairs = <IndexValuePair>[];
    
    if (dryScale != null) pairs.add(IndexValuePair(1, dryScale));
    if (wetScale != null) pairs.add(IndexValuePair(2, wetScale));
    if (widthScale != null) pairs.add(IndexValuePair(3, widthScale));
    if (roomsizeScale != null) pairs.add(IndexValuePair(4, roomsizeScale));
    if (dampingScale != null) pairs.add(IndexValuePair(5, dampingScale));
    if (mono != null) pairs.add(IndexValuePair(6, mono));

    return CommandPayload.fromPairs16(
      category: CommandCategory.mic,
      cmdId: MicCommand.reverbEffects.value,
      operation: CommandOperation.set,
      pairs: pairs,
    );
  }

  /// Set MIC plate reverb effects (CmdId 0x05)
  /// 
  /// Index mapping (PlateReverbParam):
  /// - 1: highcut_freq
  /// - 2: modulation_en
  /// - 3: predelay
  /// - 4: diffusion
  /// - 5: decay
  /// - 6: damping
  /// - 7: wetdrymix
  static CommandPayload setPlateReverbEffects({
    int? highcutFreq,
    int? modulationEn,
    int? predelay,
    int? diffusion,
    int? decay,
    int? damping,
    int? wetdrymix,
  }) {
    final pairs = <IndexValuePair>[];
    
    if (highcutFreq != null) pairs.add(IndexValuePair(1, highcutFreq));
    if (modulationEn != null) pairs.add(IndexValuePair(2, modulationEn));
    if (predelay != null) pairs.add(IndexValuePair(3, predelay));
    if (diffusion != null) pairs.add(IndexValuePair(4, diffusion));
    if (decay != null) pairs.add(IndexValuePair(5, decay));
    if (damping != null) pairs.add(IndexValuePair(6, damping));
    if (wetdrymix != null) pairs.add(IndexValuePair(7, wetdrymix));

    return CommandPayload.fromPairs16(
      category: CommandCategory.mic,
      cmdId: MicCommand.plateReverbEffects.value,
      operation: CommandOperation.set,
      pairs: pairs,
    );
  }

  /// Set MIC feedback cancel (CmdId 0x08)
  /// 
  /// Index mapping:
  /// - 1: enable (0=disable, 1=enable)
  static CommandPayload setFeedbackCancel(bool enable) {
    return CommandPayload.fromPairs(
      category: CommandCategory.mic,
      cmdId: MicCommand.feedbackCancel.value,
      operation: CommandOperation.set,
      pairs: [
        IndexValuePair(1, enable ? 1 : 0),
      ],
    );
  }
}
