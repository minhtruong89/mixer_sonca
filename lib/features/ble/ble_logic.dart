import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// --- Model ---
class BleDevice extends Equatable {
  final String id;
  final String name;
  final int rssi;
  final Map<int, List<int>> manufacturerData;
  final List<String> serviceUuids;
  final bool isConnectable;
  final int txPower;

  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.manufacturerData,
    required this.serviceUuids,
    required this.isConnectable,
    required this.txPower,
  });

  @override
  List<Object?> get props => [id, name, rssi, manufacturerData, serviceUuids, isConnectable, txPower];
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
}

class BleRepositoryImpl implements BleRepository {
  @override
  Stream<List<BleDevice>> get scanResults => FlutterBluePlus.scanResults.map(
        (results) => results
            .where((r) => r.advertisementData.serviceUuids.any((u) => u.toString().contains(SONCA_SERVICE.toLowerCase())))
            .map((r) => BleDevice(
                  id: r.device.remoteId.str,
                  name: r.device.platformName.isNotEmpty ? r.device.platformName : "N/A",
                  rssi: r.rssi,
                  manufacturerData: r.advertisementData.manufacturerData,
                  serviceUuids: r.advertisementData.serviceUuids.map((u) => u.toString()).toList(),
                  isConnectable: r.advertisementData.connectable,
                  txPower: r.advertisementData.txPowerLevel ?? 0,
                ))
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
}

// --- ViewModel ---
class BleViewModel extends ChangeNotifier {
  final BleRepository _repository;

  BleViewModel({required BleRepository repository})
      : _repository = repository;

  List<BleDevice> _devices = [];
  List<BleDevice> get devices => _devices;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  BleDevice? _selectedDevice;
  BleDevice? get selectedDevice => _selectedDevice;

  void init() {
    _repository.scanResults.listen((devices) {
      _devices = devices;
      notifyListeners();
    });
  }

  Future<void> scanDevices() async {
    // 1. Check Permissions
    final granted = await _repository.checkPermissions();
    if (!granted) {
      debugPrint("Permissions not granted");
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
           return; // Or notify UI to show message
        }
      } catch (e) {
        debugPrint("Error turning on Bluetooth: $e");
        return;
      }
    }

    _isScanning = true;
    notifyListeners();

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
}
