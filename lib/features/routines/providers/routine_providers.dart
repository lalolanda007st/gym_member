import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../member/providers/member_providers.dart';
import '../data/routine_repository.dart';
import '../models/routine.dart';

final routineRepositoryProvider = Provider<RoutineRepository>(
  (ref) => RoutineRepository(ref.watch(supabaseClientProvider)),
);

final myRoutinesProvider = FutureProvider<List<Routine>>((ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return const [];
  return ref.watch(routineRepositoryProvider).fetchActiveForMember(member.id);
});
