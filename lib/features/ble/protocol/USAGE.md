# BLE Protocol Usage Examples

This document provides examples of how to use the BLE protocol implementation for sending commands to the mixer device.

## Overview

The protocol implementation provides a structured way to communicate with the BLE device using:
- **Frame encoding/decoding** with CRC16 validation
- **Command builders** for all categories (MIC, MUSIC, RECORD, SYSTEM, GUITAR)
- **ACK/Error handling** for reliable communication
- **Automatic message ID management**

## Basic Usage

### 1. SYSTEM Category Commands

#### Set App Mode to Line In
```dart
// Import the command builders
import 'protocol/commands/system_commands.dart';
import 'protocol/protocol_constants.dart';

// Send command to set app mode to Line In
await _sendProtocolCommand(SystemCommands.setAppMode(AppMode.lineIn));
```

#### Set App Mode to Bluetooth
```dart
await _sendProtocolCommand(SystemCommands.setAppMode(AppMode.bluetooth));
```

#### Set Master Volume
```dart
// Set DAC gain to 50 and unmute
await _sendProtocolCommand(
  SystemCommands.setMasterVolume(dacGain: 50, dacMute: 0)
);
```

#### Get Master Volume
```dart
await _sendProtocolCommand(SystemCommands.getMasterVolume());
```

### 2. MIC Category Commands

#### Set MIC Volume
```dart
import 'protocol/commands/mic_commands.dart';

// Set mic1 volume to 80 and unmute
await _sendProtocolCommand(
  MicCommands.setVolume(mic1Volume: 80, mic1Mute: 0)
);

// Set both mic volumes
await _sendProtocolCommand(
  MicCommands.setVolume(
    mic1Volume: 80,
    mic1Mute: 0,
    mic2Volume: 75,
    mic2Mute: 0,
    masterVolume: 90,
  )
);
```

#### Set MIC Effects Volume
```dart
// Set bass, middle, and treble gains
await _sendProtocolCommand(
  MicCommands.setEffectsVolume(
    bassGain: 100,
    middleGain: 100,
    trebGain: 100,
  )
);
```

#### Set Echo Effects
```dart
// Configure echo parameters
await _sendProtocolCommand(
  MicCommands.setEchoEffects(
    fc: 1000,
    attenuation: 50,
    delay: 200,
    dry: 80,
    wet: 20,
  )
);
```

#### Set Reverb Effects
```dart
// Configure reverb parameters
await _sendProtocolCommand(
  MicCommands.setReverbEffects(
    dryScale: 80,
    wetScale: 20,
    roomsizeScale: 50,
    dampingScale: 50,
  )
);
```

#### Enable/Disable Feedback Cancel
```dart
// Enable feedback cancellation
await _sendProtocolCommand(MicCommands.setFeedbackCancel(true));

// Disable feedback cancellation
await _sendProtocolCommand(MicCommands.setFeedbackCancel(false));
```

## Protocol Frame Structure

### Command Frame Example
When you send a command like `SystemCommands.setAppMode(AppMode.lineIn)`, the protocol builds a frame:

```
Header (8 bytes):
  [0] Magic: 0xAA
  [1] Version: 0x01
  [2] Type: 0x01 (Command)
  [3] Flags: 0x00 (no ACK required)
  [4-5] Length: payload length (little-endian)
  [6] MsgId: auto-incremented
  [7] Seq: 0x00

Payload (variable):
  [0] Category: 0x04 (SYSTEM)
  [1] CmdId: 0x01 (appMode)
  [2] Operation: 0x01 (SET)
  [3] PayloadLen: 0x02
  [4] Count: 0x01 (1 pair)
  [5] Index: 0x01 (app_mode index)
  [6] Value: 0x02 (Line In = 2)

CRC16 (2 bytes):
  [N-1] CRC LSB
  [N] CRC MSB
```

## Receiving Responses

The protocol automatically handles incoming frames:

1. **Notification Listener**: Set up automatically when connecting to device
2. **Frame Decoding**: Incoming bytes are decoded and CRC validated
3. **ACK Handling**: ACK responses are matched to pending requests
4. **Error Handling**: Error frames are logged with error codes

### Example Log Output

```
--- Protocol Send ---
Protocol: Sending command frame
Protocol: Category=CommandCategory.system, CmdId=0x1, Op=CommandOperation.set
Protocol: Frame size=17 bytes
Protocol: Data=0xAA 0x01 0x01 0x00 0x07 0x00 0x01 0x00 0x04 0x01 0x01 0x02 0x01 0x01 0x02 0xXX 0xXX
Protocol: Command sent successfully
-------------------------------------

Protocol: Received 15 bytes from BLE
Protocol: Raw data = 0xAA 0x01 0x01 0x02 0x03 0x00 0x02 0x00 0x00 0x04 0x01 0xXX 0xXX
Protocol: Received ACK
```

## App Mode Values

| Mode | Value | Description |
|------|-------|-------------|
| Bluetooth | 1 | Bluetooth audio input |
| Line In | 2 | Line-in audio input |
| Optical | 3 | Optical audio input |
| Sound Card | 4 | Sound card input |
| HDMI | 5 | HDMI audio input |
| USB | 6 | USB audio input |

## Error Codes

| Code | Status | Description |
|------|--------|-------------|
| 0x00 | OK | Command successful |
| 0x01 | Unknown Version | Protocol version not supported |
| 0x02 | Invalid Command | Command ID not recognized |
| 0x03 | Invalid Parameter | Parameter out of range |
| 0x04 | Device Error | Device-side error |

## Advanced Usage

### Requesting ACK
```dart
// Send command and wait for ACK response
await _sendProtocolCommand(
  SystemCommands.setAppMode(AppMode.lineIn),
  requireAck: true,
);
```

### Custom Command Payload
```dart
import 'protocol/command_payload.dart';

// Build a custom command with index-value pairs
final payload = CommandPayload.fromPairs(
  category: CommandCategory.system,
  cmdId: SystemCommand.appMode.value,
  operation: CommandOperation.set,
  pairs: [
    IndexValuePair(1, 2), // index=1, value=2 (Line In)
  ],
);

await _sendProtocolCommand(payload);
```

## Notes

- All multi-byte values use **little-endian** byte order
- CRC16 uses **ISO/IEC 14443-3 Type A** algorithm
- Maximum frame size is **256 bytes** (MTU)
- Message IDs auto-increment and wrap at 256
- Index-value pairs can be 8-bit or 16-bit depending on the command
