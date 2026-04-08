import 'package:flutter/material.dart';
import 'package:mixer_sonca/features/ble/widgets/filter_icon.dart';

class EqBandSlider extends StatelessWidget {
  final int bandIndex;
  final String f0Text;
  final String qText;
  final String gainText;
  final double gain;
  final double minGain;
  final double maxGain;
  final int filterType;
  final VoidCallback onHeaderTapped;
  final ValueChanged<double> onGainChanged;

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
    required this.onHeaderTapped,
    required this.onGainChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        children: [
          // Header Texts
          InkWell(
            onTap: onHeaderTapped,
            child: Column(
              children: [
                Text(
                  f0Text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      qText,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    FilterIcon(
                      typeIndex: filterType,
                      width: 24,
                      height: 12,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  gainText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Slider Area
          Expanded(
            child: Row(
              children: [
                // Scale Ticks
                _buildScale(),
                
                // Vertical Slider
                Expanded(
                  child: _VerticalEqSlider(
                    value: gain,
                    min: minGain,
                    max: maxGain,
                    onChanged: onGainChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScale() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _scaleTick('+${maxGain.toStringAsFixed(1)}'),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick('0.0', isCenter: true),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick('${minGain.toStringAsFixed(1)}'),
      ],
    );
  }

  Widget _scaleTick(String value, {bool isCenter = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 30,
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
  final ValueChanged<double> onChanged;

  const _VerticalEqSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        
        return GestureDetector(
          onVerticalDragUpdate: (details) {
            final dy = details.localPosition.dy;
            final newValue = (1 - (dy / height)) * (max - min) + min;
            onChanged(newValue.clamp(min, max));
          },
          onTapDown: (details) {
             final dy = details.localPosition.dy;
             final newValue = (1 - (dy / height)) * (max - min) + min;
             onChanged(newValue.clamp(min, max));
          },
          child: Stack(
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
              
              // Thumb
              Positioned(
                bottom: (value - min) / (max - min) * height - 15, // 15 is half of thumb height
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
          ),
        );
      },
    );
  }
}
