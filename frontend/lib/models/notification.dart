class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String? projectId;
  final String? taskId;
  final String? fromUserId;
  final String? fromUserName;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.projectId,
    this.taskId,
    this.fromUserId,
    this.fromUserName,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'] ?? '',
      type: json['type'] ?? 'general',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      projectId: json['project'] is Map<String, dynamic>
          ? json['project']['_id']
          : json['project']?.toString(),
      taskId: json['task'] is Map<String, dynamic>
          ? json['task']['_id']
          : json['task']?.toString(),
      fromUserId: json['fromUser'] is Map<String, dynamic>
          ? json['fromUser']['_id']
          : json['fromUser']?.toString(),
      fromUserName: json['fromUser'] is Map<String, dynamic>
          ? json['fromUser']['name']
          : null,
      isRead: json['isRead'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'type': type,
      'title': title,
      'message': message,
      'project': projectId,
      'task': taskId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inDays > 7) {
      return '${(diff.inDays / 7).floor()}w ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'now';
  }

  IconType get iconType {
    switch (type) {
      case 'task_assigned':
        return IconType.taskAssigned;
      case 'task_updated':
        return IconType.taskUpdated;
      case 'task_completed':
        return IconType.taskCompleted;
      case 'comment_added':
        return IconType.comment;
      case 'mention':
        return IconType.mention;
      case 'project_invite':
        return IconType.projectInvite;
      default:
        return IconType.general;
    }
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      projectId: projectId,
      taskId: taskId,
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}

enum IconType {
  taskAssigned,
  taskUpdated,
  taskCompleted,
  comment,
  mention,
  projectInvite,
  general,
}
