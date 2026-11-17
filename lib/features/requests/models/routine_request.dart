/// Objetivos que el cliente puede elegir al pedir una rutina.
const requestGoals = <String, String>{
  'muscle': 'Ganar músculo',
  'fat_loss': 'Perder grasa',
  'strength': 'Ganar fuerza',
  'endurance': 'Resistencia',
  'health': 'Salud general',
};

const requestLevels = <String, String>{
  'beginner': 'Principiante',
  'intermediate': 'Intermedio',
  'advanced': 'Avanzado',
};

/// Coach o admin que el cliente puede elegir.
class Coach {
  const Coach({required this.id, required this.name, required this.role});
  final String id;
  final String name;
  final String role; // 'coach' o 'admin'

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class RoutineRequest {
  const RoutineRequest({
    required this.id,
    required this.goal,
    this.daysPerWeek,
    this.level,
    this.notes,
    this.preferredCoachId,
    required this.status,
    this.response,
    required this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String goal;
  final int? daysPerWeek;
  final String? level;
  final String? notes;
  final String? preferredCoachId;

  /// pending · in_progress · done · rejected · cancelled
  final String status;
  final String? response;
  final DateTime createdAt;
  final DateTime? updatedAt;

  String get goalLabel => requestGoals[goal] ?? goal;
  String? get levelLabel => level == null ? null : (requestLevels[level] ?? level);

  bool get isOpen => status == 'pending' || status == 'in_progress';

  String get statusLabel => switch (status) {
        'pending' => 'Enviada, pendiente de revisar',
        'in_progress' => 'Tu coach está preparando tu rutina',
        'done' => '¡Tu rutina está lista!',
        'rejected' => 'No se pudo atender',
        'cancelled' => 'Cancelada',
        _ => status,
      };

  factory RoutineRequest.fromMap(Map<String, dynamic> m) => RoutineRequest(
        id: m['id'] as String,
        goal: m['goal'] as String,
        daysPerWeek: m['days_per_week'] as int?,
        level: m['level'] as String?,
        notes: m['notes'] as String?,
        preferredCoachId: m['preferred_coach_id'] as String?,
        status: m['status'] as String,
        response: m['response'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        updatedAt: m['updated_at'] == null
            ? null
            : DateTime.parse(m['updated_at'] as String).toLocal(),
      );
}
