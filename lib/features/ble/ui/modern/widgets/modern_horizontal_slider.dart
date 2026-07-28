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

class ModernHorizontalSlider extends StatefulWidget {
  final DisplayItem item;
  final String label;

  const ModernHorizontalSlider({super.key, required this.item, required this.label});

  @override
  State<ModernHorizontalSlider> createState() => _ModernHorizontalSliderState();
}

class _ModernHorizontalSliderState extends State<ModernHorizontalSlider> {
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
    
    final displayVal = _currentValue.round().toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            Text(
              '$displayVal dB',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: GestureDetector(
            onHorizontalDragStart: (details) {
              setState(() {
                _isDragging = true;
                _updateValueFromLocalPosition(details.localPosition.dx, context.size!.width);
              });
            },
            onHorizontalDragUpdate: (details) {
              setState(() {
                _updateValueFromLocalPosition(details.localPosition.dx, context.size!.width);
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateValueFromLocalPosition(double dx, double width) {
    double percent = dx / width;
    percent = percent.clamp(0.0, 1.0);
    double newValue = _min + percent * (_max - _min);
    _currentValue = newValue;
    _sendValue(_currentValue);
  }
}

class _HorizontalSliderPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;

  _HorizontalSliderPainter({required this.value, required this.min, required this.max});

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

    // Draw inactive track (full)
    final centerY = size.height / 2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), trackPaint);

    // Calculate percent and position
    double percent = (value - min) / (max - min);
    percent = percent.clamp(0.0, 1.0);
    double thumbX = size.width * percent;

    // Draw active track from left to thumb
    canvas.drawLine(Offset(0, centerY), Offset(thumbX, centerY), activeTrackPaint);

    // Draw thumb
    final thumbPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(thumbX, centerY), 10, thumbPaint);
    
    // Draw cross inside thumb (as seen in image)
    final thumbLinePaint = Paint()..color = Colors.grey[800]!..strokeWidth = 2;
    canvas.drawLine(Offset(thumbX, centerY - 10), Offset(thumbX, centerY + 10), thumbLinePaint);
    canvas.drawLine(Offset(thumbX - 10, centerY), Offset(thumbX + 10, centerY), thumbLinePaint);
  }

  @override
  bool shouldRepaint(covariant _HorizontalSliderPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.min != min || oldDelegate.max != max;
  }
}
