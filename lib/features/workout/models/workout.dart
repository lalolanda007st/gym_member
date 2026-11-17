import '../../routines/models/routine.dart';

// =====================================================================
// Estado en memoria mientras el cliente entrena
// =====================================================================

class LoggedSet {
  LoggedSet({this.reps, this.weight, this.done = false});

  int? reps;
  double? weight;
  bool done;
}

class ExerciseLog {
  ExerciseLog({required this.exercise, required this.sets});

  final RoutineExercise exercise;
  final List<LoggedSet> sets;

  /// Crea las series según lo que pidió el coach, con los valores
  /// objetivo ya rellenados para que el cliente solo confirme.
  factory ExerciseLog.fromTarget(RoutineExercise e) {
    final count = (e.sets ?? 3).clamp(1, 20);
    final reps = firstNumber(e.reps);
    return ExerciseLog(
      exercise: e,
      sets: [
        for (var i = 0; i < count; i++)
          LoggedSet(reps: reps, weight: e.targetWeight),
      ],
    );
  }

  int get completedSets => sets.where((s) => s.done).length;

  /// Primer número de un texto como "8-12" o "10" (8 y 10).
  static int? firstNumber(String? text) {
    if (text == null) return null;
    final match = RegExp(r'\d+').firstMatch(text);
    return match == null ? null : int.tryParse(match.group(0)!);
  }
}

// =====================================================================
// Historial (lo que se lee de Supabase)
// =====================================================================

class SetRecord {
  const SetRecord({
    required this.exerciseName,
    this.muscleGroup,
    required this.position,
    required this.setNumber,
    this.reps,
    this.weight,
  });

  final String exerciseName;
  final String? muscleGroup;
  final int position;
  final int setNumber;
  final int? reps;
  final double? weight;

  double get volume => (reps ?? 0) * (weight ?? 0);

  factory SetRecord.fromMap(Map<String, dynamic> m) {
    final ex = m['exercises'] as Map<String, dynamic>?;
    return SetRecord(
      exerciseName: (ex?['name'] as String?) ?? 'Ejercicio',
      muscleGroup: ex?['muscle_group'] as String?,
      position: (m['position'] as int?) ?? 0,
      setNumber: (m['set_number'] as int?) ?? 1,
      reps: m['reps'] as int?,
      weight: (m['weight'] as num?)?.toDouble(),
    );
  }
}

class WorkoutRecord {
  const WorkoutRecord({
    required this.id,
    required this.date,
    this.startedAt,
    this.durationMinutes,
    this.routineName,
    this.notes,
    this.calories,
    this.avgHeartRate,
    this.maxHeartRate,
    required this.sets,
  });

  final String id;
  final DateTime date;
  final DateTime? startedAt;
  final int? durationMinutes;
  final int? calories;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final String? routineName;
  final String? notes;
  final List<SetRecord> sets;

  int get totalSets => sets.length;
  double get totalVolume => sets.fold<double>(0, (s, r) => s + r.volume);

  /// Ejercicios en orden, cada uno con sus series.
  List<(String name, String? muscle, List<SetRecord> sets)> get byExercise {
    final order = <int>[];
    final map = <int, List<SetRecord>>{};
    for (final s in sets) {
      if (!map.containsKey(s.position)) order.add(s.position);
      map.putIfAbsent(s.position, () => []).add(s);
    }
    order.sort();
    return [
      for (final p in order)
        (
          map[p]!.first.exerciseName,
          map[p]!.first.muscleGroup,
          map[p]!..sort((a, b) => a.setNumber.compareTo(b.setNumber)),
        ),
    ];
  }

  factory WorkoutRecord.fromMap(Map<String, dynamic> m) {
    final routine = m['routines'] as Map<String, dynamic>?;
    return WorkoutRecord(
      id: m['id'] as String,
      date: DateTime.parse(m['date'] as String),
      startedAt: m['started_at'] == null
          ? null
          : DateTime.parse(m['started_at'] as String).toLocal(),
      durationMinutes: m['duration_minutes'] as int?,
      calories: m['calories'] as int?,
      avgHeartRate: m['avg_heart_rate'] as int?,
      maxHeartRate: m['max_heart_rate'] as int?,
      routineName: routine?['name'] as String?,
      notes: m['notes'] as String?,
      sets: (m['session_exercises'] as List? ?? [])
          .map((e) => SetRecord.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
