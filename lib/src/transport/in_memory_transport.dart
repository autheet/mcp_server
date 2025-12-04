import 'dart:async';
import 'transport.dart';
import '../../logger.dart';

final Logger _logger = Logger('mcp_server.transport.in_memory');

/// Transport implementation using in-memory streams.
/// Useful for testing and for running the server within the same process as the client (e.g. Web).
class InMemoryServerTransport implements ServerTransport {
  final _messageController = StreamController<dynamic>.broadcast();
  final _closeCompleter = Completer<void>();

  // Stream for sending messages TO the client (server -> client)
  final _outboundController = StreamController<dynamic>.broadcast();

  // Stream for receiving messages FROM the client (client -> server)
  final _inboundController = StreamController<dynamic>.broadcast();

  bool _isClosed = false;

  InMemoryServerTransport() {
    _initialize();
  }

  void _initialize() {
    _logger.debug('Initializing InMemory transport');

    // Listen to inbound messages (from client) and forward them to the server's message stream
    _inboundController.stream.listen(
      (message) {
        if (!_messageController.isClosed) {
          _logger.debug('Received message from client: $message');
          _messageController.add(message);
        }
      },
      onError: (error, stackTrace) {
        _logger.debug('Inbound stream error: $error');
        if (!_closeCompleter.isCompleted) {
          _closeCompleter.completeError(error, stackTrace);
        }
        close();
      },
      onDone: () {
        _logger.debug('Inbound stream done');
        close();
      },
    );
  }

  /// Stream of messages sent by the server.
  /// The client should listen to this stream.
  Stream<dynamic> get outboundStream => _outboundController.stream;

  /// Sink for sending messages to the server.
  /// The client should add messages to this sink.
  Sink<dynamic> get inboundSink => _inboundController.sink;

  @override
  Stream<dynamic> get onMessage => _messageController.stream;

  @override
  Future<void> get onClose => _closeCompleter.future;

  @override
  void send(dynamic message) {
    if (_isClosed) {
      _logger.debug('Attempted to send message on closed transport');
      return;
    }

    _logger.debug('Sending message to client: $message');
    if (!_outboundController.isClosed) {
      _outboundController.add(message);
    }
  }

  @override
  void close() {
    if (_isClosed) return;
    _isClosed = true;

    _logger.debug('Closing InMemoryServerTransport');

    if (!_messageController.isClosed) _messageController.close();
    if (!_outboundController.isClosed) _outboundController.close();
    if (!_inboundController.isClosed) _inboundController.close();

    if (!_closeCompleter.isCompleted) {
      _closeCompleter.complete();
    }
  }
}
