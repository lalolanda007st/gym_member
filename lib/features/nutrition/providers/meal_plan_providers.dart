import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../member/providers/member_providers.dart';
import '../data/meal_plan_repository.dart';
import '../models/meal_plan.dart';

final mealPlanRepositoryProvider = Provider<MealPlanRepository>(
  (ref) => MealPlanRepository(ref.watch(supabaseClientProvider)),
);

/// Plan de alimentación activo del miembro actual (null = aún no tiene).
final myMealPlanProvider = FutureProvider<MealPlan?>((ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return null;
  return ref.watch(mealPlanRepositoryProvider).fetchActiveForMember(member.id);
});
