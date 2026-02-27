import 'package:flutter/material.dart';
import '../models/delivery_job.dart';
import '../services/delivery_service.dart';
import '../services/api_service.dart';

class DeliveryProvider with ChangeNotifier {
  final DeliveryService _deliveryService = DeliveryService();

  List<DeliveryJob> _deliveries = [];
  DeliveryJob? _currentDelivery;
  bool _isLoading = false;
  String? _errorMessage;

  List<DeliveryJob> get deliveries => _deliveries;
  DeliveryJob? get currentDelivery => _currentDelivery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadDeliveries({String? projectId, String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _deliveries = await _deliveryService.getDeliveries(
        projectId: projectId,
        status: status,
      );
    } catch (e) {
      _errorMessage = _parseError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadDelivery(String id) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentDelivery = await _deliveryService.getDelivery(id);
    } catch (e) {
      _errorMessage = _parseError(e);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<DeliveryJob?> createDelivery(Map<String, dynamic> data,
      {String? filePath}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final delivery =
          await _deliveryService.createDelivery(data, filePath: filePath);
      _deliveries.insert(0, delivery);
      _isLoading = false;
      notifyListeners();
      return delivery;
    } catch (e) {
      _errorMessage = _parseError(e);
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> approveDelivery(String id, {String? comments}) async {
    try {
      final updated =
          await _deliveryService.approve(id, comments: comments);
      _updateDeliveryInList(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectDelivery(String id, {String? comments}) async {
    try {
      final updated =
          await _deliveryService.reject(id, comments: comments);
      _updateDeliveryInList(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestRevision(String id, {String? comments}) async {
    try {
      final updated =
          await _deliveryService.requestRevision(id, comments: comments);
      _updateDeliveryInList(updated);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  void _updateDeliveryInList(DeliveryJob delivery) {
    final index = _deliveries.indexWhere((d) => d.id == delivery.id);
    if (index >= 0) _deliveries[index] = delivery;
    if (_currentDelivery?.id == delivery.id) _currentDelivery = delivery;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _parseError(dynamic error) {
    if (error is ApiException) return error.message;
    return 'Ocorreu um erro. Tente novamente.';
  }
}
