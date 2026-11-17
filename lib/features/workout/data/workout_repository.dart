import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/workout.dart';

class WorkoutRepository {
  WorkoutRepository(this._client);
  final SupabaseClient _client;

  /// Guarda la sesión y una fila por cada serie completada.
  /// Si falla al guardar las series, borra la sesión para no dejarla vacía.
  Future<String> saveSession({
    required String memberId,
    required String? routineId,
    required String dayLabel,
    required DateTime startedAt,
    required DateTime finishedAt,
    required List<ExerciseLog> logs,
  }) async {
    final minutes = finishedAt.difference(startedAt).inMinutes;
    final local = startedAt.toLocal();
    final date = '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';

    final session = await _client
        .from('workout_sessions')
        .insert({
          'member_id': memberId,
          'routine_id': routineId,
          'date': date,
          'notes': dayLabel,
          'started_at': startedAt.toUtc().toIso8601String(),
          'finished_at': finishedAt.toUtc().toIso8601String(),
          'duration_minutes': minutes < 1 ? 1 : minutes,
          'source': 'manual',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    final sessionId = session['id'] as String;

    final rows = <Map<String, dynamic>>[];
    for (var p = 0; p < logs.length; p++) {
      var setNumber = 0;
      for (final s in logs[p].sets) {
        if (!s.done) continue;
        setNumber++;
        rows.add({
          'session_id': sessionId,
          'exercise_id': logs[p].exercise.exerciseId,
          'position': p,
          'set_number': setNumber,
          'sets': 1,
          'reps': s.reps,
          'weight': s.weight,
        });
      }
    }

    try {
      if (rows.isNotEmpty) {
        await _client.from('session_exercises').insert(rows);
      }
    } catch (e) {
      await _client.from('workout_sessions').delete().eq('id', sessionId);
      rethrow;
    }
    return sessionId;
  }

  Future<List<WorkoutRecord>> fetchHistory(String memberId) async {
    final rows = await _client
        .from('workout_sessions')
        .select(
          'id, date, started_at, duration_minutes, calories, avg_heart_rate, '
          'max_heart_rate, notes, routines(name), '
          'session_exercises(position, set_number, reps, weight, '
          'exercises(name, muscle_group))',
        )
        .eq('member_id', memberId)
        .order('date', ascending: false)
        .order('started_at', ascending: false)
        .limit(60);
    return rows.map(WorkoutRecord.fromMap).toList();
  }

  Future<void> deleteSession(String sessionId) async {
    // Primero las series, por si la FK no tiene borrado en cascada
    await _client.from('session_exercises').delete().eq('session_id', sessionId);
    await _client.from('workout_sessions').delete().eq('id', sessionId);
  }
}
