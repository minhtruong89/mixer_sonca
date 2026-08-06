/// Type conversion utilities for protocol data types
library;

/// Convert double to Q8.8 fixed-point format
int doubleToQ8_8(double value) {
  if (value < -128.0) value = -128.0;
  if (value > 127.99609375) value = 127.99609375;
  return ((value * 256).round()) & 0xFFFF;
}

/// Convert Q8.8 fixed-point format to double
double q8_8ToDouble(int value) {
  int signedValue = value;
  if (signedValue & 0x8000 != 0) {
    signedValue = signedValue - 0x10000;
  }
  return signedValue / 256.0;
}

/// Convert double to Q6.10 fixed-point format (range: 0 to 63.9990234375, resolution: 1/1024)
int doubleToQ6_10(double value) {
  if (value < 0.0) value = 0.0;
  if (value > 63.999) value = 63.999;
  return ((value * 1024).round()) & 0xFFFF;
}

/// Convert Q6.10 fixed-point format to double
double q6_10ToDouble(int value) {
  int val = value & 0xFFFF;
  return val / 1024.0;
}

/// Encode a value based on its type string
List<int> encodeValue(dynamic value, String type) {
  switch (type.toLowerCase()) {
    case 'q8_8_le':
      // Q8.8 fixed-point, little-endian
      final q88Value = value is double ? doubleToQ8_8(value) : (value as int);
      return [q88Value & 0xFF, (q88Value >> 8) & 0xFF];
    
    case 'q6_10_le':
      // Q6.10 fixed-point, little-endian
      final q610Value = value is double ? doubleToQ6_10(value) : (value as int);
      return [q610Value & 0xFF, (q610Value >> 8) & 0xFF];

    case 'int16_le':
    case 'uint16_le':
      // 16-bit integer, little-endian
      final intValue = value is double ? value.toInt() : (value as int);
      return [intValue & 0xFF, (intValue >> 8) & 0xFF];
    
    case 'uint8':
      // 8-bit unsigned integer
      final byteValue = value is double ? value.toInt() : (value as int);
      return [byteValue & 0xFF];
    
    default:
      throw Exception('Unsupported type: $type');
  }
}

/// Decode a value based on its type string
dynamic decodeValue(List<int> bytes, String type) {
  switch (type.toLowerCase()) {
    case 'q8_8_le':
      // Q8.8 fixed-point, little-endian
      if (bytes.length < 2) throw Exception('Insufficient bytes for Q8.8');
      final q88Value = bytes[0] | (bytes[1] << 8);
      return q8_8ToDouble(q88Value);
    
    case 'q6_10_le':
      // Q6.10 fixed-point, little-endian
      if (bytes.length < 2) throw Exception('Insufficient bytes for Q6.10');
      final q610Value = bytes[0] | (bytes[1] << 8);
      return q6_10ToDouble(q610Value);

    case 'int16_le':
      // Signed 16-bit integer, little-endian
      if (bytes.length < 2) throw Exception('Insufficient bytes for int16');
      int value = bytes[0] | (bytes[1] << 8);
      // Sign extend if negative to 64 bits by subtracting 65536
      if (value & 0x8000 != 0) {
        value = value - 0x10000;
      }
      return value;
    
    case 'uint16_le':
      // Unsigned 16-bit integer, little-endian
      if (bytes.length < 2) throw Exception('Insufficient bytes for uint16');
      return bytes[0] | (bytes[1] << 8);
    
    case 'uint8':
      // 8-bit unsigned integer
      if (bytes.isEmpty) throw Exception('Insufficient bytes for uint8');
      return bytes[0];
    
    default:
      throw Exception('Unsupported type: $type');
  }
}

/// Check if type is Q8.8 fixed-point
bool isQ8_8Type(String type) {
  return type.toLowerCase() == 'q8_8_le';
}

/// Check if type is Q6.10 fixed-point
bool isQ6_10Type(String type) {
  return type.toLowerCase() == 'q6_10_le';
}

/// Check if type is signed 16-bit integer
bool isInt16Type(String type) {
  return type.toLowerCase() == 'int16_le';
}

/// Check if type is unsigned 16-bit integer
bool isUint16Type(String type) {
  return type.toLowerCase() == 'uint16_le';
}

/// Check if type is 8-bit integer
bool isUint8Type(String type) {
  return type.toLowerCase() == 'uint8';
}

/// Get byte size for a type
int getTypeSize(String type) {
  switch (type.toLowerCase()) {
    case 'q8_8_le':
    case 'q6_10_le':
    case 'int16_le':
    case 'uint16_le':
      return 2;
    case 'uint8':
      return 1;
    default:
      throw Exception('Unknown type: $type');
  }
}
