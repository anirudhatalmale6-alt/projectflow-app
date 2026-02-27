class User {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String role;
  final String? phone;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.role,
    this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
      role: json['role'] ?? 'editor',
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar_url': avatarUrl,
      'role': role,
      'phone': phone,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isEditor => role == 'editor';
  bool get isFreelancer => role == 'freelancer';
  bool get isClient => role == 'client';
  bool get canManageProjects => isAdmin || isManager;
  bool get canManageUsers => isAdmin;
  bool get canAssignTasks => isAdmin || isManager;
  bool get canApproveDeliveries => isAdmin || isManager || isClient;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? role,
    String? phone,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      phone: phone ?? this.phone,
    );
  }
}
