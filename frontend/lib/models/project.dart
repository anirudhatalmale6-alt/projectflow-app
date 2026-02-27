import 'user.dart';

class ProjectMember {
  final User user;
  final String role;
  final DateTime joinedAt;

  ProjectMember({
    required this.user,
    required this.role,
    required this.joinedAt,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> json) {
    return ProjectMember(
      user: json['user'] is Map<String, dynamic>
          ? User.fromJson(json['user'])
          : User(
              id: json['user']?.toString() ?? '',
              name: '',
              email: '',
              role: 'member',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
      role: json['role'] ?? 'member',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
    };
  }
}

class Project {
  final String id;
  final String name;
  final String description;
  final String color;
  final User? owner;
  final List<ProjectMember> members;
  final int taskCount;
  final int completedTaskCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    this.owner,
    this.members = const [],
    this.taskCount = 0,
    this.completedTaskCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      color: json['color'] ?? '#2563EB',
      owner: json['owner'] is Map<String, dynamic>
          ? User.fromJson(json['owner'])
          : null,
      members: json['members'] != null
          ? (json['members'] as List)
              .map((m) => ProjectMember.fromJson(m is Map<String, dynamic> ? m : {'user': m}))
              .toList()
          : [],
      taskCount: json['taskCount'] ?? 0,
      completedTaskCount: json['completedTaskCount'] ?? 0,
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
      'name': name,
      'description': description,
      'color': color,
    };
  }

  double get progress {
    if (taskCount == 0) return 0;
    return completedTaskCount / taskCount;
  }

  int get memberCount => members.length;

  Project copyWith({
    String? name,
    String? description,
    String? color,
    List<ProjectMember>? members,
    int? taskCount,
    int? completedTaskCount,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      owner: owner,
      members: members ?? this.members,
      taskCount: taskCount ?? this.taskCount,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
