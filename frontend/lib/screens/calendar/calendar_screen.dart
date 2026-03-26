import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/calendar_provider.dart';
import '../../models/calendar_event.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String? _projectId;
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args != _projectId) {
      _projectId = args;
      _loadMonth();
    }
  }

  void _loadMonth() {
    if (_projectId == null) return;
    final start = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final end = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0, 23, 59);
    context.read<CalendarProvider>().loadEvents(
      _projectId!,
      start: start,
      end: end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final calProvider = context.watch<CalendarProvider>();
    final dayEvents = _selectedDay != null
        ? calProvider.eventsForDay(_selectedDay!)
        : <CalendarEvent>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário'),
      ),
      body: Column(
        children: [
          _buildMonthHeader(),
          _buildWeekDays(),
          _buildCalendarGrid(calProvider),
          const Divider(height: 1),
          Expanded(
            child: _selectedDay == null
                ? Center(
                    child: Text(
                      'Selecione um dia para ver eventos',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : dayEvents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_available, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhum evento neste dia',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: dayEvents.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(dayEvents[index]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _projectId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateEvent(),
              icon: const Icon(Icons.add),
              label: const Text('Novo Evento'),
            )
          : null,
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                _selectedDay = null;
              });
              _loadMonth();
            },
          ),
          Text(
            DateFormat('MMMM yyyy', 'pt_BR').format(_focusedMonth),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                _selectedDay = null;
              });
              _loadMonth();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDays() {
    const days = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: days
            .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid(CalendarProvider calProvider) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final startOffset = firstDay.weekday % 7;
    final totalDays = lastDay.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();
    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - startOffset + 1;

              if (dayNum < 1 || dayNum > totalDays) {
                return const Expanded(child: SizedBox(height: 44));
              }

              final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
              final isToday = date.year == today.year &&
                  date.month == today.month &&
                  date.day == today.day;
              final isSelected = _selectedDay != null &&
                  date.year == _selectedDay!.year &&
                  date.month == _selectedDay!.month &&
                  date.day == _selectedDay!.day;
              final hasEvents = calProvider.eventsForDay(date).isNotEmpty;

              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = date),
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : isToday
                              ? AppTheme.primaryColor.withAlpha(25)
                              : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? AppTheme.primaryColor
                                    : Colors.black87,
                          ),
                        ),
                        if (hasEvents)
                          Container(
                            width: 5,
                            height: 5,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.primaryColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final typeColor = _getTypeColor(event.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: typeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: typeColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          CalendarEvent.typeLabel(event.type),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: typeColor),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${DateFormat('HH:mm').format(event.startTime)} - ${DateFormat('HH:mm').format(event.endTime)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (event.description != null)
                    Text(
                      event.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'deadline': return const Color(0xFFEF4444);
      case 'meeting': return const Color(0xFF2563EB);
      case 'review': return const Color(0xFFF59E0B);
      case 'milestone': return const Color(0xFF16A34A);
      default: return Colors.grey;
    }
  }

  void _showCreateEvent() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String selectedType = 'deadline';
    DateTime startDate = _selectedDay ?? DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    final calProvider = context.read<CalendarProvider>();
    bool syncGoogle = calProvider.googleLinked;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Novo Evento',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Descrição (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'deadline', child: Text('Prazo')),
                  DropdownMenuItem(value: 'meeting', child: Text('Reunião')),
                  DropdownMenuItem(value: 'review', child: Text('Revisão')),
                  DropdownMenuItem(value: 'milestone', child: Text('Marco')),
                ],
                onChanged: (v) => setSheetState(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text('${startTime.format(ctx)}'),
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: startTime);
                        if (t != null) setSheetState(() => startTime = t);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('até'),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 18),
                      label: Text('${endTime.format(ctx)}'),
                      onPressed: () async {
                        final t = await showTimePicker(context: ctx, initialTime: endTime);
                        if (t != null) setSheetState(() => endTime = t);
                      },
                    ),
                  ),
                ],
              ),
              if (calProvider.googleLinked) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: syncGoogle,
                      onChanged: (v) => setSheetState(() => syncGoogle = v ?? false),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text('Sincronizar com Google Calendar', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    final startDt = DateTime(
                      startDate.year, startDate.month, startDate.day,
                      startTime.hour, startTime.minute,
                    );
                    final endDt = DateTime(
                      startDate.year, startDate.month, startDate.day,
                      endTime.hour, endTime.minute,
                    );

                    final event = await context.read<CalendarProvider>().createEvent(
                      _projectId!,
                      {
                        'title': title,
                        'description': descController.text.trim(),
                        'type': selectedType,
                        'start_time': startDt.toIso8601String(),
                        'end_time': endDt.toIso8601String(),
                        'sync_google': syncGoogle,
                      },
                    );
                    if (event != null && ctx.mounted) Navigator.pop(ctx);
                  },
                  child: const Text('Criar Evento'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
