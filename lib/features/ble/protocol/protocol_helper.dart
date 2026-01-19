/// User-friendly protocol helpers for readable command building
library;

import 'package:flutter/foundation.dart';
import 'protocol_service.dart';
import 'protocol_constants.dart';
import 'command_payload.dart';
import 'dynamic_command_builder.dart';

/// Protocol command helper for easier, more readable command building
class ProtocolHelper {
  final DynamicCommandBuilder _builder;

  ProtocolHelper(this._builder, ProtocolService protocolService);

  // ==================== SYSTEM Commands ====================

  /// Set system app mode
  /// 
  /// Example:
  /// ```dart
  /// await helper.setAppMode(AppModeValue.lineIn);
  /// ```
  CommandPayload setAppMode(AppModeValue mode) {
    return _builder.buildCommand(
      categoryName: 'SYSTEM',
      cmdId: SystemCmd.appMode,
      operation: CommandOperation.set,
      parameters: {
        'app_mode': mode.value,
      },
    );
  }

  /// Set master volume
  /// 
  /// Example:
  /// ```dart
  /// await helper.setMasterVolume(gain: 0.8, mute: false);
  /// ```
  CommandPayload setMasterVolume({double? gain, bool? mute}) {
    final params = <String, dynamic>{};
    if (gain != null) params['dac_gain'] = gain;
    if (mute != null) params['dac_mute'] = mute ? 1 : 0;

    return _builder.buildCommand(
      categoryName: 'SYSTEM',
      cmdId: SystemCmd.masterVolume,
      operation: CommandOperation.set,
      parameters: params,
    );
  }

  // ==================== MIC Commands ====================

  /// Set MIC volume
  /// 
  /// Example:
  /// ```dart
  /// await helper.setMicVolume(
  ///   mic1Volume: 0.8,
  ///   mic1Mute: false,
  ///   mic2Volume: 0.75,
  /// );
  /// ```
  CommandPayload setMicVolume({
    double? mic1Volume,
    bool? mic1Mute,
    double? mic2Volume,
    bool? mic2Mute,
    double? masterVolume,
  }) {
    final params = <String, dynamic>{};
    if (mic1Volume != null) params['mic1_volume'] = mic1Volume;
    if (mic1Mute != null) params['mic1_mute'] = mic1Mute ? 1 : 0;
    if (mic2Volume != null) params['mic2_volume'] = mic2Volume;
    if (mic2Mute != null) params['mic2_mute'] = mic2Mute ? 1 : 0;
    if (masterVolume != null) params['mic_master_volume'] = masterVolume;

    return _builder.buildCommand(
      categoryName: 'MIC',
      cmdId: MicCmd.volume,
      operation: CommandOperation.set,
      parameters: params,
    );
  }

  /// Set MIC effects volume
  CommandPayload setMicEffectsVolume({
    double? bassGain,
    double? middleGain,
    double? trebGain,
    double? echoGain,
    double? reverbGain,
  }) {
    final params = <String, dynamic>{};
    if (bassGain != null) params['mic_bass_gain'] = bassGain;
    if (middleGain != null) params['mic_middle_gain'] = middleGain;
    if (trebGain != null) params['mic_treb_gain'] = trebGain;
    if (echoGain != null) params['mic_echo_gain'] = echoGain;
    if (reverbGain != null) params['mic_reverb_gain'] = reverbGain;

    return _builder.buildCommand(
      categoryName: 'MIC',
      cmdId: MicCmd.effectsVolume,
      operation: CommandOperation.set,
      parameters: params,
    );
  }

  /// Set MIC feedback cancel
  CommandPayload setMicFeedbackCancel(bool enable) {
    return _builder.buildCommand(
      categoryName: 'MIC',
      cmdId: MicCmd.feedbackCancel,
      operation: CommandOperation.set,
      parameters: {
        'enable': enable ? 1 : 0,
      },
    );
  }

  /// Set MIC EQ band
  /// 
  /// Example:
  /// ```dart
  /// await helper.setMicEqBand(
  ///   band: 0,
  ///   enable: true,
  ///   type: EqFilterTypeValue.peaking,
  ///   frequency: 1000,
  ///   q: 0.707,
  ///   gain: 3.5,
  /// );
  /// ```
  CommandPayload setMicEqBand({
    required int band,
    bool? enable,
    EqFilterTypeValue? type,
    int? frequency,
    double? q,
    double? gain,
  }) {
    final fields = <String, dynamic>{};
    if (enable != null) fields['enable'] = enable ? 1 : 0;
    if (type != null) fields['type'] = type.value;
    if (frequency != null) fields['f0'] = frequency;
    if (q != null) fields['Q'] = q;
    if (gain != null) fields['gain'] = gain;

    return _builder.buildEqCommand(
      categoryName: 'MIC',
      cmdId: MicCmd.eqIn,
      band: band,
      fields: fields,
    );
  }

  // ==================== MUSIC Commands ====================

  /// Set music volume
  CommandPayload setMusicVolume({
    double? inVolume,
    bool? inMute,
    double? outVolume,
    bool? outMute,
    double? bassGain,
    double? middleGain,
    double? trebGain,
  }) {
    final params = <String, dynamic>{};
    if (inVolume != null) params['music_in_volume'] = inVolume;
    if (inMute != null) params['music_in_mute'] = inMute ? 1 : 0;
    if (outVolume != null) params['music_out_volume'] = outVolume;
    if (outMute != null) params['music_out_mute'] = outMute ? 1 : 0;
    if (bassGain != null) params['music_bass_gain'] = bassGain;
    if (middleGain != null) params['music_middle_gain'] = middleGain;
    if (trebGain != null) params['music_treb_gain'] = trebGain;

    return _builder.buildCommand(
      categoryName: 'MUSIC',
      cmdId: MusicCmd.volume,
      operation: CommandOperation.set,
      parameters: params,
    );
  }

  /// Set music boost bass
  CommandPayload setMusicBoostBass({
    int? cutoffFreq,
    int? intensity,
    int? enhanced,
    bool? enable,
  }) {
    final params = <String, dynamic>{};
    if (cutoffFreq != null) params['f_cut'] = cutoffFreq;
    if (intensity != null) params['intensity'] = intensity;
    if (enhanced != null) params['enhanced'] = enhanced;
    if (enable != null) params['enable'] = enable ? 1 : 0;

    return _builder.buildCommand(
      categoryName: 'MUSIC',
      cmdId: MusicCmd.boostBass,
      operation: CommandOperation.set,
      parameters: params,
    );
  }

  // ==================== GUITAR Commands ====================

  /// Set guitar volume
  CommandPayload setGuitarVolume({double? volume, bool? mute}) {
    final params = <String, dynamic>{};
    if (volume != null) params['volume_gain'] = volume;
    if (mute != null) params['mute'] = mute ? 1 : 0;

    return _builder.buildCommand(
      categoryName: 'GUITAR',
      cmdId: GuitarCmd.volume,
      operation: CommandOperation.set,
      parameters: params,
    );
  }
}

// ==================== Command ID Constants ====================

/// SYSTEM category command IDs
class SystemCmd {
  static const int appMode = 0x01;
  static const int masterVolume = 0x02;
}

/// MIC category command IDs
class MicCmd {
  static const int volume = 0x01;
  static const int effectsVolume = 0x02;
  static const int echoEffects = 0x03;
  static const int reverbEffects = 0x04;
  static const int plateReverbEffects = 0x05;
  static const int eqIn = 0x06;
  static const int eqOut = 0x07;
  static const int feedbackCancel = 0x08;
}

/// MUSIC category command IDs
class MusicCmd {
  static const int volume = 0x01;
  static const int eqIn = 0x02;
  static const int eqOut = 0x03;
  static const int boostBass = 0x04;
  static const int exciter = 0x05;
}

/// RECORD category command IDs
class RecordCmd {
  static const int volume = 0x01;
  static const int eq = 0x02;
}

/// GUITAR category command IDs
class GuitarCmd {
  static const int volume = 0x01;
  static const int eq = 0x02;
  static const int pingpong = 0x03;
  static const int chorus = 0x04;
  static const int autoWah = 0x05;
}

// ==================== Value Enums (Dynamic from JSON) ====================

/// App mode values (loaded dynamically from JSON valueMap)
class AppModeValue {
  final String name;
  final int value;

  const AppModeValue._(this.name, this.value);

  // Static instances will be populated from JSON
  static AppModeValue? _bluetooth;
  static AppModeValue? _lineIn;
  static AppModeValue? _optical;
  static AppModeValue? _soundCard;
  static AppModeValue? _hdmi;
  static AppModeValue? _usb;

  static AppModeValue get bluetooth => _bluetooth ?? const AppModeValue._('Bluetooth', 1);
  static AppModeValue get lineIn => _lineIn ?? const AppModeValue._('LineIn', 2);
  static AppModeValue get optical => _optical ?? const AppModeValue._('Optical', 3);
  static AppModeValue get soundCard => _soundCard ?? const AppModeValue._('SoundCard', 4);
  static AppModeValue get hdmi => _hdmi ?? const AppModeValue._('HDMI', 5);
  static AppModeValue get usb => _usb ?? const AppModeValue._('USB', 6);

  /// Initialize from JSON protocol definition
  static void initializeFromProtocol(ProtocolService protocolService) {
    try {
      final systemCategory = protocolService.getCategoryByName('SYSTEM');
      final appModeCommand = systemCategory?.getCommand(0x01);
      final valueMap = appModeCommand?.valueMap;

      if (valueMap != null) {
        // Parse value map: {"1": "Bluetooth", "2": "LineIn", ...}
        valueMap.forEach((key, value) {
          final intValue = int.parse(key);
          final appMode = AppModeValue._(value, intValue);

          // Map to static instances
          switch (value.toLowerCase()) {
            case 'bluetooth':
              _bluetooth = appMode;
              break;
            case 'linein':
              _lineIn = appMode;
              break;
            case 'optical':
              _optical = appMode;
              break;
            case 'soundcard':
              _soundCard = appMode;
              break;
            case 'hdmi':
              _hdmi = appMode;
              break;
            case 'usb':
              _usb = appMode;
              break;
          }
        });
      }
    } catch (e) {
      debugPrint('Warning: Could not load AppModeValue from JSON: $e');
    }
  }

  @override
  String toString() => name;
}

/// EQ filter type values (loaded dynamically from JSON eqFilterTypes)
class EqFilterTypeValue {
  final String name;
  final int value;

  const EqFilterTypeValue._(this.name, this.value);

  // Static instances will be populated from JSON
  static EqFilterTypeValue? _unknown;
  static EqFilterTypeValue? _peaking;
  static EqFilterTypeValue? _lowShelf;
  static EqFilterTypeValue? _highShelf;
  static EqFilterTypeValue? _lowPass;
  static EqFilterTypeValue? _highPass;
  static EqFilterTypeValue? _bandPass;
  static EqFilterTypeValue? _notch;
  static EqFilterTypeValue? _lowPassOrder1;
  static EqFilterTypeValue? _highPassOrder1;

  static EqFilterTypeValue get unknown => _unknown ?? const EqFilterTypeValue._('UNKNOWN', -1);
  static EqFilterTypeValue get peaking => _peaking ?? const EqFilterTypeValue._('PEAKING', 0);
  static EqFilterTypeValue get lowShelf => _lowShelf ?? const EqFilterTypeValue._('LOW_SHELF', 1);
  static EqFilterTypeValue get highShelf => _highShelf ?? const EqFilterTypeValue._('HIGH_SHELF', 2);
  static EqFilterTypeValue get lowPass => _lowPass ?? const EqFilterTypeValue._('LOW_PASS', 3);
  static EqFilterTypeValue get highPass => _highPass ?? const EqFilterTypeValue._('HIGH_PASS', 4);
  static EqFilterTypeValue get bandPass => _bandPass ?? const EqFilterTypeValue._('BAND_PASS', 5);
  static EqFilterTypeValue get notch => _notch ?? const EqFilterTypeValue._('NOTCH', 6);
  static EqFilterTypeValue get lowPassOrder1 => _lowPassOrder1 ?? const EqFilterTypeValue._('LOW_PASS_ORDER1', 7);
  static EqFilterTypeValue get highPassOrder1 => _highPassOrder1 ?? const EqFilterTypeValue._('HIGH_PASS_ORDER1', 8);

  /// Initialize from JSON protocol definition
  static void initializeFromProtocol(ProtocolService protocolService) {
    try {
      final eqFilterTypes = protocolService.getEqFilterTypes();

      eqFilterTypes.forEach((key, eqType) {
        final filterType = EqFilterTypeValue._(eqType.name, eqType.value);

        // Map to static instances
        switch (eqType.name.toUpperCase()) {
          case 'UNKNOWN':
            _unknown = filterType;
            break;
          case 'PEAKING':
            _peaking = filterType;
            break;
          case 'LOW_SHELF':
            _lowShelf = filterType;
            break;
          case 'HIGH_SHELF':
            _highShelf = filterType;
            break;
          case 'LOW_PASS':
            _lowPass = filterType;
            break;
          case 'HIGH_PASS':
            _highPass = filterType;
            break;
          case 'BAND_PASS':
            _bandPass = filterType;
            break;
          case 'NOTCH':
            _notch = filterType;
            break;
          case 'LOW_PASS_ORDER1':
            _lowPassOrder1 = filterType;
            break;
          case 'HIGH_PASS_ORDER1':
            _highPassOrder1 = filterType;
            break;
        }
      });
    } catch (e) {
      debugPrint('Warning: Could not load EqFilterTypeValue from JSON: $e');
    }
  }

  @override
  String toString() => name;
}

