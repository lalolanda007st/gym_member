class Subscription {
  const Subscription({
    required this.id,
    required this.planType,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String id;
  final String planType;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  factory Subscription.fromMap(Map<String, dynamic> m) => Subscription(
        id: m['id'] as String,
        planType: (m['plan_type'] as String?) ?? '',
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: DateTime.parse(m['end_date'] as String),
        status: (m['status'] as String?) ?? '',
      );

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Días que quedan incluyendo hoy (0 si ya venció).
  int get daysRemaining {
    final diff = endDate.difference(_today()).inDays + 1;
    return diff < 0 ? 0 : diff;
  }

  int get totalDays => endDate.difference(startDate).inDays + 1;

  /// 0.0 – 1.0, cuánto del periodo queda.
  double get remainingFraction =>
      totalDays <= 0 ? 0 : (daysRemaining / totalDays).clamp(0.0, 1.0);

  /// Se calcula por fechas para no depender de que 'status' esté al día.
  bool get isActive =>
      !endDate.isBefore(_today()) && status.toLowerCase() != 'cancelled';

  bool get isExpiringSoon => isActive && daysRemaining <= 7;
}
