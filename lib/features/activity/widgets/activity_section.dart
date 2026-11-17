import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../health/health_providers.dart';
import '../../health/health_service.dart';
import '../models/activity.dart';
import '../providers/activity_providers.dart';

enum _Metric { calories, steps, minutes }

/// Resumen semanal: métricas + gráfica de barras + estado del reloj.
class ActivitySection extends ConsumerStatefulWidget {
  const ActivitySection({super.key});

  @override
  ConsumerState<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends ConsumerState<ActivitySection> {
  _Metric _metric = _Metric.calories;
  bool _busy = false;

  Future<void> _connect(HealthStatus status) async {
    final service = ref.read(healthServiceProvider);
    setState(() => _busy = true);
    try {
      if (status == HealthStatus.needsInstall) {
        await service.installHealthConnect();
      } else {
        final ok = await service.connect();
        if (!ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('No se concedieron los permisos. Puedes '
                  'activarlos en Ajustes → Health Connect.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      ref.invalidate(healthStatusProvider);
      ref.invalidate(healthAutoSyncProvider);
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    ref.invalidate(healthAutoSyncProvider);
    try {
      await ref.read(healthAutoSyncProvider.future);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lanza la sincronización automática al mostrar la sección
    ref.watch(healthAutoSyncProvider);
    final status = ref.watch(healthStatusProvider).value;
    final async = ref.watch(weeklyActivityProvider);

    return async.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildContent(context, ActivitySummary.demo(), status),
      data: (summary) => _buildContent(
        context,
        summary.hasData ? summary : ActivitySummary.demo(),
        status,
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, ActivitySummary s, HealthStatus? status) {
    final theme = Theme.of(context);
    final (Color color, List<int> values) = switch (_metric) {
      _Metric.calories => (
          const Color(0xFFFF6D00),
          [for (final d in s.days) d.calories]
        ),
      _Metric.steps => (
          const Color(0xFF00BFA5),
          [for (final d in s.days) d.steps]
        ),
      _Metric.minutes => (
          const Color(0xFF2979FF),
          [for (final d in s.days) d.minutes]
        ),
    };

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.watch_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Actividad · últimos 7 días',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (s.isDemo)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Ejemplo',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.local_fire_department,
                    color: const Color(0xFFFF6D00),
                    value: _compact(s.totalCalories),
                    unit: 'kcal',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    icon: Icons.directions_walk,
                    color: const Color(0xFF00BFA5),
                    value: _compact(s.totalSteps),
                    unit: 'pasos',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    icon: Icons.timer_outlined,
                    color: const Color(0xFF2979FF),
                    value: '${s.totalMinutes}',
                    unit: 'min',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    icon: Icons.favorite,
                    color: const Color(0xFFE53935),
                    value: s.avgHeartRate?.toString() ?? '—',
                    unit: 'ppm',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Center(
              child: SegmentedButton<_Metric>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _Metric.calories, label: Text('Calorías')),
                  ButtonSegment(value: _Metric.steps, label: Text('Pasos')),
                  ButtonSegment(value: _Metric.minutes, label: Text('Minutos')),
                ],
                selected: {_metric},
                onSelectionChanged: (v) => setState(() => _metric = v.first),
              ),
            ),
            const SizedBox(height: 16),
            _BarChart(
              key: ValueKey(_metric),
              values: values,
              labels: [for (final d in s.days) d.weekdayLetter],
              color: color,
            ),
            const SizedBox(height: 16),
            _WatchStatus(
              status: status,
              busy: _busy,
              lastSync: ref.watch(lastHealthSyncProvider),
              onConnect: () => _connect(status ?? HealthStatus.disconnected),
              onSync: _syncNow,
            ),
          ],
        ),
      ),
    );
  }

  static String _compact(int v) {
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return '$v';
  }
}

/// Franja inferior: conectar reloj / sincronizado / no disponible.
class _WatchStatus extends StatelessWidget {
  const _WatchStatus({
    required this.status,
    required this.busy,
    required this.lastSync,
    required this.onConnect,
    required this.onSync,
  });

  final HealthStatus? status;
  final bool busy;
  final DateTime? lastSync;
  final VoidCallback onConnect;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (IconData icon, String text, String? action, VoidCallback? onTap) =
        switch (status) {
      null => (Icons.watch_outlined, 'Comprobando reloj…', null, null),
      HealthStatus.unsupported => (
          Icons.phone_android,
          'Abre la app en tu móvil para conectar tu reloj.',
          null,
          null
        ),
      HealthStatus.needsInstall => (
          Icons.download,
          'Instala Health Connect para conectar tu reloj.',
          'Instalar',
          onConnect
        ),
      HealthStatus.disconnected => (
          Icons.watch_outlined,
          'Conecta tu reloj para ver calorías, pasos y pulsaciones reales.',
          'Conectar',
          onConnect
        ),
      HealthStatus.connected => (
          Icons.check_circle,
          lastSync == null
              ? 'Reloj conectado'
              : 'Sincronizado a las '
                  '${lastSync!.hour.toString().padLeft(2, '0')}:'
                  '${lastSync!.minute.toString().padLeft(2, '0')}',
          'Sincronizar',
          onSync
        ),
    };

    final connected = status == HealthStatus.connected;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: connected
            ? Colors.green.withValues(alpha: 0.10)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: connected ? Colors.green : null),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          if (action != null)
            busy
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : connected
                    ? TextButton(onPressed: onTap, child: Text(action))
                    : FilledButton.tonal(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Text(unit, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// Gráfica de barras animada hecha con widgets (sin paquetes externos).
class _BarChart extends StatelessWidget {
  const _BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;

  static const _maxBarHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxValue = values.fold<int>(0, (m, v) => v > m ? v : m);
    final lastIndex = values.length - 1; // hoy

    return SizedBox(
      height: _maxBarHeight + 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (values[i] > 0)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                            values[i] >= 1000
                                ? '${(values[i] / 1000).toStringAsFixed(1)}k'
                                : '${values[i]}',
                            style: theme.textTheme.labelSmall),
                      ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: maxValue == 0 ? 0 : values[i] / maxValue,
                      ),
                      duration: Duration(milliseconds: 500 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder: (_, t, __) => Container(
                        height: values[i] == 0 ? 4 : 6 + t * (_maxBarHeight - 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: values[i] == 0
                              ? theme.colorScheme.outlineVariant
                              : null,
                          gradient: values[i] == 0
                              ? null
                              : LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [color.withValues(alpha: 0.55), color],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[i],
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight:
                            i == lastIndex ? FontWeight.bold : FontWeight.normal,
                        color: i == lastIndex ? color : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
