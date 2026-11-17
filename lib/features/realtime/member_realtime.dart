import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/providers/auth_providers.dart';
import '../member/providers/member_providers.dart';
import '../requests/providers/request_providers.dart';
import '../routines/providers/routine_providers.dart';
import '../subscription/providers/subscription_providers.dart';

/// Escucha en tiempo real los cambios que hace el gimnasio para este
/// cliente (rutinas, solicitudes, membresía) y recarga esas secciones.
///
/// Basta con hacer `ref.watch(memberRealtimeProvider)` en el inicio.
/// Nota: Supabase solo envía cambios de filas que el cliente puede ver,
/// así que desactivar o borrar una rutina se refleja al recargar.
final memberRealtimeProvider = Provider<void>((ref) {
  final member = ref.watch(myMemberProvider).value;
  if (member == null) return;
  final client = ref.watch(supabaseClientProvider);

  // Agrupa ráfagas de cambios (p. ej. rutina + sus ejercicios) en una recarga
  final timers = <String, Timer>{};
  void later(String key, void Function() action) {
    timers[key]?.cancel();
    timers[key] = Timer(const Duration(milliseconds: 1200), action);
  }

  PostgresChangeFilter byMember() => PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'member_id',
        value: member.id,
      );

  final channel = client
      .channel('member-${member.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'routines',
        filter: byMember(),
        callback: (_) =>
            later('routines', () => ref.invalidate(myRoutinesProvider)),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'routine_requests',
        filter: byMember(),
        callback: (_) => later('requests', () {
          ref.invalidate(latestRequestProvider);
          ref.invalidate(myRoutinesProvider);
        }),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'subscriptions',
        filter: byMember(),
        callback: (_) =>
            later('subs', () => ref.invalidate(mySubscriptionsProvider)),
      )
      .subscribe();

  ref.onDispose(() {
    for (final t in timers.values) {
      t.cancel();
    }
    client.removeChannel(channel);
  });
});
