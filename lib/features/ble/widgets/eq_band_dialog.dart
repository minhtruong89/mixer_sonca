import 'package:flutter/material.dart';

class EqBandDialog extends StatefulWidget {
  final int bandIndex;
  final double initialGain;
  final int initialFreq;
  final double initialQ;
  final int initialType;
  final Map<String, int> filterTypes; // e.g. {'Peak': 0, 'LowShelf': 1, ...}

  const EqBandDialog({
    super.key,
    required this.bandIndex,
    required this.initialGain,
    required this.initialFreq,
    required this.initialQ,
    required this.initialType,
    required this.filterTypes,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: const Color(0xFFC0C0C0), // light gray
              child: Text(
                'Nhập giá trị EQ ${widget.bandIndex}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInputField('Gain (dB)', _gainController),
                      const SizedBox(height: 16),
                      _buildInputField('Freq (Hz)', _freqController),
                      const SizedBox(height: 16),
                      _buildInputField('Q', _qController),
                      const SizedBox(height: 24),
                      _buildDropdownField('Filter'),
                    ],
                  ),
                ),
              ),
            ),
            
            // Buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0, top: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildButton('Thay đổi', () {
                    // Extract values and check validity
                    final gain = double.tryParse(_gainController.text) ?? widget.initialGain;
                    final freq = int.tryParse(_freqController.text) ?? widget.initialFreq;
                    final q = double.tryParse(_qController.text) ?? widget.initialQ;

                    Navigator.of(context).pop({
                      'gain': gain,
                      'f0': freq,
                      'Q': q,
                      'type': _selectedType,
                    });
                  }),
                  _buildButton('Hủy', () {
                    Navigator.of(context).pop(null);
                  }),
                ],
              ),
            )
          ],
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
                items: widget.filterTypes.entries.map((entry) {
                  return DropdownMenuItem<int>(
                    value: entry.value,
                    child: Text(
                      entry.key,
                      overflow: TextOverflow.ellipsis,
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
}
