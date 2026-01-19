/// Command payload structure and encoding
library;

import 'protocol_constants.dart';
import 'protocol_types.dart';

/// Index-Value pair for command data
class IndexValuePair {
  final int index;
  final int value;

  const IndexValuePair(this.index, this.value);

  /// Encode to bytes (index: 1 byte, value: 1 byte)
  List<int> encode() => [index, value];

  /// Encode with 16-bit value (index: 1 byte, value LSB: 1 byte, value MSB: 1 byte)
  List<int> encode16() => [index, value & 0xFF, (value >> 8) & 0xFF];

  @override
  String toString() => 'IndexValuePair(index: $index, value: $value)';
}

/// Typed Index-Value pair with type information
class TypedIndexValuePair {
  final int index;
  final dynamic value;
  final String type;

  const TypedIndexValuePair({
    required this.index,
    required this.value,
    required this.type,
  });

  /// Encode to bytes based on type
  List<int> encode() {
    final valueBytes = encodeValue(value, type);
    return [index, ...valueBytes];
  }

  @override
  String toString() => 'TypedIndexValuePair(index: $index, value: $value, type: $type)';
}

/// Command Payload structure
class CommandPayload {
  final CommandCategory category;
  final int cmdId;
  final CommandOperation operation;
  final List<int> data;

  const CommandPayload({
    required this.category,
    required this.cmdId,
    required this.operation,
    required this.data,
  });

  /// Create a command payload from index-value pairs (8-bit values)
  factory CommandPayload.fromPairs({
    required CommandCategory category,
    required int cmdId,
    required CommandOperation operation,
    required List<IndexValuePair> pairs,
  }) {
    final pairBytes = <int>[];
    for (final pair in pairs) {
      pairBytes.addAll(pair.encode());
    }

    return CommandPayload(
      category: category,
      cmdId: cmdId,
      operation: operation,
      data: [pairs.length, ...pairBytes],
    );
  }

  /// Create a command payload from index-value pairs (16-bit values)
  factory CommandPayload.fromPairs16({
    required CommandCategory category,
    required int cmdId,
    required CommandOperation operation,
    required List<IndexValuePair> pairs,
  }) {
    final pairBytes = <int>[];
    for (final pair in pairs) {
      pairBytes.addAll(pair.encode16());
    }

    return CommandPayload(
      category: category,
      cmdId: cmdId,
      operation: operation,
      data: [pairs.length, ...pairBytes],
    );
  }

  /// Create a command payload from typed index-value pairs
  factory CommandPayload.fromTypedPairs({
    required CommandCategory category,
    required int cmdId,
    required CommandOperation operation,
    required List<TypedIndexValuePair> pairs,
  }) {
    final pairBytes = <int>[];
    for (final pair in pairs) {
      pairBytes.addAll(pair.encode());
    }

    return CommandPayload(
      category: category,
      cmdId: cmdId,
      operation: operation,
      data: [pairs.length, ...pairBytes],
    );
  }

  /// Encode payload to bytes
  List<int> encode() {
    return [
      category.value,
      cmdId,
      operation.value,
      data.length,
      ...data,
    ];
  }

  /// Decode payload from bytes
  static CommandPayload decode(List<int> bytes) {
    if (bytes.length < 4) {
      throw Exception('Command payload too short: ${bytes.length}');
    }

    final category = CommandCategory.fromValue(bytes[0]);
    final cmdId = bytes[1];
    final operation = CommandOperation.fromValue(bytes[2]);
    final payloadLen = bytes[3];

    if (bytes.length < 4 + payloadLen) {
      throw Exception('Payload length mismatch');
    }

    final data = bytes.sublist(4, 4 + payloadLen);

    return CommandPayload(
      category: category,
      cmdId: cmdId,
      operation: operation,
      data: data,
    );
  }

  /// Get total payload size
  int get size => 4 + data.length;

  @override
  String toString() {
    return 'CommandPayload(category: $category, cmdId: 0x${cmdId.toRadixString(16)}, '
        'operation: $operation, dataSize: ${data.length})';
  }
}

