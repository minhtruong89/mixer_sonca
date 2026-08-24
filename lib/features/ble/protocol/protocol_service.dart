/// Protocol service for loading and managing protocol definitions
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/injection.dart';
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

      final response = await http.get(Uri.parse(protocolUrl)).timeout(const Duration(seconds: 5));

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
        _logModelEnum();
        debugPrint('Protocol: ${_definition!.categories.length} categories loaded');
        
        // Log categories
        _definition!.categories.forEach((name, category) {
          debugPrint('  - $name (0x${category.id.toRadixString(16)}): ${category.commands.length} commands');
        });
      } else {
        throw Exception('Failed to load protocol: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Protocol: Error loading protocol definition via HTTP ($e), falling back to local asset...');
      try {
        String jsonString = await rootBundle.loadString('lib/ble_android_comm_format.json');
        if (jsonString.codeUnits.isNotEmpty && jsonString.codeUnits[0] == 0xFEFF) {
          jsonString = jsonString.substring(1);
        }
        final jsonData = json.decode(jsonString) as Map<String, dynamic>;
        _definition = ProtocolDefinition.fromJson(jsonData);
        _isLoaded = true;
        debugPrint('Protocol: Successfully loaded protocol definition from local asset');
        _logModelEnum();
      } catch (assetError) {
        debugPrint('Protocol: Error loading from local asset: $assetError');
        rethrow;
      }
    }
  }

  void _logModelEnum() {
    if (_definition == null) return;
    debugPrint('Protocol: ModelEnum (${_definition!.modelEnum.length} items):');
    for (final item in _definition!.modelEnum) {
      debugPrint('  [modelEnum] idx: "${item.idx}" -> nameDisplay: "${item.nameDisplay}"');
    }
  }

  /// Get active schema name based on connected model
  String get activeSchemaName {
    try {
      if (getIt.isRegistered<MixerService>()) {
        return getIt<MixerService>().getSchemaNameForActiveModel();
      }
    } catch (_) {}
    return 'defaultSchema';
  }

  /// Get all categories for active schema or specified schemaName/schemaVersion
  Map<String, CategoryDefinition> getCategories({String? schemaName, int? schemaVersion}) {
    if (!_isLoaded || _definition == null) return {};
    final resolvedSchemaName = schemaName ?? (schemaVersion == null ? activeSchemaName : null);
    return _definition!.getCategories(schemaName: resolvedSchemaName, schemaVersion: schemaVersion);
  }

  /// Get category by name (e.g., "MIC", "MUSIC")
  CategoryDefinition? getCategoryByName(String name, {String? schemaName, int? schemaVersion}) {
    if (!_isLoaded || _definition == null) {
      throw Exception('Protocol not loaded. Call loadProtocolDefinition() first.');
    }
    final resolvedSchemaName = schemaName ?? (schemaVersion == null ? activeSchemaName : null);
    return _definition!.getCategoryByName(name, schemaName: resolvedSchemaName, schemaVersion: schemaVersion);
  }

  /// Get category by ID (e.g., 0x01, 0x02)
  CategoryDefinition? getCategoryById(int id, {String? schemaName, int? schemaVersion}) {
    if (!_isLoaded || _definition == null) {
      throw Exception('Protocol not loaded. Call loadProtocolDefinition() first.');
    }
    final resolvedSchemaName = schemaName ?? (schemaVersion == null ? activeSchemaName : null);
    return _definition!.getCategoryById(id, schemaName: resolvedSchemaName, schemaVersion: schemaVersion);
  }

  /// Get command by category name and command ID
  CommandDefinition? getCommand(String categoryName, int cmdId, {String? schemaName, int? schemaVersion}) {
    final category = getCategoryByName(categoryName, schemaName: schemaName, schemaVersion: schemaVersion);
    return category?.getCommand(cmdId);
  }

  /// Get command by category name and command name
  CommandDefinition? getCommandByName(String categoryName, String commandName, {String? schemaName, int? schemaVersion}) {
    final category = getCategoryByName(categoryName, schemaName: schemaName, schemaVersion: schemaVersion);
    return category?.getCommandByName(commandName);
  }

  /// Get command by category ID and command ID
  CommandDefinition? getCommandById(int categoryId, int cmdId, {String? schemaName, int? schemaVersion}) {
    final category = getCategoryById(categoryId, schemaName: schemaName, schemaVersion: schemaVersion);
    return category?.getCommand(cmdId);
  }

  /// Get IndexDefinition by category name, command name, and parameter name
  IndexDefinition? getIndexDefinitionByParamName(String categoryName, String commandName, String paramName, {String? schemaName, int? schemaVersion}) {
    final command = getCommandByName(categoryName, commandName, schemaName: schemaName, schemaVersion: schemaVersion);
    if (command == null) return null;
    final idx = command.getIndexByName(paramName);
    if (idx == null) return null;
    return command.getIndex(idx);
  }

  /// Resolve numerical min for an IndexDefinition (resolves dynamic parameter references like "min_predelay")
  double? resolveMin(String categoryName, String commandName, String paramName, {String? schemaName, int? schemaVersion, Map<String, dynamic>? controlStates}) {
    final indexDef = getIndexDefinitionByParamName(categoryName, commandName, paramName, schemaName: schemaName, schemaVersion: schemaVersion);
    if (indexDef == null) return null;
    if (indexDef.min != null) return indexDef.min!.toDouble();

    if (indexDef.rawMin is String) {
      final refParamName = indexDef.rawMin as String;
      // Try to get current value from controlStates first if available
      if (controlStates != null) {
        final stateKey = "${commandName}_$refParamName";
        if (controlStates.containsKey(stateKey) && controlStates[stateKey] is num) {
          return (controlStates[stateKey] as num).toDouble();
        }
      }
      // Fallback to default of the referenced parameter in the same command
      final refDef = getIndexDefinitionByParamName(categoryName, commandName, refParamName, schemaName: schemaName, schemaVersion: schemaVersion);
      if (refDef?.defaultValue != null) {
        return refDef!.defaultValue!.toDouble();
      }
    }
    return null;
  }

  /// Resolve numerical max for an IndexDefinition (resolves dynamic parameter references like "max_predelay")
  double? resolveMax(String categoryName, String commandName, String paramName, {String? schemaName, int? schemaVersion, Map<String, dynamic>? controlStates}) {
    final indexDef = getIndexDefinitionByParamName(categoryName, commandName, paramName, schemaName: schemaName, schemaVersion: schemaVersion);
    if (indexDef == null) return null;
    if (indexDef.max != null) return indexDef.max!.toDouble();

    if (indexDef.rawMax is String) {
      final refParamName = indexDef.rawMax as String;
      // Try to get current value from controlStates first if available
      if (controlStates != null) {
        final stateKey = "${commandName}_$refParamName";
        if (controlStates.containsKey(stateKey) && controlStates[stateKey] is num) {
          return (controlStates[stateKey] as num).toDouble();
        }
      }
      // Fallback to default of the referenced parameter in the same command
      final refDef = getIndexDefinitionByParamName(categoryName, commandName, refParamName, schemaName: schemaName, schemaVersion: schemaVersion);
      if (refDef?.defaultValue != null) {
        return refDef!.defaultValue!.toDouble();
      }
    }
    return null;
  }

  /// Get index definition by category name, command ID, and index
  IndexDefinition? getIndex(String categoryName, int cmdId, int index, {String? schemaName, int? schemaVersion}) {
    final command = getCommand(categoryName, cmdId, schemaName: schemaName, schemaVersion: schemaVersion);
    return command?.getIndex(index);
  }

  /// Get index by parameter name
  int? getIndexByParameterName(String categoryName, int cmdId, String paramName, {String? schemaName, int? schemaVersion}) {
    final command = getCommand(categoryName, cmdId, schemaName: schemaName, schemaVersion: schemaVersion);
    return command?.getIndexByName(paramName);
  }

  /// Get parameter type by name
  String? getParameterType(String categoryName, int cmdId, String paramName, {String? schemaName, int? schemaVersion}) {
    final index = getIndexByParameterName(categoryName, cmdId, paramName, schemaName: schemaName, schemaVersion: schemaVersion);
    if (index == null) return null;
    
    final indexDef = getIndex(categoryName, cmdId, index, schemaName: schemaName, schemaVersion: schemaVersion);
    return indexDef?.type;
  }

  /// Get EQ filter type by name
  EqFilterType? getEqFilterType(String name, {String? schemaName, int? schemaVersion}) {
    if (!_isLoaded || _definition == null) {
      throw Exception('Protocol not loaded. Call loadProtocolDefinition() first.');
    }
    final filters = getEqFilterTypes(schemaName: schemaName, schemaVersion: schemaVersion);
    return filters[name];
  }

  /// Get all EQ filter types
  Map<String, EqFilterType> getEqFilterTypes({String? schemaName, int? schemaVersion}) {
    if (!_isLoaded || _definition == null) {
      throw Exception('Protocol not loaded. Call loadProtocolDefinition() first.');
    }
    final resolvedSchemaName = schemaName ?? (schemaVersion == null ? activeSchemaName : null);
    return _definition!.getEqFilterTypes(schemaName: resolvedSchemaName, schemaVersion: schemaVersion);
  }

  /// Calculate EQ index from band and field name
  int? calculateEqIndex(String categoryName, int cmdId, int band, String fieldName, {String? schemaName, int? schemaVersion}) {
    final command = getCommand(categoryName, cmdId, schemaName: schemaName, schemaVersion: schemaVersion);
    if (command == null || !command.isEqCommand) return null;
    
    return command.indexRule!.calculateIndex(band, fieldName);
  }

  /// Get field type for EQ command
  String? getEqFieldType(String categoryName, int cmdId, String fieldName, {String? schemaName, int? schemaVersion}) {
    final command = getCommand(categoryName, cmdId, schemaName: schemaName, schemaVersion: schemaVersion);
    if (command == null || !command.isEqCommand) return null;
    
    return command.indexRule!.getFieldType(fieldName);
  }

  /// Find a command definition by parameter name (index name)
  CommandDefinition? findCommand(String categoryName, String paramName, {String? schemaName, int? schemaVersion}) {
    if (!_isLoaded || _definition == null) return null;

    final category = getCategoryByName(categoryName, schemaName: schemaName, schemaVersion: schemaVersion);
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

  /// Get Production Name from modelEnum by productionModel index (e.g. 1234 -> "X500")
  String? getProductionName(int? productionModel) {
    if (productionModel == null || _definition == null) return null;
    final modelStr = productionModel.toString();
    for (final item in _definition!.modelEnum) {
      if (item.idx == modelStr) {
        return item.nameDisplay;
      }
    }
    return null;
  }
}
