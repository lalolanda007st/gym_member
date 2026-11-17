import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../member/providers/member_providers.dart';
import '../data/workout_repository.dart';
import '../models/workout.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepository(ref.watch(supabaseClientProvider)),
);

final workoutHistoryProvider =
    FutureProvider<List<WorkoutRecord>>((ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return const [];
  return ref.watch(workoutRepositoryProvider).fetchHistory(member.id);
});
