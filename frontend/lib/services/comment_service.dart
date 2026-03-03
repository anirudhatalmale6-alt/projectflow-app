import '../config/api_config.dart';
import '../models/comment.dart';
import 'api_service.dart';

class CommentService {
  final ApiService _api = ApiService();

  Future<List<Comment>> getComments(String entityType, String entityId) async {
    final path =
        '${ApiConfig.apiPrefix}/comments?entity_type=$entityType&entity_id=$entityId';
    final data = await _api.get(path);
    final list = data['comments'] ?? data['data'] ?? data;
    return (list as List).map((json) => Comment.fromJson(json)).toList();
  }

  Future<Comment> createComment(
      String entityType, String entityId, String content) async {
    final path = '${ApiConfig.apiPrefix}/comments';
    final data = await _api.post(path, body: {
      'entity_type': entityType,
      'entity_id': entityId,
      'content': content,
    });
    return Comment.fromJson(data['comment'] ?? data);
  }

  Future<void> deleteComment(String id) async {
    await _api.delete(ApiConfig.commentById(id));
  }
}
