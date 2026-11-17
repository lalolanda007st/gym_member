class ActivityDay {
  const ActivityDay({
    required this.date,
    this.calories = 0,
    this.minutes = 0,
    this.steps = 0,
    this.sessions = 0,
    this.avgHeartRate,
  });

  final DateTime date;
  final int calories;
  final int minutes;
  final int steps;
  final int sessions;
  final int? avgHeartRate;

  /// Inicial del día de la semana en español: L M X J V S D
  String get weekdayLetter =>
      const ['L', 'M', 'X', 'J', 'V', 'S', 'D'][date.weekday - 1];
}

class ActivitySummary {
  const ActivitySummary({required this.days, this.isDemo = false});

  /// Siempre 7 días, del más antiguo al más reciente (hoy al final).
  final List<ActivityDay> days;

  /// true = datos de ejemplo para mostrar cómo se verá con el reloj.
  final bool isDemo;

  bool get hasData =>
      days.any((d) => d.sessions > 0 || d.steps > 0 || d.calories > 0);

  int get totalCalories => days.fold<int>(0, (s, d) => s + d.calories);
  int get totalMinutes => days.fold<int>(0, (s, d) => s + d.minutes);
  int get totalSteps => days.fold<int>(0, (s, d) => s + d.steps);
  int get totalSessions => days.fold<int>(0, (s, d) => s + d.sessions);

  int? get avgHeartRate {
    final values = days.map((d) => d.avgHeartRate).whereType<int>().toList();
    if (values.isEmpty) return null;
    return (values.reduce((a, b) => a + b) / values.length).round();
  }

  /// Vista previa con valores inventados, marcada como ejemplo en la UI.
  static ActivitySummary demo() {
    final today = DateTime.now();
    const calories = [320, 140, 410, 280, 120, 520, 360];
    const minutes = [45, 0, 60, 40, 0, 75, 50];
    const steps = [8400, 5200, 10300, 7600, 4100, 12800, 9100];
    const hr = [132, null, 138, 129, null, 145, 135];
    return ActivitySummary(
      isDemo: true,
      days: [
        for (var i = 0; i < 7; i++)
          ActivityDay(
            date: DateTime(today.year, today.month, today.day)
                .subtract(Duration(days: 6 - i)),
            calories: calories[i],
            minutes: minutes[i],
            steps: steps[i],
            sessions: minutes[i] > 0 ? 1 : 0,
            avgHeartRate: hr[i],
          ),
      ],
    );
  }
}
