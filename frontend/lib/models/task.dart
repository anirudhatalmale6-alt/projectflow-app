class Task {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? dueDate;
  final double? estimatedHours;
  final double? actualHours;
  final List<String> tags;
  final int position;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Task({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    this.status = 'todo',
    this.priority = 'medium',
    this.assigneeId,
    this.assigneeName,
    this.dueDate,
    this.estimatedHours,
    this.actualHours,
    this.tags = const [],
    this.position = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      status: json['status'] ?? 'todo',
      priority: json['priority'] ?? 'medium',
      assigneeId: json['assignee_id']?.toString(),
      assigneeName: json['assignee_name'],
      dueDate:
          json['due_date'] != null ? DateTime.tryParse(json['due_date']) : null,
      estimatedHours: json['estimated_hours'] != null
          ? double.tryParse(json['estimated_hours'].toString())
          : null,
      actualHours: json['actual_hours'] != null
          ? double.tryParse(json['actual_hours'].toString())
          : null,
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      position: json['position'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project_id': projectId,
      'title': title,
      if (description != null) 'description': description,
      'status': status,
      'priority': priority,
      if (assigneeId != null) 'assignee_id': assigneeId,
      if (dueDate != null) 'due_date': dueDate!.toIso8601String(),
      if (estimatedHours != null) 'estimated_hours': estimatedHours,
      if (actualHours != null) 'actual_hours': actualHours,
      'tags': tags,
      'position': position,
    };
  }

  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && status != 'done';

  double get hoursProgress {
    if (estimatedHours == null || estimatedHours == 0) return 0;
    return (actualHours ?? 0) / estimatedHours!;
  }

  Task copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? status,
    String? priority,
    String? assigneeId,
    String? assigneeName,
    DateTime? dueDate,
    double? estimatedHours,
    double? actualHours,
    List<String>? tags,
    int? position,
  }) {
    return Task(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      dueDate: dueDate ?? this.dueDate,
      estimatedHours: estimatedHours ?? this.estimatedHours,
      actualHours: actualHours ?? this.actualHours,
      tags: tags ?? this.tags,
      position: position ?? this.position,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
