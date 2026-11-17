import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../exercises/data/exercise_repository.dart';
import '../../exercises/models/exercise.dart';
import '../models/routine.dart';
import '../providers/routine_provider.dart';

/// Crear o editar una rutina. Devuelve true al cerrar si se guardó.
class RoutineEditorScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String memberName;
  final Routine? routine;

  const RoutineEditorScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    this.routine,
  });

  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _Day {
  final TextEditingController label;
  final List<RoutineExercise> items;
  _Day(String text, [List<RoutineExercise>? items])
      : label = TextEditingController(text: text),
        items = items ?? [];
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
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
    _nameCtrl.addListener(_markDirty);
    _notesCtrl.addListener(_markDirty);
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

  void _markDirty() => _dirty = true;

  int get _totalExercises => _days.fold(0, (sum, d) => sum + d.items.length);

  // ---------------------------------------------------------------------
  // Guardar
  // ---------------------------------------------------------------------
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Ponle un nombre a la rutina');
      return;
    }
    if (_totalExercises == 0) {
      _snack('Añade al menos un ejercicio');
      return;
    }
    for (final d in _days) {
      if (d.items.isNotEmpty && d.label.text.trim().isEmpty) {
        _snack('Todos los días con ejercicios necesitan un nombre');
        return;
      }
    }

    // Aplanar: cada ejercicio con el nombre de su día, en orden
    final flat = <RoutineExercise>[];
    for (final d in _days) {
      final label = d.label.text.trim();
      for (final e in d.items) {
        flat.add(e.copyWith(dayLabel: label));
      }
    }

    setState(() => _saving = true);
    try {
      await ref.read(routineRepositoryProvider).saveRoutine(
            routineId: widget.routine?.id,
            memberId: widget.memberId,
            name: name,
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            exercises: flat,
          );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _snack('No se pudo guardar: ${e.message}');
    } catch (e) {
      _snack('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Hay cambios sin guardar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ---------------------------------------------------------------------
  // Días y ejercicios
  // ---------------------------------------------------------------------
  void _addDay() {
    setState(() {
      _days.add(_Day('Día ${_days.length + 1}'));
      _dirty = true;
    });
  }

  Future<void> _removeDay(int index) async {
    final day = _days[index];
    if (day.items.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('¿Eliminar día?'),
          content: Text(
              'Se quitarán sus ${day.items.length} ejercicios de la rutina.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _days.removeAt(index).label.dispose();
      _dirty = true;
    });
  }

  Future<void> _addExercise(_Day day) async {
    final exercise = await showDialog<Exercise>(
      context: context,
      builder: (_) => const _ExercisePickerDialog(),
    );
    if (exercise == null || !mounted) return;

    final draft = RoutineExercise(
      exerciseId: exercise.id!,
      exerciseName: exercise.name,
      muscleGroup: exercise.muscleGroup,
      dayLabel: day.label.text,
      sets: exercise.muscleGroup == MuscleGroup.cardio ? 1 : 3,
      reps: exercise.muscleGroup == MuscleGroup.cardio ? '20 min' : '10',
      restSeconds: exercise.muscleGroup == MuscleGroup.cardio ? null : 90,
    );
    final result = await _editParams(draft);
    if (result != null) {
      setState(() {
        day.items.add(result);
        _dirty = true;
      });
    }
  }

  Future<RoutineExercise?> _editParams(RoutineExercise e) {
    return showDialog<RoutineExercise>(
      context: context,
      builder: (_) => _ExerciseParamsDialog(initial: e),
    );
  }

  void _move(_Day day, int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= day.items.length) return;
    setState(() {
      final item = day.items.removeAt(index);
      day.items.insert(target, item);
      _dirty = true;
    });
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isNew = widget.routine == null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.pop(context, false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isNew ? 'Nueva rutina' : 'Editar rutina'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text('Para ${widget.memberName}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la rutina',
                hintText: 'Ej: Hipertrofia 4 días',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas para el cliente (opcional)',
                hintText: 'Ej: calentar 10 min antes de empezar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _days.length; i++) _buildDayCard(i),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addDay,
              icon: const Icon(Icons.add),
              label: const Text('Añadir día'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(int dayIndex) {
    final day = _days[dayIndex];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
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
                      hintText: 'Nombre del día (ej: Día 1 — Pierna)',
                      isDense: true,
                    ),
                  ),
                ),
                if (_days.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar día',
                    onPressed: () => _removeDay(dayIndex),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (day.items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Sin ejercicios',
                    style: TextStyle(color: Colors.black45)),
              ),
            for (var j = 0; j < day.items.length; j++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  child: Text('${j + 1}', style: const TextStyle(fontSize: 12)),
                ),
                title: Text(day.items[j].exerciseName),
                subtitle: Text([
                  day.items[j].summary,
                  if (day.items[j].notes?.isNotEmpty == true) day.items[j].notes!,
                ].where((s) => s.isNotEmpty).join('\n')),
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
                      tooltip: 'Subir',
                      onPressed: j == 0 ? null : () => _move(day, j, -1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_downward, size: 18),
                      tooltip: 'Bajar',
                      onPressed: j == day.items.length - 1
                          ? null
                          : () => _move(day, j, 1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Quitar',
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
// Selector de ejercicio del catálogo
// =====================================================================
class _ExercisePickerDialog extends StatefulWidget {
  const _ExercisePickerDialog();

  @override
  State<_ExercisePickerDialog> createState() => _ExercisePickerDialogState();
}

class _ExercisePickerDialogState extends State<_ExercisePickerDialog> {
  late final Future<List<Exercise>> _future;
  String _query = '';
  MuscleGroup? _group;

  @override
  void initState() {
    super.initState();
    _future = ExerciseRepository().getAllExercises();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir ejercicio'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 460,
        height: 480,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _group == null,
                      onSelected: (_) => setState(() => _group = null),
                    ),
                  ),
                  for (final g in MuscleGroup.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(g.label),
                        selected: _group == g,
                        onSelected: (_) => setState(() => _group = g),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Exercise>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
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
                      return ListTile(
                        dense: true,
                        title: Text(e.name),
                        subtitle:
                            Text('${e.muscleGroup.label} · ${e.difficulty.label}'),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

// =====================================================================
// Series, repeticiones, peso, descanso y notas
// =====================================================================
class _ExerciseParamsDialog extends StatefulWidget {
  final RoutineExercise initial;
  const _ExerciseParamsDialog({required this.initial});

  @override
  State<_ExerciseParamsDialog> createState() => _ExerciseParamsDialogState();
}

class _ExerciseParamsDialogState extends State<_ExerciseParamsDialog> {
  late final TextEditingController _sets;
  late final TextEditingController _reps;
  late final TextEditingController _weight;
  late final TextEditingController _rest;
  late final TextEditingController _notes;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _sets = TextEditingController(text: e.sets?.toString() ?? '');
    _reps = TextEditingController(text: e.reps ?? '');
    _weight = TextEditingController(
      text: e.targetWeight == null
          ? ''
          : (e.targetWeight! % 1 == 0
              ? e.targetWeight!.toStringAsFixed(0)
              : e.targetWeight!.toString()),
    );
    _rest = TextEditingController(text: e.restSeconds?.toString() ?? '');
    _notes = TextEditingController(text: e.notes ?? '');
  }

  @override
  void dispose() {
    _sets.dispose();
    _reps.dispose();
    _weight.dispose();
    _rest.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _accept() {
    final sets = int.tryParse(_sets.text.trim());
    if (sets == null || sets < 1 || sets > 20) {
      setState(() => _error = 'Series: un número entre 1 y 20');
      return;
    }
    final reps = _reps.text.trim();
    if (reps.isEmpty) {
      setState(() => _error = 'Escribe las repeticiones (ej: 10 o 8-12)');
      return;
    }

    final weightText = _weight.text.trim().replaceAll(',', '.');
    final weight = weightText.isEmpty ? null : double.tryParse(weightText);
    if (weightText.isNotEmpty && (weight == null || weight < 0)) {
      setState(() => _error = 'Peso no válido');
      return;
    }

    final restText = _rest.text.trim();
    final rest = restText.isEmpty ? null : int.tryParse(restText);
    if (restText.isNotEmpty && (rest == null || rest < 0)) {
      setState(() => _error = 'Descanso no válido (en segundos)');
      return;
    }

    Navigator.pop(
      context,
      widget.initial.copyWith(
        sets: sets,
        reps: reps,
        targetWeight: weight,
        clearWeight: weight == null,
        restSeconds: rest,
        clearRest: rest == null,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return AlertDialog(
      title: Text(widget.initial.exerciseName),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
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
                        labelText: 'Repeticiones',
                        hintText: '10 o 8-12',
                      ),
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
                        labelText: 'Peso (kg)',
                        hintText: 'Opcional',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _rest,
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      decoration: const InputDecoration(
                        labelText: 'Descanso (s)',
                        hintText: 'Opcional',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Indicaciones (opcional)',
                  hintText: 'Ej: bajar lento, 3 segundos',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _accept, child: const Text('Aceptar')),
      ],
    );
  }
}
