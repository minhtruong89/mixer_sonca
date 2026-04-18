import 'package:flutter/material.dart';

class MixerSlider extends StatelessWidget {
  final String label;
  final double value;
  final bool isMuted;
  final bool showMute;
  final double min;
  final double max;
  final VoidCallback? onLabelTap;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onMuteChanged;

  const MixerSlider({
    super.key,
    required this.label,
    required this.value,
    required this.isMuted,
    this.showMute = true,
    this.min = 0,
    this.max = 100,
    this.onLabelTap,
    required this.onChanged,
    required this.onMuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Label
          GestureDetector(
            onTap: onLabelTap,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontStyle: onLabelTap != null ? FontStyle.italic : FontStyle.normal,
                decoration: onLabelTap != null ? TextDecoration.underline : TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          
          // Value and Mute Icon Header
          SizedBox(
            height: 32, // Consistent height for all sliders
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Value Text (Centered when no icon, shifted left if icon exists to prevent overlap)
                Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                // Mute Icon
                if (showMute) ...[
                   const SizedBox(width: 4),
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
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Slider Area (Scale + Slider)
          Expanded(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final ticks = ['100', '', '', '75', '', '', '50', '', '', '25', '', '', '0'];
        
        return Stack(
          clipBehavior: Clip.none,
          children: List.generate(ticks.length, (index) {
            final label = ticks[index];
            final topPos = (index / (ticks.length - 1)) * h;
            
            return Positioned(
              top: topPos - 7, // 7 is approx half height of 12pt text
              left: 0,
              right: 0,
              child: _scaleTick(label, isCenter: label == '50'),
            );
          }),
        );
      },
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
            final localPos = details.localPosition;
            if (localPos.dx < -constraints.maxWidth / 2 || localPos.dx > constraints.maxWidth * 1.5) {
              return;
            }
            final dy = localPos.dy;
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
          ),
        );
      },
    );
  }
}
