import 'package:flutter/foundation.dart';
import '../models/job.dart';
import '../services/job_service.dart';
import '../services/api_service.dart';

class JobProvider with ChangeNotifier {
  final JobService _service = JobService();

  List<Job> _jobs = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Job> get jobs => _jobs;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<Job> get pendingJobs => _jobs.where((j) => j.status == 'pending').toList();
  List<Job> get inProgressJobs => _jobs.where((j) => j.status == 'in_progress').toList();
  List<Job> get reviewJobs => _jobs.where((j) => j.status == 'in_review' || j.status == 'revision').toList();
  List<Job> get doneJobs => _jobs.where((j) => j.status == 'approved' || j.status == 'delivered').toList();

  Future<void> loadJobs(String projectId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _jobs = await _service.getJobs(projectId);
    } catch (e) {
      _errorMessage = _parseError(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Job?> createJob(String projectId, Map<String, dynamic> data) async {
    try {
      final job = await _service.createJob(projectId, data);
      _jobs.insert(0, job);
      notifyListeners();
      return job;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateJob(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _service.updateJob(id, data);
      final idx = _jobs.indexWhere((j) => j.id == id);
      if (idx >= 0) _jobs[idx] = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteJob(String id) async {
    try {
      await _service.deleteJob(id);
      _jobs.removeWhere((j) => j.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  String _parseError(dynamic error) {
    if (error is ApiException) return error.message;
    return 'Ocorreu um erro. Tente novamente.';
  }
}
