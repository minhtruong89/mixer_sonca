/// Protocol service for loading and managing protocol definitions
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models/protocol_definition.dart';

/// Service to load and manage protocol definitions from remote JSON
class ProtocolService {
  static const String protocolUrl =
      'http://data.soncamedia.com/firmware/smartbox/ble_android_comm_format.json';

  ProtocolDefinition? _definition;
  bool _isLoaded = false;

  /// Get the loaded protocol definition
  ProtocolDefinition? get definition => _definition;

  /// Check if protocol is loaded
  bool get isLoaded => _isLoaded;

  /// Load protocol definition from URL
  Future<void> loadProtocolDefinition() async {
    try {
      debugPrint('Protocol: Loading protocol definition from $protocolUrl');

      final response = await http.get(Uri.parse(protocolUrl));

      if (response.statusCode == 200) {
        // Handle UTF-8 BOM if present
        String jsonString = response.body;
        if (jsonString.codeUnits.isNotEmpty && jsonString.codeUnits[0] == 0xFEFF) {
          jsonString = jsonString.substring(1);
        }

        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        _definition = ProtocolDefinition.fromJson(jsonData);
        _isLoaded = true;

        debugPrint('Protocol: Successfully loaded protocol definition');
        debugPrint('Protocol: ${_definition!.categories.length} categories loaded');
        
        // Log categories
        _definition!.categories.forEach((name, category) {
          debugPrint('  - $name (0x${category.id.toRadixString(16)}): ${category.commands.length} commands');
        });
      } else {
        throw Exception('Failed to load protocol: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Protocol: Error loading protocol definition: $e');
      rethrow;
    }
  }

  /// Get category by name (e.g., "MIC", "MUSIC")
  CategoryDefinition? getCategoryByName(String name) {
    if (!_isLoaded || _definition == null) {
      throw Exception('Protocol not loaded. Call loadProtocolDefinition() first.');
    }
    return _definition!.getCategoryByName(name);
  }

  /// Get category by ID (e.g., 0x01, 0x02)
  CategoryDefinition? getCategoryById(int id) {
    if (!_isLoaded || _definition == null) {
      throw Exception('Protocol not loaded. Call loadProtocolDefinition() first.');
    }
    return _definition!.getCategoryById(id);
  }

  /// Get command by category name and command ID
  CommandDefinition? getCommand(String categoryName, int cmdId) {
    final category = getCategoryByName(categoryName);
    return category?.getCommand(cmdId);
  }

  /// Get command by category name and command name
  CommandDefinition? getCommandByName(String categoryName, String commandName) {
    final category = getCategoryByName(categoryName);
    return category?.getCommandByName(commandName);
  }

  /// Get command by category ID and command ID
  CommandDefinition? getCommandById(int categoryId, int cmdId) {
    final category = getCategoryById(categoryId);
    return category?.getCommand(cmdId);
  }

  /// Get index definition by category name, command ID, and index
  IndexDefinition? getIndex(String categoryName, int cmdId, int index) {
    final command = getCommand(categoryName, cmdId);
    return command?.getIndex(index);
  }

  /// Get index by parameter name
  int? getIndexByParameterName(String categoryName, int cmdId, String paramName) {
    final command = getCommand(categoryName, cmdId);
    return command?.getIndexByName(paramName);
  }

  /// Get parameter type by name
  String? getParameterType(String categoryName, int cmdId, String paramName) {
    final index = getIndexByParameterName(categoryName, cmdId, paramName);
    if (index == null) return null;
    
    final indexDef = getIndex(categoryName, cmdId, index);
    return indexDef?.type;
  }

  /// Get EQ filter type by name
  EqFilterType? getEqFilterType(String name) {
    if (!_isLoaded || _definition == null) {
      throw Exception('Protocol not loaded. Call loadProtocolDefinition() first.');
    }
    return _definition!.eqFilterTypes[name];
  }

  /// Get all EQ filter types
  Map<String, EqFilterType> getEqFilterTypes() {
    if (!_isLoaded || _definition == null) {
      throw Exception('Protocol not loaded. Call loadProtocolDefinition() first.');
    }
    return _definition!.eqFilterTypes;
  }

  /// Calculate EQ index from band and field name
  int? calculateEqIndex(String categoryName, int cmdId, int band, String fieldName) {
    final command = getCommand(categoryName, cmdId);
    if (command == null || !command.isEqCommand) return null;
    
    return command.indexRule!.calculateIndex(band, fieldName);
  }

  /// Get field type for EQ command
  String? getEqFieldType(String categoryName, int cmdId, String fieldName) {
    final command = getCommand(categoryName, cmdId);
    if (command == null || !command.isEqCommand) return null;
    
    return command.indexRule!.getFieldType(fieldName);
  }

  /// Find a command definition by parameter name (index name)
  /// 
  /// Example: findCommand('SYSTEM', 'app_mode') -> Returns command definition for ID 0x01
  CommandDefinition? findCommand(String categoryName, String paramName) {
    if (!_isLoaded || _definition == null) return null;

    final category = getCategoryByName(categoryName);
    if (category == null) return null;

    // Search through all commands in the category
    if (category.commands != null) {
      for (final command in category.commands!.values) {
        // Check if this command contains the parameter (index)
        final index = command.getIndexByName(paramName);
        if (index != null) {
          return command;
        }
      }
    }
    
    return null;
  }
}
