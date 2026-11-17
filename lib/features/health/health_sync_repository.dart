import 'dart:io' show Platform;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'health_service.dart';

/// Sube a Supabase lo que lee [HealthService].
class HealthSyncRepository {
  HealthSyncRepository(this._client, this._health);
  final SupabaseClient _client;
  final HealthService _health;

  String get _source => Platform.isIOS ? 'healthkit' : 'health_connect';

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Sincroniza los últimos 7 días y completa los entrenos recientes
  /// que aún no tengan datos del reloj.
  Future<void> syncAll(String memberId) async {
    final days = await _health.readDaily(days: 7);
    final rows = [
      for (final d in days.where((d) => !d.isEmpty))
        {
          'member_id': memberId,
          'date': _ymd(d.date),
          'steps': d.steps,
          'active_calories': d.activeCalories,
          'avg_heart_rate': d.avgHeartRate,
          'resting_heart_rate': d.restingHeartRate,
          'source': _source,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
    ];
    if (rows.isNotEmpty) {
      await _client
          .from('daily_activity')
          .upsert(rows, onConflict: 'member_id,date');
    }
    await _backfillSessions(memberId);
  }

  /// Entrenos de los últimos 7 días sin pulsaciones: el reloj a veces
  /// sincroniza con retraso, así que lo reintentamos en cada sincronización.
  Future<void> _backfillSessions(String memberId) async {
    final since = DateTime.now().subtract(const Duration(days: 7));
    final sessions = await _client
        .from('workout_sessions')
        .select('id, started_at, finished_at')
        .eq('member_id', memberId)
        .isFilter('avg_heart_rate', null)
        .not('started_at', 'is', null)
        .not('finished_at', 'is', null)
        .gte('date', _ymd(since));

    for (final s in sessions) {
      await enrichSession(
        s['id'] as String,
        DateTime.parse(s['started_at'] as String),
        DateTime.parse(s['finished_at'] as String),
      );
    }
  }

  /// Añade calorías y pulsaciones del reloj a un entreno guardado.
  /// Devuelve true si encontró datos.
  Future<bool> enrichSession(
      String sessionId, DateTime startedAt, DateTime finishedAt) async {
    final w = await _health.readWindow(startedAt.toLocal(), finishedAt.toLocal());
    if (w.isEmpty) return false;
    await _client.from('workout_sessions').update({
      if (w.calories != null) 'calories': w.calories,
      if (w.avgHeartRate != null) 'avg_heart_rate': w.avgHeartRate,
      if (w.maxHeartRate != null) 'max_heart_rate': w.maxHeartRate,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', sessionId);
    return true;
  }
}
