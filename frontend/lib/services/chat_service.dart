import '../config/api_config.dart';
import '../models/chat_channel.dart';
import '../models/chat_message.dart';
import 'api_service.dart';

class ChatService {
  final _api = ApiService();

  Future<List<ChatChannel>> getChannels(String projectId) async {
    final data = await _api.get(ApiConfig.chatChannels(projectId));
    final list = data['channels'] as List? ?? [];
    return list.map((j) => ChatChannel.fromJson(j)).toList();
  }

  Future<ChatChannel> createChannel(String projectId, {String? name, String? type}) async {
    final data = await _api.post(
      ApiConfig.chatChannels(projectId),
      body: {
        'name': name ?? 'Geral',
        'type': type ?? 'project',
      },
    );
    return ChatChannel.fromJson(data['channel']);
  }

  Future<List<ChatMessage>> getMessages(String channelId, {int limit = 50, String? before}) async {
    final params = <String, String>{'limit': limit.toString()};
    if (before != null) params['before'] = before;
    final data = await _api.get(ApiConfig.channelMessages(channelId), queryParams: params);
    final list = data['messages'] as List? ?? [];
    return list.map((j) => ChatMessage.fromJson(j)).toList();
  }

  Future<ChatMessage> sendMessage(String channelId, String content, {String? type}) async {
    final data = await _api.post(
      ApiConfig.channelMessages(channelId),
      body: {
        'content': content,
        if (type != null) 'type': type,
      },
    );
    return ChatMessage.fromJson(data['data']);
  }
}
