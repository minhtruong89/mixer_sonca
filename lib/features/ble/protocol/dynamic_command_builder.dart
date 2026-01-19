/// Dynamic command builder using protocol definitions
library;

import 'package:flutter/foundation.dart';
import 'protocol_service.dart';
import 'protocol_constants.dart';
import 'command_payload.dart';

/// Build commands dynamically from protocol definition
class DynamicCommandBuilder {
  final ProtocolService _protocolService;

  DynamicCommandBuilder(this._protocolService);

  /// Build a command with named parameters
  /// 
  /// Example:
  /// ```dart
  /// final command = builder.buildCommand(
  ///   categoryName: 'SYSTEM',
  ///   cmdId: 0x01,
  ///   operation: CommandOperation.set,
  ///   parameters: {
  ///     'app_mode': 2, // Line In
  ///   },
  /// );
  /// ```
  CommandPayload buildCommand({
    required String categoryName,
    required int cmdId,
    required CommandOperation operation,
    required Map<String, dynamic> parameters,
  }) {
    final category = _protocolService.getCategoryByName(categoryName);
    if (category == null) {
      throw Exception('Category not found: $categoryName');
    }

    final command = category.getCommand(cmdId);
    if (command == null) {
      throw Exception('Command not found: 0x${cmdId.toRadixString(16)} in $categoryName');
    }

    // Build typed index-value pairs
    final pairs = <TypedIndexValuePair>[];

    for (final entry in parameters.entries) {
      final paramName = entry.key;
      final paramValue = entry.value;

      // Get index for this parameter
      final index = command.getIndexByName(paramName);
      if (index == null) {
        debugPrint('Warning: Parameter "$paramName" not found in command ${command.name}');
        continue;
      }

      // Get type for this parameter
      final indexDef = command.getIndex(index);
      if (indexDef == null) {
        debugPrint('Warning: Index definition not found for index $index');
        continue;
      }

      pairs.add(TypedIndexValuePair(
        index: index,
        value: paramValue,
        type: indexDef.type,
      ));
    }

    if (pairs.isEmpty) {
      throw Exception('No valid parameters provided for command ${command.name}');
    }

    return CommandPayload.fromTypedPairs(
      category: CommandCategory.values.firstWhere((c) => c.value == category.id),
      cmdId: cmdId,
      operation: operation,
      pairs: pairs,
    );
  }

  /// Build a command using category ID instead of name
  CommandPayload buildCommandById({
    required int categoryId,
    required int cmdId,
    required CommandOperation operation,
    required Map<String, dynamic> parameters,
  }) {
    final category = _protocolService.getCategoryById(categoryId);
    if (category == null) {
      throw Exception('Category not found: 0x${categoryId.toRadixString(16)}');
    }

    return buildCommand(
      categoryName: category.name,
      cmdId: cmdId,
      operation: operation,
      parameters: parameters,
    );
  }

  /// Build an EQ command with band and field parameters
  /// 
  /// Example:
  /// ```dart
  /// final command = builder.buildEqCommand(
  ///   categoryName: 'MIC',
  ///   cmdId: 0x06, // eq_in
  ///   band: 0,
  ///   fields: {
  ///     'enable': 1,
  ///     'type': 0, // PEAKING
  ///     'f0': 1000,
  ///     'Q': 0.707,
  ///     'gain': 3.5,
  ///   },
  /// );
  /// ```
  CommandPayload buildEqCommand({
    required String categoryName,
    required int cmdId,
    required int band,
    required Map<String, dynamic> fields,
  }) {
    final category = _protocolService.getCategoryByName(categoryName);
    if (category == null) {
      throw Exception('Category not found: $categoryName');
    }

    final command = category.getCommand(cmdId);
    if (command == null) {
      throw Exception('Command not found: 0x${cmdId.toRadixString(16)} in $categoryName');
    }

    if (!command.isEqCommand) {
      throw Exception('Command ${command.name} is not an EQ command');
    }

    final indexRule = command.indexRule!;

    // Validate band number
    if (band < 0 || band >= indexRule.bandCount) {
      throw Exception('Invalid band number: $band (max: ${indexRule.bandCount - 1})');
    }

    // Build typed index-value pairs
    final pairs = <TypedIndexValuePair>[];

    for (final entry in fields.entries) {
      final fieldName = entry.key;
      final fieldValue = entry.value;

      // Calculate index for this band and field
      final index = indexRule.calculateIndex(band, fieldName);
      if (index == null) {
        debugPrint('Warning: Field "$fieldName" not found in EQ command');
        continue;
      }

      // Get type for this field
      final fieldType = indexRule.getFieldType(fieldName);
      if (fieldType == null) {
        debugPrint('Warning: Type not found for field "$fieldName"');
        continue;
      }

      pairs.add(TypedIndexValuePair(
        index: index,
        value: fieldValue,
        type: fieldType,
      ));
    }

    if (pairs.isEmpty) {
      throw Exception('No valid fields provided for EQ command');
    }

    return CommandPayload.fromTypedPairs(
      category: CommandCategory.values.firstWhere((c) => c.value == category.id),
      cmdId: cmdId,
      operation: CommandOperation.set,
      pairs: pairs,
    );
  }

  /// Build an EQ command for multiple bands
  /// 
  /// Example:
  /// ```dart
  /// final command = builder.buildMultiBandEqCommand(
  ///   categoryName: 'MIC',
  ///   cmdId: 0x06,
  ///   bands: {
  ///     0: {'gain': 3.5, 'enable': 1},
  ///     1: {'gain': -2.0, 'enable': 1},
  ///   },
  /// );
  /// ```
  CommandPayload buildMultiBandEqCommand({
    required String categoryName,
    required int cmdId,
    required Map<int, Map<String, dynamic>> bands,
  }) {
    final category = _protocolService.getCategoryByName(categoryName);
    if (category == null) {
      throw Exception('Category not found: $categoryName');
    }

    final command = category.getCommand(cmdId);
    if (command == null) {
      throw Exception('Command not found: 0x${cmdId.toRadixString(16)} in $categoryName');
    }

    if (!command.isEqCommand) {
      throw Exception('Command ${command.name} is not an EQ command');
    }

    final indexRule = command.indexRule!;
    final pairs = <TypedIndexValuePair>[];

    // Process each band
    for (final bandEntry in bands.entries) {
      final band = bandEntry.key;
      final fields = bandEntry.value;

      // Validate band number
      if (band < 0 || band >= indexRule.bandCount) {
        debugPrint('Warning: Invalid band number: $band (skipping)');
        continue;
      }

      // Process each field in the band
      for (final fieldEntry in fields.entries) {
        final fieldName = fieldEntry.key;
        final fieldValue = fieldEntry.value;

        // Calculate index
        final index = indexRule.calculateIndex(band, fieldName);
        if (index == null) {
          debugPrint('Warning: Field "$fieldName" not found (skipping)');
          continue;
        }

        // Get type
        final fieldType = indexRule.getFieldType(fieldName);
        if (fieldType == null) {
          debugPrint('Warning: Type not found for field "$fieldName" (skipping)');
          continue;
        }

        pairs.add(TypedIndexValuePair(
          index: index,
          value: fieldValue,
          type: fieldType,
        ));
      }
    }

    if (pairs.isEmpty) {
      throw Exception('No valid band/field pairs provided');
    }

    return CommandPayload.fromTypedPairs(
      category: CommandCategory.values.firstWhere((c) => c.value == category.id),
      cmdId: cmdId,
      operation: CommandOperation.set,
      pairs: pairs,
    );
  }

  /// Get index for a parameter name
  int? getIndexForParameter(String categoryName, int cmdId, String paramName) {
    final command = _protocolService.getCommand(categoryName, cmdId);
    return command?.getIndexByName(paramName);
  }

  /// Get parameter type
  String? getParameterType(String categoryName, int cmdId, String paramName) {
    return _protocolService.getParameterType(categoryName, cmdId, paramName);
  }
}
