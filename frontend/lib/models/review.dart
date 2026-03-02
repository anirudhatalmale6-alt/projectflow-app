class Review {
  final String id;
  final String jobId;
  final String? assetVersionId;
  final String reviewerId;
  final String? reviewerName;
  final String? reviewerAvatar;
  final String status;
  final String? summary;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Review({
    required this.id,
    required this.jobId,
    this.assetVersionId,
    required this.reviewerId,
    this.reviewerName,
    this.reviewerAvatar,
    required this.status,
    this.summary,
    this.createdAt,
    this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] ?? '',
      jobId: json['job_id'] ?? '',
      assetVersionId: json['asset_version_id'],
      reviewerId: json['reviewer_id'] ?? '',
      reviewerName: json['reviewer_name'],
      reviewerAvatar: json['reviewer_avatar'],
      status: json['status'] ?? 'pending',
      summary: json['summary'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending': return 'Pendente';
      case 'in_progress': return 'Em Andamento';
      case 'approved': return 'Aprovado';
      case 'rejected': return 'Rejeitado';
      case 'revision_requested': return 'Revisão Solicitada';
      default: return status;
    }
  }
}

class ReviewComment {
  final String id;
  final String reviewId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String content;
  final String? timecode;
  final String? frameUrl;
  final DateTime? createdAt;

  ReviewComment({
    required this.id,
    required this.reviewId,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.content,
    this.timecode,
    this.frameUrl,
    this.createdAt,
  });

  factory ReviewComment.fromJson(Map<String, dynamic> json) {
    return ReviewComment(
      id: json['id'] ?? '',
      reviewId: json['review_id'] ?? '',
      userId: json['user_id'] ?? '',
      userName: json['user_name'],
      userAvatar: json['user_avatar'],
      content: json['content'] ?? '',
      timecode: json['timecode'],
      frameUrl: json['frame_url'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
    );
  }

  /// Parse timecode string "HH:MM:SS" to Duration
  Duration? get timecodeDuration {
    if (timecode == null || timecode!.isEmpty) return null;
    final parts = timecode!.split(':');
    if (parts.length == 3) {
      return Duration(
        hours: int.tryParse(parts[0]) ?? 0,
        minutes: int.tryParse(parts[1]) ?? 0,
        seconds: int.tryParse(parts[2]) ?? 0,
      );
    }
    if (parts.length == 2) {
      return Duration(
        minutes: int.tryParse(parts[0]) ?? 0,
        seconds: int.tryParse(parts[1]) ?? 0,
      );
    }
    return null;
  }
}
