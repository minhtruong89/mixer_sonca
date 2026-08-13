import 'package:flutter/material.dart';
import 'package:mixer_sonca/core/services/mixer_service.dart';
import 'package:mixer_sonca/injection.dart';

class MixerSlider extends StatefulWidget {
  final String label;
  final double value;
  final bool isMuted;
  final bool showMute;
  final double min;
  final double max;
  final VoidCallback? onLabelTap;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool> onMuteChanged;
  final double displayDivide;
  final double displayOffset;
  final String displayText;

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
    this.displayDivide = 1,
    this.displayOffset = 0,
    this.displayText = '',
  });

  @override
  State<MixerSlider> createState() => _MixerSliderState();
}

class _MixerSliderState extends State<MixerSlider> {
  bool _isDragging = false;
  double _localValue = 0;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = _isDragging ? _localValue : widget.value;

    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Label
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onLabelTap,
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (widget.onLabelTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.open_in_new,
                    color: Colors.greenAccent,
                    size: 14,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          
          // Value and Mute Icon Header
          SizedBox(
            height: 32, // Consistent height for all sliders
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Value Text
                Text(
                  '${((effectiveValue - widget.displayOffset) / widget.displayDivide).toStringAsFixed(((effectiveValue - widget.displayOffset) / widget.displayDivide) % 1 == 0 ? 0 : 1)}${widget.displayText}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                // Mute Icon
                if (widget.showMute) ...[
                   const SizedBox(width: 4),
                   IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      widget.isMuted ? Icons.volume_off : Icons.volume_up,
                      color: widget.isMuted ? Colors.redAccent : Colors.white,
                      size: 24,
                    ),
                    onPressed: () => widget.onMuteChanged(!widget.isMuted),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Slider Area (Scale + Slider)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final height = constraints.maxHeight;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (details) {
                    final dy = details.localPosition.dy;
                    var newValue = (1 - (dy / height)) * (widget.max - widget.min) + widget.min;
                    try {
                      if (getIt.isRegistered<MixerService>() && getIt<MixerService>().getSchemaVersionForActiveModel() == 2) {
                        newValue = newValue.roundToDouble();
                      }
                    } catch (_) {}
                    final clamped = newValue.clamp(widget.min, widget.max);
                    setState(() {
                      _isDragging = true;
                      _localValue = clamped;
                    });
                    widget.onChanged(clamped);
                  },
                  onVerticalDragUpdate: (details) {
                    final dy = details.localPosition.dy;
                    var newValue = (1 - (dy / height)) * (widget.max - widget.min) + widget.min;
                    try {
                      if (getIt.isRegistered<MixerService>() && getIt<MixerService>().getSchemaVersionForActiveModel() == 2) {
                        newValue = newValue.roundToDouble();
                      }
                    } catch (_) {}
                    final clamped = newValue.clamp(widget.min, widget.max);
                    setState(() {
                      _localValue = clamped;
                    });
                    widget.onChanged(clamped);
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
                    var newValue = (1 - (dy / height)) * (widget.max - widget.min) + widget.min;
                    try {
                      if (getIt.isRegistered<MixerService>() && getIt<MixerService>().getSchemaVersionForActiveModel() == 2) {
                        newValue = newValue.roundToDouble();
                      }
                    } catch (_) {}
                    widget.onChanged(newValue.clamp(widget.min, widget.max));
                  },
                  onDoubleTap: () {
                    widget.onChanged((widget.min + widget.max) / 2);
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
                        child: _VerticalSlider(
                          value: effectiveValue,
                          min: widget.min,
                          max: widget.max,
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
        
        final scaledMin = (widget.min - widget.displayOffset) / widget.displayDivide;
        final scaledMax = (widget.max - widget.displayOffset) / widget.displayDivide;
        final range = scaledMax - scaledMin;
        
        // Helper to format scale labels
        String formatLabel(double val) {
          if (val % 1 == 0) return val.toInt().toString();
          return val.toStringAsFixed(1);
        }

        // We use 13 slots (0 to 12) for a detailed scale
        // Labels at 100%, 75%, 50%, 25%, 0%
        return Stack(
          clipBehavior: Clip.none,
          children: List.generate(13, (index) {
            String label = '';
            if (index == 0) {
              label = formatLabel(scaledMax);
            } else if (index == 3) {
              label = formatLabel(scaledMin + range * 0.75);
            } else if (index == 6) {
              label = formatLabel(scaledMin + range * 0.5);
            } else if (index == 9) {
              label = formatLabel(scaledMin + range * 0.25);
            } else if (index == 12) {
              label = formatLabel(scaledMin);
            }
            
            final topPos = (index / 12) * h;
            
            return Positioned(
              top: topPos - 7,
              left: 0,
              right: 0,
              child: _scaleTick(label, isCenter: index == 6),
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
          width: 30,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: isCenter ? Colors.greenAccent : Colors.white60,
                fontSize: 12,
              ),
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

  const _VerticalSlider({
    required this.value,
    required this.min,
    required this.max,
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
          );
      },
    );
  }
}
