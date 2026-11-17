import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/routine_repository.dart';
import '../models/routine.dart';

final routineRepositoryProvider = Provider((ref) => RoutineRepository());

/// Rutinas de un cliente. Uso: ref.watch(memberRoutinesProvider(memberId))
final memberRoutinesProvider =
    FutureProvider.family<List<Routine>, String>((ref, memberId) {
  return ref.watch(routineRepositoryProvider).getRoutinesForMember(memberId);
});

/// Todas las rutinas (pestaña Rutinas).
final allRoutinesProvider = FutureProvider<List<Routine>>((ref) {
  return ref.watch(routineRepositoryProvider).getAllRoutines();
});

/// id -> nombre de admins y coaches.
final coachNamesProvider = FutureProvider<Map<String, String>>((ref) {
  return ref.watch(routineRepositoryProvider).getCoachNames();
});
