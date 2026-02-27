import '../config/api_config.dart';
import '../models/client_model.dart';
import 'api_service.dart';

class ClientService {
  final ApiService _api = ApiService();

  Future<List<ClientModel>> getClients({String? search}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;

    final data = await _api.get(ApiConfig.clients, queryParams: params);
    final list = data['clients'] ?? data['data'] ?? data;
    return (list as List).map((json) => ClientModel.fromJson(json)).toList();
  }

  Future<ClientModel> getClient(String id) async {
    final data = await _api.get(ApiConfig.clientById(id));
    return ClientModel.fromJson(data['client'] ?? data);
  }

  Future<ClientModel> createClient(Map<String, dynamic> clientData) async {
    final data = await _api.post(ApiConfig.clients, body: clientData);
    return ClientModel.fromJson(data['client'] ?? data);
  }

  Future<ClientModel> updateClient(String id, Map<String, dynamic> clientData) async {
    final data = await _api.put(ApiConfig.clientById(id), body: clientData);
    return ClientModel.fromJson(data['client'] ?? data);
  }

  Future<void> deleteClient(String id) async {
    await _api.delete(ApiConfig.clientById(id));
  }
}
