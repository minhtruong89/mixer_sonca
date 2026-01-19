/// Protocol handler for high-level BLE communication
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'protocol_constants.dart';
import 'protocol_frame.dart';
import 'command_payload.dart';

/// High-level protocol handler
class ProtocolHandler {
  int _nextMsgId = 1;
  final Map<int, Completer<ProtocolFrame>> _pendingRequests = {};
  final StreamController<ProtocolFrame> _incomingFrames = StreamController.broadcast();

  /// Get next message ID (auto-increment, wraps at 256)
  int getNextMsgId() {
    final msgId = _nextMsgId;
    _nextMsgId = (_nextMsgId + 1) % 256;
    return msgId;
  }

  /// Build a command frame
  ProtocolFrame buildCommandFrame(CommandPayload payload, {bool requireAck = false}) {
    final msgId = getNextMsgId();
    final payloadBytes = payload.encode();
    final flags = requireAck ? FrameFlags.ackRequired : 0;

    final header = FrameHeader.create(
      type: FrameType.command,
      length: payloadBytes.length,
      msgId: msgId,
      flags: flags,
    );

    return ProtocolFrame(
      header: header,
      payload: payloadBytes,
    );
  }

  /// Build an ACK response frame
  ProtocolFrame buildAckFrame({
    required int msgId,
    required AckStatus status,
    int? category,
    int? cmdId,
  }) {
    final payload = <int>[
      status.value,
      if (category != null) category,
      if (cmdId != null) cmdId,
    ];

    final header = FrameHeader.create(
      type: FrameType.command,
      length: payload.length,
      msgId: msgId,
      flags: FrameFlags.ackResponse,
    );

    return ProtocolFrame(
      header: header,
      payload: payload,
    );
  }

  /// Build an error response frame
  ProtocolFrame buildErrorFrame({
    required int msgId,
    required AckStatus errorCode,
  }) {
    final payload = <int>[errorCode.value];

    final header = FrameHeader.create(
      type: FrameType.command,
      length: payload.length,
      msgId: msgId,
      flags: FrameFlags.ackResponse | FrameFlags.error,
    );

    return ProtocolFrame(
      header: header,
      payload: payload,
    );
  }

  /// Handle incoming frame
  void handleIncomingFrame(List<int> data) {
    try {
      final frame = ProtocolFrame.decode(data);
      
      debugPrint('Protocol: Received frame - ${frame.header}');

      // Check if this is a response to a pending request
      if ((frame.header.flags & FrameFlags.ackResponse) != 0) {
        final completer = _pendingRequests.remove(frame.header.msgId);
        if (completer != null && !completer.isCompleted) {
          completer.complete(frame);
        }
      }

      // Broadcast to listeners
      _incomingFrames.add(frame);
    } catch (e) {
      debugPrint('Protocol: Error handling incoming frame: $e');
    }
  }

  /// Stream of incoming frames
  Stream<ProtocolFrame> get incomingFrames => _incomingFrames.stream;

  /// Wait for ACK response
  Future<ProtocolFrame> waitForAck(int msgId, {Duration timeout = const Duration(seconds: 5)}) {
    final completer = Completer<ProtocolFrame>();
    _pendingRequests[msgId] = completer;

    // Set timeout
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        _pendingRequests.remove(msgId);
        completer.completeError(TimeoutException('ACK timeout for msgId $msgId'));
      }
    });

    return completer.future;
  }

  /// Dispose resources
  void dispose() {
    _incomingFrames.close();
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Protocol handler disposed'));
      }
    }
    _pendingRequests.clear();
  }
}
