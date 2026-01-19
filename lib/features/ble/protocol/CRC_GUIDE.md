# CRC16 Calculation - Code Location Guide

## Overview

CRC16 is calculated using the **ISO/IEC 14443-3 Type A (CRC-A)** algorithm and is used to verify data integrity in BLE communication.

---

## Where CRC is Calculated

### 📍 Location 1: CRC Calculation Algorithm

**File:** [`crc16.dart`](file:///e:/FlutterWorkplace/mixer_sonca/lib/features/ble/protocol/crc16.dart)

**Function:** `calculateCrc16(List<int> data)`

**Lines:** 12-33

```dart
List<int> calculateCrc16(List<int> data) {
  const int polynomial = 0x1021;
  int crc = 0x6363; // Initial value for CRC-A

  // ============ CRC CALCULATION STARTS HERE ============
  // Process each byte in the data (header + payload)
  for (final byte in data) {
    // XOR the byte into the upper byte of the CRC
    crc ^= (byte << 8);
    
    // Process each bit
    for (int i = 0; i < 8; i++) {
      // If the MSB is set, shift and XOR with polynomial
      if ((crc & 0x8000) != 0) {
        crc = ((crc << 1) ^ polynomial) & 0xFFFF;
      } else {
        // Otherwise just shift
        crc = (crc << 1) & 0xFFFF;
      }
    }
  }
  // ============ CRC CALCULATION ENDS HERE ============

  // Return CRC as 2 bytes: LSB first, then MSB (little-endian)
  // Example: if crc = 0x1234, returns [0x34, 0x12]
  return [crc & 0xFF, (crc >> 8) & 0xFF];
}
```

**What it does:**
- Takes input data (header + payload)
- Processes each byte using CRC-A algorithm
- Returns 2-byte CRC: [LSB, MSB]

---

### 📍 Location 2: CRC Appended to Frame (Sending)

**File:** [`protocol_frame.dart`](file:///e:/FlutterWorkplace/mixer_sonca/lib/features/ble/protocol/protocol_frame.dart)

**Function:** `ProtocolFrame.encode()`

**Lines:** 107-129

```dart
List<int> encode() {
  // Step 1: Encode header to bytes (8 bytes)
  final headerBytes = header.encode();
  
  // Step 2: Combine header + payload (this is what CRC covers)
  final frameWithoutCrc = [...headerBytes, ...payload];
  
  // ============ CRC CALCULATION HAPPENS HERE ============
  // Step 3: Calculate CRC16 over header + payload
  // This calls crc16.dart -> calculateCrc16()
  // Returns 2 bytes: [CRC_LSB, CRC_MSB]
  final crcBytes = calculateCrc16(frameWithoutCrc);
  // ============ CRC CALCULATION COMPLETE ============
  
  // Step 4: Append CRC to the end of the frame
  // Final frame: [Header][Payload][CRC_LSB][CRC_MSB]
  return [...frameWithoutCrc, ...crcBytes];
}
```

**What it does:**
- Encodes header (8 bytes)
- Combines header + payload
- **Calculates CRC** over header + payload
- Appends CRC to the end
- Returns complete frame ready to send

**Frame Structure:**
```
[Header (8 bytes)] + [Payload (N bytes)] + [CRC16 (2 bytes)]
```

---

### 📍 Location 3: CRC Verification (Receiving)

**File:** [`protocol_frame.dart`](file:///e:/FlutterWorkplace/mixer_sonca/lib/features/ble/protocol/protocol_frame.dart)

**Function:** `ProtocolFrame.decode(List<int> bytes)`

**Lines:** 132-163

```dart
static ProtocolFrame decode(List<int> bytes) {
  if (bytes.length < kHeaderSize + kCrcSize) {
    throw Exception('Frame too short: ${bytes.length} bytes');
  }

  // ============ CRC VERIFICATION HAPPENS HERE ============
  // Verify CRC before processing the frame
  // This extracts the last 2 bytes (received CRC) and compares with calculated CRC
  // Calculation: CRC over bytes[0..N-2], compare with bytes[N-1..N]
  if (!verifyCrc16(bytes)) {
    throw Exception('CRC validation failed');
  }
  // ============ CRC VERIFICATION COMPLETE ============

  // Extract header (first 8 bytes)
  final headerBytes = bytes.sublist(0, kHeaderSize);
  final header = FrameHeader.decode(headerBytes);

  // Extract payload (middle bytes) and CRC (last 2 bytes)
  final payload = bytes.sublist(kHeaderSize, kHeaderSize + header.length);
  final crc = bytes.sublist(bytes.length - kCrcSize);

  return ProtocolFrame(
    header: header,
    payload: payload,
    crc: crc,
  );
}
```

**What it does:**
- Receives complete frame from BLE
- **Verifies CRC** before processing
- Throws exception if CRC is invalid
- Extracts header, payload, and CRC

---

### 📍 Location 4: CRC Verification Function

**File:** [`crc16.dart`](file:///e:/FlutterWorkplace/mixer_sonca/lib/features/ble/protocol/crc16.dart)

**Function:** `verifyCrc16(List<int> data)`

**Lines:** 35-63

```dart
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
```

**What it does:**
- Splits received data into payload and CRC
- Calculates expected CRC from payload
- Compares received CRC with expected CRC
- Returns true if they match

---

## CRC Flow Diagram

### Sending Data (Encoding)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Create Command                                       │
│    CommandPayload.encode()                              │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Build Frame                                          │
│    ProtocolFrame.encode()                               │
│    - Encode header (8 bytes)                            │
│    - Combine header + payload                           │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 3. ⚡ CALCULATE CRC ⚡                                   │
│    calculateCrc16(header + payload)                     │
│    - Process each byte with CRC-A algorithm             │
│    - Returns [CRC_LSB, CRC_MSB]                         │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 4. Append CRC                                           │
│    [Header][Payload][CRC_LSB][CRC_MSB]                  │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 5. Send via BLE                                         │
│    sendDataToBLE(frameBytes)                            │
└─────────────────────────────────────────────────────────┘
```

### Receiving Data (Decoding)

```
┌─────────────────────────────────────────────────────────┐
│ 1. Receive from BLE                                     │
│    [Header][Payload][CRC_LSB][CRC_MSB]                  │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 2. ⚡ VERIFY CRC ⚡                                      │
│    verifyCrc16(receivedBytes)                           │
│    - Extract received CRC (last 2 bytes)                │
│    - Calculate expected CRC from payload                │
│    - Compare: received == expected?                     │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
           ┌───────┴───────┐
           │               │
           ▼               ▼
    ┌──────────┐    ┌──────────┐
    │ CRC OK   │    │ CRC FAIL │
    └────┬─────┘    └────┬─────┘
         │               │
         ▼               ▼
┌─────────────┐   ┌─────────────┐
│ 3. Decode   │   │ Throw Error │
│    Frame    │   │ "CRC failed"│
└─────────────┘   └─────────────┘
```

---

## CRC Algorithm Details

**Algorithm:** ISO/IEC 14443-3 Type A (CRC-A)

**Parameters:**
- **Polynomial:** `0x1021` (x^16 + x^12 + x^5 + 1)
- **Initial Value:** `0x6363`
- **Byte Order:** Little-endian (LSB first)
- **Coverage:** Header + Payload
- **Size:** 2 bytes

**Example Calculation:**

Input data:
```
[0xAA, 0x01, 0x01, 0x00, 0x07, 0x00, 0x01, 0x00, 0x04, 0x01, 0x01, 0x02, 0x01, 0x01, 0x02]
 └─────────────── Header (8 bytes) ──────────────┘ └──────── Payload (7 bytes) ────────┘
```

CRC calculation:
1. Start with `crc = 0x6363`
2. Process each byte with XOR and shift operations
3. Result: `crc = 0x1234` (example)
4. Return: `[0x34, 0x12]` (LSB first)

Final frame:
```
[0xAA, 0x01, 0x01, 0x00, 0x07, 0x00, 0x01, 0x00, 0x04, 0x01, 0x01, 0x02, 0x01, 0x01, 0x02, 0x34, 0x12]
 └─────────────── Header (8 bytes) ──────────────┘ └──────── Payload (7 bytes) ────────┘ └─ CRC ─┘
```

---

## Quick Reference

| Action | File | Function | Line |
|--------|------|----------|------|
| **Calculate CRC** | `crc16.dart` | `calculateCrc16()` | 12-33 |
| **Append CRC (Send)** | `protocol_frame.dart` | `encode()` | 107-129 |
| **Verify CRC (Receive)** | `protocol_frame.dart` | `decode()` | 132-163 |
| **CRC Verification Logic** | `crc16.dart` | `verifyCrc16()` | 35-63 |

---

## Summary

**CRC is calculated in 2 places:**

1. **When sending** (encoding):
   - File: `protocol_frame.dart`
   - Function: `encode()`
   - Line: 119 → `final crcBytes = calculateCrc16(frameWithoutCrc);`

2. **When receiving** (decoding):
   - File: `protocol_frame.dart`
   - Function: `decode()`
   - Line: 138 → `if (!verifyCrc16(bytes))`

**The actual CRC algorithm is in:**
- File: `crc16.dart`
- Function: `calculateCrc16()`
- Lines: 12-33

All CRC-related code is clearly marked with comments:
```dart
// ============ CRC CALCULATION HAPPENS HERE ============
// ============ CRC VERIFICATION HAPPENS HERE ============
```
