import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../../core/muscle_style.dart';
import '../../member/providers/member_providers.dart';
import '../data/routine_repository.dart';
import '../models/routine.dart';
import '../providers/routine_providers.dart';

/// El cliente crea o edita una rutina propia. Devuelve true si guardó.
class MyRoutineEditorScreen extends ConsumerStatefulWidget {
  const MyRoutineEditorScreen({super.key, this.routine});

  /// null = nueva rutina
  final Routine? routine;

  @override
  ConsumerState<MyRoutineEditorScreen> createState() =>
      _MyRoutineEditorScreenState();
}

class _Day {
  _Day(String text, [List<RoutineExercise>? items])
      : label = TextEditingController(text: text),
        items = items ?? [];
  final TextEditingController label;
  final List<RoutineExercise> items;
}

class _MyRoutineEditorScreenState extends ConsumerState<MyRoutineEditorScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _notesCtrl;
  final List<_Day> _days = [];
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final r = widget.routine;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _notesCtrl = TextEditingController(text: r?.notes ?? '');
    if (r != null && r.exercises.isNotEmpty) {
      for (final d in r.dayLabels) {
        _days.add(_Day(d, r.exercisesForDay(d)));
      }
    } else {
      _days.add(_Day('Día 1'));
    }
    _nameCtrl.addListener(() => _dirty = true);
    _notesCtrl.addListener(() => _dirty = true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    for (final d in _days) {
      d.label.dispose();
    }
    super.dispose();
  }

  int get _total => _days.fold<int>(0, (s, d) => s + d.items.length);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Ponle un nombre a tu rutina');
      return;
    }
    if (_total == 0) {
      _snack('Añade al menos un ejercicio');
      return;
    }
    for (final d in _days) {
      if (d.items.isNotEmpty && d.label.text.trim().isEmpty) {
        _snack('Ponle nombre a cada día con ejercicios');
        return;
      }
    }
    final member = ref.read(myMemberProvider).value;
    if (member == null) return;

    final flat = <RoutineExercise>[
      for (final d in _days)
        for (final e in d.items) e.copyWith(dayLabel: d.label.text.trim()),
    ];

    setState(() => _saving = true);
    try {
      await ref.read(routineRepositoryProvider).saveOwnRoutine(
            routineId: widget.routine?.id,
            memberId: member.id,
            name: name,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            exercises: flat,
          );
      ref.invalidate(myRoutinesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _snack('No se pudo guardar: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Hay cambios sin guardar.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir editando')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _addExercise(_Day day) async {
    final ex = await showModalBottomSheet<CatalogExercise>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _ExercisePickerSheet(),
    );
    if (ex == null || !mounted) return;
    final cardio = ex.muscleGroup == 'cardio';
    final result = await _editParams(RoutineExercise(
      exerciseId: ex.id,
      exerciseName: ex.name,
      muscleGroup: ex.muscleGroup,
      dayLabel: day.label.text,
      sets: cardio ? 1 : 3,
      reps: cardio ? '20 min' : '10',
      restSeconds: cardio ? null : 90,
    ));
    if (result != null) {
      setState(() {
        day.items.add(result);
        _dirty = true;
      });
    }
  }

  Future<RoutineExercise?> _editParams(RoutineExercise e) =>
      showDialog<RoutineExercise>(
        context: context,
        builder: (_) => _ParamsDialog(initial: e),
      );

  Future<void> _removeDay(int i) async {
    final day = _days[i];
    if (day.items.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Eliminar día?'),
          content: Text('Se quitarán sus ${day.items.length} ejercicios.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _days.removeAt(i).label.dispose();
      _dirty = true;
    });
  }

  void _move(_Day day, int i, int delta) {
    final t = i + delta;
    if (t < 0 || t >= day.items.length) return;
    setState(() {
      day.items.insert(t, day.items.removeAt(i));
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.routine == null ? 'Mi nueva rutina' : 'Editar rutina'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la rutina',
                hintText: 'Ej: Mi rutina de verano',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _days.length; i++) _dayCard(theme, i),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _days.add(_Day('Día ${_days.length + 1}'));
                _dirty = true;
              }),
              icon: const Icon(Icons.add),
              label: const Text('Añadir día'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(ThemeData theme, int dayIndex) {
    final day = _days[dayIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: day.label,
                    onChanged: (_) => _dirty = true,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'Nombre del día (ej: Pierna)',
                      isDense: true,
                    ),
                  ),
                ),
                if (_days.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeDay(dayIndex),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var j = 0; j < day.items.length; j++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: MuscleStyle.of(day.items[j].muscleGroup)
                      .color
                      .withValues(alpha: 0.15),
                  child: Icon(MuscleStyle.of(day.items[j].muscleGroup).icon,
                      size: 16,
                      color: MuscleStyle.of(day.items[j].muscleGroup).color),
                ),
                title: Text(day.items[j].exerciseName),
                subtitle: Text(day.items[j].summary),
                onTap: () async {
                  final edited = await _editParams(day.items[j]);
                  if (edited != null) {
                    setState(() {
                      day.items[j] = edited;
                      _dirty = true;
                    });
                  }
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_upward, size: 18),
                      onPressed: j == 0 ? null : () => _move(day, j, -1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        day.items.removeAt(j);
                        _dirty = true;
                      }),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addExercise(day),
                icon: const Icon(Icons.add),
                label: const Text('Añadir ejercicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Selector de ejercicios (hoja inferior)
// =====================================================================
class _ExercisePickerSheet extends ConsumerStatefulWidget {
  const _ExercisePickerSheet();

  @override
  ConsumerState<_ExercisePickerSheet> createState() =>
      _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends ConsumerState<_ExercisePickerSheet> {
  late final Future<List<CatalogExercise>> _future;
  String _query = '';
  String? _group;

  static const _groups = [
    'chest', 'back', 'legs', 'shoulders', 'arms', 'core', 'cardio'
  ];

  @override
  void initState() {
    super.initState();
    _future = ref.read(routineRepositoryProvider).fetchCatalog();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar ejercicio...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _group == null,
                      onSelected: (_) => setState(() => _group = null),
                    ),
                  ),
                  for (final g in _groups)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: Icon(MuscleStyle.of(g).icon, size: 16),
                        label: Text(MuscleStyle.of(g).label),
                        selected: _group == g,
                        onSelected: (_) => setState(() => _group = g),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CatalogExercise>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text(friendlyError(snap.error!)));
                  }
                  final list = snap.data!
                      .where((e) => _group == null || e.muscleGroup == _group)
                      .where((e) =>
                          _query.isEmpty || e.name.toLowerCase().contains(_query))
                      .toList();
                  if (list.isEmpty) {
                    return const Center(child: Text('Sin resultados'));
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final e = list[i];
                      final st = MuscleStyle.of(e.muscleGroup);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: st.color.withValues(alpha: 0.15),
                          child: Icon(st.icon, color: st.color, size: 20),
                        ),
                        title: Text(e.name),
                        subtitle: Text([st.label, e.difficultyLabel]
                            .where((s) => s.isNotEmpty)
                            .join(' · ')),
                        onTap: () => Navigator.pop(context, e),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Series, reps, peso y descanso
// =====================================================================
class _ParamsDialog extends StatefulWidget {
  const _ParamsDialog({required this.initial});
  final RoutineExercise initial;

  @override
  State<_ParamsDialog> createState() => _ParamsDialogState();
}

class _ParamsDialogState extends State<_ParamsDialog> {
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _rest;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _sets = TextEditingController(text: e.sets?.toString() ?? '');
    _reps = TextEditingController(text: e.reps ?? '');
    final w = e.targetWeight;
    _weight = TextEditingController(
        text: w == null ? '' : (w % 1 == 0 ? w.toStringAsFixed(0) : '$w'));
    _rest = TextEditingController(text: e.restSeconds?.toString() ?? '');
  }

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    super.dispose();
  }

  void _accept() {
    final sets = int.tryParse(_sets.text.trim());
    if (sets == null || sets < 1 || sets > 20) {
      setState(() => _error = 'Series: entre 1 y 20');
      return;
    }
    final reps = _reps.text.trim();
    if (reps.isEmpty) {
      setState(() => _error = 'Escribe las repeticiones (ej: 10 o 8-12)');
      return;
    }
    final wText = _weight.text.trim().replaceAll(',', '.');
    final weight = wText.isEmpty ? null : double.tryParse(wText);
    if (wText.isNotEmpty && weight == null) {
      setState(() => _error = 'Peso no válido');
      return;
    }
    final rText = _rest.text.trim();
    final rest = rText.isEmpty ? null : int.tryParse(rText);

    Navigator.pop(
      context,
      widget.initial.copyWith(
        sets: sets,
        reps: reps,
        targetWeight: weight,
        clearWeight: weight == null,
        restSeconds: rest,
        clearRest: rest == null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(widget.initial.exerciseName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sets,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(labelText: 'Series'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _reps,
                  decoration: const InputDecoration(
                      labelText: 'Repeticiones', hintText: '10 o 8-12'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Peso (kg)', hintText: 'Opcional'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _rest,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  decoration: const InputDecoration(
                      labelText: 'Descanso (s)', hintText: 'Opcional'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(onPressed: _accept, child: const Text('Aceptar')),
      ],
    );
  }
}
