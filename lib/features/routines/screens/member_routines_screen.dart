import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../auth/models/user.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/routine.dart';
import '../providers/routine_provider.dart';
import 'routine_editor_screen.dart';

class MemberRoutinesScreen extends ConsumerWidget {
  final String memberId;
  final String memberName;

  const MemberRoutinesScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(memberRoutinesProvider(memberId));
    final currentUser = ref.watch(currentUserProvider);
    final canEdit = currentUser?.canManageRoutines ?? false;

    return Scaffold(
      appBar: AppBar(title: Text('Rutinas de $memberName')),
      body: routinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.list_alt, size: 56, color: Colors.black26),
                    const SizedBox(height: 12),
                    Text(
                      canEdit
                          ? 'Sin rutinas. Pulsa + para crear la primera.'
                          : 'Este cliente aún no tiene rutinas.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(memberRoutinesProvider(memberId).future),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: routines.length,
              itemBuilder: (context, index) => _RoutineCard(
                routine: routines[index],
                canEdit: canEdit,
                memberId: memberId,
                memberName: memberName,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'routinesFab',
              icon: const Icon(Icons.add),
              label: const Text('Nueva rutina'),
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoutineEditorScreen(
                      memberId: memberId,
                      memberName: memberName,
                    ),
                  ),
                );
                if (saved == true) {
                  ref.invalidate(memberRoutinesProvider(memberId));
                  ref.invalidate(allRoutinesProvider);
                }
              },
            )
          : null,
    );
  }
}

class _RoutineCard extends ConsumerWidget {
  final Routine routine;
  final bool canEdit;
  final String memberId;
  final String memberName;

  const _RoutineCard({
    required this.routine,
    required this.canEdit,
    required this.memberId,
    required this.memberName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = routine.dayLabels.length;
    final count = routine.exercises.length;
    final date = routine.createdAt == null
        ? ''
        : ' · creada ${DateFormat('dd/MM/yyyy').format(routine.createdAt!.toLocal())}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              routine.active ? Colors.green[100] : Colors.grey[300],
          child: Icon(
            Icons.fitness_center,
            color: routine.active ? Colors.green[800] : Colors.grey[600],
          ),
        ),
        title: Text(routine.name),
        subtitle: Text(
          '$days ${days == 1 ? 'día' : 'días'} · $count '
          '${count == 1 ? 'ejercicio' : 'ejercicios'}$date'
          '${routine.active ? '' : '\nInactiva: el cliente no la ve'}',
        ),
        isThreeLine: !routine.active,
        onTap: () async {
          if (!canEdit) {
            _showReadOnly(context);
            return;
          }
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => RoutineEditorScreen(
                memberId: memberId,
                memberName: memberName,
                routine: routine,
              ),
            ),
          );
          if (saved == true) {
            ref.invalidate(memberRoutinesProvider(memberId));
            ref.invalidate(allRoutinesProvider);
          }
        },
        trailing: canEdit
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: routine.active,
                    onChanged: (v) async {
                      await ref
                          .read(routineRepositoryProvider)
                          .setActive(routine.id!, v);
                      ref.invalidate(memberRoutinesProvider(memberId));
                      ref.invalidate(allRoutinesProvider);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar rutina?'),
        content: Text(
          'Se eliminará "${routine.name}". Si solo quieres que el cliente '
          'deje de verla, desactívala con el interruptor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(routineRepositoryProvider).deleteRoutine(routine.id!);
      ref.invalidate(memberRoutinesProvider(memberId));
      ref.invalidate(allRoutinesProvider);
    }
  }

  /// Vista de solo lectura para trabajadores.
  void _showReadOnly(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(routine.name, style: Theme.of(context).textTheme.titleLarge),
            if (routine.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(routine.notes!),
            ],
            for (final day in routine.dayLabels) ...[
              const SizedBox(height: 16),
              Text(day,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Divider(),
              for (final e in routine.exercisesForDay(day))
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.exerciseName),
                  subtitle: Text([
                    e.summary,
                    if (e.notes?.isNotEmpty == true) e.notes!,
                  ].where((s) => s.isNotEmpty).join('\n')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
