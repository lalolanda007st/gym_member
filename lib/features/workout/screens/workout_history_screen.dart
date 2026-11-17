import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors.dart';
import '../../../core/muscle_style.dart';
import '../../activity/providers/activity_providers.dart';
import '../models/workout.dart';
import '../providers/workout_providers.dart';

class WorkoutHistoryScreen extends ConsumerWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workoutHistoryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis entrenos')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fitness_center,
                        size: 64, color: theme.colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    const Text(
                      'Aún no has registrado entrenos.\n'
                      'Abre una rutina y pulsa "Empezar entreno".',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final totalSets = list.fold<int>(0, (s, w) => s + w.totalSets);
          final totalMinutes =
              list.fold<int>(0, (s, w) => s + (w.durationMinutes ?? 0));

          return RefreshIndicator(
            onRefresh: () => ref.refresh(workoutHistoryProvider.future),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _Total(
                        icon: Icons.event_available,
                        value: '${list.length}',
                        label: 'entrenos'),
                    _Total(
                        icon: Icons.repeat,
                        value: '$totalSets',
                        label: 'series'),
                    _Total(
                        icon: Icons.timer_outlined,
                        value: totalMinutes >= 60
                            ? '${(totalMinutes / 60).toStringAsFixed(1)} h'
                            : '$totalMinutes min',
                        label: 'tiempo'),
                  ],
                ),
                const SizedBox(height: 16),
                for (final w in list) _WorkoutTile(workout: w),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        elevation: 0,
        color: theme.colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(height: 4),
              Text(value,
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer)),
              Text(label,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkoutTile extends ConsumerWidget {
  const _WorkoutTile({required this.workout});
  final WorkoutRecord workout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final w = workout;
    final dayFmt = DateFormat("EEE d 'de' MMM", 'es');
    final timeFmt = DateFormat.Hm('es');
    final muscles = <String?>{for (final s in w.sets) s.muscleGroup};

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${w.date.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSecondaryContainer)),
              Text(DateFormat.MMM('es').format(w.date).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer)),
            ],
          ),
        ),
        title: Text(w.notes?.isNotEmpty == true
            ? w.notes!
            : (w.routineName ?? 'Entreno')),
        subtitle: Text([
          if (w.routineName != null && w.notes?.isNotEmpty == true)
            w.routineName!,
          '${w.totalSets} series',
          if (w.durationMinutes != null) '${w.durationMinutes} min',
          if (w.totalVolume > 0) '${w.totalVolume.round()} kg',
          if (w.calories != null) '${w.calories} kcal',
          if (w.avgHeartRate != null) '♥ ${w.avgHeartRate} ppm',
        ].join(' · ')),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  '${dayFmt.format(w.date)}'
                  '${w.startedAt != null ? ' · ${timeFmt.format(w.startedAt!)}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                for (final m in muscles.take(4))
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(MuscleStyle.of(m).icon,
                        size: 16, color: MuscleStyle.of(m).color),
                  ),
              ],
            ),
          ),
          for (final (name, muscle, sets) in w.byExercise)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 36,
                    margin: const EdgeInsets.only(right: 10, top: 2),
                    decoration: BoxDecoration(
                      color: MuscleStyle.of(muscle).color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final s in sets)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${s.reps ?? '-'}'
                                  '${s.weight != null ? ' × ${_fmtKg(s.weight!)}' : ''}',
                                  style: theme.textTheme.labelMedium,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Eliminar'),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtKg(double w) =>
      '${w % 1 == 0 ? w.toStringAsFixed(0) : w.toString()} kg';

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar este entreno?'),
        content: const Text('No se puede deshacer.'),
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
      await ref.read(workoutRepositoryProvider).deleteSession(workout.id);
      ref.invalidate(workoutHistoryProvider);
      ref.invalidate(weeklyActivityProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo eliminar: ${friendlyError(e)}')));
      }
    }
  }
}
