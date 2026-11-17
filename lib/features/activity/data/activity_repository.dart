import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity.dart';

class ActivityRepository {
  ActivityRepository(this._client);
  final SupabaseClient _client;

  /// Combina, por día, los entrenos registrados (minutos, calorías y FC
  /// del entreno) con la actividad diaria del reloj (pasos, calorías activas).
  Future<ActivitySummary> fetchLast7Days(String memberId) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));

    final sessionsF = _client
        .from('workout_sessions')
        .select('date, duration_minutes, calories, avg_heart_rate')
        .eq('member_id', memberId)
        .gte('date', _ymd(start))
        .order('date');

    final dailyF = _client
        .from('daily_activity')
        .select('date, steps, active_calories, avg_heart_rate')
        .eq('member_id', memberId)
        .gte('date', _ymd(start));

    final sessions = await sessionsF;
    final daily = await dailyF;

    final sessionsByDay = <String, List<Map<String, dynamic>>>{};
    for (final r in sessions) {
      final key = (r['date'] as String).substring(0, 10);
      sessionsByDay.putIfAbsent(key, () => []).add(r);
    }
    final dailyByDay = <String, Map<String, dynamic>>{
      for (final r in daily) (r['date'] as String).substring(0, 10): r,
    };

    final days = <ActivityDay>[];
    for (var i = 0; i < 7; i++) {
      final date = start.add(Duration(days: i));
      final key = _ymd(date);
      final list = sessionsByDay[key] ?? const [];
      final d = dailyByDay[key];

      final sessionCalories =
          list.fold<int>(0, (s, r) => s + ((r['calories'] as int?) ?? 0));
      final dailyCalories = (d?['active_calories'] as int?) ?? 0;

      final hrs = [
        ...list.map((r) => r['avg_heart_rate'] as int?).whereType<int>(),
      ];
      final dailyHr = d?['avg_heart_rate'] as int?;

      days.add(ActivityDay(
        date: date,
        sessions: list.length,
        minutes:
            list.fold<int>(0, (s, r) => s + ((r['duration_minutes'] as int?) ?? 0)),
        // Las calorías del día (reloj) ya incluyen las del entreno
        calories: dailyCalories > 0 ? dailyCalories : sessionCalories,
        steps: (d?['steps'] as int?) ?? 0,
        avgHeartRate: hrs.isNotEmpty
            ? (hrs.reduce((a, b) => a + b) / hrs.length).round()
            : dailyHr,
      ));
    }
    return ActivitySummary(days: days);
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
