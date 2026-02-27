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
    if (_socket != null) disconnect();

    _socket = io.io(
      ApiConfig.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionAttempts(10)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
    });

    _socket!.onConnectError((_) {
      _isConnected = false;
    });

    // Forward events to listeners
    _socket!.onAny((event, data) {
      if (_listeners.containsKey(event)) {
        for (final callback in _listeners[event]!) {
          callback(data);
        }
      }
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  void on(String event, SocketCallback callback) {
    _listeners.putIfAbsent(event, () => []);
    _listeners[event]!.add(callback);
  }

  void off(String event, [SocketCallback? callback]) {
    if (callback != null) {
      _listeners[event]?.remove(callback);
    } else {
      _listeners.remove(event);
    }
  }

  void emit(String event, [dynamic data]) {
    _socket?.emit(event, data);
  }

  void joinProject(String projectId) {
    emit('join_project', {'project_id': projectId});
  }

  void leaveProject(String projectId) {
    emit('leave_project', {'project_id': projectId});
  }
}
