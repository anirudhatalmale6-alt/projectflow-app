class ChatMessage {
  final String id;
  final String channelId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String content;
  final String type;
  final String? fileUrl;
  final String? fileName;
  final DateTime? createdAt;

  ChatMessage({
    required this.id,
    required this.channelId,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.content,
    this.type = 'text',
    this.fileUrl,
    this.fileName,
    this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'].toString(),
      channelId: json['channel_id'].toString(),
      userId: json['user_id'].toString(),
      userName: json['user_name'],
      userAvatar: json['user_avatar'],
      content: json['content'] ?? '',
      type: json['type'] ?? 'text',
      fileUrl: json['file_url'],
      fileName: json['file_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}
