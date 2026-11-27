import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/services/gym_store.dart';
import '../models/badge_model.dart';

/// Controller terpusat untuk manajemen Badge Pencapaian dengan persistensi Hive.
class BadgeController extends ChangeNotifier {
  static final BadgeController instance = BadgeController._internal();

  static const String boxName = 'badges_box';

  final List<BadgeModel> _badges = [];
  Box<BadgeModel>? _box;
  String? _claimingBadgeId;
  String? _lastError;
  bool _initialized = false;

  BadgeController._internal() {
    _seedDefaults();
    GymStore.instance.addListener(_syncWithGymStore);
  }

  List<BadgeModel> get badges => List.unmodifiable(_badges);
  String? get claimingBadgeId => _claimingBadgeId;
  bool isBadgeClaiming(String id) => _claimingBadgeId == id;
  String? get lastError => _lastError;
  int get unlockedCount => _badges.where((b) => b.isUnlocked).length;
  int get eligibleCount =>
      _badges.where((b) => b.isEligible && !b.isUnlocked).length;

  static List<BadgeModel> _defaultBadges() => const [
        BadgeModel(
          id: 'first_workout',
          title: 'First Workout',
          description:
              'Simpan catatan latihan pertamamu untuk membuka badge ini.',
          category: 'Gym',
          icon: Icons.fitness_center_rounded,
          badgeColor: Color(0xFF00E676),
        ),
        BadgeModel(
          id: 'boss_slayer',
          title: 'Boss Slayer',
          description:
              'Kalahkan Boss di layar Boss Battle untuk membuka badge ini.',
          category: 'Boss Battle',
          icon: Icons.shield_rounded,
          badgeColor: Color(0xFFFF5252),
        ),
        BadgeModel(
          id: 'century_lifter',
          title: 'Century Lifter',
          description:
              'Kumpulkan total volume latihan gym mencapai 1.000 kg.',
          category: 'Gym',
          icon: Icons.emoji_events_rounded,
          badgeColor: Color(0xFFFFD600),
        ),
        BadgeModel(
          id: 'workout_veteran',
          title: 'Workout Veteran',
          description: 'Simpan 10 catatan latihan untuk membuka badge ini.',
          category: 'Gym',
          icon: Icons.bolt_rounded,
          badgeColor: Color(0xFF00B0FF),
        ),
      ];

  void _seedDefaults() {
    if (_badges.isNotEmpty) return;
    _badges.addAll(_defaultBadges());
  }

  /// Membuka Hive Box dan memuat status badge yang tersimpan secara lokal.
  Future<void> init() async {
    if (_initialized) return;

    try {
      _box = await _openOrResetBox();

      final defaults = _defaultBadges();
      final loadedBadges = <BadgeModel>[];

      for (final def in defaults) {
        final saved = _box?.get(def.id);
        if (saved != null) {
          loadedBadges.add(
            def.copyWith(
              isEligible: saved.isEligible || saved.isUnlocked,
              isUnlocked: saved.isUnlocked,
              unlockedAt: saved.unlockedAt,
            ),
          );
        } else {
          loadedBadges.add(def);
          await _box?.put(def.id, def);
        }
      }

      _badges
        ..clear()
        ..addAll(loadedBadges);
    } catch (e, st) {
      debugPrint(
        'BadgeController.init error (fallback ke default in-memory): $e\n$st',
      );
      _box = null;
      _badges.clear();
      _seedDefaults();
    } finally {
      _initialized = true;
    }

    try {
      if (!GymStore.instance.isLoaded) {
        await GymStore.instance
            .loadFromDatabase()
            .timeout(const Duration(seconds: 2));
      }
      _syncWithGymStore();
    } catch (e) {
      debugPrint('BadgeController sync GymStore skip/error: $e');
    }

    notifyListeners();
  }

  Future<Box<BadgeModel>?> _openOrResetBox() async {
    try {
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box<BadgeModel>(boxName)
          : await Hive.openBox<BadgeModel>(boxName);
      // Uji baca seluruh entri agar data korup/typeId bentrok langsung terdeteksi
      for (final key in box.keys) {
        box.get(key);
      }
      return box;
    } catch (e) {
      debugPrint('BadgeController Hive box rusak/bentrok, mereset box: $e');
      try {
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box<BadgeModel>(boxName).close();
        }
        await Hive.deleteBoxFromDisk(boxName);
        return await Hive.openBox<BadgeModel>(boxName);
      } catch (resetError) {
        debugPrint('BadgeController gagal reset box: $resetError');
        return null;
      }
    }
  }

  Future<void> _saveBadge(BadgeModel badge) async {
    try {
      final box = _box ??
          (Hive.isBoxOpen(boxName)
              ? Hive.box<BadgeModel>(boxName)
              : await Hive.openBox<BadgeModel>(boxName));
      _box = box;
      await box.put(badge.id, badge);
    } catch (e) {
      debugPrint('BadgeController._saveBadge error: $e');
    }
  }

  /// Sinkronisasi otomatis milestone gym dengan data di GymStore.
  void _syncWithGymStore() {
    final int workoutCount = GymStore.instance.logs.length;
    final double gymVolume = GymStore.instance.totalVolumeKg;
    bool changed = false;

    for (int i = 0; i < _badges.length; i++) {
      final badge = _badges[i];
      if (badge.isUnlocked) continue;

      bool shouldBeEligible = badge.isEligible;
      if (badge.id == 'first_workout' && workoutCount >= 1) {
        shouldBeEligible = true;
      } else if (badge.id == 'century_lifter' && gymVolume >= 1000.0) {
        shouldBeEligible = true;
      } else if (badge.id == 'workout_veteran' && workoutCount >= 10) {
        shouldBeEligible = true;
      }

      if (shouldBeEligible != badge.isEligible) {
        final updated = badge.copyWith(isEligible: shouldBeEligible);
        _badges[i] = updated;
        unawaited(_saveBadge(updated));
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Membuka badge Boss Slayer otomatis saat user mengalahkan Boss.
  Future<void> unlockBossSlayer() async {
    if (!_initialized) {
      await init();
    }
    final index = _badges.indexWhere((b) => b.id == 'boss_slayer');
    if (index == -1) return;

    final badge = _badges[index];
    if (badge.isEligible || badge.isUnlocked) return;

    final updated = badge.copyWith(isEligible: true);
    _badges[index] = updated;
    await _saveBadge(updated);
    notifyListeners();
  }

  /// Toggle manual untuk keperluan pengujian demo.
  Future<void> toggleEligible(String id) async {
    final index = _badges.indexWhere((b) => b.id == id);
    if (index == -1 || _badges[index].isUnlocked) return;

    final updated = _badges[index].copyWith(
      isEligible: !_badges[index].isEligible,
    );
    _badges[index] = updated;
    await _saveBadge(updated);
    notifyListeners();
  }

  /// Mengklaim badge yang sudah memenuhi syarat dan menyimpannya ke Hive.
  Future<BadgeModel?> claimBadge(String id) async {
    final index = _badges.indexWhere((b) => b.id == id);
    if (index == -1) return null;

    final badge = _badges[index];
    if (!badge.isEligible || badge.isUnlocked || _claimingBadgeId != null) {
      return null;
    }

    _claimingBadgeId = id;
    _lastError = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final updatedBadge = badge.copyWith(
        isEligible: true,
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      );

      _badges[index] = updatedBadge;
      await _saveBadge(updatedBadge);
      return updatedBadge;
    } catch (e) {
      _lastError = 'Gagal mengklaim badge: $e';
      debugPrint('BadgeController.claimBadge error: $e');
      return null;
    } finally {
      _claimingBadgeId = null;
      notifyListeners();
    }
  }
}
