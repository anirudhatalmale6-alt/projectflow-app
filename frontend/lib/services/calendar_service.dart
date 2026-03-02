import '../config/api_config.dart';
import '../models/calendar_event.dart';
import 'api_service.dart';

class CalendarService {
  final _api = ApiService();

  Future<List<CalendarEvent>> getEvents(String projectId, {String? start, String? end, String? type}) async {
    final params = <String, String>{};
    if (start != null) params['start'] = start;
    if (end != null) params['end'] = end;
    if (type != null) params['type'] = type;
    final data = await _api.get(ApiConfig.calendarEvents(projectId), queryParams: params);
    final list = data['events'] as List? ?? [];
    return list.map((j) => CalendarEvent.fromJson(j)).toList();
  }

  Future<CalendarEvent> createEvent(String projectId, Map<String, dynamic> body) async {
    final data = await _api.post(ApiConfig.calendarEvents(projectId), body: body);
    return CalendarEvent.fromJson(data['event']);
  }

  Future<CalendarEvent> updateEvent(String id, Map<String, dynamic> body) async {
    final data = await _api.patch(ApiConfig.calendarEventById(id), body: body);
    return CalendarEvent.fromJson(data['event']);
  }

  Future<void> deleteEvent(String id) async {
    await _api.delete(ApiConfig.calendarEventById(id));
  }
}
