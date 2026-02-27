import '../config/api_config.dart';
import '../models/delivery_job.dart';
import 'api_service.dart';

class DeliveryService {
  final ApiService _api = ApiService();

  Future<List<DeliveryJob>> getDeliveries({
    String? projectId,
    String? status,
  }) async {
    final params = <String, String>{};
    if (status != null) params['status'] = status;

    final path = projectId != null
        ? ApiConfig.deliveriesByProject(projectId)
        : ApiConfig.deliveries;

    final data = await _api.get(path, queryParams: params);
    final list = data['deliveries'] ?? data['data'] ?? data;
    return (list as List).map((json) => DeliveryJob.fromJson(json)).toList();
  }

  Future<DeliveryJob> getDelivery(String id) async {
    final data = await _api.get(ApiConfig.deliveryById(id));
    return DeliveryJob.fromJson(data['delivery'] ?? data);
  }

  Future<DeliveryJob> createDelivery(Map<String, dynamic> deliveryData,
      {String? filePath}) async {
    if (filePath != null) {
      final fields = deliveryData.map((k, v) => MapEntry(k, v.toString()));
      final data = await _api.multipartPost(
        ApiConfig.deliveries,
        fields: fields,
        filePath: filePath,
        fileField: 'file',
      );
      return DeliveryJob.fromJson(data['delivery'] ?? data);
    }

    final data = await _api.post(ApiConfig.deliveries, body: deliveryData);
    return DeliveryJob.fromJson(data['delivery'] ?? data);
  }

  Future<DeliveryJob> updateDelivery(
      String id, Map<String, dynamic> deliveryData) async {
    final data =
        await _api.put(ApiConfig.deliveryById(id), body: deliveryData);
    return DeliveryJob.fromJson(data['delivery'] ?? data);
  }

  Future<void> deleteDelivery(String id) async {
    await _api.delete(ApiConfig.deliveryById(id));
  }

  Future<DeliveryJob> approve(String id, {String? comments}) async {
    final data = await _api.post(
      ApiConfig.deliveryApprove(id),
      body: {if (comments != null) 'comments': comments},
    );
    return DeliveryJob.fromJson(data['delivery'] ?? data);
  }

  Future<DeliveryJob> reject(String id, {String? comments}) async {
    final data = await _api.post(
      ApiConfig.deliveryReject(id),
      body: {if (comments != null) 'comments': comments},
    );
    return DeliveryJob.fromJson(data['delivery'] ?? data);
  }

  Future<DeliveryJob> requestRevision(String id, {String? comments}) async {
    final data = await _api.post(
      ApiConfig.deliveryRevision(id),
      body: {if (comments != null) 'comments': comments},
    );
    return DeliveryJob.fromJson(data['delivery'] ?? data);
  }
}
