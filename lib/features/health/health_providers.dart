import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../activity/providers/activity_providers.dart';
import '../auth/providers/auth_providers.dart';
import '../member/providers/member_providers.dart';
import '../workout/providers/workout_providers.dart';
import 'health_service.dart';
import 'health_sync_repository.dart';

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());

final healthSyncRepositoryProvider = Provider<HealthSyncRepository>(
  (ref) => HealthSyncRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(healthServiceProvider),
  ),
);

final healthStatusProvider = FutureProvider<HealthStatus>((ref) {
  return ref.watch(healthServiceProvider).status();
});

/// Hora de la última sincronización correcta (null = nunca en esta sesión).
final lastHealthSyncProvider =
    NotifierProvider<LastHealthSync, DateTime?>(LastHealthSync.new);

class LastHealthSync extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void set(DateTime value) => state = value;
}

/// Sincroniza si hay permisos. Se ejecuta al abrir el inicio y al pulsar
/// "Sincronizar". Nunca lanza: un fallo del reloj no debe romper la app.
final healthAutoSyncProvider = FutureProvider<void>((ref) async {
  final status = await ref.watch(healthStatusProvider.future);
  if (status != HealthStatus.connected) return;
  final member = await ref.watch(myMemberProvider.future);
  if (member == null) return;
  try {
    await ref.read(healthSyncRepositoryProvider).syncAll(member.id);
    ref.read(lastHealthSyncProvider.notifier).set(DateTime.now());
    ref.invalidate(weeklyActivityProvider);
    ref.invalidate(workoutHistoryProvider);
  } catch (_) {
    // Sin conexión o permisos revocados: se reintentará en la próxima apertura
  }
});
