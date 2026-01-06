import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mixer_sonca/core/models/device_model.dart';

class ConfigService {
  static const String _configUrl = 'http://data.soncamedia.com/firmware/smartbox/model_config_new.txt';
  
  String? _configData;
  String? get configData => _configData;
  
  List<DeviceModel> _models = [];
  List<DeviceModel> get models => _models;
  
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
          
          _isLoaded = true;

          debugPrint('');
          debugPrint('--- Model Config ---');
          debugPrint('ConfigService: Found ${_models.length} device models');
          for (var model in _models) {
            debugPrint('  - ${model.modelName} (ID: ${model.modelId}, Sub: ${model.modelIdSub})');
          }
          debugPrint('-----------------------');
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
}
