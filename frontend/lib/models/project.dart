import 'user.dart';

class TaskStats {
  final int total;
  final int todo;
  final int inProgress;
  final int review;
  final int done;

  TaskStats({
    this.total = 0,
    this.todo = 0,
    this.inProgress = 0,
    this.review = 0,
    this.done = 0,
  });

  factory TaskStats.fromJson(Map<String, dynamic> json) {
    return TaskStats(
      total: json['total'] ?? 0,
      todo: json['todo'] ?? 0,
      inProgress: json['in_progress'] ?? 0,
      review: json['review'] ?? 0,
      done: json['done'] ?? 0,
    );
  }

  double get progress => total > 0 ? done / total : 0.0;
}

class Project {
  final String id;
  final String name;
  final String? description;
  final String? clientId;
  final String? clientName;
  final String status;
  final DateTime? deadline;
  final double? budget;
  final String? currency;
  final List<User> members;
  final TaskStats taskStats;
  final int deliveryCount;
  final String? color;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    this.clientId,
    this.clientName,
    this.status = 'draft',
    this.deadline,
    this.budget,
    this.currency = 'BRL',
    this.members = const [],
    TaskStats? taskStats,
    this.deliveryCount = 0,
    this.color,
    this.createdAt,
    this.updatedAt,
  }) : taskStats = taskStats ?? TaskStats();

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      clientId: json['client_id']?.toString(),
      clientName: json['client_name'],
      status: json['status'] ?? 'draft',
      deadline:
          json['deadline'] != null ? DateTime.tryParse(json['deadline']) : null,
      budget: json['budget'] != null
          ? double.tryParse(json['budget'].toString())
          : null,
      currency: json['currency'] ?? 'BRL',
      members: json['members'] != null
          ? (json['members'] as List).map((m) => User.fromJson(m)).toList()
          : [],
      taskStats: json['task_stats'] != null
          ? TaskStats.fromJson(json['task_stats'])
          : TaskStats(),
      deliveryCount: json['delivery_count'] ?? 0,
      color: json['color'],
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
      'name': name,
      if (description != null) 'description': description,
      if (clientId != null) 'client_id': clientId,
      'status': status,
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
      if (budget != null) 'budget': budget,
      if (currency != null) 'currency': currency,
      if (color != null) 'color': color,
    };
  }

  bool get isOverdue =>
      deadline != null && deadline!.isBefore(DateTime.now()) && status != 'completed' && status != 'archived';

  int get daysUntilDeadline =>
      deadline != null ? deadline!.difference(DateTime.now()).inDays : 0;

  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? clientId,
    String? clientName,
    String? status,
    DateTime? deadline,
    double? budget,
    String? currency,
    List<User>? members,
    TaskStats? taskStats,
    int? deliveryCount,
    String? color,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      status: status ?? this.status,
      deadline: deadline ?? this.deadline,
      budget: budget ?? this.budget,
      currency: currency ?? this.currency,
      members: members ?? this.members,
      taskStats: taskStats ?? this.taskStats,
      deliveryCount: deliveryCount ?? this.deliveryCount,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
