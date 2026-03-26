import '../config/api_config.dart';
import '../models/project.dart';
import '../models/user.dart';
import 'api_service.dart';

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class ProjectService {
  final ApiService _api = ApiService();

  Future<List<Project>> getProjects({
    String? status,
    String? search,
    int? page,
    int? limit,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (page != null) params['page'] = page.toString();
    if (limit != null) params['limit'] = limit.toString();

    final data = await _api.get(ApiConfig.projects, queryParams: params);
    final list = data['projects'] ?? data['data'] ?? data;
    return (list as List).map((json) => Project.fromJson(json)).toList();
  }

  Future<Project> getProject(String id) async {
    final data = await _api.get(ApiConfig.projectById(id));
    final projectJson = Map<String, dynamic>.from(data['project'] ?? data);

    // Merge stats into project JSON so Project.fromJson can parse them
    // MySQL SUM(CASE...) returns strings, so force int conversion
    if (data['stats'] != null) {
      final stats = data['stats'];
      if (stats['tasks'] != null) {
        final t = stats['tasks'];
        projectJson['task_stats'] = {
          'total': _toInt(t['total_tasks']),
          'todo': _toInt(t['todo']),
          'in_progress': _toInt(t['in_progress']),
          'review': _toInt(t['review']),
          'done': _toInt(t['done']),
        };
      }
      if (stats['deliveries'] != null) {
        projectJson['delivery_count'] = _toInt(stats['deliveries']['total_deliveries']);
      }
    }
    if (data['members'] != null) {
      projectJson['members'] = data['members'];
    }

    return Project.fromJson(projectJson);
  }

  Future<Project> createProject(Map<String, dynamic> projectData) async {
    final data = await _api.post(ApiConfig.projects, body: projectData);
    return Project.fromJson(data['project'] ?? data);
  }

  Future<Project> updateProject(String id, Map<String, dynamic> projectData) async {
    final data = await _api.put(ApiConfig.projectById(id), body: projectData);
    return Project.fromJson(data['project'] ?? data);
  }

  Future<void> deleteProject(String id) async {
    await _api.delete(ApiConfig.projectById(id));
  }

  // Members
  Future<List<User>> getMembers(String projectId) async {
    final data = await _api.get(ApiConfig.projectMembers(projectId));
    final list = data['members'] ?? data['data'] ?? data;
    return (list as List).map((json) => User.fromJson(json)).toList();
  }

  Future<void> addMember(String projectId, String userId, {String? role}) async {
    await _api.post(
      ApiConfig.projectMembers(projectId),
      body: {'userId': userId, if (role != null) 'role': role},
    );
  }

  Future<void> removeMember(String projectId, String userId) async {
    await _api.delete(ApiConfig.projectMember(projectId, userId));
  }
}
