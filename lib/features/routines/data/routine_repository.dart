import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/routine.dart';

/// Ejercicio del catálogo (solo lo que necesita el editor del cliente).
class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    this.muscleGroup,
    this.difficulty,
  });

  final String id;
  final String name;
  final String? muscleGroup;
  final String? difficulty;

  String get difficultyLabel => switch (difficulty) {
        'beginner' => 'Principiante',
        'intermediate' => 'Intermedio',
        'advanced' => 'Avanzado',
        _ => '',
      };
}

class RoutineRepository {
  RoutineRepository(this._client);
  final SupabaseClient _client;

  /// Rutinas activas del miembro (del coach y propias).
  Future<List<Routine>> fetchActiveForMember(String memberId) async {
    final rows = await _client
        .from('routines')
        .select(
          'id, name, notes, source, updated_at, '
          'routine_exercises(id, exercise_id, day_label, position, sets, reps, '
          'target_weight, rest_seconds, notes, exercises(name, muscle_group))',
        )
        .eq('member_id', memberId)
        .eq('active', true)
        .order('updated_at', ascending: false);
    return rows.map(Routine.fromMap).toList();
  }

  Future<List<CatalogExercise>> fetchCatalog() async {
    final rows = await _client
        .from('exercises')
        .select('id, name, muscle_group, difficulty')
        .order('name');
    return [
      for (final r in rows)
        CatalogExercise(
          id: r['id'] as String,
          name: r['name'] as String,
          muscleGroup: r['muscle_group'] as String?,
          difficulty: r['difficulty'] as String?,
        ),
    ];
  }

  /// Crea o actualiza una rutina PROPIA del cliente (source = 'member').
  /// RLS impide que toque las rutinas del coach.
  Future<String> saveOwnRoutine({
    String? routineId,
    required String memberId,
    required String name,
    String? notes,
    required List<RoutineExercise> exercises,
  }) async {
    String id;
    final now = DateTime.now().toUtc().toIso8601String();

    if (routineId == null) {
      final row = await _client
          .from('routines')
          .insert({
            'member_id': memberId,
            'coach_id': _client.auth.currentUser?.id,
            'source': 'member',
            'name': name,
            'notes': notes,
          })
          .select('id')
          .single();
      id = row['id'] as String;
    } else {
      id = routineId;
      await _client
          .from('routines')
          .update({'name': name, 'notes': notes, 'updated_at': now})
          .eq('id', id);
      await _client.from('routine_exercises').delete().eq('routine_id', id);
    }

    if (exercises.isNotEmpty) {
      await _client.from('routine_exercises').insert([
        for (var i = 0; i < exercises.length; i++)
          exercises[i].copyWith(position: i).toInsertMap(id),
      ]);
    }
    return id;
  }

  Future<void> deleteOwnRoutine(String routineId) async {
    await _client.from('routines').delete().eq('id', routineId);
  }
}
