import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

/// Sesión actual; se actualiza con login, logout y refresco de token.
final sessionProvider = StreamProvider<Session?>((ref) async* {
  final repo = ref.watch(authRepositoryProvider);
  yield repo.currentSession;
  await for (final state in repo.authStateChanges()) {
    yield state.session;
  }
});

/// id del usuario autenticado (null si no hay sesión).
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider).value?.user.id;
});
