import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../services/api_service.dart';

class CalendarProvider with ChangeNotifier {
  final CalendarService _service = CalendarService();

  List<CalendarEvent> _events = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CalendarEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<CalendarEvent> eventsForDay(DateTime day) {
    return _events.where((e) {
      return e.startTime.year == day.year &&
          e.startTime.month == day.month &&
          e.startTime.day == day.day;
    }).toList();
  }

  Future<void> loadEvents(String projectId, {DateTime? start, DateTime? end}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _service.getEvents(
        projectId,
        start: start?.toIso8601String(),
        end: end?.toIso8601String(),
      );
    } catch (e) {
      _errorMessage = _parseError(e);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<CalendarEvent?> createEvent(String projectId, Map<String, dynamic> data) async {
    try {
      final event = await _service.createEvent(projectId, data);
      _events.add(event);
      _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
      return event;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateEvent(String id, Map<String, dynamic> data) async {
    try {
      final updated = await _service.updateEvent(id, data);
      final idx = _events.indexWhere((e) => e.id == id);
      if (idx >= 0) _events[idx] = updated;
      _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEvent(String id) async {
    try {
      await _service.deleteEvent(id);
      _events.removeWhere((e) => e.id == id);
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
