import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mixer_sonca/core/services/config_service.dart';
import 'package:mixer_sonca/core/models/mixer_define.dart';
import 'package:mixer_sonca/injection.dart';

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
  final ConfigService _configService;

  BleRepositoryImpl({required ConfigService configService}) 
      : _configService = configService;

  String _extractSoncaName(Map<int, List<int>> manufacturerData) {
    try {
      // Iterate through manufacturer data entries
      for (var entry in manufacturerData.entries) {
        final data = entry.value;
        
        // Need at least 2 bytes to extract model ID
        if (data.length >= 2) {
          // Extract first 2 bytes and convert to hex string (e.g., 0x41 0x37 -> "4137")
          final byte1 = data[0].toRadixString(16).padLeft(2, '0');
          final byte2 = data[1].toRadixString(16).padLeft(2, '0');
          final hexString = byte1 + byte2;
          //debugPrint('BLE: _extractSoncaName hexString = ' + hexString);
          
          // Convert hex to decimal (e.g., "4137" -> 16695, but we want "413" -> 1043)
          // Actually, looking at the example: 0x413 means we take 3 hex digits
          // Let's try with 3 bytes for 3 hex digits
          if (data.length >= 2) {
            // Take first 3 hex digits: byte1 (2 digits) + first digit of byte2
            final modelIdHex = hexString.substring(0, 3); // "413"
            final modelId = int.tryParse(modelIdHex, radix: 16); // Convert hex to decimal
            
            if (modelId != null) {
              //debugPrint('BLE: Extracted model ID: $modelId (hex: 0x$modelIdHex) from mfg data');
              
              // Match against config models
              for (var model in _configService.models) {
                if (model.modelId == modelId) {
                  //debugPrint('BLE: Matched model: ${model.modelName}');
                  return model.modelName;
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('BLE: Error extracting Sonca name: $e');
    }
    
    return "N/A";
  }

  @override
  Stream<List<BleDevice>> get scanResults => FlutterBluePlus.scanResults.map(
        (results) => results
            .where((r) => r.advertisementData.serviceUuids.any((u) => u.toString().contains(SONCA_SERVICE.toLowerCase())))
            .map((r) {
              final soncaName = _extractSoncaName(r.advertisementData.manufacturerData);
              
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
    final state = await FlutterBluePlus.adapterState.first;
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

  void init() {
    _repository.scanResults.listen((devices) {
      _devices = devices;
      notifyListeners();
    });
  }

  Future<void> scanDevices() async {
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

      // Start display _mixerCurrent
      _updateDisplayMixer();

      // Test send and receive BLE
      await sendDataToBLE([0x01, 0x02, 0x03]); // Example test data
      await receiveDataFromBLE();

      
    } catch (e) {
      debugPrint("Error connecting to device: $e");
      // Handle error (maybe clear selection or show toast)
    } finally {
      _isConnecting = false;
      _connectingDeviceId = null;
      notifyListeners();
    }
  }

  List<MixerDefine> _displayMixerCurrent = [];
  List<MixerDefine> get displayMixerCurrent => _displayMixerCurrent;

  void _updateDisplayMixer() {
     try {
       final configService = getIt<ConfigService>();
       final globalItem = configService.mixerCurrent.firstWhere((e) => e.name == "GLOBAL", orElse: () => MixerDefine(name: 'NOT_FOUND', children: []));
       
       if (globalItem.name != 'NOT_FOUND') {
         _displayMixerCurrent = globalItem.children;
         debugPrint('BleViewModel: Updated display mixer with ${_displayMixerCurrent.length} items');
       } else {
         _displayMixerCurrent = [];
         debugPrint('BleViewModel: GLOBAL item not found in mixerCurrent');
       }
       notifyListeners();
     } catch (e) {
       debugPrint('BleViewModel: Error updating display mixer: $e');
     }
  }

  void toggleMixerItem(MixerDefine item) {
    item.itemValue = item.itemValue == 0 ? 1 : 0;
    notifyListeners();
  }
  
  void setMixerItemValue(MixerDefine item, int value) {
    item.itemValue = value;
    notifyListeners();
  }

  void selectRadioItem(MixerDefine item, List<MixerDefine> group) {
    for (var i in group) {
      i.itemValue = 0;
    }
    item.itemValue = 1;
    notifyListeners();
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
