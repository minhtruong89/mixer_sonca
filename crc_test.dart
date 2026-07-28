import 'dart:typed_data';

List<int> calculateCrc16(List<int> data) {
  const int polynomial = 0x8408; // Reversed 0x1021
  int crc = 0x6363; // Initial value

  for (final byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      if ((crc & 0x0001) != 0) {
        crc = (crc >> 1) ^ polynomial;
      } else {
        crc >>= 1;
      }
    }
  }
  return [crc & 0xFF, (crc >> 8) & 0xFF];
}

void main() {
  final frame = [0xAA, 0x01, 0x01, 0x02, 0x10, 0x00, 0x01, 0x00, 0x00, 0x02, 0x01, 0x04, 0x02, 0x32, 0x4B, 0x03, 0x40, 0x1F, 0x04, 0x32, 0x4B, 0x00, 0xE8, 0x37];
  final crc = calculateCrc16(frame);
  print('Calculated CRC: 0x${crc[0].toRadixString(16).padLeft(2, '0').toUpperCase()} 0x${crc[1].toRadixString(16).padLeft(2, '0').toUpperCase()}');
  print('Expected CRC: 0x6C 0xA7');
}
