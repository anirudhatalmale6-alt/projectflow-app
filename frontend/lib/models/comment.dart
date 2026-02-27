import 'user.dart';

class Comment {
  final String id;
  final String content;
  final String taskId;
  final User? author;
  final List<String> mentions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    required this.content,
    required this.taskId,
    this.author,
    this.mentions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? json['id'] ?? '',
      content: json['content'] ?? '',
      taskId: json['task'] is Map<String, dynamic>
          ? json['task']['_id'] ?? ''
          : json['task']?.toString() ?? '',
      author: json['author'] is Map<String, dynamic>
          ? User.fromJson(json['author'])
          : null,
      mentions: json['mentions'] != null
          ? List<String>.from(json['mentions'])
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'mentions': mentions,
    };
  }

  bool get isEdited => updatedAt.isAfter(createdAt.add(const Duration(seconds: 1)));
}
