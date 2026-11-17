import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/muscle_style.dart';
import '../../activity/providers/activity_providers.dart';
import '../../health/health_providers.dart';
import '../../health/health_service.dart';
import '../../member/providers/member_providers.dart';
import '../../routines/models/routine.dart';
import '../models/workout.dart';
import '../providers/workout_providers.dart';

/// Entreno en vivo de un día de la rutina.
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({
    super.key,
    required this.routine,
    required this.dayLabel,
  });

  final Routine routine;
  final String dayLabel;

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  late final DateTime _startedAt;
  late final List<ExerciseLog> _logs;
  Timer? _clock;
  Duration _elapsed = Duration.zero;

  // Descanso
  Timer? _restTimer;
  int _restLeft = 0;
  int _restTotal = 0;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _logs = widget.routine
        .exercisesForDay(widget.dayLabel)
        .map(ExerciseLog.fromTarget)
        .toList();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _elapsed = DateTime.now().difference(_startedAt));
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  int get _doneSets => _logs.fold<int>(0, (s, l) => s + l.completedSets);
  int get _totalSets => _logs.fold<int>(0, (s, l) => s + l.sets.length);

  // ---------------------------------------------------------------------
  // Descanso
  // ---------------------------------------------------------------------
  void _startRest(int seconds) {
    _restTimer?.cancel();
    if (seconds <= 0) return;
    setState(() {
      _restTotal = seconds;
      _restLeft = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_restLeft <= 1) {
        t.cancel();
        setState(() => _restLeft = 0);
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      } else {
        setState(() => _restLeft--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restLeft = 0);
  }

  void _toggleSet(ExerciseLog log, LoggedSet set) {
    setState(() => set.done = !set.done);
    if (set.done) {
      HapticFeedback.lightImpact();
      _startRest(log.exercise.restSeconds ?? 0);
    }
  }

  // ---------------------------------------------------------------------
  // Terminar
  // ---------------------------------------------------------------------
  Future<void> _finish() async {
    if (_doneSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Marca al menos una serie como hecha (✓)')));
      return;
    }

    final pending = _totalSets - _doneSets;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Terminar entreno?'),
        content: Text(pending == 0
            ? '¡Completaste todas las series!'
            : 'Te quedan $pending series sin marcar. '
                'Solo se guardarán las completadas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Terminar y guardar')),
        ],
      ),
    );
    if (ok != true) return;

    final member = ref.read(myMemberProvider).value;
    if (member == null) return;

    setState(() => _saving = true);
    final finishedAt = DateTime.now();
    try {
      final sessionId = await ref.read(workoutRepositoryProvider).saveSession(
            memberId: member.id,
            routineId: widget.routine.id,
            dayLabel: widget.dayLabel,
            startedAt: _startedAt,
            finishedAt: finishedAt,
            logs: _logs,
          );
      // Calorías y pulsaciones del reloj, si está conectado. Si el reloj aún
      // no ha sincronizado, se completará en la próxima sincronización.
      try {
        final health = await ref.read(healthStatusProvider.future);
        if (health == HealthStatus.connected) {
          await ref
              .read(healthSyncRepositoryProvider)
              .enrichSession(sessionId, _startedAt, finishedAt);
        }
      } catch (_) {}
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(weeklyActivityProvider);
      _clock?.cancel();
      _restTimer?.cancel();
      if (!mounted) return;
      await _showSummary(finishedAt.difference(_startedAt));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo guardar: ${friendlyError(e)}')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showSummary(Duration d) {
    double volume = 0;
    for (final l in _logs) {
      for (final s in l.sets.where((s) => s.done)) {
        volume += (s.reps ?? 0) * (s.weight ?? 0);
      }
    }
    final theme = Theme.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.emoji_events,
            size: 48, color: theme.colorScheme.primary),
        title: const Text('¡Entreno guardado!'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryStat(value: _fmtDuration(d), label: 'tiempo'),
            _SummaryStat(value: '$_doneSets', label: 'series'),
            _SummaryStat(
                value: volume == 0 ? '—' : '${volume.round()} kg',
                label: 'volumen'),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Genial')),
        ],
      ),
    );
  }

  Future<bool> _confirmExit() async {
    if (_doneSets == 0) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Perderás las series que has marcado.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir entrenando')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir')),
        ],
      ),
    );
    return ok == true;
  }

  static String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _totalSets == 0 ? 0.0 : _doneSets / _totalSets;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmExit() && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.dayLabel, overflow: TextOverflow.ellipsis),
              Text(widget.routine.name,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
          actions: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 6),
                    Text(_fmtDuration(_elapsed),
                        style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(value: progress, minHeight: 6),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
          children: [
            for (var i = 0; i < _logs.length; i++)
              _ExerciseLogCard(
                index: i + 1,
                log: _logs[i],
                onToggle: (set) => _toggleSet(_logs[i], set),
                onChanged: () => setState(() {}),
              ),
          ],
        ),
        bottomSheet: _restLeft > 0
            ? _RestBanner(
                left: _restLeft,
                total: _restTotal,
                onSkip: _skipRest,
                onAdd: () => setState(() {
                  _restLeft += 15;
                  _restTotal += 15;
                }),
              )
            : null,
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              onPressed: _saving ? null : _finish,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.flag),
              label: Text('Terminar entreno · $_doneSets/$_totalSets series'),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Tarjeta de ejercicio con sus series
// =====================================================================
class _ExerciseLogCard extends StatelessWidget {
  const _ExerciseLogCard({
    required this.index,
    required this.log,
    required this.onToggle,
    required this.onChanged,
  });

  final int index;
  final ExerciseLog log;
  final void Function(LoggedSet) onToggle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = log.exercise;
    final style = MuscleStyle.of(e.muscleGroup);
    final allDone = log.completedSets == log.sets.length;

    final target = [
      if (e.reps != null) '${e.reps} reps',
      if (e.weightLabel != null) e.weightLabel!,
      if (e.restLabel != null) 'descanso ${e.restLabel}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: allDone ? Colors.green : theme.colorScheme.outlineVariant,
          width: allDone ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$index. ${e.exerciseName}',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (target.isNotEmpty)
                        Text('Objetivo: $target',
                            style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                if (allDone)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            if (e.notes?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('💡 ${e.notes}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(fontStyle: FontStyle.italic)),
              ),
            const SizedBox(height: 10),
            // Cabecera de columnas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  SizedBox(
                      width: 44,
                      child: Text('Serie', style: theme.textTheme.labelSmall)),
                  Expanded(
                      child: Text('Reps',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall)),
                  Expanded(
                      child: Text('Kg',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall)),
                  const SizedBox(width: 52),
                ],
              ),
            ),
            for (var i = 0; i < log.sets.length; i++)
              _SetRow(
                key: ObjectKey(log.sets[i]),
                number: i + 1,
                set: log.sets[i],
                onToggle: () => onToggle(log.sets[i]),
                onChanged: onChanged,
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    final last = log.sets.isNotEmpty ? log.sets.last : null;
                    log.sets.add(LoggedSet(
                      reps: last?.reps,
                      weight: last?.weight,
                    ));
                    onChanged();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Serie'),
                ),
                if (log.sets.length > 1 && !log.sets.last.done)
                  TextButton.icon(
                    onPressed: () {
                      log.sets.removeLast();
                      onChanged();
                    },
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Quitar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.number,
    required this.set,
    required this.onToggle,
    required this.onChanged,
  });

  final int number;
  final LoggedSet set;
  final VoidCallback onToggle;
  final VoidCallback onChanged;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _reps;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    _reps = TextEditingController(text: widget.set.reps?.toString() ?? '');
    _weight = TextEditingController(text: _fmtWeight(widget.set.weight));
  }

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  static String _fmtWeight(double? w) {
    if (w == null) return '';
    return w % 1 == 0 ? w.toStringAsFixed(0) : w.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = widget.set.done;

    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          isDense: true,
          filled: true,
          fillColor: done
              ? Colors.green.withValues(alpha: 0.10)
              : theme.colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: CircleAvatar(
              radius: 14,
              backgroundColor: done
                  ? Colors.green
                  : theme.colorScheme.surfaceContainerHighest,
              child: Text('${widget.number}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: done ? Colors.white : null)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _reps,
                enabled: !done,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: deco('-'),
                onChanged: (v) {
                  widget.set.reps = int.tryParse(v);
                  widget.onChanged();
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _weight,
                enabled: !done,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: deco('-'),
                onChanged: (v) {
                  widget.set.weight =
                      double.tryParse(v.replaceAll(',', '.'));
                  widget.onChanged();
                },
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: done
                    ? Colors.green
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor:
                    done ? Colors.white : theme.colorScheme.onSurfaceVariant,
              ),
              tooltip: done ? 'Desmarcar' : 'Serie hecha',
              icon: const Icon(Icons.check),
              onPressed: widget.onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Banner de descanso
// =====================================================================
class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.left,
    required this.total,
    required this.onSkip,
    required this.onAdd,
  });

  final int left;
  final int total;
  final VoidCallback onSkip;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = left ~/ 60;
    final s = (left % 60).toString().padLeft(2, '0');

    return Material(
      color: theme.colorScheme.inverseSurface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: total == 0 ? 0 : left / total,
                      strokeWidth: 4,
                      color: theme.colorScheme.inversePrimary,
                      backgroundColor: Colors.white24,
                    ),
                    Icon(Icons.hourglass_bottom,
                        size: 18, color: theme.colorScheme.onInverseSurface),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Descanso',
                        style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onInverseSurface)),
                    Text('$m:$s',
                        style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.bold,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                  ],
                ),
              ),
              TextButton(
                onPressed: onAdd,
                child: Text('+15 s',
                    style:
                        TextStyle(color: theme.colorScheme.inversePrimary)),
              ),
              TextButton(
                onPressed: onSkip,
                child: Text('Saltar',
                    style:
                        TextStyle(color: theme.colorScheme.inversePrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
