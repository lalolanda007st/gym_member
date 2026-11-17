import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../member/providers/member_providers.dart';
import '../data/subscription_repository.dart';
import '../models/subscription.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepository(ref.watch(supabaseClientProvider)),
);

final mySubscriptionsProvider =
    FutureProvider<List<Subscription>>((ref) async {
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return const [];
  return ref.watch(subscriptionRepositoryProvider).fetchForMember(member.id);
});

/// La suscripción vigente; si no hay ninguna, la última vencida (o null).
final currentSubscriptionProvider =
    FutureProvider<Subscription?>((ref) async {
  final subs = await ref.watch(mySubscriptionsProvider.future);
  if (subs.isEmpty) return null;
  return subs.firstWhere((s) => s.isActive, orElse: () => subs.first);
});
