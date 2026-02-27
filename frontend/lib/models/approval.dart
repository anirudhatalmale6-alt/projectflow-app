class Approval {
  final String id;
  final String deliveryId;
  final String status;
  final String? reviewerId;
  final String? reviewerName;
  final String? comments;
  final DateTime? createdAt;

  Approval({
    required this.id,
    required this.deliveryId,
    this.status = 'pending',
    this.reviewerId,
    this.reviewerName,
    this.comments,
    this.createdAt,
  });

  factory Approval.fromJson(Map<String, dynamic> json) {
    return Approval(
      id: json['id']?.toString() ?? '',
      deliveryId: json['delivery_id']?.toString() ?? '',
      status: json['status'] ?? 'pending',
      reviewerId: json['reviewer_id']?.toString(),
      reviewerName: json['reviewer_name'],
      comments: json['comments'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'delivery_id': deliveryId,
      'status': status,
      if (reviewerId != null) 'reviewer_id': reviewerId,
      if (comments != null) 'comments': comments,
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isRevision => status == 'revision';
}
