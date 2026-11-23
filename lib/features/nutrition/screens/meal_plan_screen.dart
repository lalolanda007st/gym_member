import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/meal_plan_providers.dart';

/// Pantalla de solo lectura: el miembro ve el plan de alimentación
/// que le dejó su coach (desayuno/comida/cena con alimentos y porciones).
class MealPlanScreen extends ConsumerWidget {
  const MealPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planAsync = ref.watch(myMealPlanProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Plan de alimentación')),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (plan) {
          if (plan == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tu coach aún no te ha asignado un plan de alimentación.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final meals = plan.mealLabels;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(myMealPlanProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(plan.name, style: theme.textTheme.headlineSmall),
                if (plan.notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.campaign_outlined,
                            color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            plan.notes!,
                            style: TextStyle(
                                color: theme.colorScheme.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (meals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Text('Este plan todavía no tiene alimentos.'),
                  ),
                for (final meal in meals) ...[
                  Text(meal,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Divider(),
                  for (final item in plan.itemsForMeal(meal))
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.restaurant_outlined),
                        title: Text(item.foodName),
                        subtitle: item.portionLabel.isEmpty
                            ? null
                            : Text(item.portionLabel),
                        trailing: item.notes?.isNotEmpty == true
                            ? Tooltip(
                                message: item.notes!,
                                child: const Icon(Icons.info_outline, size: 18),
                              )
                            : null,
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
