import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:equatable/equatable.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:mixer_sonca/injection.dart';
import 'protocol/protocol_handler.dart';
import 'protocol/protocol_constants.dart';
import 'protocol/protocol_frame.dart';
import 'protocol/command_payload.dart';
import 'protocol/dynamic_command_builder.dart';
import 'protocol/protocol_types.dart';
import 'protocol/protocol_service.dart';
import 'protocol/models/protocol_definition.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';

// --- Model ---
class BleDevice extends Equatable {
  final String id;
  final String name;
  final String soncaName;
  final int rssi;
  final Map<int, List<int>> manufacturerData;
  final List<String> serviceUuids;
  final bool isConnectable;
  final int txPower;

  const BleDevice({
    required this.id,
    required this.name,
    required this.soncaName,
    required this.rssi,
    required this.manufacturerData,
    required this.serviceUuids,
    required this.isConnectable,
    required this.txPower,
  });

  @override
  List<Object?> get props => [id, name, soncaName, rssi, manufacturerData, serviceUuids, isConnectable, txPower];
}


const String SONCA_SERVICE = "5343";

// --- Repository ---
abstract class BleRepository {
  Future<bool> checkPermissions();
  Stream<List<BleDevice>> get scanResults;
  Future<void> startScan();
  Future<void> stopScan();
  Future<bool> get isBluetoothOn;
  Future<void> turnOnBluetooth();
  Future<void> connect(BleDevice device);
  Future<void> disconnect(BleDevice device);
  Future<List<BluetoothService>> discoverServices(BleDevice device);
}

class BleRepositoryImpl implements BleRepository {
  BleRepositoryImpl();



  @override
  Stream<List<BleDevice>> get scanResults => FlutterBluePlus.scanResults.map(
        (results) => results
            .where((r) => r.advertisementData.serviceUuids.any((u) => u.toString().contains(SONCA_SERVICE.toLowerCase())))
            .map((r) {
              // Use complete local name from advertisement data for soncaName
              final soncaName = r.advertisementData.localName.isNotEmpty 
                  ? r.advertisementData.localName 
                  : (r.device.platformName.isNotEmpty ? r.device.platformName : "N/A");
              
              return BleDevice(
                id: r.device.remoteId.str,
                name: r.device.platformName.isNotEmpty ? r.device.platformName : "N/A",
                soncaName: soncaName,
                rssi: r.rssi,
                manufacturerData: r.advertisementData.manufacturerData,
                serviceUuids: r.advertisementData.serviceUuids.map((u) => u.toString()).toList(),
                isConnectable: r.advertisementData.connectable,
                txPower: r.advertisementData.txPowerLevel ?? 0,
              );
            })
            .toList(),
      );

  @override
  Future<bool> checkPermissions() async {
    // On iOS, Bluetooth permissions are handled automatically by the system
    // when Info.plist keys are present. No need to request via permission_handler.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return true;
    }
    
    // On Android, we need to explicitly request permissions
    if (defaultTargetPlatform == TargetPlatform.android) {
      var status = await Permission.bluetoothScan.request();
      var connectStatus = await Permission.bluetoothConnect.request();
      var locationStatus = await Permission.location.request();
      
      return status.isGranted && connectStatus.isGranted && locationStatus.isGranted;
    }
    
    // For other platforms, assume granted
    return true;
  }

  @override
  Future<void> startScan() async {
    // Stop any existing scan
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }
    
    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
  }

  @override
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  @override
  Future<bool> get isBluetoothOn async {
    final state = await FlutterBluePlus.adapterState.where((s) => s != BluetoothAdapterState.unknown).first;
    return state == BluetoothAdapterState.on;
  }

  @override
  Future<void> turnOnBluetooth() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await FlutterBluePlus.turnOn();
    }
  }

  @override
  Future<void> connect(BleDevice device) async {
    // Reconstruct BluetoothDevice from ID/remoteId
    final bluetoothDevice = BluetoothDevice.fromId(device.id);
    await bluetoothDevice.connect(autoConnect: false);
  }

  @override
  Future<void> disconnect(BleDevice device) async {
    final bluetoothDevice = BluetoothDevice.fromId(device.id);
    await bluetoothDevice.disconnect();
  }

  @override
  Future<List<BluetoothService>> discoverServices(BleDevice device) async {
    final bluetoothDevice = BluetoothDevice.fromId(device.id);
    return await bluetoothDevice.discoverServices();
  }
}

// --- ViewModel ---
class BleViewModel extends ChangeNotifier {
  final BleRepository _repository;
  final ProtocolHandler _protocolHandler = ProtocolHandler();

  BleViewModel({required BleRepository repository})
      : _repository = repository;

  List<BleDevice> _devices = [];
  List<BleDevice> get devices {
    if (_selectedDevice != null && !_devices.any((d) => d.id == _selectedDevice!.id)) {
      return [_selectedDevice!, ..._devices];
    }
    return _devices;
  }

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  BleDevice? _selectedDevice;
  BleDevice? get selectedDevice => _selectedDevice;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  String? _connectingDeviceId;
  String? get connectingDeviceId => _connectingDeviceId;

  /// Map to store dynamic control states (e.g., {'mic_bass_gain': 50, 'app_mode': 1})
  final Map<String, dynamic> _controlStates = {};
  Map<String, dynamic> get controlStates => _controlStates;

  dynamic getControlValue(String key, {dynamic defaultValue}) {
    return _controlStates[key] ?? defaultValue;
  }

  void updateControlValue(String key, dynamic value, {bool notify = true}) {
    if (_controlStates[key] == value) return;
    _controlStates[key] = value;
    if (notify) notifyListeners();
  }

  bool _isBleListenersSetup = false;

  void _ensureBleInitialized() {
    if (_isBleListenersSetup) return;
    _isBleListenersSetup = true;

    _repository.scanResults.listen((devices) {
      _devices = devices;
      notifyListeners();
    });

    // Listen to BLE connection changes
    FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      if (event.connectionState == BluetoothConnectionState.disconnected) {
        if (_selectedDevice != null && event.device.remoteId.str == _selectedDevice!.id) {
          debugPrint('BLE: Device disconnected.');
          _handleDeviceDisconnected();
        }
      }
    });

    // Listen to device Bluetooth adapter state
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        debugPrint('BLE: Adapter turned off.');
        _handleDeviceDisconnected();
      }
    });
  }

  Future<void> saveConfigToFile() async {
    final mixerService = getIt<MixerService>();
    final displayConfig = mixerService.displayConfig;
    if (displayConfig == null) {
      debugPrint('BleViewModel: saveConfigToFile - displayConfig is null');
      return;
    }

    final Map<String, dynamic> values = {};
    debugPrint('BleViewModel: saveConfigToFile - total control states: ${_controlStates.length}');
    // 1. Collect all parameters and their current values from all areas
    for (var section in displayConfig.defaultDisplay.sections.values) {
      for (var item in section.items.values) {
        final List<String> params = [];
        if (item.indexList.isNotEmpty) {
          params.addAll(item.indexList);
        } else if (item.paramName != null && item.paramName!.isNotEmpty) {
          params.add(item.paramName!);
        }
        
        for (var param in params) {
          final stateKey = "${item.command}_$param";
          // Format: Category.Command.ParamName
          final key = "${item.category}.${item.command}.$param";
          
          if (_controlStates.containsKey(stateKey)) {
            values[key] = _controlStates[stateKey];
          } else {
            // Provide a sensible default based on control type if missing
            if (param.toLowerCase().endsWith('mute')) {
              values[key] = 0;
            } else if (item.control.isSwitch) {
              values[key] = 0;
            } else if (item.control.isVerticalSlider) {
              // Usually the default in UI is midpoint or 0
              values[key] = (item.control.minValue + item.control.maxValue) / 2;
            } else if (item.control.isRadio || item.control.isDropdown) {
              // Default to first option or 0
              values[key] = 0;
            } else {
              values[key] = 0;
            }
          }
        }

      }
      
      // Handle EQ Area which doesn't use `items`
      if (section.areaFormat == "EQ Area" && section.command != null) {
        final totalBands = section.totalEQBand ?? 10;
        final commandName = section.command!;
        
        // Parse default EQ values from config
        int defaultTypeEnum = 2;
        final typeValue = section.control?.rawConfig['type']?.toString();
        if (typeValue != null) {
           final parsedInt = int.tryParse(typeValue);
           if (parsedInt != null) {
              defaultTypeEnum = parsedInt;
           } else {
              final protocolService = getIt<ProtocolService>();
              if (protocolService.isLoaded) {
                 final filterType = protocolService.definition!.eqFilterTypes[typeValue.toUpperCase()];
                 if (filterType != null) defaultTypeEnum = filterType.value;
              }
           }
        }
        final defaultF0 = section.control?.rawConfig['f0']?.toString() ?? '0';
        final defaultQ = int.tryParse(section.control?.rawConfig['Q']?.toString() ?? '0') ?? 0;
        final double qValue = defaultQ / 256.0;
        final defaultGain = double.tryParse(section.control?.rawConfig['gain']?.toString() ?? '0') ?? 0.0;

        for (int b = 0; b < totalBands; b++) {
          // Determine default F0 for this band
          String bandF0Value = defaultF0;
          if (section.bandF0 != null && b < section.bandF0!.length) {
            bandF0Value = section.bandF0![b];
          }
          int baseF0 = int.tryParse(bandF0Value) ?? 0;

          final eqParams = ['type', 'f0', 'Q', 'gain'];
          for (var param in eqParams) {
             final stateKey = "${commandName}_band${b}_$param";
             
             // Export key should use 1-based indexing (band1, band2, ...)
             final exportParamName = 'band${b + 1}_$param';
             
             // Find category name for EQ Area command
             final protocolService = getIt<ProtocolService>();
             String categoryName = "";
             for (var cat in protocolService.definition?.categories.values ?? <CategoryDefinition>[]) {
               if (cat.getCommandByName(commandName) != null) {
                 categoryName = cat.name;
                 break;
               }
             }
             
             final key = "$categoryName.$commandName.$exportParamName";
             if (_controlStates.containsKey(stateKey)) {
                var val = _controlStates[stateKey];
                // Convert raw Q/gain (int) to double if needed, like in UI
                if (param == 'Q' && val is int) val = val / 256.0;
                if (param == 'gain' && val is int) val = val / 256.0;
                values[key] = val;
             } else {
                // Apply defaults if missing
                if (param == 'type') values[key] = defaultTypeEnum;
                else if (param == 'f0') values[key] = baseF0;
                else if (param == 'Q') values[key] = double.parse(qValue.toStringAsFixed(2)); // e.g. 0.7
                else if (param == 'gain') values[key] = defaultGain;
             }
          }
        }


      }
    }
    
    debugPrint('BleViewModel: saveConfigToFile - collected ${values.length} parameters to save.');

    // 2. Sort the keys alphabetically (this naturally groups by category)
    final sortedKeys = values.keys.toList()..sort();
    final Map<String, dynamic> sortedValues = {
      for (var key in sortedKeys) key: values[key]
    };

    final finalOutput = {"values": sortedValues};

    // 3. Save to file with timestamp HC_yyyy_MM_dd_HH_mm.json
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }

      final now = DateTime.now();
      final formatter = DateFormat('yyyy_MM_dd_HH_mm');
      final timestamp = formatter.format(now);
      final fileName = "HC_$timestamp.json";
      
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }
      
      if (directory == null) {
        debugPrint('BleViewModel: Cannot find Downloads directory');
        return;
      }

      final file = File('${directory.path}/$fileName');
      
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(encoder.convert(finalOutput));
      
      debugPrint('BleViewModel: Config saved to ${file.path}');
    } catch (e) {
      debugPrint('BleViewModel: Error saving config: $e');
    }
  }

  Future<void> loadConfigToFile() async {
    debugPrint('BleViewModel: loadConfigToFile called');
    
    try {
      // 1. Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        debugPrint('BleViewModel: File picker cancelled or no file selected.');
        return;
      }

      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);

      if (jsonData is! Map || !jsonData.containsKey('values')) {
        debugPrint('BleViewModel: Invalid config file format (missing "values" object).');
        return;
      }

      final Map<String, dynamic> values = Map<String, dynamic>.from(jsonData['values']);
      
      // Used to batch commands for sending to BLE
      final Map<String, Map<String, Map<String, dynamic>>> batchedNormal = {};
      final Map<String, Map<String, Map<int, Map<String, dynamic>>>> batchedEq = {};

      final protocolService = getIt<ProtocolService>();

      // 2. Parse and update state
      for (final entry in values.entries) {
        final key = entry.key;
        final val = entry.value;

        final parts = key.split('.');
        if (parts.length != 3) continue;

        final categoryName = parts[0];
        final commandName = parts[1];
        String paramName = parts[2];

        // Check if it's an EQ band parameter (e.g., band1_Q -> band0_Q)
        final eqMatch = RegExp(r'^band(\d+)_(.*)$').firstMatch(paramName);
        int? bandIndex;
        String? eqField;
        
        if (eqMatch != null) {
          final bIdx = int.tryParse(eqMatch.group(1)!) ?? 1;
          bandIndex = bIdx - 1; // Convert 1-based export index back to 0-based
          eqField = eqMatch.group(2)!;
          paramName = 'band${bandIndex}_$eqField';
        }

        final stateKey = "${commandName}_$paramName";
        
        // Convert Q and gain doubles back to internal integer Q8.8 representation for UI state
        dynamic internalVal = val;
        if (eqMatch != null && (eqField == 'Q' || eqField == 'gain')) {
           if (val is num) internalVal = (val * 256.0).round();
           else if (val is String) internalVal = (double.parse(val) * 256.0).round();
        } else if (val is String && num.tryParse(val) != null) {
           internalVal = num.parse(val);
        }

        _controlStates[stateKey] = internalVal;

        // Queue for BLE send
        final cmdDef = protocolService.getCommandByName(categoryName, commandName);
        if (cmdDef != null) {
           if (cmdDef.isEqCommand && bandIndex != null && eqField != null) {
              batchedEq[categoryName] ??= {};
              batchedEq[categoryName]![commandName] ??= {};
              batchedEq[categoryName]![commandName]![bandIndex] ??= {};
              
              // DynamicCommandBuilder encodes actual value directly without pre-conversion for float types
              // Wait, UI uses internalVal (int), DynamicCommandBuilder uses index type logic.
              // We should pass internalVal to it.
              batchedEq[categoryName]![commandName]![bandIndex]![eqField] = internalVal;
           } else {
              batchedNormal[categoryName] ??= {};
              batchedNormal[categoryName]![commandName] ??= {};
              batchedNormal[categoryName]![commandName]![paramName] = internalVal;
           }
        }
      }

      // 3. Notify UI
      notifyListeners();
      debugPrint('BleViewModel: Loaded ${values.length} parameters to UI.');

      // 4. Send to BLE device if connected
      if (_selectedDevice != null) {
         final builder = getIt<DynamicCommandBuilder>();
         
         final allCategories = {...batchedNormal.keys, ...batchedEq.keys}.toList();
         allCategories.sort(); // Sort by category alphabetically

         for (final catName in allCategories) {
            // Send Normal Commands for this category
            final normalCmds = batchedNormal[catName];
            if (normalCmds != null) {
               for (final cmdEntry in normalCmds.entries) {
                  final cmdName = cmdEntry.key;
                  final cmdDef = protocolService.getCommandByName(catName, cmdName);
                  if (cmdDef == null) continue;
                  
                  try {
                     final commands = builder.buildCommand(
                       categoryName: catName,
                       cmdId: cmdDef.id,
                       operation: CommandOperation.set,
                       parameters: cmdEntry.value,
                     );
                     // DynamicCommandBuilder automatically breaks payloads if they exceed maxPairCount
                     for (final cmd in commands) {
                        await sendProtocolCommand(cmd);
                        await Future.delayed(const Duration(milliseconds: 60));
                     }
                  } catch(e) {
                    debugPrint('BleViewModel: Error building normal command for $cmdName: $e');
                  }
               }
            }

            // Send EQ Commands for this category
            final eqCmds = batchedEq[catName];
            if (eqCmds != null) {
               for (final cmdEntry in eqCmds.entries) {
                  final cmdName = cmdEntry.key;
                  final cmdDef = protocolService.getCommandByName(catName, cmdName);
                  if (cmdDef == null) continue;
                  
                  try {
                     final commands = builder.buildMultiBandEqCommand(
                       categoryName: catName,
                       cmdId: cmdDef.id,
                       bands: cmdEntry.value,
                       operation: CommandOperation.set,
                     );
                     // DynamicCommandBuilder automatically breaks payloads if they exceed maxPairCount
                     for (final cmd in commands) {
                        await sendProtocolCommand(cmd);
                        await Future.delayed(const Duration(milliseconds: 60));
                     }
                  } catch(e) {
                    debugPrint('BleViewModel: Error building EQ command for $cmdName: $e');
                  }
               }
            }
         }
         debugPrint('BleViewModel: Synced loaded config to BLE device.');
      }

    } catch (e) {
      debugPrint('BleViewModel: Error loading config file: $e');
    }
  }

  void init() {
    // Listen for incoming protocol frames
    _protocolHandler.incomingFrames.listen((frame) {
      debugPrint('Protocol: Received frame - ${frame.header}');
      // Handle incoming frames (ACK, responses, etc.)
      _handleProtocolFrame(frame);
    });
  }

  void _handleDeviceDisconnected() {
    _selectedDevice = null;
    _controlStates.clear();
    _connectingDeviceId = null;
    _isConnecting = false;
    notifyListeners();
  }

  Future<void> scanDevices() async {
    _ensureBleInitialized();
    _isScanning = true;
    notifyListeners();

    // 1. Check Permissions
    final granted = await _repository.checkPermissions();
    if (!granted) {
      debugPrint("Permissions not granted");
      _isScanning = false;
      notifyListeners();
      return;
    }

    // 2. Check Bluetooth State
    bool isOn = await _repository.isBluetoothOn;
    if (!isOn) {
      try {
        await _repository.turnOnBluetooth();
        // Wait a bit for it to turn on
        await Future.delayed(const Duration(seconds: 2));
        isOn = await _repository.isBluetoothOn;
        if (!isOn) {
           debugPrint("Bluetooth could not be turned on");
           _isScanning = false;
           notifyListeners();
           return; // Or notify UI to show message
        }
      } catch (e) {
        debugPrint("Error turning on Bluetooth: $e");
        _isScanning = false;
        notifyListeners();
        return;
      }
    }

    try {
      await _repository.startScan();
    } catch (e) {
      debugPrint("Error scanning: $e");
    } finally {
      // Note: FlutterBluePlus stops automatically after timeout,
      // but we update state here if we want manual control.
      Future.delayed(const Duration(seconds: 5), () {
        _isScanning = false;
        notifyListeners();
      });
    }
  }

  void selectDevice(BleDevice? device) {
    _selectedDevice = device;
    notifyListeners();
  }

  Future<void> connectToDevice(BleDevice device) async {
    _isConnecting = true;
    _connectingDeviceId = device.id;
    notifyListeners();

    // 0. Disconnect any existing connection to ensure a clean state
    if (_selectedDevice != null) {
      debugPrint('BLE: Disconnecting existing device ${_selectedDevice!.name} before connecting to new one.');
      try {
        await _repository.disconnect(_selectedDevice!);
        // Small delay to allow BLE stack to settle
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint('BLE: Error disconnecting previous device: $e');
      }
    }

    // Force disconnect any other stale devices
    try {
      final connected = FlutterBluePlus.connectedDevices;
      for (var d in connected) {
        if (d.remoteId.str != device.id) {
          debugPrint('BLE: Force disconnecting stale device ${d.platformName}');
          await d.disconnect();
        }
      }
    } catch (e) {
      debugPrint('BLE: Error cleaning up stale connections: $e');
    }
    
    // Stop scanning before connecting to avoid interference
    try {      
      if (_isScanning) {
        await _repository.stopScan();
        _isScanning = false;
        notifyListeners(); // Update UI scan button
      }
    } catch(e) { /* ignore scan stop error */ }

    try {
      await _repository.connect(device);
      _selectedDevice = device;
      
      // Discover services after connection
      //final services = await _repository.discoverServices(device);
      //_logServices(services);

      // Setup protocol listener for incoming frames
      await _setupProtocolListener();

      // Test send and receive BLE
      /*await sendDataToBLE([0x02, 0x80, 0x01, 0x00, 0xF4]);
      await receiveDataFromBLE();

      final helper = getIt<ProtocolHelper>();
      final command1 = helper.setAppMode(AppModeValue.lineIn);
      await sendProtocolCommand(command1);*/

      // Get data and save value into display item
      await fetchInitialStates();
      
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      // Handle error (maybe clear selection or show toast)
    } finally {
      _isConnecting = false;
      _connectingDeviceId = null;
      notifyListeners();
    }
  }



  void _logServices(List<BluetoothService> services) {
    // Filter for the specific Sonca service
    final soncaServices = services.where((s) => s.uuid.toString().toLowerCase().contains(SONCA_SERVICE.toLowerCase())).toList();

    debugPrint('--------------------------------------------------');
    debugPrint('SONCA SERVICES FOUND: ${soncaServices.length}');
    for (var service in soncaServices) {
      debugPrint('Service UUID: 0x${service.uuid.str.toUpperCase()}');
      debugPrint('  Primary: ${service.isPrimary}');
      
      for (var characteristic in service.characteristics) {
        debugPrint('  Characteristic UUID: 0x${characteristic.uuid.str.toUpperCase()}');
        debugPrint('    Properties: ${characteristic.properties.toString()}');
        
        for (var descriptor in characteristic.descriptors) {
          debugPrint('    Descriptor UUID: 0x${descriptor.uuid.str.toUpperCase()}');
        }
      }
      debugPrint(''); // Empty line between services
    }
    debugPrint('--------------------------------------------------');
  }

  /// Send byte array to the currently connected BLE device
  Future<void> sendDataToBLE(List<int> data) async {
    if (_selectedDevice == null) {
      debugPrint('BLE Send: No device connected');
      return;
    }

    try {
      debugPrint('\n--- BLE Send ---');
      debugPrint('BLE Send: Sending ${data.length} bytes to device ${_selectedDevice!.name}');
      debugPrint('BLE Send: Data = ${data.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
      
      final bluetoothDevice = BluetoothDevice.fromId(_selectedDevice!.id);
      final services = await bluetoothDevice.discoverServices();
      
      // Find the Sonca service
      final soncaService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase().contains(SONCA_SERVICE.toLowerCase()),
        orElse: () => throw Exception('Sonca service not found'),
      );
      
      // Find a writable characteristic
      final writableChar = soncaService.characteristics.firstWhere(
        (c) => c.properties.write || c.properties.writeWithoutResponse,
        orElse: () => throw Exception('No writable characteristic found'),
      );
      
      debugPrint('BLE Send: Using characteristic UUID: 0x${writableChar.uuid.str.toUpperCase()}');
      
      // Write data to the characteristic
      await writableChar.write(data, withoutResponse: writableChar.properties.writeWithoutResponse);
      
      debugPrint('BLE Send: Data sent successfully');
    } catch (e) {
      debugPrint('BLE Send: Error sending data: $e');
    }
    debugPrint('-------------------------------------');
  }

  /// Receive byte array from the currently connected BLE device
  Future<void> receiveDataFromBLE() async {
    if (_selectedDevice == null) {
      debugPrint('BLE Receive: No device connected');
      return;
    }

    try {
      debugPrint('\n--- BLE Receive ---');
      debugPrint('BLE Receive: Setting up notification listener for device ${_selectedDevice!.name}');
      
      final bluetoothDevice = BluetoothDevice.fromId(_selectedDevice!.id);
      final services = await bluetoothDevice.discoverServices();
      
      // Find the Sonca service
      final soncaService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase().contains(SONCA_SERVICE.toLowerCase()),
        orElse: () => throw Exception('Sonca service not found'),
      );
      
      // Find a notifiable characteristic
      final notifiableChar = soncaService.characteristics.firstWhere(
        (c) => c.properties.notify || c.properties.indicate,
        orElse: () => throw Exception('No notifiable characteristic found'),
      );
      
      debugPrint('BLE Receive: Using characteristic UUID: 0x${notifiableChar.uuid.str.toUpperCase()}');
      
      // Enable notifications
      await notifiableChar.setNotifyValue(true);
      
      // Listen for incoming data
      notifiableChar.lastValueStream.listen((value) {
        debugPrint('BLE Receive: Received ${value.length} bytes');
        debugPrint('BLE Receive: Data = ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');

        debugPrint('-------------------------------------');
      });

      debugPrint('BLE Receive: Notification listener set up successfully');
    } catch (e) {
      debugPrint('BLE Receive: Error setting up receiver: $e');
    }
  }

  /// Send a protocol command to the connected BLE device
  Future<void> sendProtocolCommand(CommandPayload payload, {bool requireAck = false}) async {
    if (_selectedDevice == null) {
      debugPrint('Protocol: No device connected');
      return;
    }

    try {
      // Build the protocol frame
      final frame = _protocolHandler.buildCommandFrame(payload, requireAck: requireAck);
      final frameBytes = frame.encode();

      debugPrint('\n--- Protocol Send ---');
      debugPrint('Protocol: Sending command frame');
      debugPrint('Protocol: Category=${payload.category}, CmdId=0x${payload.cmdId.toRadixString(16)}, Op=${payload.operation}');
      debugPrint('Protocol: Frame size=${frameBytes.length} bytes');
      debugPrint('Protocol: Data=${frameBytes.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');

      // Send via BLE
      await sendDataToBLE(frameBytes);

      // Wait for ACK if required
      if (requireAck) {
        try {
          final ackFrame = await _protocolHandler.waitForAck(frame.header.msgId);
          debugPrint('Protocol: Received ACK - ${ackFrame.header}');
        } catch (e) {
          debugPrint('Protocol: ACK timeout or error: $e');
        }
      }

      debugPrint('Protocol: Command sent successfully');
      debugPrint('-------------------------------------');
    } catch (e) {
      debugPrint('Protocol: Error sending command: $e');
    }
  }

  /// Handle incoming protocol frames
  void _handleProtocolFrame(ProtocolFrame frame) {
    debugPrint('Protocol: Handling frame - msgId=${frame.header.msgId}, flags=0x${frame.header.flags.toRadixString(16)}');

    // Check if this is an ACK response
    if ((frame.header.flags & FrameFlags.ackResponse) != 0) {
      if ((frame.header.flags & FrameFlags.error) != 0) {
        debugPrint('Protocol: Received error response');
        if (frame.payload.isNotEmpty) {
          final errorCode = AckStatus.fromValue(frame.payload[0]);
          debugPrint('Protocol: Error code: $errorCode');
        }
      } else {
        debugPrint('Protocol: Received ACK');
      }
    }

    // Check if frame has data payload (responses to GET or unsolicited updates)
    if (frame.payload.isNotEmpty) {
      if((frame.header.flags & FrameFlags.ackResponse) == 0){
        try {
          final payload = CommandPayload.decode(frame.payload);
          debugPrint('Protocol: Decoded data payload - category=0x${payload.category.toRadixString(16)}, cmdId=0x${payload.cmdId.toRadixString(16)}, op=0x${payload.operation.toRadixString(16)}');

          final protocolService = getIt<ProtocolService>();
          final category = protocolService.getCategoryById(payload.category);
          if (category == null) return;

          final command = category.getCommand(payload.cmdId);
          if (command == null) return;

          // Manual Parsing of pair data: [NumPairs, Index1, Val1, Index2, Val2...]
          if (payload.data.isNotEmpty) {
            final numPairs = payload.data[0];
            int offset = 1;
            for (int i = 0; i < numPairs; i++) {
              if (offset >= payload.data.length) break;

              final index = payload.data[offset++];
              final indexDef = command.getIndex(index);

              if (indexDef != null) {
                final typeSize = getTypeSize(indexDef.type);
                if (offset + typeSize <= payload.data.length) {
                  final valueBytes = payload.data.sublist(offset, offset + typeSize);
                  final value = decodeValue(valueBytes, indexDef.type);
                  offset += typeSize;

                  final stateKey = "${command.name}_${indexDef.name}";
                  debugPrint('Protocol: Updating state - $stateKey = $value');
                  updateControlValue(stateKey, value);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Protocol: Error decoding payload: $e');
        }

      } else {
        try {
          final payload = AckPayload.decode(frame.payload);
          debugPrint('Protocol: Decoded ack payload - status=0x${payload.status.toRadixString(16)}, category=0x${payload.category.toRadixString(16)}, cmdId=0x${payload.cmdId.toRadixString(16)}');

          final protocolService = getIt<ProtocolService>();
          final category = protocolService.getCategoryById(payload.category);
          if (category == null) return;

          final command = category.getCommand(payload.cmdId);
          if (command == null) return;

          // Manual Parsing of pair data: [NumPairs, Index1, Val1, Index2, Val2...]
          if (payload.data.isNotEmpty) {
            final numPairs = payload.data[0];
            debugPrint('numPairs = $numPairs');
            int offset = 1;
            for (int i = 0; i < numPairs; i++) {
              if (offset >= payload.data.length) break;

              final index = payload.data[offset++];
              final indexDef = command.getIndex(index);

              if (indexDef != null) {
                final typeSize = getTypeSize(indexDef.type);
                if (offset + typeSize <= payload.data.length) {
                  final valueBytes = payload.data.sublist(offset, offset + typeSize);
                  final value = decodeValue(valueBytes, indexDef.type);
                  offset += typeSize;

                  final stateKey = "${command.name}_${indexDef.name}";
                  debugPrint('Protocol: Updating state - $stateKey = $value');
                  updateControlValue(stateKey, value);
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Protocol: Error decoding payload: $e');
        }

      }

    }

  }

  /// Fetch initial states for important controls (Main Areas)
  Future<void> fetchInitialStates() async {
    debugPrint('Protocol: Fetching initial states for Main Areas...');

    if (_selectedDevice == null) return;

    debugPrint('Main Areas Fetching data...');    
    final mixerService = getIt<MixerService>();
    
    // 1. Get all sections marked as "Main Area"
    final mainSections = mixerService.getSectionNamesByType("Main Area");
    
    if (mainSections.isEmpty) {
        // Fallback to legacy Area 1/2 if no "Main Area" type is defined yet in JSON
        await fetchSectionStates('Area 1');
        await fetchSectionStates('Area 2');
    } else {
        for (final sectionName in mainSections) {
            await fetchSectionStates(sectionName);
        }
    }
  }

  /// Fetch state for all parameters in a specific section
  Future<void> fetchSectionStates(String sectionName) async {
    if (_selectedDevice == null) return;

    final mixerService = getIt<MixerService>();
    final protocolService = getIt<ProtocolService>();
    final builder = getIt<DynamicCommandBuilder>();
    
    final section = mixerService.getItemsForSection(sectionName);
    if (section == null) return;

    debugPrint('Protocol: Syncing parameters for section "$sectionName"...');

    // 1. Special handling for EQ Area
    if (section.areaFormat == "EQ Area" && section.command != null) {
      final totalBands = section.totalEQBand ?? 10;
      final commandName = section.command!;
      
      // Find command definition and category
      CommandDefinition? cmdDef;
      String categoryName = "";
      for (var cat in protocolService.definition?.categories.values ?? <CategoryDefinition>[]) {
        final d = cat.getCommandByName(commandName);
        if (d != null) {
          cmdDef = d;
          categoryName = cat.name;
          break;
        }
      }

      if (cmdDef != null && cmdDef.indexRule != null) {
        debugPrint('Protocol: EQ Area detected. Fetching $totalBands bands for $commandName (Batched)...');
        
        // Construct a single batched map for all parameters across all bands
        Map<int, Map<String, dynamic>> allBands = {};
        for (int b = 0; b < totalBands; b++) {
          final fields = cmdDef.indexRule!.fieldOrder.values.toList();
          Map<String, dynamic> fieldMap = {};
          for (final fieldName in fields) {
            fieldMap[fieldName] = 0; // Value is ignored for GET
          }
          allBands[b] = fieldMap;
        }

        try {
          final commands = builder.buildMultiBandEqCommand(
            categoryName: categoryName,
            cmdId: cmdDef.id,
            bands: allBands,
            operation: CommandOperation.get,
          );
          for (final command in commands) {
            await sendProtocolCommand(command);
            // Small delay for processing the batched request
            await Future.delayed(const Duration(milliseconds: 50));
          }
        } catch (e) {
          debugPrint('Protocol: Error fetching batched EQ data for $commandName: $e');
        }
      }
    }
    
    // 2. Handle individual items in the section
    // Group parameters by Category and CommandID to bundle GET requests
    final Map<String, Map<int, Map<String, dynamic>>> batchedRequests = {};

    for (final item in section.items.values) {
       // 1. Get parameters to fetch
       final paramsToFetch = <String>[];
       if (item.indexList.isNotEmpty) {
         paramsToFetch.addAll(item.indexList);
       } else if (item.paramName != null && item.paramName!.isNotEmpty) {
         paramsToFetch.add(item.paramName!);
       }
       
       if (paramsToFetch.isEmpty) continue;
       
       // 2. Collate into batches
       for (final paramName in paramsToFetch) {
          // Find command definition to get the correct ID
          CommandDefinition? cmdDef;
          if (item.command.isNotEmpty) {
            cmdDef = protocolService.getCommandByName(item.category, item.command);
          }
          cmdDef ??= protocolService.findCommand(item.category, paramName);
              
          if (cmdDef == null) continue;

          // Organize by category and command ID
          batchedRequests[item.category] ??= {};
          batchedRequests[item.category]![cmdDef.id] ??= {};
          batchedRequests[item.category]![cmdDef.id]![paramName] = 0; // Value ignored for GET
       }
    }

    // 3. Dispatch the batched requests
    for (final categoryEntry in batchedRequests.entries) {
      final categoryName = categoryEntry.key;
      for (final commandEntry in categoryEntry.value.entries) {
        final cmdId = commandEntry.key;
        final parameters = commandEntry.value;

        try {
          final commands = builder.buildCommand(
            categoryName: categoryName,
            cmdId: cmdId,
            operation: CommandOperation.get,
            parameters: parameters,
          );
          
          final paramNames = parameters.keys.join(', ');
          debugPrint('Protocol: Sending batched GET for $categoryName Command 0x${cmdId.toRadixString(16)} (Params: $paramNames)');
          
          for (final command in commands) {
            await sendProtocolCommand(command);
            // Standard delay between command headers
            await Future.delayed(const Duration(milliseconds: 50));
          }
        } catch (e) {
          debugPrint('Protocol: Error fetching batched state for $categoryName:0x${cmdId.toRadixString(16)}: $e');
        }
      }
    }
  }

  /// Setup protocol notification listener for the connected device
  Future<void> _setupProtocolListener() async {
    if (_selectedDevice == null) {
      debugPrint('Protocol: No device connected');
      return;
    }

    try {
      debugPrint('\n--- Protocol Listener Setup ---');
      debugPrint('Protocol: Setting up notification listener for device ${_selectedDevice!.name}');
      
      final bluetoothDevice = BluetoothDevice.fromId(_selectedDevice!.id);
      final services = await bluetoothDevice.discoverServices();
      
      // Find the Sonca service
      final soncaService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase().contains(SONCA_SERVICE.toLowerCase()),
        orElse: () => throw Exception('Sonca service not found'),
      );
      
      // Find a notifiable characteristic
      final notifiableChar = soncaService.characteristics.firstWhere(
        (c) => c.properties.notify || c.properties.indicate,
        orElse: () => throw Exception('No notifiable characteristic found'),
      );
      
      //debugPrint('Protocol: Using characteristic UUID: 0x${notifiableChar.uuid.str.toUpperCase()}');
      
      // Enable notifications
      await notifiableChar.setNotifyValue(true);
      
      // Listen for incoming data and pass to protocol handler
      notifiableChar.lastValueStream.listen((value) {
        debugPrint('Protocol: Received ${value.length} bytes from BLE');
        debugPrint('Protocol: Raw data = ${value.map((b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join(' ')}');
        
        // Pass to protocol handler for decoding
        _protocolHandler.handleIncomingFrame(value);
      });

      debugPrint('Protocol: Notification listener set up successfully');
      debugPrint('-------------------------------------');
    } catch (e) {
      debugPrint('Protocol: Error setting up listener: $e');
    }
  }

  Future<void> disconnectDevice() async {
    if (_selectedDevice != null) {
       try {
        await _repository.disconnect(_selectedDevice!);
        _selectedDevice = null;
        notifyListeners();
      } catch (e) {
        debugPrint("Error disconnecting device: $e");
      }
    }
  }
}
