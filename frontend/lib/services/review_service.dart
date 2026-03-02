import '../config/api_config.dart';
import '../models/review.dart';
import 'api_service.dart';

class ReviewService {
  final ApiService _api = ApiService();

  Future<List<Review>> getReviews(String jobId) async {
    final data = await _api.get(ApiConfig.reviewsByJob(jobId));
    final list = (data['reviews'] ?? data['data'] ?? []) as List;
    return list.map((j) => Review.fromJson(j)).toList();
  }

  Future<Review> createReview(String jobId, {String? summary, String? assetVersionId}) async {
    final data = await _api.post(ApiConfig.reviewsByJob(jobId), body: {
      if (summary != null) 'summary': summary,
      if (assetVersionId != null) 'asset_version_id': assetVersionId,
    });
    return Review.fromJson(data['review'] ?? data['data'] ?? data);
  }

  Future<Review> updateReview(String reviewId, {String? status, String? summary}) async {
    final data = await _api.put(ApiConfig.reviewById(reviewId), body: {
      if (status != null) 'status': status,
      if (summary != null) 'summary': summary,
    });
    return Review.fromJson(data['review'] ?? data['data'] ?? data);
  }

  Future<List<ReviewComment>> getComments(String reviewId) async {
    final data = await _api.get(ApiConfig.reviewComments(reviewId));
    final list = (data['comments'] ?? data['data'] ?? []) as List;
    return list.map((c) => ReviewComment.fromJson(c)).toList();
  }

  Future<ReviewComment> addComment(String reviewId, {
    required String content,
    String? timecode,
    String? frameUrl,
  }) async {
    final data = await _api.post(ApiConfig.reviewComments(reviewId), body: {
      'content': content,
      if (timecode != null) 'timecode': timecode,
      if (frameUrl != null) 'frame_url': frameUrl,
    });
    return ReviewComment.fromJson(data['comment'] ?? data['data'] ?? data);
  }
}
