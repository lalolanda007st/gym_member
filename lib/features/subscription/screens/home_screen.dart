import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors.dart';
import '../../../core/muscle_style.dart';
import '../../activity/providers/activity_providers.dart';
import '../../activity/widgets/activity_section.dart';
import '../../auth/providers/auth_providers.dart';
import '../../member/providers/member_providers.dart';
import '../../realtime/member_realtime.dart';
import '../../routines/models/routine.dart';
import '../../routines/providers/routine_providers.dart';
import '../../routines/screens/my_routine_editor_screen.dart';
import '../../routines/screens/routine_detail_screen.dart';
import '../../requests/models/routine_request.dart';
import '../../requests/providers/request_providers.dart';
import '../../requests/screens/request_routine_screen.dart';
import '../../workout/providers/workout_providers.dart';
import '../../workout/screens/workout_history_screen.dart';
import '../../nutrition/providers/meal_plan_providers.dart';
import '../../nutrition/screens/meal_plan_screen.dart';
import '../models/subscription.dart';
import '../providers/subscription_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(memberRealtimeProvider); // recarga sola cuando el gimnasio cambia algo
    final theme = Theme.of(context);
    final member = ref.watch(myMemberProvider).value;
    final current = ref.watch(currentSubscriptionProvider);
    final history = ref.watch(mySubscriptionsProvider);
    final routines = ref.watch(myRoutinesProvider);
    final firstName = (member?.name ?? '').split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myRoutinesProvider);
            ref.invalidate(weeklyActivityProvider);
            ref.invalidate(workoutHistoryProvider);
            ref.invalidate(latestRequestProvider);
            ref.invalidate(myMealPlanProvider);
            await ref.refresh(mySubscriptionsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // ---------- Saludo ----------
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(),
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        Text(firstName.isEmpty ? 'Bienvenido' : firstName,
                            style: theme.textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout),
                    onPressed: () => _confirmLogout(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ---------- Membresía ----------
              current.when(
                loading: () => const _CardSkeleton(),
                error: (e, _) =>
                    _MessageCard(icon: Icons.cloud_off, text: friendlyError(e)),
                data: (s) => s == null
                    ? const _MessageCard(
                        icon: Icons.info_outline,
                        text: 'Aún no tienes ninguna suscripción registrada. '
                            'Pásate por recepción.',
                      )
                    : MembershipCard(
                        subscription: s, memberName: member?.name ?? ''),
              ),
              const SizedBox(height: 28),

              // ---------- Rutinas ----------
              _SectionTitle(
                icon: Icons.list_alt,
                title: 'Mis rutinas',
                trailing: routines.value?.isNotEmpty == true
                    ? '${routines.value!.length}'
                    : null,
              ),
              const SizedBox(height: 12),
              routines.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) =>
                    _MessageCard(icon: Icons.cloud_off, text: friendlyError(e)),
                data: (list) => list.isEmpty
                    ? const _MessageCard(
                        icon: Icons.sports,
                        text: 'Aún no tienes rutinas. Crea la tuya o pídele '
                            'una a tu coach.',
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < list.length; i++)
                            _RoutineCard(routine: list[i], colorIndex: i),
                        ],
                      ),
              ),
              const _RequestStatusCard(),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46)),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Crear mi rutina'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const MyRoutineEditorScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(46)),
                      icon: const Icon(Icons.support_agent),
                      label: const Text('Pedir al coach'),
                      onPressed: () {
                        final open =
                            ref.read(latestRequestProvider).value?.isOpen ??
                                false;
                        if (open) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Ya tienes una solicitud en '
                                    'curso. Puedes cancelarla si quieres '
                                    'pedir otra.')),
                          );
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const RequestRoutineScreen()));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ---------- Mis entrenos ----------
              const _LastWorkoutCard(),
              const SizedBox(height: 12),
              const _MealPlanCard(),
              const SizedBox(height: 28),

              // ---------- Actividad (reloj) ----------
              const ActivitySection(),
              const SizedBox(height: 20),

              // ---------- Historial ----------
              history.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (subs) => subs.isEmpty
                    ? const SizedBox.shrink()
                    : Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          leading: const Icon(Icons.history),
                          title: const Text('Historial de suscripciones'),
                          subtitle: Text('${subs.length} registradas'),
                          shape: const Border(),
                          children: subs.map((s) => _HistoryTile(s)).toList(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok == true) await ref.read(authRepositoryProvider).signOut();
  }
}

// =====================================================================
// Tarjeta de membresía
// =====================================================================
class MembershipCard extends StatelessWidget {
  const MembershipCard({
    super.key,
    required this.subscription,
    required this.memberName,
  });

  final Subscription subscription;
  final String memberName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = subscription;
    final fmt = DateFormat.yMMMd('es');

    final (List<Color> colors, String label) = !s.isActive
        ? (const [Color(0xFFB71C1C), Color(0xFFE53935)], 'VENCIDA')
        : s.isExpiringSoon
            ? (const [Color(0xFFE65100), Color(0xFFFFA000)], 'POR VENCER')
            : (const [Color(0xFF1B5E20), Color(0xFF43A047)], 'ACTIVA');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -30,
            child: Icon(Icons.fitness_center,
                size: 130, color: Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_membership, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.planType.isEmpty ? 'Membresía' : s.planType,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(label,
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${s.daysRemaining}',
                        style: theme.textTheme.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            height: 1)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        s.daysRemaining == 1 ? 'día restante' : 'días restantes',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: s.remainingFraction,
                    minHeight: 8,
                    color: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                const SizedBox(height: 14),
                DefaultTextStyle(
                  style: theme.textTheme.bodySmall!
                      .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(memberName,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('Vence ${fmt.format(s.endDate)}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Tarjeta de rutina
// =====================================================================
class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine, required this.colorIndex});
  final Routine routine;
  final int colorIndex;

  static const _palettes = [
    [Color(0xFFE65100), Color(0xFFFF8F00)],
    [Color(0xFF283593), Color(0xFF5C6BC0)],
    [Color(0xFF00695C), Color(0xFF26A69A)],
    [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _palettes[colorIndex % _palettes.length];
    final days = routine.dayLabels.length;
    final count = routine.exercises.length;
    final muscles = <String?>{
      for (final e in routine.exercises) e.muscleGroup
    }.take(5).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RoutineDetailScreen(routine: routine),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (routine.isMine)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('CREADA POR TI',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1)),
                          ),
                        Text(routine.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          '$days ${days == 1 ? 'día' : 'días'} · '
                          '$count ${count == 1 ? 'ejercicio' : 'ejercicios'}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            for (final m in muscles)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Tooltip(
                                  message: MuscleStyle.of(m).label,
                                  child: CircleAvatar(
                                    radius: 15,
                                    backgroundColor:
                                        Colors.white.withValues(alpha: 0.2),
                                    child: Icon(MuscleStyle.of(m).icon,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Estado de la solicitud de rutina
// =====================================================================
class _RequestStatusCard extends ConsumerWidget {
  const _RequestStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final req = ref.watch(latestRequestProvider).value;
    if (req == null) return const SizedBox.shrink();

    // Las ya resueltas solo se muestran durante 7 días
    final resolvedAt = req.updatedAt ?? req.createdAt;
    if (!req.isOpen && DateTime.now().difference(resolvedAt).inDays > 7) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final coaches = ref.watch(coachesProvider).value ?? const [];
    String? coachName;
    for (final c in coaches) {
      if (c.id == req.preferredCoachId) coachName = c.name;
    }
    final (Color bg, Color fg, IconData icon) = switch (req.status) {
      'done' => (const Color(0xFFE8F5E9), const Color(0xFF1B5E20),
          Icons.check_circle),
      'rejected' => (theme.colorScheme.errorContainer,
          theme.colorScheme.onErrorContainer, Icons.info_outline),
      'in_progress' => (const Color(0xFFE3F2FD), const Color(0xFF0D47A1),
          Icons.edit_calendar),
      _ => (const Color(0xFFFFF3E0), const Color(0xFF8D4E00),
          Icons.hourglass_top),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.statusLabel,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: fg, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  '${req.goalLabel} · ${req.daysPerWeek ?? '?'} días/semana'
                  '${req.levelLabel != null ? ' · ${req.levelLabel}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
                if (coachName != null)
                  Text('Con: $coachName',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
                if (req.response?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text('Coach: "${req.response}"',
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: fg, fontStyle: FontStyle.italic)),
                ],
              ],
            ),
          ),
          if (req.status == 'pending')
            TextButton(
              style: TextButton.styleFrom(foregroundColor: fg),
              onPressed: () => _cancel(context, ref, req),
              child: const Text('Cancelar'),
            ),
        ],
      ),
    );
  }

  Future<void> _cancel(
      BuildContext context, WidgetRef ref, RoutineRequest req) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar la solicitud?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(requestRepositoryProvider).cancel(req.id);
      ref.invalidate(latestRequestProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

// =====================================================================
// Acceso al historial de entrenos
// =====================================================================
class _LastWorkoutCard extends ConsumerWidget {
  const _LastWorkoutCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(workoutHistoryProvider).value ?? const [];
    final last = history.isEmpty ? null : history.first;

    String subtitle;
    if (last == null) {
      subtitle = 'Abre una rutina y pulsa "Empezar" para registrar tu entreno';
    } else {
      final days = DateTime.now()
          .difference(DateTime(last.date.year, last.date.month, last.date.day))
          .inDays;
      final when = days <= 0
          ? 'hoy'
          : days == 1
              ? 'ayer'
              : 'hace $days días';
      subtitle = 'Último: $when · ${last.totalSets} series'
          '${last.durationMinutes != null ? ' · ${last.durationMinutes} min' : ''}';
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary,
          child: Icon(Icons.history, color: theme.colorScheme.onSecondary),
        ),
        title: Text(
          history.isEmpty
              ? 'Mis entrenos'
              : 'Mis entrenos (${history.length})',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSecondaryContainer),
        ),
        subtitle: Text(subtitle,
            style: TextStyle(color: theme.colorScheme.onSecondaryContainer)),
        trailing: Icon(Icons.chevron_right,
            color: theme.colorScheme.onSecondaryContainer),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WorkoutHistoryScreen()),
        ),
      ),
    );
  }
}

// =====================================================================
// Acceso al plan de alimentación
// =====================================================================
class _MealPlanCard extends ConsumerWidget {
  const _MealPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final planAsync = ref.watch(myMealPlanProvider);
    final plan = planAsync.value;

    final subtitle = planAsync.isLoading
        ? 'Cargando...'
        : plan == null
            ? 'Tu coach aún no te ha asignado un plan'
            : '${plan.mealLabels.length} '
                '${plan.mealLabels.length == 1 ? 'comida' : 'comidas'} · '
                '${plan.items.length} '
                '${plan.items.length == 1 ? 'alimento' : 'alimentos'}';

    return Card(
      elevation: 0,
      color: theme.colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.tertiary,
          child: Icon(Icons.restaurant_menu,
              color: theme.colorScheme.onTertiary),
        ),
        title: Text(
          'Plan de alimentación',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onTertiaryContainer),
        ),
        subtitle: Text(subtitle,
            style: TextStyle(color: theme.colorScheme.onTertiaryContainer)),
        trailing: Icon(Icons.chevron_right,
            color: theme.colorScheme.onTertiaryContainer),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MealPlanScreen()),
        ),
      ),
    );
  }
}

// =====================================================================
// Auxiliares
// =====================================================================
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(trailing!,
                style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile(this.s);
  final Subscription s;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd('es');
    return ListTile(
      leading: Icon(
        s.isActive ? Icons.check_circle : Icons.history,
        color: s.isActive ? Colors.green : null,
      ),
      title: Text(s.planType.isEmpty ? 'Suscripción' : s.planType),
      subtitle: Text('${fmt.format(s.startDate)} – ${fmt.format(s.endDate)}'),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 200,
        child: Card(child: Center(child: CircularProgressIndicator())),
      );
}
