import 'package:flutter/foundation.dart';
import '../models/chat_channel.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/api_service.dart';

class ChatProvider with ChangeNotifier {
  final ChatService _service = ChatService();

  List<ChatChannel> _channels = [];
  List<ChatMessage> _messages = [];
  ChatChannel? _currentChannel;
  bool _isLoading = false;
  String? _errorMessage;

  List<ChatChannel> get channels => _channels;
  List<ChatMessage> get messages => _messages;
  ChatChannel? get currentChannel => _currentChannel;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _messages = await _service.getMessages(channelId);
      _currentChannel = _channels.firstWhere(
        (c) => c.id == channelId,
        orElse: () => _channels.first,
      );
    } catch (e) {
      _errorMessage = _parseError(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> sendMessage(String channelId, String content) async {
    try {
      final msg = await _service.sendMessage(channelId, content);
      _messages.add(msg);
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

  void addMessageFromSocket(ChatMessage message) {
    if (_currentChannel?.id == message.channelId) {
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
    notifyListeners();
  }

  String _parseError(dynamic error) {
    if (error is ApiException) return error.message;
    return 'Ocorreu um erro. Tente novamente.';
  }
}
