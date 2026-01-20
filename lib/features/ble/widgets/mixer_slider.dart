import 'package:flutter/material.dart';

class MixerSlider extends StatelessWidget {
  final String label;
  final double value;
  final bool isMuted;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onMuteChanged;

  const MixerSlider({
    super.key,
    required this.label,
    required this.value,
    required this.isMuted,
    this.min = 0,
    this.max = 100,
    required this.onChanged,
    required this.onMuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Label
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          
          // Value and Mute Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value.toInt().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isMuted ? Icons.volume_off : Icons.volume_up,
                  color: isMuted ? Colors.redAccent : Colors.white,
                  size: 24,
                ),
                onPressed: () => onMuteChanged(!isMuted),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Slider Area (Scale + Slider)
          Expanded(
            child: Row(
              children: [
                // Scale Ticks
                _buildScale(),
                
                // Vertical Slider
                Expanded(
                  child: _VerticalSlider(
                    value: value,
                    min: min,
                    max: max,
                    onChanged: onChanged,
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
        _scaleTick('100'),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick('75'),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick('50', isCenter: true),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick('25'),
        _scaleTick(''),
        _scaleTick(''),
        _scaleTick('0'),
      ],
    );
  }

  Widget _scaleTick(String value, {bool isCenter = false}) {
    return Row(
      children: [
        SizedBox(
          width: 25,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: isCenter ? Colors.greenAccent : Colors.white60,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: value.isNotEmpty ? 8 : 4,
          height: 2,
          color: isCenter ? Colors.greenAccent : Colors.white24,
        ),
      ],
    );
  }
}

class _VerticalSlider extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _VerticalSlider({
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
              
              // Active Bar (Optional, typical in mixers to show level or just the thumb)
              // Mixer sliders often don't have a colored active track like system sliders,
              // but let's add a subtle one if desired.
              
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
