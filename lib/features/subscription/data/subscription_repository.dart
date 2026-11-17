import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subscription.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._client);
  final SupabaseClient _client;

  /// Historial completo del miembro, la más reciente primero.
  /// RLS (subs_self_select) garantiza que solo vea las suyas.
  Future<List<Subscription>> fetchForMember(String memberId) async {
    final rows = await _client
        .from('subscriptions')
        .select('id, plan_type, start_date, end_date, status')
        .eq('member_id', memberId)
        .order('end_date', ascending: false);
    return rows.map(Subscription.fromMap).toList();
  }
}
