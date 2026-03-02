class Job {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String type;
  final String status;
  final String? assigneeId;
  final String? assigneeName;
  final String? assigneeAvatar;
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
    this.assigneeId,
    this.assigneeName,
    this.assigneeAvatar,
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
      assigneeId: json['assignee_id']?.toString(),
      assigneeName: json['assignee_name'],
      assigneeAvatar: json['assignee_avatar'],
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      sortOrder: json['sort_order'],
      assetCount: json['asset_count'] ?? 0,
      reviewCount: json['review_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
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
      case 'review': return 'Revisão';
      case 'approved': return 'Aprovado';
      case 'done': return 'Concluído';
      default: return status;
    }
  }
}
