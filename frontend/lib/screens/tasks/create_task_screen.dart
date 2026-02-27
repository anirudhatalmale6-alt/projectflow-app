import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../providers/project_provider.dart';
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
  String? _assigneeId;
  String? _projectId;
  List<String> _tags = [];
  bool _isEditing = false;
  String? _editId;

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
      _assigneeId = arg.assigneeId;
      _tags = List.from(arg.tags);
    } else if (arg is String && _projectId == null) {
      _projectId = arg;
    }

    // Load project members for assignment
    if (_projectId != null) {
      context.read<ProjectProvider>().loadProject(_projectId!);
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
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
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<TaskProvider>();
    final data = {
      if (_projectId != null) 'project_id': _projectId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'priority': _priority,
      if (_assigneeId != null) 'assignee_id': _assigneeId,
      if (_dueDate != null) 'due_date': _dueDate!.toIso8601String(),
      if (_estimatedHoursController.text.isNotEmpty)
        'estimated_hours':
            double.tryParse(_estimatedHoursController.text),
      'tags': _tags,
    };

    bool success;
    if (_isEditing) {
      success = await provider.updateTask(_editId!, data);
    } else {
      final task = await provider.createTask(data);
      success = task != null;
    }

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectProvider = context.watch<ProjectProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final members = projectProvider.currentMembers;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Tarefa' : 'Nova Tarefa'),
      ),
      body: LoadingOverlay(
        isLoading: taskProvider.isLoading,
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
                // Assignee
                DropdownButtonFormField<String>(
                  value: _assigneeId,
                  decoration: const InputDecoration(
                    labelText: 'Responsavel',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Nao atribuido'),
                    ),
                    ...members.map((m) {
                      return DropdownMenuItem(
                        value: m.id,
                        child: Text('${m.name} (${AppTheme.getRoleLabel(m.role)})'),
                      );
                    }),
                  ],
                  onChanged: (value) =>
                      setState(() => _assigneeId = value),
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
                          ? DateFormat('dd/MM/yyyy').format(_dueDate!)
                          : 'Selecionar data',
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
