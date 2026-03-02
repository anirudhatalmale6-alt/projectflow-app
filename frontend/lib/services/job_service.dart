import '../config/api_config.dart';
import '../models/job.dart';
import 'api_service.dart';

class JobService {
  final _api = ApiService();

  Future<List<Job>> getJobs(String projectId) async {
    final data = await _api.get(ApiConfig.jobsByProject(projectId));
    final list = data['jobs'] as List? ?? [];
    return list.map((j) => Job.fromJson(j)).toList();
  }

  Future<Job> createJob(String projectId, Map<String, dynamic> body) async {
    final data = await _api.post(ApiConfig.jobsByProject(projectId), body: body);
    return Job.fromJson(data['job']);
  }

  Future<Job> updateJob(String id, Map<String, dynamic> body) async {
    final data = await _api.patch(ApiConfig.jobById(id), body: body);
    return Job.fromJson(data['job']);
  }

  Future<void> deleteJob(String id) async {
    await _api.delete(ApiConfig.jobById(id));
  }
}
