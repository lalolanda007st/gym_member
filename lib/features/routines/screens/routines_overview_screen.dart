import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/routine.dart';
import '../providers/routine_provider.dart';
import 'member_routines_screen.dart';
import 'routine_editor_screen.dart';

enum _StatusFilter { all, active, inactive }

/// Pestaña "Rutinas": todas las rutinas de todos los clientes en un solo lugar.
class RoutinesOverviewScreen extends ConsumerStatefulWidget {
  const RoutinesOverviewScreen({super.key});

  @override
  ConsumerState<RoutinesOverviewScreen> createState() =>
      _RoutinesOverviewScreenState();
}

class _RoutinesOverviewScreenState
    extends ConsumerState<RoutinesOverviewScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _StatusFilter _status = _StatusFilter.all;
  bool _onlyMine = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(allRoutinesProvider);
    ref.invalidate(coachNamesProvider);
  }

  List<Routine> _applyFilters(List<Routine> all, String? myId) {
    final q = _query.toLowerCase();
    return all.where((r) {
      if (_status == _StatusFilter.active && !r.active) return false;
      if (_status == _StatusFilter.inactive && r.active) return false;
      if (_onlyMine && r.coachId != myId) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          (r.memberName?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(allRoutinesProvider);
    final coachNames = ref.watch(coachNamesProvider).value ?? const {};
    final currentUser = ref.watch(currentUserProvider);
    final canEdit = currentUser?.canManageRoutines ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutinas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _refresh,
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (all) {
          final filtered = _applyFilters(all, currentUser?.id);
          final activeCount = all.where((r) => r.active).length;
          final clientsCount = all.map((r) => r.memberId).toSet().length;

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await ref.read(allRoutinesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              children: [
                // ---------- Resumen ----------
                Row(
                  children: [
                    _SummaryTile(
                      icon: Icons.list_alt,
                      color: Colors.deepPurple,
                      value: '${all.length}',
                      label: 'Rutinas',
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      value: '$activeCount',
                      label: 'Activas',
                    ),
                    const SizedBox(width: 8),
                    _SummaryTile(
                      icon: Icons.people_outline,
                      color: Colors.blue,
                      value: '$clientsCount',
                      label: 'Clientes',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ---------- Buscador ----------
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por cliente o rutina...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 8),

                // ---------- Filtros ----------
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Todas'),
                      selected: _status == _StatusFilter.all,
                      onSelected: (_) =>
                          setState(() => _status = _StatusFilter.all),
                    ),
                    ChoiceChip(
                      label: const Text('Activas'),
                      selected: _status == _StatusFilter.active,
                      onSelected: (_) =>
                          setState(() => _status = _StatusFilter.active),
                    ),
                    ChoiceChip(
                      label: const Text('Inactivas'),
                      selected: _status == _StatusFilter.inactive,
                      onSelected: (_) =>
                          setState(() => _status = _StatusFilter.inactive),
                    ),
                    if (canEdit)
                      FilterChip(
                        label: const Text('Creadas por mí'),
                        selected: _onlyMine,
                        onSelected: (v) => setState(() => _onlyMine = v),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // ---------- Lista ----------
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        const Icon(Icons.search_off,
                            size: 48, color: Colors.black26),
                        const SizedBox(height: 8),
                        Text(
                          all.isEmpty
                              ? (canEdit
                                  ? 'Aún no hay rutinas. Pulsa "Nueva rutina".'
                                  : 'Aún no hay rutinas.')
                              : 'Ninguna rutina coincide con los filtros.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  for (final r in filtered)
                    _RoutineTile(
                      routine: r,
                      coachName: r.coachId == null ? null : coachNames[r.coachId],
                      canEdit: canEdit,
                      onChanged: _refresh,
                    ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              heroTag: 'routinesOverviewFab',
              icon: const Icon(Icons.add),
              label: const Text('Nueva rutina'),
              onPressed: _createForClient,
            )
          : null,
    );
  }

  Future<void> _createForClient() async {
    final member = await showDialog<({String id, String name, String? email})>(
      context: context,
      builder: (_) => const _MemberPickerDialog(),
    );
    if (member == null || !mounted) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoutineEditorScreen(
          memberId: member.id,
          memberName: member.name,
        ),
      ),
    );
    if (saved == true) {
      ref.invalidate(memberRoutinesProvider(member.id));
      _refresh();
    }
  }
}

// =====================================================================
// Tarjeta de rutina
// =====================================================================
class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({
    required this.routine,
    required this.coachName,
    required this.canEdit,
    required this.onChanged,
  });

  final Routine routine;
  final String? coachName;
  final bool canEdit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = routine;
    final days = r.dayLabels.length;
    final count = r.exercises.length;
    final memberName = r.memberName ?? 'Cliente';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: r.active ? Colors.green[100] : Colors.grey[300],
          child: Text(
            memberName.isNotEmpty ? memberName[0].toUpperCase() : '?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: r.active ? Colors.green[800] : Colors.grey[700],
            ),
          ),
        ),
        title: Text(r.name),
        subtitle: Text(
          '$memberName\n'
          '$days ${days == 1 ? 'día' : 'días'} · '
          '$count ${count == 1 ? 'ejercicio' : 'ejercicios'}'
          '${coachName != null ? ' · por $coachName' : ''}',
        ),
        isThreeLine: true,
        trailing: canEdit
            ? Switch(
                value: r.active,
                onChanged: (v) async {
                  await ref.read(routineRepositoryProvider).setActive(r.id!, v);
                  ref.invalidate(memberRoutinesProvider(r.memberId));
                  onChanged();
                },
              )
            : Chip(
                label: Text(r.active ? 'Activa' : 'Inactiva'),
                backgroundColor:
                    r.active ? Colors.green[100] : Colors.grey[300],
              ),
        onTap: () async {
          if (!canEdit) {
            // Trabajadores: ver las rutinas del cliente en modo lectura
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberRoutinesScreen(
                  memberId: r.memberId,
                  memberName: memberName,
                ),
              ),
            );
            return;
          }
          final saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => RoutineEditorScreen(
                memberId: r.memberId,
                memberName: memberName,
                routine: r,
              ),
            ),
          );
          if (saved == true) {
            ref.invalidate(memberRoutinesProvider(r.memberId));
            onChanged();
          }
        },
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color)),
                  Text(label,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Selector de cliente
// =====================================================================
class _MemberPickerDialog extends ConsumerStatefulWidget {
  const _MemberPickerDialog();

  @override
  ConsumerState<_MemberPickerDialog> createState() =>
      _MemberPickerDialogState();
}

class _MemberPickerDialogState extends ConsumerState<_MemberPickerDialog> {
  late final Future<List<({String id, String name, String? email})>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = ref.read(routineRepositoryProvider).getMembers();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('¿Para qué cliente?'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 420,
        height: 440,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar cliente...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<({String id, String name, String? email})>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final list = snap.data!
                      .where((m) =>
                          _query.isEmpty ||
                          m.name.toLowerCase().contains(_query) ||
                          (m.email?.toLowerCase().contains(_query) ?? false))
                      .toList();
                  if (list.isEmpty) {
                    return const Center(child: Text('Sin resultados'));
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(m.name.isNotEmpty
                              ? m.name[0].toUpperCase()
                              : '?'),
                        ),
                        title: Text(m.name),
                        subtitle: m.email == null || m.email!.isEmpty
                            ? null
                            : Text(m.email!),
                        onTap: () => Navigator.pop(context, m),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
