class ClientModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? company;
  final String? notes;
  final DateTime? createdAt;

  ClientModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.company,
    this.notes,
    this.createdAt,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      company: json['company'],
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
      if (company != null) 'company': company,
      if (notes != null) 'notes': notes,
    };
  }

  String get displayName => company != null && company!.isNotEmpty
      ? '$name ($company)'
      : name;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  ClientModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? company,
    String? notes,
  }) {
    return ClientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}
