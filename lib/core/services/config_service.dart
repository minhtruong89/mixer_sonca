import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mixer_sonca/core/models/device_model.dart';
import 'package:mixer_sonca/core/models/mixer_define.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/injection.dart';

class ConfigService {
  static const String _configUrl = 'http://data.soncamedia.com/firmware/smartbox/model_config_new.txt';
  
  String? _configData;
  String? get configData => _configData;
  
  List<DeviceModel> _models = [];
  List<DeviceModel> get models => _models;
  
  List<MixerDefine> _mixerCurrent = [];
  List<MixerDefine> get mixerCurrent => _mixerCurrent;
  
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> loadConfig() async {
    try {
      final response = await http.get(Uri.parse(_configUrl));
      
      if (response.statusCode == 200) {
        _configData = response.body;
        
        String jsonString = _configData!;
        
        // Remove UTF-8 BOM (EF BB BF) - appears as characters with codes 239, 187, 191
        if (jsonString.length >= 3 && 
            jsonString.codeUnitAt(0) == 0xEF && 
            jsonString.codeUnitAt(1) == 0xBB && 
            jsonString.codeUnitAt(2) == 0xBF) {
          jsonString = jsonString.substring(3);
        }
        
        jsonString = jsonString.trim();
        
        // Parse JSON
        try {
          final jsonData = json.decode(jsonString);
          _models = (jsonData['model'] as List)
              .map((m) => DeviceModel.fromJson(m as Map<String, dynamic>))
              .toList();
          
          // Filter Mixer Defines
          if (jsonData.containsKey('defaultDisplayMixer')) {
             final mixerService = getIt<MixerService>();
             final defaultDisplayMixer = jsonData['defaultDisplayMixer'] as List;
             
             _mixerCurrent = _filterMixerDefines(mixerService.mixerDefines, defaultDisplayMixer);
             
             debugPrint('');
             debugPrint('--- Mixer Current Tree (Filtered) ---');
             for (var define in _mixerCurrent) {
               define.debugPrintTree();
             }
             debugPrint('-------------------------------------');
          }

          _isLoaded = true;

          debugPrint('');
          debugPrint('--- Model Config ---');
          debugPrint('ConfigService: Found ${_models.length} device models');
          for (var model in _models) {
            debugPrint('  - ${model.modelName} (ID: ${model.modelId}, Sub: ${model.modelIdSub})');
          }
          debugPrint('-------------------------------------');
        } catch (e, stackTrace) {
          debugPrint('ConfigService: Error parsing JSON: $e');
          debugPrint('ConfigService: Stack trace: $stackTrace');
        }
      } else {
        debugPrint('ConfigService: Failed to download config. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ConfigService: Error downloading config: $e');
    }
  }

  List<MixerDefine> _filterMixerDefines(List<MixerDefine> source, List<dynamic> whitelist) {
    List<MixerDefine> result = [];
    
    for (var criterion in whitelist) {
      if (criterion is String) {
        // Simple string match: Include the whole node as-is
        final match = source.firstWhere((e) => e.name == criterion, orElse: () => MixerDefine(name: 'NOT_FOUND', children: [])); // Dummy fallback
        if (match.name != 'NOT_FOUND') {
          result.add(match);
        }
      } else if (criterion is Map<String, dynamic>) {
        // Map match e.g. {"GLOBAL": [...]}
        // Should have only one key usually
        criterion.forEach((key, value) {
           final match = source.firstWhere((e) => e.name == key, orElse: () => MixerDefine(name: 'NOT_FOUND', children: []));
           if (match.name != 'NOT_FOUND') {
             if (value is List) {
               // Recursively filter children
               final filteredChildren = _filterMixerDefines(match.children, value);
               // Create a new node with filtered children
               result.add(MixerDefine(
                 name: match.name,
                 index: match.index,
                 children: filteredChildren,
                 itemValue: match.itemValue,
                 itemType: match.itemType,
               ));
             } else {
               // If value is not a list (e.g. null), maybe just include parent?
               // Assuming strict format per example
             }
           }
        });
      }
    }
    return result;
  }
}
