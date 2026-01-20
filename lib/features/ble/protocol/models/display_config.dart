/// Models for parsing model_config_display.json
library;

/// Root display configuration object
class DisplayConfig {
  final DefaultDisplay defaultDisplay;

  const DisplayConfig({required this.defaultDisplay});

  factory DisplayConfig.fromJson(Map<String, dynamic> json) {
    return DisplayConfig(
      defaultDisplay: DefaultDisplay.fromJson(json['defaulDisplay'] ?? {}),
    );
  }
}

class DefaultDisplay {
  final Map<String, DisplaySection> sections;

  const DefaultDisplay({required this.sections});

  factory DefaultDisplay.fromJson(Map<String, dynamic> json) {
    final sectionsMap = <String, DisplaySection>{};
    if (json['sections'] != null) {
      (json['sections'] as Map<String, dynamic>).forEach((key, value) {
        sectionsMap[key] = DisplaySection.fromJson(value);
      });
    }
    return DefaultDisplay(sections: sectionsMap);
  }
}

/// Represents a section like "Area 2"
class DisplaySection {
  final String description;
  final Map<String, DisplayItem> items;

  const DisplaySection({
    required this.description,
    required this.items,
  });

  factory DisplaySection.fromJson(Map<String, dynamic> json) {
    final itemsMap = <String, DisplayItem>{};
    if (json['items'] != null) {
      (json['items'] as Map<String, dynamic>).forEach((key, value) {
        itemsMap[key] = DisplayItem.fromJson(key, value);
      });
    }
    return DisplaySection(
      description: json['desc'] ?? '',
      items: itemsMap,
    );
  }
}

/// Represents an individual item like "Ngõ vào" or "MIC FBX"
class DisplayItem {
  final String label; // The key in "items" map (e.g., "Ngõ vào")
  final String category; // "SYSTEM", "MIC", etc.
  final String command; // "system_app_mode", "mic_feedback_cancel"
  final String? paramName; // "app_mode", "enable" (mapped from JSON's "index")
  final List<String> indexList; // New: for controls with multiple parameters (e.g. mute + volume)
  final DisplayControl control;
  final DisplayEvent? event;

  const DisplayItem({
    required this.label,
    required this.category,
    required this.command,
    this.paramName,
    this.indexList = const [],
    required this.control,
    this.event,
  });

  factory DisplayItem.fromJson(String label, Map<String, dynamic> json) {
    final indexList = <String>[];
    if (json['indexList'] != null) {
      for (var idx in json['indexList']) {
        indexList.add(idx.toString());
      }
    }

    return DisplayItem(
      label: label,
      category: json['category'] ?? '',
      command: json['command'] ?? '',
      // Note: JSON uses "index" key for parameter name
      paramName: json['index']?.toString(), 
      indexList: indexList,
      control: DisplayControl.fromJson(json['control'] ?? {}),
      event: json['event'] != null ? DisplayEvent.fromJson(json['event']) : null,
    );
  }
}

class DisplayEvent {
  final String? click;

  const DisplayEvent({this.click});

  factory DisplayEvent.fromJson(Map<String, dynamic> json) {
    return DisplayEvent(
      click: json['click']?.toString(),
    );
  }
}

/// Represents the UI control details
class DisplayControl {
  final String typeDisplay; // "group radio button", "swicht button", "vertical slider"
  final String valueType; // "uint16"
  final List<DisplayOption> options;
  final double minValue;
  final double maxValue;

  const DisplayControl({
    required this.typeDisplay,
    required this.valueType,
    this.options = const [],
    this.minValue = 0,
    this.maxValue = 100,
  });

  factory DisplayControl.fromJson(Map<String, dynamic> json) {
    final optionsList = <DisplayOption>[];
    if (json['options'] != null) {
      for (var opt in json['options']) {
        optionsList.add(DisplayOption.fromJson(opt));
      }
    }
    return DisplayControl(
      typeDisplay: json['typeDisplay'] ?? '',
      valueType: json['valueType'] ?? '',
      options: optionsList,
      minValue: double.tryParse(json['minValue']?.toString() ?? '0') ?? 0,
      maxValue: double.tryParse(json['maxValue']?.toString() ?? '100') ?? 100,
    );
  }
  
  bool get isSwitch => typeDisplay.contains('swic') || typeDisplay.contains('switch'); // Handle typo in JSON "swicht"
  bool get isRadio => typeDisplay.contains('radio');
  bool get isVerticalSlider => typeDisplay.contains('slider');
}

/// Represents an option in a radio group
class DisplayOption {
  final String label;
  final String value;

  const DisplayOption({
    required this.label,
    required this.value,
  });

  factory DisplayOption.fromJson(Map<String, dynamic> json) {
    return DisplayOption(
      label: json['label'] ?? '',
      value: json['value']?.toString() ?? '',
    );
  }
}
