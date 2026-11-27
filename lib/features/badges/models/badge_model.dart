import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Model untuk Badge Pencapaian latihan gym dan Boss Battle.
class BadgeModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final Color badgeColor;
  final bool isEligible;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const BadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.badgeColor,
    this.isEligible = false,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  static IconData iconForId(String id) {
    switch (id) {
      case 'first_workout':
        return Icons.fitness_center_rounded;
      case 'boss_slayer':
        return Icons.shield_rounded;
      case 'century_lifter':
        return Icons.emoji_events_rounded;
      case 'workout_veteran':
        return Icons.bolt_rounded;
      default:
        return Icons.military_tech_rounded;
    }
  }

  BadgeModel copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    IconData? icon,
    Color? badgeColor,
    bool? isEligible,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return BadgeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      badgeColor: badgeColor ?? this.badgeColor,
      isEligible: isEligible ?? this.isEligible,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

/// TypeAdapter manual untuk menyimpan [BadgeModel] di Hive Box.
class BadgeModelAdapter extends TypeAdapter<BadgeModel> {
  @override
  final int typeId = 0;

  @override
  BadgeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    final id = fields[0] as String;
    return BadgeModel(
      id: id,
      title: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as String,
      icon: BadgeModel.iconForId(id),
      badgeColor: Color(fields[4] as int),
      isEligible: fields[5] as bool? ?? false,
      isUnlocked: fields[6] as bool? ?? false,
      unlockedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BadgeModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.badgeColor.toARGB32())
      ..writeByte(5)
      ..write(obj.isEligible)
      ..writeByte(6)
      ..write(obj.isUnlocked)
      ..writeByte(7)
      ..write(obj.unlockedAt);
  }
}
