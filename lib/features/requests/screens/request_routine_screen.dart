import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../member/providers/member_providers.dart';
import '../models/routine_request.dart';
import '../providers/request_providers.dart';

/// Formulario para pedir una rutina al coach.
class RequestRoutineScreen extends ConsumerStatefulWidget {
  const RequestRoutineScreen({super.key});

  @override
  ConsumerState<RequestRoutineScreen> createState() =>
      _RequestRoutineScreenState();
}

class _RequestRoutineScreenState extends ConsumerState<RequestRoutineScreen> {
  String _goal = 'muscle';
  int _days = 3;
  String _level = 'beginner';
  String? _coachId; // null = cualquier coach
  final _notesCtrl = TextEditingController();
  bool _sending = false;

  static const _goalIcons = <String, IconData>{
    'muscle': Icons.fitness_center,
    'fat_loss': Icons.local_fire_department,
    'strength': Icons.bolt,
    'endurance': Icons.directions_run,
    'health': Icons.favorite_outline,
  };

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final member = ref.read(myMemberProvider).value;
    if (member == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(requestRepositoryProvider).create(
            memberId: member.id,
            goal: _goal,
            daysPerWeek: _days,
            level: _level,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            preferredCoachId: _coachId,
          );
      ref.invalidate(latestRequestProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.send, size: 40),
          title: const Text('¡Solicitud enviada!'),
          content: const Text(
              'Tu coach la revisará y te asignará una rutina. '
              'La verás en "Mis rutinas" cuando esté lista.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido')),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pedir rutina al coach')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('¿Cuál es tu objetivo?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          for (final entry in requestGoals.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _OptionTile(
                icon: _goalIcons[entry.key] ?? Icons.flag,
                label: entry.value,
                selected: _goal == entry.key,
                onTap: () => setState(() => _goal = entry.key),
              ),
            ),
          const SizedBox(height: 16),
          Text('¿Cuántos días por semana puedes entrenar?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (var d = 2; d <= 6; d++)
                ChoiceChip(
                  label: Text('$d días'),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('¿Cuál es tu nivel?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              for (final e in requestLevels.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {_level},
            onSelectionChanged: (v) => setState(() => _level = v.first),
          ),
          const SizedBox(height: 20),
          Text('¿Con qué coach?',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ref.watch(coachesProvider).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
                // Si falla la lista, se puede pedir igual a "cualquier coach"
                error: (_, __) => _CoachOption(
                  initials: null,
                  name: 'Cualquier coach',
                  subtitle: 'El primero que esté disponible',
                  selected: true,
                  onTap: () {},
                ),
                data: (coaches) => Column(
                  children: [
                    _CoachOption(
                      initials: null,
                      name: 'Cualquier coach',
                      subtitle: 'El primero que esté disponible',
                      selected: _coachId == null,
                      onTap: () => setState(() => _coachId = null),
                    ),
                    for (final c in coaches)
                      _CoachOption(
                        initials: c.initials,
                        name: c.name,
                        subtitle: c.role == 'admin' ? 'Administrador' : 'Coach',
                        selected: _coachId == c.id,
                        onTap: () => setState(() => _coachId = c.id),
                      ),
                  ],
                ),
              ),
          const SizedBox(height: 20),
          TextField(
            controller: _notesCtrl,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Algo que tu coach deba saber (opcional)',
              hintText: 'Lesiones, horario, máquinas que prefieres, '
                  'zonas que quieres trabajar...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send),
            label: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected
                            ? theme.colorScheme.onPrimaryContainer
                            : null)),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachOption extends StatelessWidget {
  const _CoachOption({
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  /// null = opción "cualquier coach"
  final String? initials;
  final String name;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondaryContainer,
                  foregroundColor: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSecondaryContainer,
                  child: initials == null
                      ? const Icon(Icons.groups, size: 20)
                      : Text(initials!,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.w500)),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
