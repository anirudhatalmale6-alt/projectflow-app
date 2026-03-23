import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class HoursTracker extends StatefulWidget {
  final double? estimatedHours;
  final double? actualHours;
  final bool editable;
  final Function(double)? onHoursChanged;
  final DateTime? timerStartedAt;

  const HoursTracker({
    super.key,
    this.estimatedHours,
    this.actualHours,
    this.editable = false,
    this.onHoursChanged,
    this.timerStartedAt,
  });

  @override
  State<HoursTracker> createState() => _HoursTrackerState();
}

class _HoursTrackerState extends State<HoursTracker> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  bool get _isTimerRunning => widget.timerStartedAt != null;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(HoursTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timerStartedAt != widget.timerStartedAt) {
      _timer?.cancel();
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    if (_isTimerRunning) {
      _updateElapsed();
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        _updateElapsed();
      });
    } else {
      _elapsed = Duration.zero;
    }
  }

  void _updateElapsed() {
    if (widget.timerStartedAt != null) {
      setState(() {
        _elapsed = DateTime.now().toUtc().difference(widget.timerStartedAt!.toUtc());
        if (_elapsed.isNegative) _elapsed = Duration.zero;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    final estimated = widget.estimatedHours ?? 0;
    final actual = widget.actualHours ?? 0;
    final elapsedHours = _elapsed.inSeconds / 3600.0;
    final totalActual = actual + (_isTimerRunning ? elapsedHours : 0);
    final progress = estimated > 0 ? totalActual / estimated : 0.0;
    final isOver = progress > 1.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined,
                  size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'Controle de Horas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (widget.editable)
                InkWell(
                  onTap: () => _showHoursDialog(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Registrar',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Live timer display
          if (_isTimerRunning) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsingDot(color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: AppTheme.primaryColor,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EM PROGRESSO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimado',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${estimated.toStringAsFixed(1)}h',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppTheme.dividerColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Realizado',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalActual.toStringAsFixed(1)}h',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isOver ? AppTheme.errorColor : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppTheme.dividerColor,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Restante',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      estimated > 0
                          ? '${(estimated - totalActual).toStringAsFixed(1)}h'
                          : '\u2014',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isOver
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AppTheme.dividerColor,
              color: isOver ? AppTheme.errorColor : AppTheme.primaryColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).toInt()}% do tempo estimado utilizado',
            style: TextStyle(
              fontSize: 11,
              color: isOver ? AppTheme.errorColor : AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  void _showHoursDialog(BuildContext context) {
    final controller = TextEditingController(
      text: (widget.actualHours ?? 0).toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrar Horas'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Total de horas trabalhadas',
            suffixText: 'horas',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && widget.onHoursChanged != null) {
                widget.onHoursChanged!(value);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}

/// A pulsing dot animation to indicate timer is running
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withOpacity(0.4 + 0.6 * _controller.value),
          ),
        );
      },
    );
  }
}
