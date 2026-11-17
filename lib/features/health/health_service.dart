import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';

/// Estado de la conexión con los datos de salud del móvil.
enum HealthStatus {
  /// Escritorio / web: no hay datos de salud.
  unsupported,

  /// Android sin Health Connect instalado o desactualizado.
  needsInstall,

  /// Disponible pero el cliente no ha dado permiso.
  disconnected,

  /// Permisos concedidos: se puede sincronizar.
  connected,
}

class DailyHealth {
  const DailyHealth({
    required this.date,
    this.steps,
    this.activeCalories,
    this.avgHeartRate,
    this.restingHeartRate,
  });

  final DateTime date;
  final int? steps;
  final int? activeCalories;
  final int? avgHeartRate;
  final int? restingHeartRate;

  bool get isEmpty =>
      steps == null &&
      activeCalories == null &&
      avgHeartRate == null &&
      restingHeartRate == null;
}

class WindowHealth {
  const WindowHealth({this.calories, this.avgHeartRate, this.maxHeartRate});
  final int? calories;
  final int? avgHeartRate;
  final int? maxHeartRate;

  bool get isEmpty =>
      calories == null && avgHeartRate == null && maxHeartRate == null;
}

/// Lee pasos, calorías y pulsaciones de Health Connect (Android) o
/// HealthKit (iOS). El reloj escribe ahí a través de su propia app
/// (Samsung Health, Mi Fitness, Zepp, Garmin Connect, Fitbit…).
class HealthService {
  final Health _health = Health();
  bool _configured = false;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
  ];
  static final _permissions =
      _types.map((_) => HealthDataAccess.READ).toList();

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<HealthStatus> status() async {
    if (!isSupported) return HealthStatus.unsupported;
    await _ensureConfigured();
    if (Platform.isAndroid) {
      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk != HealthConnectSdkStatus.sdkAvailable) {
        return HealthStatus.needsInstall;
      }
    }
    final granted =
        await _health.hasPermissions(_types, permissions: _permissions);
    return granted == true ? HealthStatus.connected : HealthStatus.disconnected;
  }

  /// Abre Play Store para instalar/actualizar Health Connect.
  Future<void> installHealthConnect() async {
    await _ensureConfigured();
    await _health.installHealthConnect();
  }

  /// Muestra la pantalla del sistema para conceder permisos.
  Future<bool> connect() async {
    if (!isSupported) return false;
    await _ensureConfigured();
    return _health.requestAuthorization(_types, permissions: _permissions);
  }

  /// Resumen por día de los últimos [days] días (hoy incluido).
  Future<List<DailyHealth>> readDaily({int days = 7}) async {
    await _ensureConfigured();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = <DailyHealth>[];

    for (var i = days - 1; i >= 0; i--) {
      final start = today.subtract(Duration(days: i));
      final end = i == 0 ? now : start.add(const Duration(days: 1));

      int? steps;
      try {
        steps = await _health.getTotalStepsInInterval(start, end);
      } catch (_) {}

      final points = await _read(
        [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.HEART_RATE,
          HealthDataType.RESTING_HEART_RATE,
        ],
        start,
        end,
      );

      final calories = _sum(points, HealthDataType.ACTIVE_ENERGY_BURNED);
      final hr = _values(points, HealthDataType.HEART_RATE);
      final resting = _values(points, HealthDataType.RESTING_HEART_RATE);

      result.add(DailyHealth(
        date: start,
        steps: (steps == null || steps == 0) ? null : steps,
        activeCalories: calories == null || calories == 0 ? null : calories.round(),
        avgHeartRate: hr.isEmpty ? null : _avg(hr),
        restingHeartRate: resting.isEmpty ? null : _avg(resting),
      ));
    }
    return result;
  }

  /// Calorías y pulsaciones entre dos instantes (la duración de un entreno).
  Future<WindowHealth> readWindow(DateTime start, DateTime end) async {
    await _ensureConfigured();
    final points = await _read(
      [HealthDataType.ACTIVE_ENERGY_BURNED, HealthDataType.HEART_RATE],
      start,
      end,
    );
    final calories = _sum(points, HealthDataType.ACTIVE_ENERGY_BURNED);
    final hr = _values(points, HealthDataType.HEART_RATE);
    return WindowHealth(
      calories: calories == null || calories == 0 ? null : calories.round(),
      avgHeartRate: hr.isEmpty ? null : _avg(hr),
      maxHeartRate:
          hr.isEmpty ? null : hr.reduce((a, b) => a > b ? a : b).round(),
    );
  }

  // ---------------------------------------------------------------------
  Future<List<HealthDataPoint>> _read(
      List<HealthDataType> types, DateTime start, DateTime end) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: types,
        startTime: start,
        endTime: end,
      );
      return _health.removeDuplicates(points);
    } catch (_) {
      return const [];
    }
  }

  static List<double> _values(List<HealthDataPoint> points, HealthDataType t) {
    return [
      for (final p in points)
        if (p.type == t && p.value is NumericHealthValue)
          (p.value as NumericHealthValue).numericValue.toDouble(),
    ];
  }

  static double? _sum(List<HealthDataPoint> points, HealthDataType t) {
    final v = _values(points, t);
    if (v.isEmpty) return null;
    return v.fold<double>(0, (a, b) => a + b);
  }

  static int _avg(List<double> v) =>
      (v.fold<double>(0, (a, b) => a + b) / v.length).round();
}
