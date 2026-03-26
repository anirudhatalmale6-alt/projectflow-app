import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../services/api_service.dart';

class CalendarProvider with ChangeNotifier {
  final CalendarService _service = CalendarService();

  List<CalendarEvent> _events = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _googleLinked = false;
  String? _errorMessage;
  String? _syncMessage;

  List<CalendarEvent> get events => _events;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get googleLinked => _googleLinked;
  String? get errorMessage => _errorMessage;
  String? get syncMessage => _syncMessage;

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

  // Google Calendar Sync

  Future<void> checkGoogleStatus() async {
    try {
      final status = await _service.getGoogleCalendarStatus();
      _googleLinked = status['linked'] == true;
      notifyListeners();
    } catch (_) {
      _googleLinked = false;
    }
  }

  Future<bool> importFromGoogle(String projectId, DateTime start, DateTime end) async {
    _isSyncing = true;
    _syncMessage = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.importFromGoogle(
        projectId,
        start.toIso8601String(),
        end.toIso8601String(),
      );
      final imported = result['imported'] ?? 0;
      final total = result['total_google_events'] ?? 0;
      _syncMessage = '$imported eventos importados de $total do Google Calendar.';

      // Reload events
      await loadEvents(projectId, start: start, end: end);
    } catch (e) {
      _errorMessage = _parseError(e);
    }

    _isSyncing = false;
    notifyListeners();
    return _errorMessage == null;
  }

  Future<bool> exportToGoogle(String projectId) async {
    _isSyncing = true;
    _syncMessage = null;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.exportToGoogle(projectId);
      final exported = result['exported'] ?? 0;
      final total = result['total_local_events'] ?? 0;
      _syncMessage = '$exported de $total eventos exportados para o Google Calendar.';
    } catch (e) {
      _errorMessage = _parseError(e);
    }

    _isSyncing = false;
    notifyListeners();
    return _errorMessage == null;
  }

  void clearSyncMessage() {
    _syncMessage = null;
    notifyListeners();
  }

  String _parseError(dynamic error) {
    if (error is ApiException) return error.message;
    return 'Ocorreu um erro. Tente novamente.';
  }
}
