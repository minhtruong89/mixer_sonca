/// Type conversion utilities for protocol data types
library;

/// Convert double to Q8.8 fixed-point format
/// 
/// Q8.8 format: 16-bit signed integer representing fixed-point number
/// - Integer part: Upper 8 bits
/// - Fractional part: Lower 8 bits
/// - Range: -128.0 to 127.99609375
/// - Resolution: 1/256 = 0.00390625
int doubleToQ8_8(double value) {
  // Clamp value to valid range
  if (value < -128.0) value = -128.0;
  if (value > 127.99609375) value = 127.99609375;
  
  // Convert to Q8.8 and mask to 16 bits
  return ((value * 256).round()) & 0xFFFF;
}

/// Convert Q8.8 fixed-point format to double
double q8_8ToDouble(int value) {
  // Handle sign extension for 16-bit signed integer
  int signedValue = value;
  if (signedValue & 0x8000 != 0) {
    // Negative number - sign extend to 32 bits
    signedValue = signedValue | 0xFFFF0000;
  }
  
  return signedValue / 256.0;
}

/// Encode a value based on its type string
List<int> encodeValue(dynamic value, String type) {
  switch (type.toLowerCase()) {
    case 'q8_8_le':
      // Q8.8 fixed-point, little-endian
      final q88Value = value is double ? doubleToQ8_8(value) : (value as int);
      return [q88Value & 0xFF, (q88Value >> 8) & 0xFF];
    
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
    
    case 'int16_le':
      // Signed 16-bit integer, little-endian
      if (bytes.length < 2) throw Exception('Insufficient bytes for int16');
      int value = bytes[0] | (bytes[1] << 8);
      // Sign extend if negative
      if (value & 0x8000 != 0) {
        value = value | 0xFFFF0000;
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
    case 'int16_le':
    case 'uint16_le':
      return 2;
    case 'uint8':
      return 1;
    default:
      throw Exception('Unknown type: $type');
  }
}
