import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/member_repository.dart';
import '../models/member.dart';

final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(ref.watch(supabaseClientProvider)),
);

/// Se recalcula al cambiar de usuario (login / logout).
final myMemberProvider = FutureProvider<Member?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(memberRepositoryProvider).fetchMyMember(userId);
});
