/// Protocol frame structure and encoding/decoding
library;

import 'package:flutter/foundation.dart';
import 'protocol_constants.dart';
import 'crc16.dart';

/// Frame Header (Fixed 8 bytes)
class FrameHeader {
  final int magic; // 0xAA
  final int version; // Protocol version
  final FrameType type; // Command or Data
  final int flags; // ACK req, ACK resp, Error
  final int length; // Payload length (not including header)
  final int msgId; // Message ID for pairing request/response
  final int seq; // Segment sequence (0 for Command)

  const FrameHeader({
    required this.magic,
    required this.version,
    required this.type,
    required this.flags,
    required this.length,
    required this.msgId,
    required this.seq,
  });

  /// Create a frame header with default values
  factory FrameHeader.create({
    required FrameType type,
    required int length,
    required int msgId,
    int flags = 0,
    int seq = 0,
  }) {
    return FrameHeader(
      magic: kMagicByte,
      version: kProtocolVersion,
      type: type,
      flags: flags,
      length: length,
      msgId: msgId,
      seq: seq,
    );
  }

  /// Encode header to bytes (little-endian)
  List<int> encode() {
    return [
      magic,
      version,
      type.value,
      flags,
      length & 0xFF, // Length LSB
      (length >> 8) & 0xFF, // Length MSB
      msgId,
      seq,
    ];
  }

  /// Decode header from bytes
  static FrameHeader decode(List<int> bytes) {
    if (bytes.length < kHeaderSize) {
      throw Exception('Invalid header size: ${bytes.length}');
    }

    final magic = bytes[0];
    if (magic != kMagicByte) {
      throw Exception('Invalid magic byte: 0x${magic.toRadixString(16)}');
    }

    final version = bytes[1];
    if (version != kProtocolVersion) {
      throw Exception('Unsupported protocol version: 0x${version.toRadixString(16)}');
    }

    return FrameHeader(
      magic: magic,
      version: version,
      type: FrameType.fromValue(bytes[2]),
      flags: bytes[3],
      length: bytes[4] | (bytes[5] << 8), // Little-endian
      msgId: bytes[6],
      seq: bytes[7],
    );
  }

  @override
  String toString() {
    return 'FrameHeader(magic: 0x${magic.toRadixString(16)}, version: 0x${version.toRadixString(16)}, '
        'type: $type, flags: 0x${flags.toRadixString(16)}, length: $length, msgId: $msgId, seq: $seq)';
  }
}

/// Complete Protocol Frame
class ProtocolFrame {
  final FrameHeader header;
  final List<int> payload;
  final List<int>? crc; // Optional for encoding, required for decoding

  const ProtocolFrame({
    required this.header,
    required this.payload,
    this.crc,
  });

  /// Encode frame to bytes with CRC
  /// 
  /// Frame structure:
  /// [Header (8 bytes)] + [Payload (N bytes)] + [CRC16 (2 bytes)]
  /// 
  /// CRC is calculated over: Header + Payload
  /// CRC is appended as: [LSB, MSB]
  List<int> encode() {
    // Step 1: Encode header to bytes (8 bytes)
    final headerBytes = header.encode();
    //debugPrint('Header Bytes: ${headerBytes.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}');
    //debugPrint('Payload Bytes: ${payload.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}');
    
    // Step 2: Combine header + payload (this is what CRC covers)
    final frameWithoutCrc = [...headerBytes, ...payload];
    //debugPrint('Frame Without CRC: ${frameWithoutCrc.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}');
    
    // ============ CRC CALCULATION HAPPENS HERE ============
    // Step 3: Calculate CRC16 over header + payload
    // This calls crc16.dart -> calculateCrc16()
    // Returns 2 bytes: [CRC_LSB, CRC_MSB]
    final crcBytes = calculateCrc16(frameWithoutCrc);
    //debugPrint('CRC Bytes: ${crcBytes.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}');
    // ============ CRC CALCULATION COMPLETE ============
    
    // Step 4: Append CRC to the end of the frame
    // Final frame: [Header][Payload][CRC_LSB][CRC_MSB]
    final completeFrame = [...frameWithoutCrc, ...crcBytes];
    debugPrint('Complete Frame: ${completeFrame.map((b) => '0x${b.toRadixString(16).toUpperCase().padLeft(2, '0')}').join(', ')}');
    return completeFrame;
  }

  /// Decode frame from bytes with CRC validation
  /// 
  /// Incoming frame structure:
  /// [Header (8 bytes)] + [Payload (N bytes)] + [CRC16 (2 bytes)]
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

    // Validate payload length
    final expectedPayloadLength = header.length;
    final actualPayloadLength = bytes.length - kHeaderSize - kCrcSize;
    
    if (expectedPayloadLength != actualPayloadLength) {
      throw Exception('Payload length mismatch: expected $expectedPayloadLength, got $actualPayloadLength');
    }

    // Extract payload (middle bytes) and CRC (last 2 bytes)
    final payload = bytes.sublist(kHeaderSize, kHeaderSize + header.length);
    final crc = bytes.sublist(bytes.length - kCrcSize);

    return ProtocolFrame(
      header: header,
      payload: payload,
      crc: crc,
    );
  }

  /// Get total frame size
  int get totalSize => kHeaderSize + payload.length + kCrcSize;

  /// Check if frame fits within MTU
  bool fitsInMtu() => totalSize <= kMaxMtu;

  @override
  String toString() {
    return 'ProtocolFrame(header: $header, payloadSize: ${payload.length}, totalSize: $totalSize)';
  }
}
