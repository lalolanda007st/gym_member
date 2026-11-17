import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/muscle_style.dart';
import '../../workout/screens/workout_session_screen.dart';
import '../models/routine.dart';
import '../providers/routine_providers.dart';
import 'my_routine_editor_screen.dart';

class RoutineDetailScreen extends ConsumerStatefulWidget {
  const RoutineDetailScreen({super.key, required this.routine});
  final Routine routine;

  @override
  ConsumerState<RoutineDetailScreen> createState() =>
      _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends ConsumerState<RoutineDetailScreen> {
  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MyRoutineEditorScreen(routine: r)),
    );
    // Volvemos al inicio para que se vea la versión actualizada
    if (saved == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar rutina?'),
        content: Text('Se eliminará "${r.name}". Tus entrenos registrados '
            'con ella se conservan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(routineRepositoryProvider).deleteOwnRoutine(r.id);
      ref.invalidate(myRoutinesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo eliminar: ${friendlyError(e)}')));
      }
    }
  }

  int _selectedDay = 0;

  Routine get r => widget.routine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = r.dayLabels;

    if (days.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(r.name)),
        body: const Center(child: Text('Esta rutina aún no tiene ejercicios')),
      );
    }

    final dayExercises = r.exercisesForDay(days[_selectedDay]);
    final totalSets =
        r.exercises.fold<int>(0, (s, e) => s + (e.sets ?? 0));

    return Scaffold(
      floatingActionButton: dayExercises.isEmpty
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.play_arrow),
              label: Text(days.length > 1
                  ? 'Empezar ${days[_selectedDay]}'
                  : 'Empezar entreno'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WorkoutSessionScreen(
                    routine: r,
                    dayLabel: days[_selectedDay],
                  ),
                ),
              ),
            ),
      body: CustomScrollView(
        slivers: [
          // ---------- Cabecera con degradado ----------
          SliverAppBar(
            pinned: true,
            actions: r.isMine
                ? [
                    PopupMenuButton<String>(
                      onSelected: (v) => v == 'edit' ? _edit() : _delete(),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_outlined),
                            title: Text('Editar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_outline,
                                color: Colors.red),
                            title: Text('Eliminar'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ]
                : null,
            expandedHeight: 220,
            foregroundColor: Colors.white,
            backgroundColor: theme.colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                  start: 56, bottom: 16, end: 16),
              title: Text(
                r.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: 10,
                      child: Icon(Icons.fitness_center,
                          size: 180,
                          color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 60,
                      child: Row(
                        children: [
                          _HeaderStat(
                              value: '${days.length}',
                              label: days.length == 1 ? 'día' : 'días'),
                          _HeaderStat(
                              value: '${r.exercises.length}',
                              label: 'ejercicios'),
                          _HeaderStat(value: '$totalSets', label: 'series'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---------- Selector de días ----------
          if (days.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 92,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _DayChip(
                    index: i + 1,
                    label: days[i],
                    count: r.exercisesForDay(days[i]).length,
                    selected: i == _selectedDay,
                    onTap: () => setState(() => _selectedDay = i),
                  ),
                ),
              ),
            ),

          // ---------- Notas del coach y músculos del día ----------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.notes?.isNotEmpty == true) ...[
                    _CoachNote(text: r.notes!),
                    const SizedBox(height: 16),
                  ],
                  Text(days[_selectedDay],
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in {
                        for (final e in dayExercises) e.muscleGroup
                      })
                        _MuscleChip(style: MuscleStyle.of(m)),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // ---------- Ejercicios ----------
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.builder(
              itemCount: dayExercises.length,
              itemBuilder: (_, i) =>
                  _ExerciseCard(index: i + 1, exercise: dayExercises[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.index,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Material(
      color: selected
          ? theme.colorScheme.primary
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 128,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('DÍA $index',
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: fg, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
              Text('$count ${count == 1 ? 'ejercicio' : 'ejercicios'}',
                  style: theme.textTheme.labelSmall?.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.style});
  final MuscleStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: 5),
          Text(style.label,
              style: TextStyle(
                  color: style.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CoachNote extends StatelessWidget {
  const _CoachNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined,
              color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nota de tu coach',
                    style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(text,
                    style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.index, required this.exercise});
  final int index;
  final RoutineExercise exercise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = exercise;
    final style = MuscleStyle.of(e.muscleGroup);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: style.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(style.icon, color: style.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.exerciseName,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              Text(style.label,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: style.color)),
                            ],
                          ),
                        ),
                        Text('#$index',
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.outline,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _Metric(
                            icon: Icons.repeat,
                            value: '${e.sets ?? '-'} × ${e.reps ?? '-'}',
                            label: 'series × reps',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            icon: Icons.fitness_center,
                            value: e.weightLabel ?? '—',
                            label: 'peso',
                          ),
                        ),
                        Expanded(
                          child: _Metric(
                            icon: Icons.timer_outlined,
                            value: e.restLabel ?? '—',
                            label: 'descanso',
                          ),
                        ),
                      ],
                    ),
                    if (e.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.tips_and_updates_outlined,
                                size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(e.notes!,
                                  style: theme.textTheme.bodySmall),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Flexible(
              child: Text(value,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
