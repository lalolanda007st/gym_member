const _muscleLabels = {
  'chest': 'Pecho',
  'back': 'Espalda',
  'legs': 'Piernas',
  'shoulders': 'Hombros',
  'arms': 'Brazos',
  'core': 'Core',
  'cardio': 'Cardio',
};

class RoutineExercise {
  const RoutineExercise({
    this.id,
    required this.exerciseId,
    required this.exerciseName,
    this.muscleGroup,
    required this.dayLabel,
    this.position = 0,
    this.sets,
    this.reps,
    this.targetWeight,
    this.restSeconds,
    this.notes,
  });

  final String? id; // null mientras se crea en el editor
  final String exerciseId;
  final String exerciseName;
  final String? muscleGroup;
  final String dayLabel;
  final int position;
  final int? sets;
  final String? reps;
  final double? targetWeight;
  final int? restSeconds;
  final String? notes;

  String? get muscleLabel =>
      muscleGroup == null ? null : (_muscleLabels[muscleGroup] ?? muscleGroup);

  String? get weightLabel {
    if (targetWeight == null) return null;
    final w = targetWeight! % 1 == 0
        ? targetWeight!.toStringAsFixed(0)
        : targetWeight!.toString();
    return '$w kg';
  }

  String? get restLabel {
    if (restSeconds == null) return null;
    if (restSeconds! >= 60 && restSeconds! % 60 == 0) {
      return '${restSeconds! ~/ 60} min';
    }
    if (restSeconds! > 60) {
      return '${restSeconds! ~/ 60} min ${restSeconds! % 60} s';
    }
    return '$restSeconds s';
  }

  /// Resumen tipo "3 × 8-12 · 40 kg · 90 s"
  String get summary => [
        '${sets ?? '?'} × ${reps?.isNotEmpty == true ? reps : '?'}',
        if (weightLabel != null) weightLabel!,
        if (restLabel != null) restLabel!,
      ].join(' · ');

  RoutineExercise copyWith({
    String? dayLabel,
    int? position,
    int? sets,
    String? reps,
    double? targetWeight,
    int? restSeconds,
    String? notes,
    bool clearWeight = false,
    bool clearRest = false,
  }) {
    return RoutineExercise(
      id: id,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      muscleGroup: muscleGroup,
      dayLabel: dayLabel ?? this.dayLabel,
      position: position ?? this.position,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      targetWeight: clearWeight ? null : (targetWeight ?? this.targetWeight),
      restSeconds: clearRest ? null : (restSeconds ?? this.restSeconds),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toInsertMap(String routineId) => {
        'routine_id': routineId,
        'exercise_id': exerciseId,
        'day_label': dayLabel,
        'position': position,
        'sets': sets,
        'reps': reps,
        'target_weight': targetWeight,
        'rest_seconds': restSeconds,
        'notes': (notes?.isEmpty ?? true) ? null : notes,
      };

  factory RoutineExercise.fromMap(Map<String, dynamic> m) {
    final ex = m['exercises'] as Map<String, dynamic>?;
    return RoutineExercise(
      id: m['id'] as String?,
      exerciseId: m['exercise_id'] as String,
      exerciseName: (ex?['name'] as String?) ?? 'Ejercicio',
      muscleGroup: ex?['muscle_group'] as String?,
      dayLabel: (m['day_label'] as String?) ?? 'Día 1',
      position: (m['position'] as int?) ?? 0,
      sets: m['sets'] as int?,
      reps: m['reps'] as String?,
      targetWeight: (m['target_weight'] as num?)?.toDouble(),
      restSeconds: m['rest_seconds'] as int?,
      notes: m['notes'] as String?,
    );
  }
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    this.notes,
    this.updatedAt,
    this.source = 'coach',
    required this.exercises,
  });

  final String id;
  final String name;
  final String? notes;
  final DateTime? updatedAt;

  /// 'coach' = asignada por el gimnasio, 'member' = creada por el cliente.
  final String source;
  final List<RoutineExercise> exercises;

  bool get isMine => source == 'member';

  /// Días en el orden definido.
  List<String> get dayLabels {
    final seen = <String>[];
    for (final e in exercises) {
      if (!seen.contains(e.dayLabel)) seen.add(e.dayLabel);
    }
    return seen;
  }

  List<RoutineExercise> exercisesForDay(String day) =>
      exercises.where((e) => e.dayLabel == day).toList();

  factory Routine.fromMap(Map<String, dynamic> m) {
    final list = (m['routine_exercises'] as List? ?? [])
        .map((e) => RoutineExercise.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Routine(
      id: m['id'] as String,
      name: m['name'] as String,
      notes: m['notes'] as String?,
      source: (m['source'] as String?) ?? 'coach',
      updatedAt: m['updated_at'] == null
          ? null
          : DateTime.parse(m['updated_at'] as String),
      exercises: list,
    );
  }
}
