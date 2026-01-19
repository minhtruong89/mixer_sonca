# Protocol Helper - Quick Reference Guide

## Three Ways to Send Commands

### ✅ APPROACH 1: ProtocolHelper (RECOMMENDED - Most Readable)

**Best for:** Most use cases - simple, readable, type-safe

```dart
import 'package:mixer_sonca/features/ble/protocol/protocol_helper.dart';

final helper = getIt<ProtocolHelper>();

// Set app mode to Line In
final command = helper.setAppMode(AppModeValue.lineIn);
await _sendProtocolCommand(command);

// Set MIC volume
final command = helper.setMicVolume(
  mic1Volume: 0.8,
  mic1Mute: false,
  mic2Volume: 0.75,
);
await _sendProtocolCommand(command);

// Set MIC EQ band
final command = helper.setMicEqBand(
  band: 0,
  enable: true,
  type: EqFilterTypeValue.peaking,
  frequency: 1000,
  q: 0.707,
  gain: 3.5,
);
await _sendProtocolCommand(command);
```

**Advantages:**
- ✅ No magic numbers
- ✅ Auto-complete friendly
- ✅ Type-safe (enums instead of integers)
- ✅ Self-documenting code
- ✅ Easy to remember

---

### APPROACH 2: DynamicCommandBuilder with Constants

**Best for:** When you need more flexibility but still want readability

```dart
import 'package:mixer_sonca/features/ble/protocol/dynamic_command_builder.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_helper.dart'; // For constants

final builder = getIt<DynamicCommandBuilder>();

// Set app mode to Line In
final command = builder.buildCommand(
  categoryName: 'SYSTEM',
  cmdId: SystemCmd.appMode,  // Constant instead of 0x01
  operation: CommandOperation.set,
  parameters: {
    'app_mode': AppModeValue.lineIn.value, // Enum instead of 2
  },
);
await _sendProtocolCommand(command);
```

**Advantages:**
- ✅ More flexible than helper methods
- ✅ Still uses readable constants
- ✅ Can send custom parameters

---

### APPROACH 3: Fully Dynamic (Maximum Flexibility)

**Best for:** When protocol changes frequently or you need maximum flexibility

```dart
final builder = getIt<DynamicCommandBuilder>();

// Set app mode to Line In
final command = builder.buildCommand(
  categoryName: 'SYSTEM',
  cmdId: 0x01,
  operation: CommandOperation.set,
  parameters: {
    'app_mode': 2, // Line In
  },
);
await _sendProtocolCommand(command);
```

**Advantages:**
- ✅ Maximum flexibility
- ✅ Works even if constants not defined
- ✅ Protocol updates without code changes

---

## Available Helper Methods

### SYSTEM Category

```dart
// Set app mode
helper.setAppMode(AppModeValue.lineIn);
helper.setAppMode(AppModeValue.bluetooth);
helper.setAppMode(AppModeValue.optical);

// Set master volume
helper.setMasterVolume(gain: 0.8, mute: false);
```

### MIC Category

```dart
// Set volume
helper.setMicVolume(
  mic1Volume: 0.8,
  mic1Mute: false,
  mic2Volume: 0.75,
  mic2Mute: false,
  masterVolume: 0.9,
);

// Set effects volume
helper.setMicEffectsVolume(
  bassGain: 0.0,
  middleGain: 0.0,
  trebGain: 0.0,
  echoGain: 0.5,
  reverbGain: 0.3,
);

// Set feedback cancel
helper.setMicFeedbackCancel(true);  // Enable
helper.setMicFeedbackCancel(false); // Disable

// Set EQ band
helper.setMicEqBand(
  band: 0,
  enable: true,
  type: EqFilterTypeValue.peaking,
  frequency: 1000,
  q: 0.707,
  gain: 3.5,
);
```

### MUSIC Category

```dart
// Set volume
helper.setMusicVolume(
  inVolume: 0.8,
  inMute: false,
  outVolume: 0.9,
  outMute: false,
  bassGain: 0.0,
  middleGain: 0.0,
  trebGain: 0.0,
);

// Set boost bass
helper.setMusicBoostBass(
  cutoffFreq: 100,
  intensity: 50,
  enhanced: 1,
  enable: true,
);
```

### GUITAR Category

```dart
// Set volume
helper.setGuitarVolume(volume: 0.8, mute: false);
```

---

## Available Constants

### Command IDs

```dart
// SYSTEM
SystemCmd.appMode        // 0x01
SystemCmd.masterVolume   // 0x02

// MIC
MicCmd.volume            // 0x01
MicCmd.effectsVolume     // 0x02
MicCmd.echoEffects       // 0x03
MicCmd.reverbEffects     // 0x04
MicCmd.plateReverbEffects // 0x05
MicCmd.eqIn              // 0x06
MicCmd.eqOut             // 0x07
MicCmd.feedbackCancel    // 0x08

// MUSIC
MusicCmd.volume          // 0x01
MusicCmd.eqIn            // 0x02
MusicCmd.eqOut           // 0x03
MusicCmd.boostBass       // 0x04
MusicCmd.exciter         // 0x05

// RECORD
RecordCmd.volume         // 0x01
RecordCmd.eq             // 0x02

// GUITAR
GuitarCmd.volume         // 0x01
GuitarCmd.eq             // 0x02
GuitarCmd.pingpong       // 0x03
GuitarCmd.chorus         // 0x04
GuitarCmd.autoWah        // 0x05
```

### App Mode Values

```dart
AppModeValue.bluetooth   // 1
AppModeValue.lineIn      // 2
AppModeValue.optical     // 3
AppModeValue.soundCard   // 4
AppModeValue.hdmi        // 5
AppModeValue.usb         // 6

// Get string representation
AppModeValue.lineIn.toString() // "Line In"
```

### EQ Filter Types

```dart
EqFilterTypeValue.unknown         // -1
EqFilterTypeValue.peaking         // 0
EqFilterTypeValue.lowShelf        // 1
EqFilterTypeValue.highShelf       // 2
EqFilterTypeValue.lowPass         // 3
EqFilterTypeValue.highPass        // 4
EqFilterTypeValue.bandPass        // 5
EqFilterTypeValue.notch           // 6
EqFilterTypeValue.lowPassOrder1   // 7
EqFilterTypeValue.highPassOrder1  // 8

// Get string representation
EqFilterTypeValue.peaking.toString() // "Peaking"
```

---

## Comparison Table

| Feature | Helper | Builder + Constants | Fully Dynamic |
|---------|--------|---------------------|---------------|
| Readability | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |
| Type Safety | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Flexibility | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Auto-complete | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Easy to Remember | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐ |

---

## Recommendation

**For most use cases, use APPROACH 1 (ProtocolHelper):**

```dart
// ✅ GOOD - Easy to read and remember
final helper = getIt<ProtocolHelper>();
final command = helper.setAppMode(AppModeValue.lineIn);
await _sendProtocolCommand(command);
```

**Instead of:**

```dart
// ❌ HARD TO REMEMBER - What is 0x01? What is 2?
final builder = getIt<DynamicCommandBuilder>();
final command = builder.buildCommand(
  categoryName: 'SYSTEM',
  cmdId: 0x01,  // What command is this?
  operation: CommandOperation.set,
  parameters: {
    'app_mode': 2, // What mode is this?
  },
);
await _sendProtocolCommand(command);
```

---

## Adding New Helper Methods

If you need a helper method that doesn't exist yet, you can add it to `protocol_helper.dart`:

```dart
// Example: Add a new helper for MIC echo effects
CommandPayload setMicEchoEffects({
  int? fc,
  int? attenuation,
  int? delay,
  int? dry,
  int? wet,
}) {
  final params = <String, dynamic>{};
  if (fc != null) params['fc'] = fc;
  if (attenuation != null) params['attenuation'] = attenuation;
  if (delay != null) params['delay'] = delay;
  if (dry != null) params['dry'] = dry;
  if (wet != null) params['wet'] = wet;

  return _builder.buildCommand(
    categoryName: 'MIC',
    cmdId: MicCmd.echoEffects,
    operation: CommandOperation.set,
    parameters: params,
  );
}
```

Then use it:

```dart
final command = helper.setMicEchoEffects(
  fc: 1000,
  attenuation: 50,
  delay: 200,
  dry: 80,
  wet: 20,
);
```
