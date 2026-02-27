import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';

typedef SocketCallback = void Function(dynamic data);

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  final Map<String, List<SocketCallback>> _listeners = {};

  bool get isConnected => _isConnected;

  void connect(String token) {
    if (_socket != null) {
      disconnect();
    }

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      print('[Socket] Connected');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('[Socket] Disconnected');
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      print('[Socket] Connection error: $error');
    });

    _socket!.onError((error) {
      print('[Socket] Error: $error');
    });

    // Task events
    _socket!.on('task:created', (data) => _emit('task:created', data));
    _socket!.on('task:updated', (data) => _emit('task:updated', data));
    _socket!.on('task:deleted', (data) => _emit('task:deleted', data));
    _socket!.on('task:statusChanged', (data) => _emit('task:statusChanged', data));
    _socket!.on('task:assigned', (data) => _emit('task:assigned', data));

    // Comment events
    _socket!.on('comment:added', (data) => _emit('comment:added', data));
    _socket!.on('comment:deleted', (data) => _emit('comment:deleted', data));

    // Project events
    _socket!.on('project:updated', (data) => _emit('project:updated', data));
    _socket!.on('project:memberAdded', (data) => _emit('project:memberAdded', data));
    _socket!.on('project:memberRemoved', (data) => _emit('project:memberRemoved', data));

    // Notification events
    _socket!.on('notification', (data) => _emit('notification', data));
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _listeners.clear();
  }

  void joinProject(String projectId) {
    _socket?.emit('project:join', {'projectId': projectId});
  }

  void leaveProject(String projectId) {
    _socket?.emit('project:leave', {'projectId': projectId});
  }

  void on(String event, SocketCallback callback) {
    _listeners[event] ??= [];
    _listeners[event]!.add(callback);
  }

  void off(String event, [SocketCallback? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
    } else {
      _listeners.remove(event);
    }
  }

  void _emit(String event, dynamic data) {
    final callbacks = _listeners[event];
    if (callbacks != null) {
      for (final callback in List<SocketCallback>.from(callbacks)) {
        callback(data);
      }
    }
  }
}
