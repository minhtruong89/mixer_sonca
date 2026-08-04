import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';

class MixerService {
  static const String _displayUrl = 'http://data.soncamedia.com/firmware/smartbox/model_config_display.json';
  static const String _displayModernUrl = 'http://data.soncamedia.com/firmware/smartbox/model_config_display_modern.json';

  static int themeMode = 0; // 0 = classic, 1 = modern

  DisplayConfig? _displayConfig;
  DisplayConfig? get displayConfig => _displayConfig;

  /// Load display configuration (Area 2 layout)
  Future<void> loadDisplayConfig() async {
    try {
      final targetUrl = themeMode == 1 ? _displayModernUrl : _displayUrl;
      debugPrint('MixerService: Downloading display config from $targetUrl');
      final response = await http.get(Uri.parse(targetUrl)).timeout(const Duration(seconds: 5));

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
        throw Exception('Failed to load display config. Status code: ${response.statusCode}');
      }
    } catch (e) {
       debugPrint('MixerService: Error fetching display config via HTTP ($e), falling back to local asset...');
       try {
         String fallbackAsset = themeMode == 1 ? 'lib/model_config_display_modern.json' : 'lib/model_config_display.json';
         String content = await rootBundle.loadString(fallbackAsset);
         if (content.startsWith('\uFEFF')) {
             content = content.substring(1);
         }
         final Map<String, dynamic> jsonMap = json.decode(content);
         _displayConfig = DisplayConfig.fromJson(jsonMap);
         debugPrint('MixerService: Display config loaded successfully from local asset ($fallbackAsset)');
       } catch (assetError) {
         debugPrint('MixerService: Error loading from local asset: $assetError');
       }
    }
  }

  String? _activeModelIdx;
  String? get activeModelIdx => _activeModelIdx;

  void setActiveModelIdx(String? idx) {
    _activeModelIdx = idx;
    debugPrint('MixerService: Active model idx set to "$idx" (schemaVersion: ${getSchemaVersionForActiveModel()})');
  }

  /// Get the active schemaVersion based on connected model idx, or fallback to defaultDisplay schemaVersion (1)
  int getSchemaVersionForActiveModel({String? modelIdx}) {
    if (_displayConfig == null) return 1;

    final targetIdx = modelIdx ?? _activeModelIdx;
    if (targetIdx != null && targetIdx.isNotEmpty) {
      final modelConfig = _displayConfig!.getModelDisplayByIdx(targetIdx);
      if (modelConfig != null) {
        return modelConfig.schemaVersion;
      }
    }

    return _displayConfig!.defaultDisplay.schemaVersion;
  }

  /// Get items for a specific section (e.g., "Area 1", "Area 2") using active connected model if available
  DisplaySection? getItemsForSection(String sectionName, {String? modelIdx}) {
    if (_displayConfig == null) return null;

    final targetIdx = modelIdx ?? _activeModelIdx;
    if (targetIdx != null && targetIdx.isNotEmpty) {
      final modelConfig = _displayConfig!.getModelDisplayByIdx(targetIdx);
      if (modelConfig != null && modelConfig.sections.containsKey(sectionName)) {
        return modelConfig.sections[sectionName];
      }
    }

    return _displayConfig!.defaultDisplay.sections[sectionName];
  }

  /// Get names of sections filtered by areaType using active model if available
  List<String> getSectionNamesByType(String type, {String? modelIdx}) {
    if (_displayConfig == null) return [];
    
    final targetIdx = modelIdx ?? _activeModelIdx;
    Map<String, DisplaySection> sections = _displayConfig!.defaultDisplay.sections;
    
    if (targetIdx != null && targetIdx.isNotEmpty) {
      final modelConfig = _displayConfig!.getModelDisplayByIdx(targetIdx);
      if (modelConfig != null && modelConfig.sections.isNotEmpty) {
        sections = modelConfig.sections;
      }
    }

    return sections.entries
        .where((e) => e.value.areaType == type)
        .map((e) => e.key)
        .toList();
  }
}
