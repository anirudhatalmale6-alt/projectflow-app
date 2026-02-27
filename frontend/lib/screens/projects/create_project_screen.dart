import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../config/theme.dart';
import '../../models/project.dart';
import '../../providers/project_provider.dart';
import '../../widgets/loading_widget.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();

  String _currency = 'BRL';
  DateTime? _deadline;
  String? _clientId;
  String? _clientName;
  Color _color = AppTheme.primaryColor;
  String _status = 'draft';
  bool _isEditing = false;
  String? _editId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Project && !_isEditing) {
      _isEditing = true;
      _editId = arg.id;
      _nameController.text = arg.name;
      _descriptionController.text = arg.description ?? '';
      _budgetController.text = arg.budget?.toString() ?? '';
      _currency = arg.currency ?? 'BRL';
      _deadline = arg.deadline;
      _clientId = arg.clientId;
      _clientName = arg.clientName;
      _status = arg.status;
      if (arg.color != null) {
        try {
          _color = Color(int.parse('0xFF${arg.color!.replaceAll('#', '')}'));
        } catch (_) {}
      }
    }

    // Load clients
    context.read<ProjectProvider>().loadClients();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cor do Projeto'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: _color,
            onColorChanged: (color) {
              setState(() => _color = color);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProjectProvider>();
    final colorHex =
        '#${_color.value.toRadixString(16).substring(2).toUpperCase()}';

    final data = {
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'status': _status,
      if (_clientId != null) 'client_id': _clientId,
      if (_deadline != null) 'deadline': _deadline!.toIso8601String(),
      if (_budgetController.text.isNotEmpty)
        'budget': double.tryParse(_budgetController.text),
      'currency': _currency,
      'color': colorHex,
    };

    bool success;
    if (_isEditing) {
      success = await provider.updateProject(_editId!, data);
    } else {
      final project = await provider.createProject(data);
      success = project != null;
    }

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProjectProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Projeto' : 'Novo Projeto'),
      ),
      body: LoadingOverlay(
        isLoading: provider.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do Projeto *',
                    hintText: 'Ex: Video Institucional - Empresa X',
                    prefixIcon: Icon(Icons.movie_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome do projeto';
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
                    hintText: 'Descreva o projeto...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                // Client selector
                DropdownButtonFormField<String>(
                  value: _clientId,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sem cliente'),
                    ),
                    ...provider.clients.map((client) {
                      return DropdownMenuItem(
                        value: client.id,
                        child: Text(client.displayName),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _clientId = value;
                      _clientName = provider.clients
                          .where((c) => c.id == value)
                          .map((c) => c.name)
                          .firstOrNull;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Status
                if (_isEditing)
                  DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      prefixIcon: Icon(Icons.flag_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Rascunho')),
                      DropdownMenuItem(
                          value: 'in_progress', child: Text('Em Progresso')),
                      DropdownMenuItem(
                          value: 'review', child: Text('Em Revisao')),
                      DropdownMenuItem(
                          value: 'delivered', child: Text('Entregue')),
                      DropdownMenuItem(
                          value: 'completed', child: Text('Concluido')),
                      DropdownMenuItem(
                          value: 'archived', child: Text('Arquivado')),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'draft'),
                  ),
                if (_isEditing) const SizedBox(height: 16),
                // Deadline
                InkWell(
                  onTap: _selectDeadline,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Prazo de Entrega',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(
                      _deadline != null
                          ? DateFormat('dd/MM/yyyy').format(_deadline!)
                          : 'Selecionar data',
                      style: TextStyle(
                        color: _deadline != null
                            ? AppTheme.textPrimary
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Budget row
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        value: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Moeda',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'BRL', child: Text('R\$')),
                          DropdownMenuItem(value: 'USD', child: Text('US\$')),
                          DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        ],
                        onChanged: (v) =>
                            setState(() => _currency = v ?? 'BRL'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _budgetController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Orcamento',
                          hintText: '0.00',
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Color picker
                InkWell(
                  onTap: _pickColor,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Cor do Projeto',
                      prefixIcon: Icon(Icons.palette_outlined),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.dividerColor),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '#${_color.value.toRadixString(16).substring(2).toUpperCase()}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _save,
                    child: Text(
                      _isEditing ? 'Salvar Alteracoes' : 'Criar Projeto',
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
