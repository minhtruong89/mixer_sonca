import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';
import 'modern_slider_helper.dart';

class ModernHorizontalSlider extends StatefulWidget {
  final DisplayItem item;
  final String label;

  const ModernHorizontalSlider({super.key, required this.item, required this.label});

  @override
  State<ModernHorizontalSlider> createState() => _ModernHorizontalSliderState();
}

class _ModernHorizontalSliderState extends State<ModernHorizontalSlider> {
  double _currentValue = 50.0;
  bool _isDragging = false;
  bool _hasVibratedAtPoint = false;
  late double _min;
  late double _max;
  String? _muteParam;
  String? _volumeParam;

  @override
  void initState() {
    super.initState();
    _min = widget.item.control.minValue.toDouble();
    _max = widget.item.control.maxValue.toDouble();

    if (widget.item.indexList.isNotEmpty) {
      for (final p in widget.item.indexList) {
        if (p.endsWith('_mute')) {
          _muteParam = p;
          break;
        }
      }
      _volumeParam = widget.item.indexList.firstWhere(
        (p) => p != _muteParam, 
        orElse: () => widget.item.indexList[0]
      );
    } else {
      _volumeParam = widget.item.paramName;
    }
  }

  void _sendValue(double val) {
    final viewModel = context.read<BleViewModel>();

    if (_muteParam != null) {
      final muteStateKey = "${widget.item.command}_$_muteParam";
      if (viewModel.getControlValue(muteStateKey, defaultValue: 0) == 1) {
        ModernSliderHelper.throttledSend(context, widget.item, 0, _muteParam!);
      }
    }
    
    if (_volumeParam != null) {
      ModernSliderHelper.throttledSend(context, widget.item, val, _volumeParam!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();
    final stateKey = "${widget.item.command}_${_volumeParam ?? ''}";
    
    dynamic rawVal = viewModel.getControlValue(stateKey);
    final bool hasValue = (rawVal != null) || _isDragging;
    
    if (!_isDragging && rawVal != null) {
      if (rawVal is int) {
        _currentValue = rawVal.toDouble();
      } else if (rawVal is double) {
        _currentValue = rawVal;
      }
    }
    
    final String muteKey = _muteParam != null
        ? "${widget.item.command}_$_muteParam"
        : "${widget.item.command}_volume_mute";
    final bool isMuted = (viewModel.getControlValue(muteKey, defaultValue: 0) == 1);

    final displayVal = hasValue ? ModernSliderHelper.formatDisplayValue(_currentValue, widget.item) : "";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
              Text(
                displayVal,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sliderWidth = constraints.maxWidth;
                return GestureDetector(
                  onTapDown: (details) {
                    setState(() {
                      _updateValueFromLocalPosition(details.localPosition.dx, sliderWidth);
                    });
                  },
                  onHorizontalDragStart: (details) {
                    setState(() {
                      _isDragging = true;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _updateValueFromLocalPosition(details.localPosition.dx, sliderWidth);
                    });
                  },
                  onHorizontalDragEnd: (details) {
                    setState(() {
                      _isDragging = false;
                    });
                  },
                  child: CustomPaint(
                    painter: _HorizontalSliderPainter(
                      value: _currentValue,
                      min: _min,
                      max: _max,
                      isMuted: isMuted,
                      hasValue: hasValue,
                      vibrateValue: widget.item.control.vibrateValue,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _updateValueFromLocalPosition(double dx, double width) {
    double percent = dx / width;
    percent = percent.clamp(0.0, 1.0);
    double newValue = _min + percent * (_max - _min);

    final vibrateVal = widget.item.control.vibrateValue;
    if (vibrateVal != null) {
      final prevDiff = _currentValue - vibrateVal;
      final newDiff = newValue - vibrateVal;

      final crossed = (prevDiff < 0 && newDiff >= 0) || (prevDiff > 0 && newDiff <= 0);
      final isNear = newDiff.abs() <= ((_max - _min) * 0.03);

      if ((crossed || isNear) && !_hasVibratedAtPoint) {
        debugPrint('Haptic Vibrate triggered at newValue: $newValue (vibrateVal: $vibrateVal)');
        ModernSliderHelper.triggerHaptic();
        _hasVibratedAtPoint = true;
      } else if (!isNear && _hasVibratedAtPoint) {
        _hasVibratedAtPoint = false;
      }
    }

    _currentValue = newValue;
    _sendValue(_currentValue);
  }
}

class _HorizontalSliderPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final double? vibrateValue;
  final bool isMuted;
  final bool hasValue;

  _HorizontalSliderPainter({
    required this.value,
    required this.min,
    required this.max,
    this.vibrateValue,
    this.isMuted = false,
    this.hasValue = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final activeTrackPaint = Paint()
      ..color = isMuted ? Colors.white : Colors.red
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final trackY = size.height / 2;

    // 1. Draw faint ticks across vertical lines (behind red line)
    final faintTickPaint = Paint()
      ..color = const Color.fromARGB(20, 255, 255, 255)
      ..strokeWidth = 1;

    int numTicks = 11;
    for (int i = 0; i < numTicks; i++) {
      double tickX = size.width * (i / (numTicks - 1));
      canvas.drawLine(Offset(tickX, trackY - 8), Offset(tickX, trackY + 8), faintTickPaint);
    }

    // 2. Draw base track line (grey)
    canvas.drawLine(Offset(0, trackY), Offset(size.width, trackY), trackPaint);

    if (!hasValue) return;

    // Calculate positions
    double percent = 0.0;
    if (max > min) {
      percent = (value - min) / (max - min);
    }
    percent = percent.clamp(0.0, 1.0);
    double thumbX = size.width * percent;

    double startX;
    if (vibrateValue != null && max > min) {
      double vibPercent = ((vibrateValue! - min) / (max - min)).clamp(0.0, 1.0);
      startX = size.width * vibPercent;
    } else {
      startX = 0;
    }

    // 3. Draw active track line (red) from vibrateX baseline to thumbX
    canvas.drawLine(Offset(startX, trackY), Offset(thumbX, trackY), activeTrackPaint);

    // 4. Draw vibrateValue tick (solid white vertical line) at baseline
    if (vibrateValue != null && max > min) {
      final vibrateTickPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0;

      canvas.drawLine(Offset(startX, trackY - 12), Offset(startX, trackY + 12), vibrateTickPaint);
    }

    // 5. Draw thumb circle (white)
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(thumbX, trackY), 10, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _HorizontalSliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.vibrateValue != vibrateValue;
  }
}
