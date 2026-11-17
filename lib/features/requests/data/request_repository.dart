import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/routine_request.dart';

class RequestRepository {
  RequestRepository(this._client);
  final SupabaseClient _client;

  /// Última solicitud que no fue cancelada por el propio cliente.
  Future<RoutineRequest?> fetchLatest(String memberId) async {
    final row = await _client
        .from('routine_requests')
        .select()
        .eq('member_id', memberId)
        .neq('status', 'cancelled')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : RoutineRequest.fromMap(row);
  }

  Future<void> create({
    required String memberId,
    required String goal,
    required int daysPerWeek,
    required String level,
    String? notes,
    String? preferredCoachId,
  }) async {
    try {
      await _client.from('routine_requests').insert({
        'member_id': memberId,
        'goal': goal,
        'days_per_week': daysPerWeek,
        'level': level,
        'notes': notes,
        'preferred_coach_id': preferredCoachId,
      });
    } on PostgrestException catch (e) {
      // Índice único: ya hay una solicitud abierta
      if (e.code == '23505') {
        throw Exception('Ya tienes una solicitud en curso. '
            'Espera a que tu coach la atienda o cancélala.');
      }
      rethrow;
    }
  }

  /// Coaches (y admins) disponibles para elegir.
  Future<List<Coach>> fetchCoaches() async {
    final rows = await _client.rpc('list_coaches') as List;
    return [
      for (final r in rows)
        Coach(
          id: (r as Map<String, dynamic>)['id'] as String,
          name: (r['full_name'] as String?) ?? 'Coach',
          role: (r['role'] as String?) ?? 'coach',
        ),
    ];
  }

  Future<void> cancel(String requestId) async {
    await _client.from('routine_requests').update({
      'status': 'cancelled',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }
}
