class DeliveryJob {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final String? format;
  final int version;
  final String? fileUrl;
  final int? fileSize;
  final String status;
  final String? uploadedBy;
  final String? uploadedByName;
  final String? reviewedBy;
  final String? reviewedByName;
  final String? reviewNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DeliveryJob({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    this.format,
    this.version = 1,
    this.fileUrl,
    this.fileSize,
    this.status = 'pending',
    this.uploadedBy,
    this.uploadedByName,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory DeliveryJob.fromJson(Map<String, dynamic> json) {
    return DeliveryJob(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      format: json['format'],
      version: json['version'] ?? 1,
      fileUrl: json['file_url'],
      fileSize: json['file_size'],
      status: json['status'] ?? 'pending',
      uploadedBy: json['uploaded_by']?.toString(),
      uploadedByName: json['uploaded_by_name'],
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedByName: json['reviewed_by_name'],
      reviewNotes: json['review_notes'],
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
      if (format != null) 'format': format,
      'status': status,
    };
  }

  String get fileSizeFormatted {
    if (fileSize == null) return '—';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    if (fileSize! < 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get versionLabel => 'v$version';

  bool get canBeReviewed =>
      status == 'uploaded' || status == 'in_review';

  DeliveryJob copyWith({
    String? id,
    String? projectId,
    String? title,
    String? description,
    String? format,
    int? version,
    String? fileUrl,
    int? fileSize,
    String? status,
    String? uploadedBy,
    String? reviewedBy,
    String? reviewNotes,
  }) {
    return DeliveryJob(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      description: description ?? this.description,
      format: format ?? this.format,
      version: version ?? this.version,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedByName: uploadedByName,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
