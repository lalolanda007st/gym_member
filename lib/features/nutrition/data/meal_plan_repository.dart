import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal_plan.dart';

/// Lado del miembro: solo lectura de su plan de alimentación activo.
class MealPlanRepository {
  MealPlanRepository(this._client);
  final SupabaseClient _client;

  /// Plan activo del miembro, o null si el coach aún no le asignó uno.
  Future<MealPlan?> fetchActiveForMember(String memberId) async {
    final rows = await _client
        .from('meal_plans')
        .select(
          'id, member_id, coach_id, name, notes, active, created_at, updated_at, '
          'meal_plan_items(id, meal_label, food_name, quantity, unit, notes, position)',
        )
        .eq('member_id', memberId)
        .eq('active', true)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return MealPlan.fromMap(rows.first);
  }
}
