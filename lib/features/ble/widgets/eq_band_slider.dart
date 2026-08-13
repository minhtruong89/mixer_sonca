import 'package:flutter/material.dart';
import 'package:mixer_sonca/features/ble/widgets/filter_icon.dart';

class EqBandSlider extends StatefulWidget {
  final int bandIndex;
  final String f0Text;
  final String qText;
  final String gainText;
  final double gain;
  final double minGain;
  final double maxGain;
  final int filterType;
  final bool isEnable;
  final bool hasEnableField;
  final bool hasValue;
  final VoidCallback onHeaderTapped;
  final ValueChanged<double> onGainChanged;
  final ValueChanged<bool>? onEnableChanged;

  const EqBandSlider({
    super.key,
    required this.bandIndex,
    required this.f0Text,
    required this.qText,
    required this.gainText,
    required this.gain,
    this.minGain = -6.0,
    this.maxGain = 6.0,
    required this.filterType,
    this.isEnable = true,
    this.hasEnableField = false,
    this.hasValue = true,
    required this.onHeaderTapped,
    required this.onGainChanged,
    this.onEnableChanged,
  });

  @override
  State<EqBandSlider> createState() => _EqBandSliderState();
}

class _EqBandSliderState extends State<EqBandSlider> {
  bool _isDragging = false;
  double _localGain = 0;

  @override
  Widget build(BuildContext context) {
    final effectiveGain = _isDragging ? _localGain : widget.gain;
    final displayGainText = "${effectiveGain > 0 ? '+' : ''}${effectiveGain.toStringAsFixed(1)}dB";

    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          // Optional Enable Switch/Button
          if (widget.hasEnableField) ...[
            GestureDetector(
              onTap: () => widget.onEnableChanged?.call(!widget.isEnable),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isEnable ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.isEnable ? Colors.greenAccent : Colors.redAccent,
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.isEnable ? "ON" : "OFF",
                  style: TextStyle(
                    color: widget.isEnable ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          // Header Texts
          InkWell(
            onTap: widget.onHeaderTapped,
            child: Opacity(
              opacity: (widget.hasEnableField && !widget.isEnable) ? 0.4 : 1.0,
              child: Column(
                children: [
                  Text(
                    widget.f0Text,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.qText,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      FilterIcon(
                        typeIndex: widget.filterType,
                        width: 24,
                        height: 12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.hasValue ? displayGainText : "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          
          // Slider Area
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (details) {
                    final dy = details.localPosition.dy;
                    final newValue = ((1 - (dy / height)) * (widget.maxGain - widget.minGain) + widget.minGain).clamp(widget.minGain, widget.maxGain);
                    setState(() {
                      _isDragging = true;
                      _localGain = newValue;
                    });
                    widget.onGainChanged(newValue);
                  },
                  onVerticalDragUpdate: (details) {
                    final dy = details.localPosition.dy;
                    final newValue = ((1 - (dy / height)) * (widget.maxGain - widget.minGain) + widget.minGain).clamp(widget.minGain, widget.maxGain);
                    setState(() {
                      _localGain = newValue;
                    });
                    widget.onGainChanged(newValue);
                  },
                  onVerticalDragEnd: (_) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  onVerticalDragCancel: () {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  onTapUp: (details) {
                    final dy = details.localPosition.dy;
                    final newValue = ((1 - (dy / height)) * (widget.maxGain - widget.minGain) + widget.minGain).clamp(widget.minGain, widget.maxGain);
                    widget.onGainChanged(newValue);
                  },
                  onDoubleTap: () {
                    final centerVal = (widget.minGain + widget.maxGain) / 2;
                    setState(() {
                      _localGain = centerVal;
                    });
                    widget.onGainChanged(centerVal);
                  },
                  child: Row(
                    children: [
                      // Scale Ticks
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20), // Align with thumb center
                          child: _buildScale(),
                        ),
                      ),
                      
                      // Vertical Slider
                      Expanded(
                        child: _VerticalEqSlider(
                          value: effectiveGain,
                          min: widget.minGain,
                          max: widget.maxGain,
                          hasValue: widget.hasValue,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScale() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final ticks = [
          '+${widget.maxGain.toInt()}', '', '', '', '', '', 
          '0', 
          '', '', '', '', '', 
          widget.minGain.toInt().toString()
        ];
        
        return Stack(
          clipBehavior: Clip.none,
          children: List.generate(ticks.length, (index) {
            final label = ticks[index];
            final topPos = (index / (ticks.length - 1)) * h;
            
            return Positioned(
              top: topPos - 6, // 6 is approx half height of 10pt text
              left: 0,
              right: 0,
              child: _scaleTick(label, isCenter: label == '0.0'),
            );
          }),
        );
      },
    );
  }

  Widget _scaleTick(String value, {bool isCenter = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 24,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isCenter ? Colors.white : Colors.white60,
              fontSize: 10,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: value.isNotEmpty ? 8 : 4,
          height: 2,
          color: isCenter ? Colors.green : Colors.white24,
        ),
      ],
    );
  }
}

class _VerticalEqSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final bool hasValue;

  const _VerticalEqSlider({
    required this.value,
    required this.min,
    required this.max,
    this.hasValue = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        
        return Stack(
          alignment: Alignment.bottomCenter,
          children: [
              // Track
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Thumb (only visible if hasValue is true)
              if (hasValue)
                Positioned(
                  bottom: (value - min) / (max - min) * (height - 40), 
                  child: Container(
                    width: 30,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFF5F5F5),
                          Color(0xFFBDBDBD),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 2,
                        color: Colors.black26,
                      ),
                    ),
                  ),
                ),
            ],
          );
      },
    );
  }
}
