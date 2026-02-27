import 'user.dart';

enum TaskStatus {
  todo('todo', 'To Do'),
  inProgress('in_progress', 'In Progress'),
  review('review', 'Review'),
  done('done', 'Done');

  final String value;
  final String label;
  const TaskStatus(this.value, this.label);

  static TaskStatus fromString(String value) {
    return TaskStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => TaskStatus.todo,
    );
  }
}

enum TaskPriority {
  low('low', 'Low'),
  medium('medium', 'Medium'),
  high('high', 'High'),
  critical('critical', 'Critical');

  final String value;
  final String label;
  const TaskPriority(this.value, this.label);

  static TaskPriority fromString(String value) {
    return TaskPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => TaskPriority.medium,
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final String projectId;
  final User? assignee;
  final User? creator;
  final DateTime? dueDate;
  final List<String> tags;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.projectId,
    this.assignee,
    this.creator,
    this.dueDate,
    this.tags = const [],
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: TaskStatus.fromString(json['status'] ?? 'todo'),
      priority: TaskPriority.fromString(json['priority'] ?? 'medium'),
      projectId: json['project'] is Map<String, dynamic>
          ? json['project']['_id'] ?? ''
          : json['project']?.toString() ?? '',
      assignee: json['assignee'] is Map<String, dynamic>
          ? User.fromJson(json['assignee'])
          : null,
      creator: json['creator'] is Map<String, dynamic>
          ? User.fromJson(json['creator'])
          : null,
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'])
          : [],
      commentCount: json['commentCount'] ?? 0,
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
      'title': title,
      'description': description,
      'status': status.value,
      'priority': priority.value,
      'assignee': assignee?.id,
      'dueDate': dueDate?.toIso8601String(),
      'tags': tags,
    };
  }

  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == TaskStatus.done) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  bool get isDueSoon {
    if (dueDate == null) return false;
    if (status == TaskStatus.done) return false;
    final diff = dueDate!.difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 2;
  }

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    User? assignee,
    DateTime? dueDate,
    List<String>? tags,
    int? commentCount,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      projectId: projectId,
      assignee: assignee ?? this.assignee,
      creator: creator,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
