import '../config/api_config.dart';
import '../models/comment.dart';
import 'api_service.dart';

class CommentService {
  final ApiService _api = ApiService();

  Future<List<Comment>> getComments(String taskId) async {
    final response = await _api.get(ApiConfig.comments(taskId));
    final List<dynamic> data = response['comments'] ?? response['data'] ?? response;
    return data.map((json) => Comment.fromJson(json)).toList();
  }

  Future<Comment> addComment(String taskId, String content, {List<String>? mentions}) async {
    final body = <String, dynamic>{
      'content': content,
    };
    if (mentions != null && mentions.isNotEmpty) {
      body['mentions'] = mentions;
    }
    final response = await _api.post(ApiConfig.comments(taskId), body: body);
    final data = response['comment'] ?? response['data'] ?? response;
    return Comment.fromJson(data);
  }

  Future<Comment> updateComment(String taskId, String commentId, String content) async {
    final response = await _api.put(
      ApiConfig.comment(taskId, commentId),
      body: {'content': content},
    );
    final data = response['comment'] ?? response['data'] ?? response;
    return Comment.fromJson(data);
  }

  Future<void> deleteComment(String taskId, String commentId) async {
    await _api.delete(ApiConfig.comment(taskId, commentId));
  }
}
