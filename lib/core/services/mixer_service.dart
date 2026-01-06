import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mixer_sonca/core/models/mixer_define.dart';

class MixerService {
  static const String _url = 'http://data.soncamedia.com/firmware/smartbox/mixer_define.txt';

  List<MixerDefine> _mixerDefines = [];
  List<MixerDefine> get mixerDefines => _mixerDefines;

  Future<void> loadMixerDefine() async {
    try {
      final response = await http.get(Uri.parse(_url));

      if (response.statusCode == 200) {
        String content = utf8.decode(response.bodyBytes);
        if (content.startsWith('\uFEFF')) {
            content = content.substring(1);
        }
        
        final Map<String, dynamic> jsonMap = json.decode(content);
        
        _mixerDefines = _parseMap(jsonMap);

        debugPrint('');
        debugPrint('--- Mixer Define Tree ---');
        for (var define in _mixerDefines) {
          define.debugPrintTree();
        }
        debugPrint('-------------------------------------');
      } else {
        debugPrint('MixerService: Failed to load data. Status code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('MixerService: Error fetching data: $e');
    }
  }

  List<MixerDefine> _parseMap(Map<String, dynamic> map) {
    List<MixerDefine> result = [];

    map.forEach((key, value) {
      result.add(_parseItem(key, value));
    });

    return result;
  }

  MixerDefine _parseItem(String key, dynamic value) {
    int? index;
    List<MixerDefine> children = [];

    if (value is int) {
      // Simple case: "MIC": 0
      index = value;
    } else if (value is Map<String, dynamic>) {
      // Complex case with index and params/children
      if (value.containsKey('index')) {
        index = value['index'] as int?;
      }

      if (value.containsKey('params')) {
        // Params is a Map, treat keys as children
        final params = value['params'];
        if (params is Map<String, dynamic>) {
          children.addAll(_parseMap(params));
        }
      } 
      
      if (value.containsKey('children')) {
        // Children is a List
        final childrenList = value['children'];
        if (childrenList is List) {
          for (var child in childrenList) {
             // Child in list usually has "name" and "index"
             if (child is Map<String, dynamic>) {
               String name = child['name'] ?? 'Unknown';
               // If there is no explicit key (since it's a list), we use the "name" property as the name
               children.add(_parseItem(name, child));
             }
          }
        }
      }
      
      // Handle nested structure inside 'INPUT_LINE' where children are list items
      if (value.containsKey('INPUT_LINE')) {
          // This logic might be redundant if recursing params handles it, 
          // but let's look at the structure again.
          // "GLOBAL" -> "params" -> "INPUT_LINE" -> "children"
          // "params" is a Map, so "INPUT_LINE" is a key in _parseMap.
          // _parseItem("INPUT_LINE", inputLineValue)
          // inputLineValue has "index" and "children".
          // So the 'children' block above handles it.
      }
    }

    return MixerDefine(name: key, index: index, children: children);
  }
}
