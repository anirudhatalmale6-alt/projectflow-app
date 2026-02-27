class Comment {
  final String id;
  final String entityType;
  final String entityId;
  final String? userId;
  final String? userName;
  final String? userAvatarUrl;
  final String content;
  final DateTime? createdAt;

  Comment({
    required this.id,
    required this.entityType,
    required this.entityId,
    this.userId,
    this.userName,
    this.userAvatarUrl,
    required this.content,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id']?.toString() ?? '',
      entityType: json['entity_type'] ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      userName: json['user_name'],
      userAvatarUrl: json['user_avatar_url'],
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entity_type': entityType,
      'entity_id': entityId,
      'content': content,
    };
  }

  String get userInitials {
    if (userName == null || userName!.isEmpty) return '?';
    final parts = userName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return userName![0].toUpperCase();
  }
}
