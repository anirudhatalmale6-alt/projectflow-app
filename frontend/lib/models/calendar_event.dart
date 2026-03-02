class CalendarEvent {
  final String id;
  final String projectId;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final String? createdByName;
  final DateTime? createdAt;

  CalendarEvent({
    required this.id,
    required this.projectId,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.type = 'deadline',
    this.createdByName,
    this.createdAt,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'].toString(),
      projectId: json['project_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      type: json['type'] ?? 'deadline',
      createdByName: json['created_by_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  static String typeLabel(String type) {
    switch (type) {
      case 'deadline': return 'Prazo';
      case 'meeting': return 'Reunião';
      case 'review': return 'Revisão';
      case 'milestone': return 'Marco';
      default: return type;
    }
  }
}
