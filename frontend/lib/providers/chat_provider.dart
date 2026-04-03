import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat_channel.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _service = ChatService();
  final SocketService _socket = SocketService();

  List<ChatChannel> _channels = [];
  List<ChatMessage> _messages = [];
  ChatChannel? _currentChannel;
  String? _currentChannelId;
  String? _currentProjectId;
  bool _isLoading = false;
  bool _loadingMessages = false;
  String? _errorMessage;
  String? _typingUser;
  Timer? _typingTimer;
  bool _listenersSetUp = false;

  List<ChatChannel> get channels => _channels;
  List<ChatMessage> get messages => _messages;
  ChatChannel? get currentChannel => _currentChannel;
  bool get isLoading => _isLoading;
  bool get loadingMessages => _loadingMessages;
  String? get errorMessage => _errorMessage;
  String? get typingUser => _typingUser;

  void _setupSocketListeners() {
    if (_listenersSetUp) return;
    _listenersSetUp = true;

    _socket.on('chat_message', (data) {
      if (data == null) return;
      try {
        final msgData = data['message'] ?? data;
        final channelId = data['channel_id'] ?? msgData['channel_id'];
        if (_currentChannelId == channelId?.toString()) {
          final msg = ChatMessage.fromJson(msgData is Map<String, dynamic>
              ? msgData
              : Map<String, dynamic>.from(msgData));
          final exists = _messages.any((m) => m.id == msg.id);
          if (!exists) {
            _messages.add(msg);
            notifyListeners();
          }
        }
      } catch (_) {}
    });

    _socket.on('user_typing', (data) {
      if (data == null) return;
      try {
        final name = data['user_name'] as String?;
        if (_typingUser == name) return; // already showing this user typing
        _typingUser = name;
        notifyListeners();
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (_typingUser == name) {
            _typingUser = null;
            notifyListeners();
          }
        });
      } catch (_) {}
    });

    _socket.on('user_stop_typing', (data) {
      _typingUser = null;
      notifyListeners();
    });
  }

  void joinProject(String projectId) {
    _currentProjectId = projectId;
    _socket.joinProject(projectId);
    _setupSocketListeners();
  }

  void leaveProject() {
    if (_currentProjectId != null) {
      _socket.leaveProject(_currentProjectId!);
    }
    _socket.off('chat_message');
    _socket.off('user_typing');
    _socket.off('user_stop_typing');
    _currentProjectId = null;
    _typingUser = null;
    _listenersSetUp = false;
  }

  void sendTyping(String channelId) {
    if (_currentProjectId != null) {
      _socket.emit('typing', {
        'projectId': _currentProjectId,
        'entityType': 'channel',
        'entityId': channelId,
      });
    }
  }

  void sendStopTyping(String channelId) {
    if (_currentProjectId != null) {
      _socket.emit('stop_typing', {
        'projectId': _currentProjectId,
        'entityType': 'channel',
        'entityId': channelId,
      });
    }
  }

  Future<void> loadChannels(String projectId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _channels = await _service.getChannels(projectId);
    } catch (e) {
      _errorMessage = _parseError(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMessages(String channelId) async {
    _loadingMessages = true;
    _errorMessage = null;
    _currentChannelId = channelId;
    notifyListeners();

    try {
      _messages = await _service.getMessages(channelId);
      _currentChannel = _channels.isNotEmpty
          ? _channels.firstWhere(
              (c) => c.id == channelId,
              orElse: () => _channels.first,
            )
          : null;
    } catch (e) {
      _errorMessage = _parseError(e);
    }

    _loadingMessages = false;
    notifyListeners();
  }

  Future<bool> sendMessage(String channelId, String content) async {
    try {
      final msg = await _service.sendMessage(channelId, content);
      final exists = _messages.any((m) => m.id == msg.id);
      if (!exists) {
        _messages.add(msg);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<ChatChannel?> createChannel(String projectId, {String? name}) async {
    try {
      final channel = await _service.createChannel(projectId, name: name);
      _channels.add(channel);
      notifyListeners();
      return channel;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return null;
    }
  }

  Future<ChatChannel?> ensureDefaultChannel(String projectId) async {
    await loadChannels(projectId);
    if (_channels.isEmpty) {
      return await createChannel(projectId, name: 'Geral');
    }
    return _channels.first;
  }

  void addMessageFromSocket(ChatMessage message) {
    if (_currentChannelId == message.channelId) {
      final exists = _messages.any((m) => m.id == message.id);
      if (!exists) {
        _messages.add(message);
        notifyListeners();
      }
    }
  }

  void clearMessages() {
    _messages = [];
    _currentChannel = null;
    _currentChannelId = null;
    _typingUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _parseError(dynamic error) {
    if (error is ApiException) return error.message;
    return 'Ocorreu um erro. Tente novamente.';
  }
}
