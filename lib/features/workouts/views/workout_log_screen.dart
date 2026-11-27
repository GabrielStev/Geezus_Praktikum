import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/gym_store.dart';
import '../../tracking/views/step_counter_screen.dart';
import 'workout_detail_screen.dart';

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _cardColor = Color(0xFF1E1E2C);
  static const Color _bgColor = Color(0xFF121212);

  static const String _addCustomOption = '+ Tambah Jenis Latihan Lain';
  static const String _customExercisesPrefKey = 'custom_weight_exercises';
  static const List<String> _defaultExercises = [
    'Bench Press',
    'Incline Dumbbell Press',
    'Squat',
    'Leg Press',
    'Deadlift',
    'Overhead Press',
    'Barbell Row',
    'Lat Pulldown',
    'Bicep Curl',
    'Tricep Pushdown',
    'Romanian Deadlift',
    'Shoulder Lateral Raise',
  ];

  final _formKey = GlobalKey<FormState>();
  final _customExerciseController = TextEditingController();
  final _weightController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();

  List<String> _customExercises = [];
  String _selectedExercise = _defaultExercises.first;
  Set<String> _selectedGroupKeys = {};
  bool _isSaving = false;

  List<String> get _allExercises {
    final seen = <String>{};
    final result = <String>[];
    for (final item in [..._defaultExercises, ..._customExercises]) {
      final key = item.trim().toLowerCase();
      if (key.isNotEmpty && seen.add(key)) {
        result.add(item.trim());
      }
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    GymStore.instance.loadFromDatabase();
    _loadCustomExercises();
  }

  @override
  void dispose() {
    _customExerciseController.dispose();
    _weightController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomExercises() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_customExercisesPrefKey) ?? [];
      if (!mounted) return;
      setState(() {
        _customExercises = saved
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      });
    } catch (e) {
      debugPrint('WorkoutLogScreen._loadCustomExercises error: $e');
    }
  }

  Future<String> _resolveAndPersistExerciseName() async {
    if (_selectedExercise != _addCustomOption) {
      return _selectedExercise;
    }

    final rawName = _customExerciseController.text.trim();
    final lowerKey = rawName.toLowerCase();

    // Gunakan nama kanonik bila sudah ada di daftar (case-insensitive)
    for (final existing in _allExercises) {
      if (existing.toLowerCase() == lowerKey) {
        return existing;
      }
    }

    final updatedCustom = [..._customExercises, rawName];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_customExercisesPrefKey, updatedCustom);
    } catch (e) {
      debugPrint('WorkoutLogScreen save custom exercise error: $e');
    }

    if (mounted) {
      setState(() {
        _customExercises = updatedCustom;
      });
    }
    return rawName;
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final exerciseName = await _resolveAndPersistExerciseName();

    await GymStore.instance.addLog(
      exerciseName,
      double.parse(_weightController.text.replaceAll(',', '.')),
      int.parse(_setsController.text),
      int.parse(_repsController.text),
    );

    if (!mounted) return;
    _customExerciseController.clear();
    _weightController.clear();
    _setsController.clear();
    _repsController.clear();
    setState(() {
      _selectedExercise = exerciseName;
      _isSaving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Latihan "$exerciseName" berhasil disimpan.')),
    );
  }

  String? _positiveNumber(String? value, {bool decimal = false}) {
    final parsed = decimal
        ? double.tryParse((value ?? '').trim().replaceAll(',', '.'))
        : int.tryParse((value ?? '').trim())?.toDouble();
    if (parsed == null || parsed <= 0) return 'Masukkan angka lebih dari 0';
    return null;
  }

  Future<void> _showGroupBySheet(List<GymLog> logs) async {
    // Kumpulkan daftar nama latihan unik dari riwayat (case-insensitive)
    final Map<String, String> uniqueNames = {};
    final Map<String, int> sessionCounts = {};
    for (final log in logs) {
      final clean = log.name.trim();
      final key = clean.toLowerCase();
      if (key.isEmpty) continue;
      uniqueNames.putIfAbsent(key, () => clean);
      sessionCounts[key] = (sessionCounts[key] ?? 0) + 1;
    }

    final tempSelected = Set<String>.from(_selectedGroupKeys);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: _cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final keys = uniqueNames.keys.toList()
              ..sort((a, b) => uniqueNames[a]!.compareTo(uniqueNames[b]!));

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Group by Jenis Latihan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() => tempSelected.clear());
                          },
                          child: const Text(
                            'Reset / Semua',
                            style: TextStyle(color: Colors.amberAccent),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Pilih 1 atau lebih latihan untuk mengelompokkan riwayat dan melihat PR beban tertinggi.',
                      style: TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: keys.length,
                        itemBuilder: (context, index) {
                          final key = keys[index];
                          final name = uniqueNames[key]!;
                          final count = sessionCounts[key] ?? 0;
                          final checked = tempSelected.contains(key);

                          return CheckboxListTile(
                            value: checked,
                            activeColor: _primaryColor,
                            checkColor: Colors.white,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '$count sesi tercatat',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  tempSelected.add(key);
                                } else {
                                  tempSelected.remove(key);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, <String>{}),
                            child: const Text(
                              'Reset / Semua',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx, tempSelected),
                            child: const Text(
                              'Terapkan',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedGroupKeys = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          title: const Text(
            'Menu Latihan',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: _cardColor,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: _primaryColor,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(
                icon: Icon(Icons.fitness_center),
                text: 'Angkat Beban',
              ),
              Tab(
                icon: Icon(Icons.directions_walk),
                text: 'Lari / Jalan',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildWeightTrainingTab(),
            const StepCounterScreen(embedded: true),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightTrainingTab() {
    final dropdownOptions = [..._allExercises, _addCustomOption];
    final activeDropdownValue = dropdownOptions.contains(_selectedExercise)
        ? _selectedExercise
        : _defaultExercises.first;

    return SafeArea(
      child: AnimatedBuilder(
        animation: GymStore.instance,
        builder: (context, _) {
          final store = GymStore.instance;
          final bool isGroupedMode = _selectedGroupKeys.isNotEmpty;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Masukkan hasil latihanmu untuk menambah kekuatan di Boss Battle.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey(activeDropdownValue),
                        initialValue: activeDropdownValue,
                        isExpanded: true,
                        dropdownColor: _cardColor,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Pilih jenis latihan',
                          prefixIcon: Icon(Icons.fitness_center),
                        ),
                        items: dropdownOptions.map((exercise) {
                          final isCustomOpt = exercise == _addCustomOption;
                          return DropdownMenuItem<String>(
                            value: exercise,
                            child: Text(
                              exercise,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCustomOpt
                                    ? Colors.amberAccent
                                    : Colors.white,
                                fontWeight: isCustomOpt
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedExercise = val;
                          });
                        },
                      ),
                      if (activeDropdownValue == _addCustomOption) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customExerciseController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Nama latihan custom',
                            hintText: 'Contoh: Bulgarian Split Squat',
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                          validator: (value) {
                            if (_selectedExercise == _addCustomOption &&
                                (value == null || value.trim().isEmpty)) {
                              return 'Nama latihan custom wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _weightController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Beban (kg)',
                          prefixIcon: Icon(Icons.monitor_weight_outlined),
                        ),
                        validator: (value) =>
                            _positiveNumber(value, decimal: true),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _setsController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Set'),
                              validator: _positiveNumber,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _repsController,
                              style: const TextStyle(color: Colors.white),
                              keyboardType: TextInputType.number,
                              decoration:
                                  const InputDecoration(labelText: 'Repetisi'),
                              validator: _positiveNumber,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveWorkout,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving ? 'Menyimpan...' : 'Simpan Latihan',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Total Volume',
                      '${store.totalVolumeKg.toStringAsFixed(1)} kg',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard('Gym Damage', '${store.gymDamage} DMG'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat latihan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: store.logs.isEmpty
                        ? null
                        : () => _showGroupBySheet(store.logs),
                    icon: Icon(
                      Icons.filter_list,
                      size: 16,
                      color: isGroupedMode ? Colors.white : _primaryColor,
                    ),
                    label: Text(
                      isGroupedMode
                          ? 'Group by (${_selectedGroupKeys.length})'
                          : 'Group by',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isGroupedMode ? _primaryColor : Colors.white24,
                      ),
                      backgroundColor: isGroupedMode
                          ? _primaryColor.withValues(alpha: 0.25)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (store.logs.isEmpty)
                const Card(
                  color: _cardColor,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Belum ada catatan latihan.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                )
              else if (!isGroupedMode)
                ...store.logs.take(10).map(_buildWorkoutTile)
              else
                ..._buildGroupedSections(store.logs),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildGroupedSections(List<GymLog> logs) {
    final Map<String, List<GymLog>> grouped = {};
    final Map<String, String> displayNames = {};

    for (final log in logs) {
      final key = log.name.trim().toLowerCase();
      if (!_selectedGroupKeys.contains(key)) continue;
      displayNames.putIfAbsent(key, () => log.name.trim());
      grouped.putIfAbsent(key, () => []).add(log);
    }

    if (grouped.isEmpty) {
      return [
        Card(
          color: _cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Tidak ada riwayat untuk filter latihan terpilih.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedGroupKeys = {}),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      final groupLogs = entry.value;
      final groupName = displayNames[entry.key] ?? entry.key;
      final prWeight = groupLogs.map((e) => e.weight).reduce(max);
      final prText =
          prWeight % 1 == 0 ? prWeight.toInt().toString() : prWeight.toStringAsFixed(1);

      widgets.add(
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _primaryColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primaryColor.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${groupLogs.length} sesi tercatat',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amberAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amberAccent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      color: Colors.amberAccent,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'PR: $prText kg',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      for (final log in groupLogs) {
        widgets.add(_buildWorkoutTile(log));
      }
    }

    return widgets;
  }

  Widget _buildWorkoutTile(GymLog log) {
    return Card(
      color: _cardColor,
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkoutDetailScreen(log: log),
            ),
          );
        },
        leading: const Icon(Icons.fitness_center, color: _primaryColor),
        title: Text(log.name, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          '${log.weight} kg × ${log.sets} set × ${log.reps} repetisi',
          style: const TextStyle(color: Colors.white60),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${log.volume.toStringAsFixed(0)} kg',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              color: Colors.white38,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
