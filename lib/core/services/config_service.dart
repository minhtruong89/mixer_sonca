import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConfigService {
  static const String _configUrl = 'http://data.soncamedia.com/firmware/smartbox/model_config_new.txt';
  
  String? _configData;
  String? get configData => _configData;
  
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  Future<void> loadConfig() async {
    try {
      debugPrint('ConfigService: Downloading config from $_configUrl');
      
      final response = await http.get(Uri.parse(_configUrl));
      
      if (response.statusCode == 200) {
        _configData = response.body;
        _isLoaded = true;
        
        debugPrint('ConfigService: Config downloaded successfully');
        debugPrint('ConfigService: Config length: ${_configData?.length} characters');
        debugPrint('ConfigService: Config preview: ${_configData?.substring(0, _configData!.length > 200 ? 200 : _configData!.length)}...');
      } else {
        debugPrint('ConfigService: Failed to download config. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ConfigService: Error downloading config: $e');
    }
  }
}
