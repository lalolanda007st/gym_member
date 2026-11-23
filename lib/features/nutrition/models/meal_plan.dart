/// Un alimento con su porción dentro de una comida del plan
/// (Desayuno, Comida, Cena, Snack...).
class MealPlanItem {
  const MealPlanItem({
    this.id,
    required this.mealLabel,
    required this.foodName,
    this.quantity,
    this.unit,
    this.notes,
    this.position = 0,
  });

  final String? id;
  final String mealLabel;
  final String foodName;
  final double? quantity;
  final String? unit;
  final String? notes;
  final int position;

  /// Ej: "150 g" o "1 taza". Vacío si no se especificó cantidad ni unidad.
  String get portionLabel {
    if (quantity == null) return unit ?? '';
    final q = quantity! % 1 == 0
        ? quantity!.toStringAsFixed(0)
        : quantity!.toString();
    return (unit == null || unit!.isEmpty) ? q : '$q $unit';
  }

  factory MealPlanItem.fromMap(Map<String, dynamic> m) => MealPlanItem(
        id: m['id'] as String?,
        mealLabel: m['meal_label'] as String,
        foodName: m['food_name'] as String,
        quantity: (m['quantity'] as num?)?.toDouble(),
        unit: m['unit'] as String?,
        notes: m['notes'] as String?,
        position: m['position'] as int? ?? 0,
      );

  Map<String, dynamic> toInsertMap(String mealPlanId) => {
        'meal_plan_id': mealPlanId,
        'meal_label': mealLabel,
        'food_name': foodName,
        'quantity': quantity,
        'unit': unit,
        'notes': notes,
        'position': position,
      };

  MealPlanItem copyWith({
    String? mealLabel,
    String? foodName,
    double? quantity,
    bool clearQuantity = false,
    String? unit,
    bool clearUnit = false,
    String? notes,
    int? position,
  }) =>
      MealPlanItem(
        id: id,
        mealLabel: mealLabel ?? this.mealLabel,
        foodName: foodName ?? this.foodName,
        quantity: clearQuantity ? null : (quantity ?? this.quantity),
        unit: clearUnit ? null : (unit ?? this.unit),
        notes: notes ?? this.notes,
        position: position ?? this.position,
      );
}

/// Plan de alimentación que un coach deja a un miembro: desayuno, comida,
/// cena (y lo que se agregue) con alimentos y porciones.
class MealPlan {
  const MealPlan({
    this.id,
    required this.memberId,
    this.coachId,
    required this.name,
    this.notes,
    this.active = true,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  final String? id;
  final String memberId;
  final String? coachId;
  final String name;
  final String? notes;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MealPlanItem> items;

  /// Nombres de comida en el orden en que aparecen (sin repetir).
  List<String> get mealLabels {
    final seen = <String>[];
    for (final i in items) {
      if (!seen.contains(i.mealLabel)) seen.add(i.mealLabel);
    }
    return seen;
  }

  List<MealPlanItem> itemsForMeal(String label) =>
      items.where((i) => i.mealLabel == label).toList()
        ..sort((a, b) => a.position.compareTo(b.position));

  factory MealPlan.fromMap(Map<String, dynamic> m) => MealPlan(
        id: m['id'] as String?,
        memberId: m['member_id'] as String,
        coachId: m['coach_id'] as String?,
        name: m['name'] as String,
        notes: m['notes'] as String?,
        active: m['active'] as bool? ?? true,
        createdAt: m['created_at'] == null
            ? null
            : DateTime.parse(m['created_at'] as String),
        updatedAt: m['updated_at'] == null
            ? null
            : DateTime.parse(m['updated_at'] as String),
        items: (m['meal_plan_items'] as List<dynamic>? ?? const [])
            .map((e) => MealPlanItem.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
