import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../member/providers/member_providers.dart';
import '../data/activity_repository.dart';
import '../models/activity.dart';

final activityRepositoryProvider = Provider<ActivityRepository>(
  (ref) => ActivityRepository(ref.watch(supabaseClientProvider)),
);

final weeklyActivityProvider = FutureProvider<ActivitySummary>((ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return ActivitySummary.demo();
  return ref.watch(activityRepositoryProvider).fetchLast7Days(member.id);
});
