class Job {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String type;
  final String status;
  final String priority;
  final String? assigneeId;
  final String? assigneeName;
  final String? assigneeAvatar;
  final String? createdById;
  final String? createdByName;
  final DateTime? dueDate;
  final int? sortOrder;
  final int assetCount;
  final int reviewCount;
  final DateTime? createdAt;

  Job({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    this.type = 'edit',
    this.status = 'pending',
    this.priority = 'medium',
    this.assigneeId,
    this.assigneeName,
    this.assigneeAvatar,
    this.createdById,
    this.createdByName,
    this.dueDate,
    this.sortOrder,
    this.assetCount = 0,
    this.reviewCount = 0,
    this.createdAt,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'].toString(),
      projectId: json['project_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      type: json['type'] ?? 'edit',
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'medium',
      assigneeId: (json['assigned_to'] ?? json['assignee_id'])?.toString(),
      assigneeName: json['assigned_to_name'] ?? json['assignee_name'],
      assigneeAvatar: json['assignee_avatar'],
      createdById: json['created_by']?.toString(),
      createdByName: json['created_by_name'],
      dueDate: json['due_date'] != null
          ? DateTime.tryParse(json['due_date'].toString())
          : null,
      sortOrder: json['sort_order'],
      assetCount: int.tryParse(json['asset_count']?.toString() ?? '0') ?? 0,
      reviewCount: int.tryParse(json['review_count']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'edit': return 'Edição';
      case 'color_grade': return 'Cor';
      case 'motion_graphics': return 'Motion';
      case 'audio_mix': return 'Áudio';
      case 'subtitles': return 'Legendas';
      case 'vfx': return 'VFX';
      default: return 'Outro';
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pendente';
      case 'in_progress': return 'Em Progresso';
      case 'in_review': return 'Em Revisão';
      case 'revision': return 'Revisão';
      case 'approved': return 'Aprovado';
      case 'delivered': return 'Entregue';
      default: return status;
    }
  }

  static String priorityLabel(String priority) {
    switch (priority) {
      case 'low': return 'Baixa';
      case 'medium': return 'Média';
      case 'high': return 'Alta';
      case 'urgent': return 'Urgente';
      default: return priority;
    }
  }
}
