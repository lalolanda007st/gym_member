import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../member/providers/member_providers.dart';
import '../data/request_repository.dart';
import '../models/routine_request.dart';

final requestRepositoryProvider = Provider<RequestRepository>(
  (ref) => RequestRepository(ref.watch(supabaseClientProvider)),
);

final latestRequestProvider = FutureProvider<RoutineRequest?>((ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return null;
  return ref.watch(requestRepositoryProvider).fetchLatest(member.id);
});

final coachesProvider = FutureProvider<List<Coach>>((ref) {
  return ref.watch(requestRepositoryProvider).fetchCoaches();
});
