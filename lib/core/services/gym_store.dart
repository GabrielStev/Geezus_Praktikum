import 'package:flutter/material.dart';
import '../storage/sqlite_helper.dart';

class GymLog {
  final int? id;
  final String name;
  final double weight;
  final int sets;
  final int reps;
  final DateTime date;

  GymLog({
    this.id,
    required this.name,
    required this.weight,
    required this.sets,
    required this.reps,
    required this.date,
  });

  double get volume => weight * sets * reps;

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'exercise_name': name,
        'weight_kg': weight,
        'sets': sets,
        'reps': reps,
        'volume_kg': volume,
        'date': date.toIso8601String(),
      };

  factory GymLog.fromMap(Map<String, dynamic> map) => GymLog(
        id: map['id'] as int?,
        name: map['exercise_name']?.toString() ?? '',
        weight: (map['weight_kg'] as num?)?.toDouble() ?? 0,
        sets: (map['sets'] as num?)?.toInt() ?? 0,
        reps: (map['reps'] as num?)?.toInt() ?? 0,
        date: map['date'] != null
            ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
            : DateTime.now(),
      );
}

/// Central store for manually recorded gym activity.
/// Data is persisted to SQLite and survives app restarts.
/// No dummy data — all values come from real user activity.
class GymStore extends ChangeNotifier {
  static final GymStore instance = GymStore._internal();
  GymStore._internal();

  final List<GymLog> _logs = [];
  bool _loaded = false;

  List<GymLog> get logs => List.unmodifiable(_logs);
  bool get isLoaded => _loaded;

  // ── Computed stats ──────────────────────────────────────────────────────

  double get totalVolumeKg =>
      _logs.fold(0.0, (sum, item) => sum + item.volume);

  Map<String, double> get monthlyMaxes {
    final Map<String, double> maxes = {};
    for (var log in _logs) {
      final key = log.name.toUpperCase();
      if (!maxes.containsKey(key) || log.weight > maxes[key]!) {
        maxes[key] = log.weight;
      }
    }
    return maxes;
  }

  Map<String, double> get monthlyVolumes {
    final Map<String, double> volumes = {};
    for (var log in _logs) {
      final key = log.name.toUpperCase();
      volumes[key] = (volumes[key] ?? 0) + log.volume;
    }
    return volumes;
  }

  int get gymDamage => (totalVolumeKg * 0.08).round();
  // The trimmed practical version uses manually recorded gym sessions only.
  int get totalBaseDamage => gymDamage;

  // ── Persistence ──────────────────────────────────────────────────────────

  /// Load stored gym logs from SQLite.
  /// Call once at app startup (or when the Boss Battle screen is opened).
  Future<void> loadFromDatabase() async {
    if (_loaded) return;
    try {
      final rows = await SqliteHelper.instance.getGymLogs();
      _logs.clear();
      _logs.addAll(rows.map((r) => GymLog.fromMap(r)));

      _loaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('GymStore.loadFromDatabase error: $e');
    }
  }

  /// Add a gym log entry and persist it to SQLite immediately.
  Future<void> addLog(String name, double weight, int sets, int reps) async {
    final log = GymLog(
      name: name,
      weight: weight,
      sets: sets,
      reps: reps,
      date: DateTime.now(),
    );
    _logs.add(log);
    notifyListeners();

    try {
      await SqliteHelper.instance.insertGymLog(log.toMap());
    } catch (e) {
      debugPrint('GymStore.addLog persist error: $e');
    }
  }

  /// Force a full reload from SQLite (e.g., after clearing data).
  Future<void> reload() async {
    _loaded = false;
    await loadFromDatabase();
  }

  /// Reset only in-memory state without touching SQLite.
  /// For use in unit tests where Flutter bindings are not available.
  void resetForTesting() {
    _logs.clear();
    _loaded = true; // Prevent loadFromDatabase from being called
  }
}
