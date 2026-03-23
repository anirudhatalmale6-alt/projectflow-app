import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../providers/task_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/loading_widget.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _estimatedHoursController = TextEditingController();
  final _tagController = TextEditingController();

  String _priority = 'medium';
  DateTime? _dueDate;
  List<String> _assigneeIds = [];
  String? _projectId;
  List<String> _tags = [];
  bool _isEditing = false;
  String? _editId;
  bool _saving = false;
  List<User> _allUsers = [];
  bool _loadingUsers = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Task && !_isEditing) {
      _isEditing = true;
      _editId = arg.id;
      _projectId = arg.projectId;
      _titleController.text = arg.title;
      _descriptionController.text = arg.description ?? '';
      _estimatedHoursController.text =
          arg.estimatedHours?.toStringAsFixed(1) ?? '';
      _priority = arg.priority;
      _dueDate = arg.dueDate;
      _assigneeIds = arg.assignees.map((a) => a.id).toList();
      if (_assigneeIds.isEmpty && arg.assigneeId != null) {
        _assigneeIds = [arg.assigneeId!];
      }
      _tags = List.from(arg.tags);
    } else if (arg is String && _projectId == null) {
      _projectId = arg;
    }

    // Load all system users for assignment
    if (_allUsers.isEmpty && !_loadingUsers) {
      _loadAllUsers();
    }
  }

  Future<void> _loadAllUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final api = ApiService();
      final response = await api.get(ApiConfig.adminUsers);
      if (response != null) {
        final List<dynamic> usersData =
            response is List ? response : (response['users'] ?? response['data'] ?? []);
        setState(() {
          _allUsers = usersData
              .map((u) => User.fromJson(u as Map<String, dynamic>))
              .where((u) => u.isApproved)
              .toList();
        });
      }
    } catch (_) {
      // Silently fail - users can still create tasks without assignees
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _estimatedHoursController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now.add(const Duration(days: 7));
    final firstDate = initial.isBefore(now) ? initial : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _dueDate != null
            ? TimeOfDay.fromDateTime(_dueDate!)
            : const TimeOfDay(hour: 18, minute: 0),
      );
      setState(() {
        if (time != null) {
          _dueDate = DateTime(
              picked.year, picked.month, picked.day, time.hour, time.minute);
        } else {
          _dueDate = DateTime(picked.year, picked.month, picked.day, 18, 0);
        }
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);

    final provider = context.read<TaskProvider>();
    final data = {
      if (_projectId != null) 'project_id': _projectId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'priority': _priority,
      if (_assigneeIds.isNotEmpty) 'assigneeId': _assigneeIds.first,
      'assigneeIds': _assigneeIds,
      if (_dueDate != null) 'dueDate': _dueDate!.toIso8601String(),
      if (_estimatedHoursController.text.isNotEmpty)
        'estimatedHours':
            double.tryParse(_estimatedHoursController.text),
      'tags': _tags,
    };

    try {
      bool success;
      if (_isEditing) {
        success = await provider.updateTask(_editId!, data);
      } else {
        final task = await provider.createTask(data);
        success = task != null;
      }

      if (success && mounted) {
        Navigator.pop(context);
      } else if (!success && mounted) {
        final error = provider.errorMessage ?? 'Erro ao salvar tarefa.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red[700]),
        );
        provider.clearError();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final members = _allUsers;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
      ),
      body: LoadingOverlay(
        isLoading: _saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titulo da Tarefa *',
                    hintText: 'Ex: Edicao do video principal',
                    prefixIcon: Icon(Icons.task_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o titulo da tarefa';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descricao',
                    hintText: 'Descreva a tarefa...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                // Priority
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Prioridade',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Baixa')),
                    DropdownMenuItem(value: 'medium', child: Text('Media')),
                    DropdownMenuItem(value: 'high', child: Text('Alta')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
                  ],
                  onChanged: (value) =>
                      setState(() => _priority = value ?? 'medium'),
                ),
                const SizedBox(height: 16),
                // Assignees (multi-select)
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Responsaveis',
                    prefixIcon: Icon(Icons.people_outlined),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_assigneeIds.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _assigneeIds.map((id) {
                            final member = members.where((m) => m.id == id).toList();
                            final name = member.isNotEmpty ? member.first.name : 'Membro';
                            return Chip(
                              label: Text(name, style: const TextStyle(fontSize: 13)),
                              avatar: CircleAvatar(
                                radius: 12,
                                backgroundColor: AppTheme.primaryColor,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                              onDeleted: () => setState(() => _assigneeIds.remove(id)),
                              deleteIconColor: AppTheme.textSecondary,
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: members
                            .where((m) => !_assigneeIds.contains(m.id))
                            .map((m) => ActionChip(
                                  avatar: const Icon(Icons.add, size: 16),
                                  label: Text(m.name, style: const TextStyle(fontSize: 13)),
                                  onPressed: () => setState(() => _assigneeIds.add(m.id)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Due date
                InkWell(
                  onTap: _selectDueDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data de Entrega',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _dueDate != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(_dueDate!)
                          : 'Selecionar data e hora',
                      style: TextStyle(
                        color: _dueDate != null
                            ? AppTheme.textPrimary
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Estimated hours
                TextFormField(
                  controller: _estimatedHoursController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Horas Estimadas',
                    hintText: 'Ex: 8.0',
                    prefixIcon: Icon(Icons.timer_outlined),
                    suffixText: 'horas',
                  ),
                ),
                const SizedBox(height: 16),
                // Tags
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          labelText: 'Tags',
                          hintText: 'Adicionar tag',
                          prefixIcon: Icon(Icons.label_outlined),
                        ),
                        onFieldSubmitted: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addTag,
                      icon: const Icon(Icons.add_circle),
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _tags
                        .map((tag) => Chip(
                              label: Text(tag),
                              onDeleted: () {
                                setState(() => _tags.remove(tag));
                              },
                              deleteIconColor: AppTheme.textSecondary,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(
                      _isEditing ? 'Salvar Alteracoes' : 'Criar Tarefa',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
