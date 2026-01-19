/// CRC16 calculation using custom LSB-first algorithm (matching C implementation)
library;

/// Check if CRC matches
bool checkCrc(List<int> data, List<int> expectedCrc) {
  final calculated = calculateCrc16(data);
  return calculated[0] == expectedCrc[0] && calculated[1] == expectedCrc[1];
}
///
/// Matches C implementation:
/// #define BLE_ANDROID_COMM_PROTOCOL_CRC_INIT       (0x6363U)
/// #define BLE_ANDROID_COMM_PROTOCOL_CRC_POLY       (0x8408U)
///
/// This is an LSB-first implementation (KERMIT/CCITT-REV style but with custom init)
List<int> calculateCrc16(List<int> data) {
  const int polynomial = 0x8408; // Reversed 0x1021
  int crc = 0x6363; // Initial value

  // ============ CRC CALCULATION STARTS HERE ============
  for (final byte in data) {
    // XOR byte into low byte of CRC
    crc ^= byte;
    
    for (int i = 0; i < 8; i++) {
      // Check LSB
      if ((crc & 0x0001) != 0) {
        // Shift right and XOR with polynomial
        crc = (crc >> 1) ^ polynomial;
      } else {
        // Just shift right
        crc >>= 1;
      }
    }
  }
  // ============ CRC CALCULATION ENDS HERE ============

  // Return CRC as 2 bytes: LSB first, then MSB (little-endian)
  return [crc & 0xFF, (crc >> 8) & 0xFF];
}

/// Verify CRC16 for received data
/// 
/// [data] includes the payload and the 2-byte CRC at the end
/// Returns true if CRC is valid
/// 
/// Example: data = [Header][Payload][CRC_LSB][CRC_MSB]
bool verifyCrc16(List<int> data) {
  if (data.length < 2) return false;

  // ============ CRC VERIFICATION PROCESS ============
  // Step 1: Split received data into payload and CRC
  // Payload = everything except last 2 bytes
  final payload = data.sublist(0, data.length - 2);
  // Received CRC = last 2 bytes [LSB, MSB]
  final receivedCrc = data.sublist(data.length - 2);

  // Step 2: Calculate what the CRC should be
  // This calls calculateCrc16() on the payload
  final expectedCrc = calculateCrc16(payload);

  // Step 3: Compare received CRC with calculated CRC
  // Both are 2-byte arrays: [LSB, MSB]
  // Returns true if they match (CRC is valid)
  return receivedCrc[0] == expectedCrc[0] && receivedCrc[1] == expectedCrc[1];
  // ============ CRC VERIFICATION COMPLETE ============
}
