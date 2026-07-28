import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mixer_sonca/features/ble/ble_logic.dart';
import 'package:mixer_sonca/features/ble/protocol/models/display_config.dart';
import 'package:mixer_sonca/core/utils/debouncer.dart';
import 'package:mixer_sonca/injection.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_service.dart';
import 'package:mixer_sonca/features/ble/protocol/dynamic_command_builder.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_types.dart';
import 'package:mixer_sonca/features/ble/protocol/protocol_constants.dart';

class ModernVerticalSlider extends StatefulWidget {
  final DisplayItem item;
  final String label;

  const ModernVerticalSlider({super.key, required this.item, required this.label});

  @override
  State<ModernVerticalSlider> createState() => _ModernVerticalSliderState();
}

class _ModernVerticalSliderState extends State<ModernVerticalSlider> {
  final Debouncer _debouncer = Debouncer(milliseconds: 100);
  double _currentValue = 50.0;
  bool _isDragging = false;
  late double _min;
  late double _max;

  @override
  void initState() {
    super.initState();
    _min = widget.item.control.minValue.toDouble();
    _max = widget.item.control.maxValue.toDouble();
  }

  void _sendValue(double val) {
    final viewModel = context.read<BleViewModel>();
    final stateKey = "${widget.item.command}_${widget.item.indexList.isNotEmpty ? widget.item.indexList.first : widget.item.paramName}";
    
    // Internal representation is int for most things
    viewModel.updateControlValue(stateKey, val.round(), notify: false);
    
    _debouncer.run(() {
      final protocolService = getIt<ProtocolService>();
      final cmdDef = protocolService.getCommandByName(widget.item.category, widget.item.command);
      if (cmdDef != null) {
        final builder = getIt<DynamicCommandBuilder>();
        final Map<String, dynamic> params = {};
        for (var idx in (widget.item.indexList.isNotEmpty ? widget.item.indexList : [widget.item.paramName!])) {
           params[idx] = viewModel.getControlValue("${widget.item.command}_$idx", defaultValue: _min.round());
        }
        final cmds = builder.buildCommand(
          categoryName: widget.item.category, 
          cmdId: cmdDef.id, 
          operation: CommandOperation.set, 
          parameters: params
        );
        for (var cmd in cmds) {
          viewModel.sendDataToBLE(cmd.encode());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BleViewModel>();
    final stateKey = "${widget.item.command}_${widget.item.indexList.isNotEmpty ? widget.item.indexList.first : widget.item.paramName}";
    
    if (!_isDragging) {
      dynamic val = viewModel.getControlValue(stateKey);
      if (val != null) {
        if (val is int) _currentValue = val.toDouble();
        else if (val is double) _currentValue = val;
      }
    }
    
    // Calculate display value relative to center (0 to 100 -> -50 to +50 conceptually if needed, but user said raw)
    // Actually, in the image it shows BASS, MID, TREBLE with "0 dB" at center.
    // If raw is 0-100, we'll just display it. To match the image exactly we could map 0-100 to -12 to +12,
    // but the user said "raw minValue and maxValue in json". We'll just show the raw value.
    final displayVal = _currentValue.round().toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.label,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '$displayVal dB', // Assuming dB suffix based on image
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          width: 60,
          child: GestureDetector(
            onVerticalDragStart: (details) {
              setState(() {
                _isDragging = true;
                _updateValueFromLocalPosition(details.localPosition.dy, 180);
              });
            },
            onVerticalDragUpdate: (details) {
              setState(() {
                _updateValueFromLocalPosition(details.localPosition.dy, 180);
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateValueFromLocalPosition(double dy, double height) {
    // dy is from top (0) to bottom (height)
    // value is from max (top) to min (bottom)
    double percent = 1.0 - (dy / height);
    percent = percent.clamp(0.0, 1.0);
    double newValue = _min + percent * (_max - _min);
    _currentValue = newValue;
    _sendValue(_currentValue);
  }
}

class _VerticalSliderPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;

  _VerticalSliderPainter({required this.value, required this.min, required this.max});

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = Colors.grey[800]!
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final activeTrackPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final tickPaint = Paint()
      ..color = Colors.grey[700]!
      ..strokeWidth = 1;

    // Draw vertical track
    final trackX = size.width / 2;
    canvas.drawLine(Offset(trackX, 0), Offset(trackX, size.height), trackPaint);

    // Draw ticks
    int numTicks = 11;
    for (int i = 0; i < numTicks; i++) {
      double tickY = size.height * (i / (numTicks - 1));
      canvas.drawLine(Offset(trackX - 10, tickY), Offset(trackX + 10, tickY), tickPaint);
    }

    // Calculate percent and position
    double percent = (value - min) / (max - min);
    percent = percent.clamp(0.0, 1.0);
    double thumbY = size.height * (1.0 - percent);
    double centerY = size.height / 2;

    // Draw active track from center to thumb (like EQ)
    canvas.drawLine(Offset(trackX, centerY), Offset(trackX, thumbY), activeTrackPaint);

    // Draw thumb
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(trackX, thumbY), 10, thumbPaint);
  }

  @override
  bool shouldRepaint(covariant _VerticalSliderPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.min != min || oldDelegate.max != max;
  }
}
