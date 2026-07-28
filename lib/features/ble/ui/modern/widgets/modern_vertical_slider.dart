import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';
import 'modern_slider_helper.dart';

class ModernVerticalSlider extends StatefulWidget {
  final DisplayItem item;
  final String label;

  const ModernVerticalSlider({super.key, required this.item, required this.label});

  @override
  State<ModernVerticalSlider> createState() => _ModernVerticalSliderState();
}

class _ModernVerticalSliderState extends State<ModernVerticalSlider> {
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
    
    if (!_isDragging) {
      dynamic val = viewModel.getControlValue(stateKey);
      if (val != null) {
        if (val is int) {
          _currentValue = val.toDouble();
        } else if (val is double) {
          _currentValue = val;
        }
      }
    }
    
    final String muteKey = _muteParam != null
        ? "${widget.item.command}_$_muteParam"
        : "${widget.item.command}_volume_mute";
    final bool isMuted = (viewModel.getControlValue(muteKey, defaultValue: 0) == 1);

    final displayVal = ModernSliderHelper.formatDisplayValue(_currentValue, widget.item);

        const double sliderHeight = 300.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              displayVal,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: sliderHeight,
              width: 60,
              child: GestureDetector(
                onTapDown: (details) {
                  setState(() {
                    _updateValueFromLocalPosition(details.localPosition.dy, sliderHeight);
                  });
                },
                onVerticalDragStart: (details) {
                  setState(() {
                    _isDragging = true;
                  });
                },
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _updateValueFromLocalPosition(details.localPosition.dy, sliderHeight);
                  });
                },
                onVerticalDragEnd: (details) {
                  setState(() {
                    _isDragging = false;
                  });
                },
                child: CustomPaint(
                  painter: _VerticalSliderPainter(
                    value: _currentValue,
                    min: _min,
                    max: _max,
                    isMuted: isMuted,
                    vibrateValue: widget.item.control.vibrateValue,
                  ),
                ),
              ),
            ),
          ],
        );
  }

  void _updateValueFromLocalPosition(double dy, double height) {
    double percent = 1.0 - (dy / height);
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

class _VerticalSliderPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final double? vibrateValue;
  final bool isMuted;

  _VerticalSliderPainter({
    required this.value,
    required this.min,
    required this.max,
    this.vibrateValue,
    this.isMuted = false,
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

    final trackX = size.width / 2;

    // 1. Draw faint ticks across (behind red line so red line covers middle)
    final faintTickPaint = Paint()
      ..color = const Color.fromARGB(70, 255, 255, 255)
      ..strokeWidth = 0.5;

    int numTicks = 11;
    for (int i = 0; i < numTicks; i++) {
      double tickY = size.height * (i / (numTicks - 1));
      canvas.drawLine(Offset(trackX - 10, tickY), Offset(trackX + 10, tickY), faintTickPaint);
    }

    // 2. Draw base track line (grey)
    canvas.drawLine(Offset(trackX, 0), Offset(trackX, size.height), trackPaint);

    // Calculate positions
    double percent = 0.0;
    if (max > min) {
      percent = (value - min) / (max - min);
    }
    percent = percent.clamp(0.0, 1.0);
    double thumbY = size.height * (1.0 - percent);

    double startY;
    if (vibrateValue != null && max > min) {
      double vibPercent = ((vibrateValue! - min) / (max - min)).clamp(0.0, 1.0);
      startY = size.height * (1.0 - vibPercent);
    } else {
      startY = size.height / 2;
    }

    // 3. Draw active track line (red) from vibrateY baseline to thumbY
    canvas.drawLine(Offset(trackX, startY), Offset(trackX, thumbY), activeTrackPaint);

    // 4. Draw vibrateValue tick (solid white horizontal line) at baseline
    if (vibrateValue != null && max > min) {
      final vibrateTickPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5;

      canvas.drawLine(Offset(trackX - 14, startY), Offset(trackX + 14, startY), vibrateTickPaint);
    }

    // 5. Draw thumb circle (white)
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(trackX, thumbY), 10, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _VerticalSliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.vibrateValue != vibrateValue;
  }
}
