# Dynamic Protocol System - Usage Examples

This document demonstrates how to use the dynamic protocol system to send commands to the BLE device.

## Overview

The dynamic protocol system loads protocol definitions from a remote JSON file at app startup, eliminating all hardcoded values. Commands are built dynamically using parameter names from the JSON definition.

**JSON URL:** `http://data.soncamedia.com/firmware/smartbox/ble_android_comm_format.json`

## Basic Usage

### 1. Get the Dynamic Command Builder

```dart
import 'package:mixer_sonca/features/ble/protocol/dynamic_command_builder.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_constants.dart';
import 'package:mixer_sonca/injection.dart';

final builder = getIt<DynamicCommandBuilder>();
```

### 2. Build and Send Commands

## SYSTEM Category Examples

### Set App Mode to Line In
```dart
final command = builder.buildCommand(
  categoryName: 'SYSTEM',
  cmdId: 0x01,
  operation: CommandOperation.set,
  parameters: {
    'app_mode': 2, // 2 = Line In (from JSON valueMap)
  },
);
await _sendProtocolCommand(command);
```

### Set App Mode to Bluetooth
```dart
final command = builder.buildCommand(
  categoryName: 'SYSTEM',
  cmdId: 0x01,
  operation: CommandOperation.set,
  parameters: {
    'app_mode': 1, // 1 = Bluetooth
  },
);
await _sendProtocolCommand(command);
```

### Set Master Volume
```dart
final command = builder.buildCommand(
  categoryName: 'SYSTEM',
  cmdId: 0x02,
  operation: CommandOperation.set,
  parameters: {
    'dac_gain': 0.5, // Q8.8 format - automatically converted
    'dac_mute': 0,   // 0 = unmute, 1 = mute
  },
);
await _sendProtocolCommand(command);
```

---

## MIC Category Examples

### Set MIC Volume
```dart
final command = builder.buildCommand(
  categoryName: 'MIC',
  cmdId: 0x01,
  operation: CommandOperation.set,
  parameters: {
    'mic1_volume': 0.8,  // Q8.8 format (0.0 to 1.0 range)
    'mic1_mute': 0,      // 0 = unmute
    'mic2_volume': 0.75,
    'mic2_mute': 0,
    'mic_master_volume': 0.9,
  },
);
await _sendProtocolCommand(command);
```

### Set MIC Effects Volume
```dart
final command = builder.buildCommand(
  categoryName: 'MIC',
  cmdId: 0x02,
  operation: CommandOperation.set,
  parameters: {
    'mic_bass_gain': 0.0,    // Q8.8 format
    'mic_middle_gain': 0.0,
    'mic_treb_gain': 0.0,
    'mic_echo_gain': 0.5,
    'mic_reverb_gain': 0.3,
  },
);
await _sendProtocolCommand(command);
```

### Set MIC Echo Effects
```dart
final command = builder.buildCommand(
  categoryName: 'MIC',
  cmdId: 0x03,
  operation: CommandOperation.set,
  parameters: {
    'fc': 1000,           // int16
    'attenuation': 50,    // int16
    'delay': 200,         // int16
    'dry': 80,            // int16
    'wet': 20,            // int16
  },
);
await _sendProtocolCommand(command);
```

### Set MIC Reverb Effects
```dart
final command = builder.buildCommand(
  categoryName: 'MIC',
  cmdId: 0x04,
  operation: CommandOperation.set,
  parameters: {
    'dry_scale': 80,      // int16
    'wet_scale': 20,      // int16
    'roomsize_scale': 50, // int16
    'damping_scale': 50,  // int16
  },
);
await _sendProtocolCommand(command);
```

### Enable/Disable Feedback Cancel
```dart
final command = builder.buildCommand(
  categoryName: 'MIC',
  cmdId: 0x08,
  operation: CommandOperation.set,
  parameters: {
    'enable': 1, // 1 = enable, 0 = disable
  },
);
await _sendProtocolCommand(command);
```

---

## EQ Commands (10-Band Equalizer)

### Set Single EQ Band
```dart
// Set band 0, gain to +3.5 dB
final command = builder.buildEqCommand(
  categoryName: 'MIC',
  cmdId: 0x06, // eq_in
  band: 0,
  fields: {
    'enable': 1,      // uint16
    'type': 0,        // int16 (0 = PEAKING)
    'f0': 100,        // uint16 (frequency in Hz)
    'Q': 0.707,       // Q8.8 format
    'gain': 3.5,      // Q8.8 format (dB)
  },
);
await _sendProtocolCommand(command);
```

### Set Multiple EQ Bands
```dart
final command = builder.buildMultiBandEqCommand(
  categoryName: 'MIC',
  cmdId: 0x06, // eq_in
  bands: {
    0: {'gain': 3.5, 'enable': 1},   // Band 0: +3.5 dB
    1: {'gain': -2.0, 'enable': 1},  // Band 1: -2.0 dB
    2: {'gain': 1.5, 'enable': 1},   // Band 2: +1.5 dB
  },
);
await _sendProtocolCommand(command);
```

### Configure Complete EQ Band
```dart
final command = builder.buildEqCommand(
  categoryName: 'MUSIC',
  cmdId: 0x02, // eq_in
  band: 5,
  fields: {
    'enable': 1,
    'type': 1,      // 1 = LOW_SHELF
    'f0': 80,       // 80 Hz
    'Q': 0.707,     // Q factor
    'gain': 6.0,    // +6 dB boost
  },
);
await _sendProtocolCommand(command);
```

---

## MUSIC Category Examples

### Set Music Volume
```dart
final command = builder.buildCommand(
  categoryName: 'MUSIC',
  cmdId: 0x01,
  operation: CommandOperation.set,
  parameters: {
    'music_in_volume': 0.8,   // Q8.8
    'music_in_mute': 0,
    'music_out_volume': 0.9,  // Q8.8
    'music_out_mute': 0,
    'music_bass_gain': 0.0,   // Q8.8
    'music_middle_gain': 0.0, // Q8.8
    'music_treb_gain': 0.0,   // Q8.8
  },
);
await _sendProtocolCommand(command);
```

### Set Music Boost Bass
```dart
final command = builder.buildCommand(
  categoryName: 'MUSIC',
  cmdId: 0x04,
  operation: CommandOperation.set,
  parameters: {
    'f_cut': 100,      // int16 (cutoff frequency)
    'intensity': 50,   // int16
    'enhanced': 1,     // int16
    'enable': 1,       // uint16
  },
);
await _sendProtocolCommand(command);
```

### Set Music Exciter
```dart
final command = builder.buildCommand(
  categoryName: 'MUSIC',
  cmdId: 0x05,
  operation: CommandOperation.set,
  parameters: {
    'f_cut': 5000,  // int16
    'dry': 70,      // int16
    'wet': 30,      // int16
    'enable': 1,    // uint16
  },
);
await _sendProtocolCommand(command);
```

---

## RECORD Category Examples

### Set Record Volume
```dart
final command = builder.buildCommand(
  categoryName: 'RECORD',
  cmdId: 0x01,
  operation: CommandOperation.set,
  parameters: {
    'record_in_volume': 0.8,  // Q8.8
    'record_out_volume': 0.9, // Q8.8
    'record_mute': 0,         // uint16
  },
);
await _sendProtocolCommand(command);
```

---

## GUITAR Category Examples

### Set Guitar Volume
```dart
final command = builder.buildCommand(
  categoryName: 'GUITAR',
  cmdId: 0x01,
  operation: CommandOperation.set,
  parameters: {
    'volume_gain': 0.8, // Q8.8
    'mute': 0,          // uint16
  },
);
await _sendProtocolCommand(command);
```

### Set Guitar Pingpong Effect
```dart
final command = builder.buildCommand(
  categoryName: 'GUITAR',
  cmdId: 0x03,
  operation: CommandOperation.set,
  parameters: {
    'attenuation': 50,         // int16
    'delay': 200,              // int16
    'high_quality_enable': 1,  // uint16
    'wetdrymix': 50,           // int16
    'max_delay': 500,          // int16
  },
);
await _sendProtocolCommand(command);
```

### Set Guitar Chorus Effect
```dart
final command = builder.buildCommand(
  categoryName: 'GUITAR',
  cmdId: 0x04,
  operation: CommandOperation.set,
  parameters: {
    'delay_length': 10,  // int16
    'mod_depth': 5,      // int16
    'mod_rate': 2,       // int16
    'feedback': 30,      // int16
    'dry': 70,           // int16
    'wet': 30,           // int16
  },
);
await _sendProtocolCommand(command);
```

### Set Guitar Auto Wah Effect
```dart
final command = builder.buildCommand(
  categoryName: 'GUITAR',
  cmdId: 0x05,
  operation: CommandOperation.set,
  parameters: {
    'modulation_rate': 5,   // int16
    'min_frequency': 200,   // int16
    'max_frequency': 2000,  // int16
    'depth': 50,            // int16
    'dry': 50,              // int16
    'wet': 50,              // int16
  },
);
await _sendProtocolCommand(command);
```

---

## Type Conversion

The system automatically handles type conversion based on the JSON definition:

### Q8.8 Fixed-Point Format
- **Type**: `q8_8_le`
- **Range**: -128.0 to 127.99609375
- **Usage**: Volume, gain parameters
- **Example**: `0.8` → `0x00CC` (204 in decimal)

### Signed 16-bit Integer
- **Type**: `int16_le`
- **Range**: -32768 to 32767
- **Usage**: Effect parameters, frequencies
- **Example**: `1000` → `0xE803` (little-endian)

### Unsigned 16-bit Integer
- **Type**: `uint16_le`
- **Range**: 0 to 65535
- **Usage**: Enable/disable flags, mute
- **Example**: `1` → `0x0100` (little-endian)

---

## EQ Filter Types

From JSON definition (`eqFilterTypes`):

| Name | Value | Description |
|------|-------|-------------|
| UNKNOWN | -1 | Unknown filter type |
| PEAKING | 0 | Peaking filter |
| LOW_SHELF | 1 | Low shelf filter |
| HIGH_SHELF | 2 | High shelf filter |
| LOW_PASS | 3 | Low pass filter |
| HIGH_PASS | 4 | High pass filter |
| BAND_PASS | 5 | Band pass filter |
| NOTCH | 6 | Notch filter |
| LOW_PASS_ORDER1 | 7 | 1st order low pass |
| HIGH_PASS_ORDER1 | 8 | 1st order high pass |

---

## Benefits of Dynamic Protocol

### ✅ No Hardcoded Values
- All IDs, indices, and types loaded from JSON
- Update protocol by changing JSON file on server
- No app rebuild required

### ✅ Type Safety
- Automatic type conversion (Q8.8, int16, uint16)
- Type validation at runtime
- Prevents encoding errors

### ✅ Maintainable
- Single source of truth (JSON file)
- Easy to add new commands
- Self-documenting through JSON structure

### ✅ Flexible
- Change parameter names without code changes
- Add new categories dynamically
- Modify index mappings on the fly

---

## Error Handling

```dart
try {
  final command = builder.buildCommand(
    categoryName: 'SYSTEM',
    cmdId: 0x01,
    operation: CommandOperation.set,
    parameters: {
      'app_mode': 2,
    },
  );
  await _sendProtocolCommand(command);
} catch (e) {
  debugPrint('Error building/sending command: $e');
}
```

---

## Updating the Protocol

To update the protocol definition:

1. **Update JSON file** on server: `http://data.soncamedia.com/firmware/smartbox/ble_android_comm_format.json`
2. **Restart app** - Protocol automatically reloads
3. **No code changes needed** - Commands use new definitions

Example: Adding a new parameter to MIC volume:
```json
{
  "indices": {
    "1": { "name": "mic1_volume", "type": "q8_8_le" },
    "2": { "name": "mic1_mute", "type": "uint16_le" },
    "6": { "name": "mic1_new_param", "type": "int16_le" }
  }
}
```

Then use it immediately:
```dart
final command = builder.buildCommand(
  categoryName: 'MIC',
  cmdId: 0x01,
  operation: CommandOperation.set,
  parameters: {
    'mic1_new_param': 100, // New parameter works immediately!
  },
);
```
