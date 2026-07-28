import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/ui/modern/modern_permission_page.dart';
import 'package:mixer_sonca/features/ble/ui/modern/modern_scan_page.dart';
import 'package:mixer_sonca/features/ble/ui/modern/modern_main_area_page.dart';

class ModernBlePage extends StatefulWidget {
  const ModernBlePage({super.key});

  @override
  State<ModernBlePage> createState() => _ModernBlePageState();
}

class _ModernBlePageState extends State<ModernBlePage> {
  bool _isChecking = true;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    
    // Wait for the next frame so context.read works
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = context.read<BleViewModel>();
      viewModel.init(); // Initialize the protocol stream listener!
      final isOk = await viewModel.checkPermissionsAndBluetooth();
      
      if (mounted) {
        setState(() {
          _hasPermissions = isOk;
          _isChecking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isChecking
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _hasPermissions
              ? (viewModel.selectedDevice != null && !viewModel.isConnecting
                  ? const ModernMainAreaPage()
                  : const ModernScanPage())
              : ModernPermissionPage(
                  onPermissionsGranted: () {
                    setState(() {
                      _hasPermissions = true;
                    });
                  },
                ),
    );
  }
}
