class ChatChannel {
  final String id;
  final String projectId;
  final String name;
  final String type;
  final String? jobId;
  final int messageCount;
  final String? lastMessage;
  final DateTime? createdAt;

  ChatChannel({
    required this.id,
    required this.projectId,
    required this.name,
    this.type = 'project',
    this.jobId,
    this.messageCount = 0,
    this.lastMessage,
    this.createdAt,
  });

  factory ChatChannel.fromJson(Map<String, dynamic> json) {
    return ChatChannel(
      id: json['id'].toString(),
      projectId: json['project_id'].toString(),
      name: json['name'] ?? 'Geral',
      type: json['type'] ?? 'project',
      jobId: json['job_id']?.toString(),
      messageCount: json['message_count'] ?? 0,
      lastMessage: json['last_message'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}
