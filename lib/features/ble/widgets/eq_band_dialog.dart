import 'package:flutter/material.dart';
import 'package:mixer_sonca/features/ble/widgets/filter_icon.dart';

class EqBandDialog extends StatefulWidget {
  final int bandIndex;
  final double initialGain;
  final int initialFreq;
  final double initialQ;
  final int initialType;
  final Map<String, int> filterTypes; // e.g. {'Peak': 0, 'LowShelf': 1, ...}
  final Map<String, dynamic>? fieldLimits;

  const EqBandDialog({
    super.key,
    required this.bandIndex,
    required this.initialGain,
    required this.initialFreq,
    required this.initialQ,
    required this.initialType,
    required this.filterTypes,
    this.fieldLimits,
  });

  @override
  State<EqBandDialog> createState() => _EqBandDialogState();
}

class _EqBandDialogState extends State<EqBandDialog> {
  late TextEditingController _gainController;
  late TextEditingController _freqController;
  late TextEditingController _qController;
  late int _selectedType;

  @override
  void initState() {
    super.initState();
    _gainController = TextEditingController(text: widget.initialGain.toStringAsFixed(1));
    _freqController = TextEditingController(text: widget.initialFreq.toString());
    _qController = TextEditingController(text: widget.initialQ.toStringAsFixed(1));
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _gainController.dispose();
    _freqController.dispose();
    _qController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2C2C2C),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 300,
          maxHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).viewInsets.bottom - 16,
        ),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(), // Removes the white overscroll glow
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title Bar - Compact
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: const Color(0xFFC0C0C0),
                  child: Text(
                    'Nhập giá trị EQ ${widget.bandIndex}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInputField('Gain (dB)', _gainController),
                      const SizedBox(height: 4),
                      _buildInputField('Freq (Hz)', _freqController),
                      const SizedBox(height: 4),
                      _buildInputField('Q', _qController),
                      const SizedBox(height: 8),
                      _buildDropdownField('Filter'),
                    ],
                  ),
                ),
                
                // Buttons Row
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton('Thay đổi', () {
                        final gainValue = double.tryParse(_gainController.text) ?? widget.initialGain;
                        final freqValue = double.tryParse(_freqController.text) ?? widget.initialFreq.toDouble();
                        final qValue = double.tryParse(_qController.text) ?? widget.initialQ;

                        // Validation
                        if (widget.fieldLimits != null) {
                          final gainLimit = widget.fieldLimits!['gain'];
                          if (gainLimit != null) {
                             final min = double.tryParse(gainLimit['min'].toString()) ?? -100.0;
                             final max = double.tryParse(gainLimit['max'].toString()) ?? 100.0;
                             if (gainValue < min || gainValue > max) {
                               _showError(context, 'Gain phải nằm trong khoảng $min dB đến $max dB');
                               return;
                             }
                          }

                          final freqLimit = widget.fieldLimits!['f0'];
                          if (freqLimit != null) {
                             final min = double.tryParse(freqLimit['min'].toString()) ?? 0.0;
                             final max = double.tryParse(freqLimit['max'].toString()) ?? 24000.0;
                             if (freqValue < min || freqValue > max) {
                               _showError(context, 'Tần số phải nằm trong khoảng $min Hz đến $max Hz');
                               return;
                             }
                          }

                          final qLimit = widget.fieldLimits!['Q'];
                          if (qLimit != null) {
                             final min = double.tryParse(qLimit['min'].toString()) ?? 0.0;
                             final max = double.tryParse(qLimit['max'].toString()) ?? 100.0;
                             if (qValue < min || qValue > max) {
                               _showError(context, 'Q phải nằm trong khoảng $min đến $max');
                               return;
                             }
                          }
                        }

                        Navigator.of(context).pop({
                          'gain': gainValue,
                          'f0': freqValue.toInt(),
                          'Q': qValue,
                          'type': _selectedType,
                        });
                      }),
                      _buildButton('Hủy', () {
                        Navigator.of(context).pop(null);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: const TextStyle(color: Colors.orange, fontSize: 16),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.only(bottom: 4),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.orange),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.orange, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedType,
                dropdownColor: const Color(0xFF2C2C2C),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.orange), // Add icon back
                isDense: true,
                isExpanded: true, // Force to fill width
                style: const TextStyle(color: Colors.orange, fontSize: 16),
                items: widget.filterTypes.entries
                    .where((entry) => entry.key.toUpperCase() != 'UNKNOWN')
                    .map((entry) {
                  String displayName = entry.key;
                  // Map display names according to requirements
                  final upper = entry.key.toUpperCase();
                  if (upper == 'PEAKING') {
                    displayName = 'PEAK';
                  } else if (upper == 'LOW_SHELF') {
                    displayName = 'LSF';
                  } else if (upper == 'HIGH_SHELF') {
                    displayName = 'HSF';
                  } else if (upper == 'LOW_PASS_LINKWITZ') {
                    displayName = 'LLwz';
                  } else if (upper == 'HIGH_PASS_LINKWITZ') {
                    displayName = 'HLwz';
                  } else if (upper == 'LOW_PASS_BUTTERWORTH') {
                    displayName = 'LBut';
                  } else if (upper == 'HIGH_PASS_BUTTERWORTH') {
                    displayName = 'HBut';
                  } else if (upper == 'LOW_PASS_BESSEL') {
                    displayName = 'LBsl';
                  } else if (upper == 'HIGH_PASS_BESSEL') {
                    displayName = 'HBsl';
                  } else if (upper == 'NOTCH') {
                    displayName = 'NOTCH';
                  } else if (upper == 'FLAT') {
                    displayName = 'FLAT';
                  }

                  return DropdownMenuItem<int>(
                    value: entry.value,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterIcon(
                          typeIndex: entry.value,
                          width: 45,
                          height: 22,
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedType = newValue;
                    });
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 100,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: Border.all(color: Colors.white24),
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Giá trị không hợp lệ', style: TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}
