import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';

class MixerService {
  static const String _displayUrl = 'http://data.soncamedia.com/firmware/smartbox/model_config_display.json';

  DisplayConfig? _displayConfig;
  DisplayConfig? get displayConfig => _displayConfig;

  /// Load display configuration (Area 2 layout)
  Future<void> loadDisplayConfig() async {
    try {
      debugPrint('MixerService: Downloading display config from $_displayUrl');
      final response = await http.get(Uri.parse(_displayUrl));

      if (response.statusCode == 200) {
        String content = utf8.decode(response.bodyBytes);
        // Remove BOM if present
        if (content.startsWith('\uFEFF')) {
            content = content.substring(1);
        }
        
        final Map<String, dynamic> jsonMap = json.decode(content);
        _displayConfig = DisplayConfig.fromJson(jsonMap);
        
        debugPrint('MixerService: Display config loaded successfully');
        if (_displayConfig?.defaultDisplay.sections.isNotEmpty == true) {
          debugPrint('MixerService: Found sections: ${_displayConfig!.defaultDisplay.sections.keys.join(", ")}');
        }
      } else {
        debugPrint('MixerService: Failed to load display config. Status code: ${response.statusCode}');
      }
    } catch (e) {
       debugPrint('MixerService: Error fetching display config: $e');
    }
  }

  /// Get items for a specific section (e.g., "Area 2")
  DisplaySection? getItemsForSection(String sectionName) {
    if (_displayConfig == null) return null;
    return _displayConfig!.defaultDisplay.sections[sectionName];
  }
}
