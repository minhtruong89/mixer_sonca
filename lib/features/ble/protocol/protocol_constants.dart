/// Protocol constants and enums for BLE communication
library;

// Frame Header Constants
const int kMagicByte = 0xAA;
const int kProtocolVersion = 0x01;
const int kHeaderSize = 8;
const int kCrcSize = 2;
const int kMaxMtu = 256;

// Frame Types
enum FrameType {
  command(0x01),
  data(0x02);

  const FrameType(this.value);
  final int value;

  static FrameType fromValue(int value) {
    return FrameType.values.firstWhere((e) => e.value == value);
  }
}

// Frame Flags
class FrameFlags {
  static const int ackRequired = 0x01; // Bit 0
  static const int ackResponse = 0x02; // Bit 1
  static const int error = 0x04; // Bit 2
}

// Command Categories
enum CommandCategory {
  mic(0x01),
  music(0x02),
  record(0x03),
  system(0x04),
  guitar(0x05);

  const CommandCategory(this.value);
  final int value;

  static CommandCategory fromValue(int value) {
    return CommandCategory.values.firstWhere((e) => e.value == value);
  }
}

// Command Operations
enum CommandOperation {
  get(0x00),
  set(0x01),
  event(0x02);

  const CommandOperation(this.value);
  final int value;

  static CommandOperation fromValue(int value) {
    return CommandOperation.values.firstWhere((e) => e.value == value);
  }
}

// MIC Category Commands (0x01)
enum MicCommand {
  volume(0x01),
  effectsVolume(0x02),
  echoEffects(0x03),
  reverbEffects(0x04),
  plateReverbEffects(0x05),
  eqIn(0x06),
  eqOut(0x07),
  feedbackCancel(0x08);

  const MicCommand(this.value);
  final int value;
}

// MUSIC Category Commands (0x02)
enum MusicCommand {
  volume(0x01),
  eqIn(0x02),
  eqOut(0x03),
  boostBass(0x04),
  exciter(0x05);

  const MusicCommand(this.value);
  final int value;
}

// RECORD Category Commands (0x03)
enum RecordCommand {
  volume(0x01),
  eq(0x02);

  const RecordCommand(this.value);
  final int value;
}

// SYSTEM Category Commands (0x04)
enum SystemCommand {
  appMode(0x01),
  masterVolume(0x02);

  const SystemCommand(this.value);
  final int value;
}

// GUITAR Category Commands (0x05)
enum GuitarCommand {
  volume(0x01),
  eq(0x02),
  pingpong(0x03),
  chorus(0x04),
  autoWah(0x05);

  const GuitarCommand(this.value);
  final int value;
}

// System App Mode Values
enum AppMode {
  bluetooth(1),
  lineIn(2),
  optical(3),
  soundCard(4),
  hdmi(5),
  usb(6);

  const AppMode(this.value);
  final int value;

  static AppMode fromValue(int value) {
    return AppMode.values.firstWhere((e) => e.value == value);
  }
}

// ACK Status Codes
enum AckStatus {
  ok(0x00),
  unknownVersion(0x01),
  invalidCommand(0x02),
  invalidParameter(0x03),
  deviceError(0x04);

  const AckStatus(this.value);
  final int value;

  static AckStatus fromValue(int value) {
    return AckStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AckStatus.deviceError,
    );
  }
}
