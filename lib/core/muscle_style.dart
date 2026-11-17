import 'package:flutter/material.dart';

/// Color, icono y nombre de cada grupo muscular, para dar identidad visual
/// a rutinas y ejercicios.
class MuscleStyle {
  const MuscleStyle(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static const _styles = <String, MuscleStyle>{
    'chest': MuscleStyle('Pecho', Icons.fitness_center, Color(0xFFE53935)),
    'back': MuscleStyle('Espalda', Icons.rowing, Color(0xFF1E88E5)),
    'legs': MuscleStyle('Piernas', Icons.directions_run, Color(0xFF43A047)),
    'shoulders':
        MuscleStyle('Hombros', Icons.sports_gymnastics, Color(0xFF8E24AA)),
    'arms': MuscleStyle('Brazos', Icons.sports_mma, Color(0xFFFB8C00)),
    'core': MuscleStyle('Core', Icons.self_improvement, Color(0xFF00897B)),
    'cardio': MuscleStyle('Cardio', Icons.favorite, Color(0xFFD81B60)),
  };

  static const general =
      MuscleStyle('General', Icons.fitness_center, Color(0xFF546E7A));

  static MuscleStyle of(String? key) => _styles[key] ?? general;
}
