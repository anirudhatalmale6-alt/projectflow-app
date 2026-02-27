import '../config/api_config.dart';
import '../models/project.dart';
import '../models/user.dart';
import 'api_service.dart';

class ProjectService {
  final ApiService _api = ApiService();

  Future<List<Project>> getProjects() async {
    final response = await _api.get(ApiConfig.projects);
    final List<dynamic> data = response['projects'] ?? response['data'] ?? response;
    return data.map((json) => Project.fromJson(json)).toList();
  }

  Future<Project> getProject(String id) async {
    final response = await _api.get(ApiConfig.project(id));
    final data = response['project'] ?? response['data'] ?? response;
    return Project.fromJson(data);
  }

  Future<Project> createProject(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.projects, body: data);
    final projectData = response['project'] ?? response['data'] ?? response;
    return Project.fromJson(projectData);
  }

  Future<Project> updateProject(String id, Map<String, dynamic> data) async {
    final response = await _api.put(ApiConfig.project(id), body: data);
    final projectData = response['project'] ?? response['data'] ?? response;
    return Project.fromJson(projectData);
  }

  Future<void> deleteProject(String id) async {
    await _api.delete(ApiConfig.project(id));
  }

  Future<List<ProjectMember>> getMembers(String projectId) async {
    final response = await _api.get(ApiConfig.projectMembers(projectId));
    final List<dynamic> data = response['members'] ?? response['data'] ?? response;
    return data.map((json) => ProjectMember.fromJson(json)).toList();
  }

  Future<void> addMember(String projectId, String email, {String role = 'member'}) async {
    await _api.post(
      ApiConfig.projectMembers(projectId),
      body: {'email': email, 'role': role},
    );
  }

  Future<void> removeMember(String projectId, String userId) async {
    await _api.delete(ApiConfig.projectMember(projectId, userId));
  }

  Future<void> updateMemberRole(
      String projectId, String userId, String role) async {
    await _api.put(
      ApiConfig.projectMember(projectId, userId),
      body: {'role': role},
    );
  }

  Future<Map<String, dynamic>> getProjectStats(String id) async {
    final response = await _api.get(ApiConfig.projectStats(id));
    return response['stats'] ?? response['data'] ?? response;
  }
}
