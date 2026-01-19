/// Protocol definition models for dynamic protocol loading
library;

/// Root protocol definition
class ProtocolDefinition {
  final String protocol;
  final FramingDefinition framing;
  final Map<String, EqFilterType> eqFilterTypes;
  final Map<String, CategoryDefinition> categories;

  const ProtocolDefinition({
    required this.protocol,
    required this.framing,
    required this.eqFilterTypes,
    required this.categories,
  });

  factory ProtocolDefinition.fromJson(Map<String, dynamic> json) {
    // Parse EQ filter types
    final eqFilterTypesMap = <String, EqFilterType>{};
    if (json['eqFilterTypes'] != null && json['eqFilterTypes']['values'] != null) {
      for (final item in json['eqFilterTypes']['values']) {
        final filterType = EqFilterType.fromJson(item);
        eqFilterTypesMap[filterType.name] = filterType;
      }
    }

    // Parse categories
    final categoriesMap = <String, CategoryDefinition>{};
    if (json['categories'] != null) {
      (json['categories'] as Map<String, dynamic>).forEach((key, value) {
        categoriesMap[key] = CategoryDefinition.fromJson(key, value);
      });
    }

    return ProtocolDefinition(
      protocol: json['protocol'] ?? '',
      framing: FramingDefinition.fromJson(json['framing'] ?? {}),
      eqFilterTypes: eqFilterTypesMap,
      categories: categoriesMap,
    );
  }

  /// Get category by name
  CategoryDefinition? getCategoryByName(String name) {
    return categories[name];
  }

  /// Get category by ID
  CategoryDefinition? getCategoryById(int id) {
    return categories.values.firstWhere(
      (cat) => cat.id == id,
      orElse: () => throw Exception('Category not found for ID: 0x${id.toRadixString(16)}'),
    );
  }
}

/// Framing definition
class FramingDefinition {
  final Map<String, dynamic> header;
  final Map<String, dynamic> crc16;
  final Map<String, dynamic> commandPayload;
  final Map<String, dynamic> dataPayload;

  const FramingDefinition({
    required this.header,
    required this.crc16,
    required this.commandPayload,
    required this.dataPayload,
  });

  factory FramingDefinition.fromJson(Map<String, dynamic> json) {
    return FramingDefinition(
      header: json['header'] ?? {},
      crc16: json['crc16'] ?? {},
      commandPayload: json['commandPayload'] ?? {},
      dataPayload: json['dataPayload'] ?? {},
    );
  }
}

/// EQ filter type
class EqFilterType {
  final String name;
  final int value;

  const EqFilterType({
    required this.name,
    required this.value,
  });

  factory EqFilterType.fromJson(Map<String, dynamic> json) {
    return EqFilterType(
      name: json['name'] ?? '',
      value: json['value'] ?? 0,
    );
  }
}

/// Category definition (MIC, MUSIC, RECORD, SYSTEM, GUITAR)
class CategoryDefinition {
  final String name;
  final int id;
  final Map<int, CommandDefinition> commands;

  const CategoryDefinition({
    required this.name,
    required this.id,
    required this.commands,
  });

  factory CategoryDefinition.fromJson(String name, Map<String, dynamic> json) {
    // Parse ID (hex string to int)
    final idStr = json['id'] as String;
    final id = int.parse(idStr.replaceFirst('0x', ''), radix: 16);

    // Parse commands
    final commandsMap = <int, CommandDefinition>{};
    if (json['commands'] != null) {
      (json['commands'] as Map<String, dynamic>).forEach((cmdIdStr, cmdValue) {
        final cmdId = int.parse(cmdIdStr.replaceFirst('0x', ''), radix: 16);
        commandsMap[cmdId] = CommandDefinition.fromJson(cmdId, cmdValue);
      });
    }

    return CategoryDefinition(
      name: name,
      id: id,
      commands: commandsMap,
    );
  }

  /// Get command by ID
  CommandDefinition? getCommand(int cmdId) {
    return commands[cmdId];
  }
}

/// Command definition
class CommandDefinition {
  final int id;
  final String name;
  final String? paramType;
  final Map<int, IndexDefinition>? indices;
  final IndexRuleDefinition? indexRule;
  final Map<String, String>? valueMap;

  const CommandDefinition({
    required this.id,
    required this.name,
    this.paramType,
    this.indices,
    this.indexRule,
    this.valueMap,
  });

  factory CommandDefinition.fromJson(int id, Map<String, dynamic> json) {
    // Parse indices
    Map<int, IndexDefinition>? indicesMap;
    if (json['indices'] != null) {
      indicesMap = {};
      (json['indices'] as Map<String, dynamic>).forEach((indexStr, indexValue) {
        final index = int.parse(indexStr);
        indicesMap![index] = IndexDefinition.fromJson(index, indexValue);
      });
    }

    // Parse index rule (for EQ commands)
    IndexRuleDefinition? indexRuleDef;
    if (json['indexRule'] != null) {
      indexRuleDef = IndexRuleDefinition.fromJson(json['indexRule']);
    }

    // Parse value map
    Map<String, String>? valueMapDef;
    if (json['valueMap'] != null) {
      valueMapDef = {};
      (json['valueMap'] as Map<String, dynamic>).forEach((key, value) {
        valueMapDef![key] = value.toString();
      });
    }

    return CommandDefinition(
      id: id,
      name: json['name'] ?? '',
      paramType: json['paramType'],
      indices: indicesMap,
      indexRule: indexRuleDef,
      valueMap: valueMapDef,
    );
  }

  /// Get index definition by index number
  IndexDefinition? getIndex(int index) {
    return indices?[index];
  }

  /// Get index by parameter name
  int? getIndexByName(String paramName) {
    if (indices == null) return null;
    
    for (final entry in indices!.entries) {
      if (entry.value.name == paramName) {
        return entry.key;
      }
    }
    return null;
  }

  /// Check if this is an EQ command (has index rule)
  bool get isEqCommand => indexRule != null;
}

/// Index definition (parameter within a command)
class IndexDefinition {
  final int index;
  final String name;
  final String type;

  const IndexDefinition({
    required this.index,
    required this.name,
    required this.type,
  });

  factory IndexDefinition.fromJson(int index, Map<String, dynamic> json) {
    return IndexDefinition(
      index: index,
      name: json['name'] ?? '',
      type: json['type'] ?? 'uint16_le',
    );
  }
}

/// Index rule definition (for EQ commands with band/field structure)
class IndexRuleDefinition {
  final String indexRange;
  final int bandCount;
  final int fieldsPerBand;
  final Map<int, String> fieldOrder;
  final Map<String, String> fieldTypes;

  const IndexRuleDefinition({
    required this.indexRange,
    required this.bandCount,
    required this.fieldsPerBand,
    required this.fieldOrder,
    required this.fieldTypes,
  });

  factory IndexRuleDefinition.fromJson(Map<String, dynamic> json) {
    // Parse field order
    final fieldOrderMap = <int, String>{};
    if (json['fieldOrder'] != null) {
      (json['fieldOrder'] as Map<String, dynamic>).forEach((key, value) {
        fieldOrderMap[int.parse(key)] = value.toString();
      });
    }

    // Parse field types
    final fieldTypesMap = <String, String>{};
    if (json['fieldTypes'] != null) {
      (json['fieldTypes'] as Map<String, dynamic>).forEach((key, value) {
        fieldTypesMap[key] = value.toString();
      });
    }

    return IndexRuleDefinition(
      indexRange: json['indexRange'] ?? '',
      bandCount: json['bandCount'] ?? 0,
      fieldsPerBand: json['fieldsPerBand'] ?? 0,
      fieldOrder: fieldOrderMap,
      fieldTypes: fieldTypesMap,
    );
  }

  /// Calculate band and field from index
  /// Returns (band, field) tuple
  (int, int) calculateBandAndField(int index) {
    final band = (index - 1) ~/ fieldsPerBand;
    final field = (index - 1) % fieldsPerBand;
    return (band, field);
  }

  /// Get field name from field number
  String? getFieldName(int fieldNum) {
    return fieldOrder[fieldNum];
  }

  /// Get field type from field name
  String? getFieldType(String fieldName) {
    return fieldTypes[fieldName];
  }

  /// Calculate index from band and field name
  int? calculateIndex(int band, String fieldName) {
    // Find field number
    int? fieldNum;
    for (final entry in fieldOrder.entries) {
      if (entry.value == fieldName) {
        fieldNum = entry.key;
        break;
      }
    }
    
    if (fieldNum == null) return null;
    
    return band * fieldsPerBand + fieldNum + 1;
  }
}
