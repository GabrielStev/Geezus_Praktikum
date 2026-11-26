import 'package:flutter/material.dart';
import '../../../core/services/gym_store.dart';

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _cardColor = Color(0xFF1E1E2C);

  final _formKey = GlobalKey<FormState>();
  final _exerciseController = TextEditingController();
  final _weightController = TextEditingController();
  final _setsController = TextEditingController();
  final _repsController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    GymStore.instance.loadFromDatabase();
  }

  @override
  void dispose() {
    _exerciseController.dispose();
    _weightController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _saveWorkout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await GymStore.instance.addLog(
      _exerciseController.text.trim(),
      double.parse(_weightController.text.replaceAll(',', '.')),
      int.parse(_setsController.text),
      int.parse(_repsController.text),
    );

    if (!mounted) return;
    _formKey.currentState!.reset();
    _exerciseController.clear();
    _weightController.clear();
    _setsController.clear();
    _repsController.clear();
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Catatan latihan berhasil disimpan.')),
    );
  }

  String? _positiveNumber(String? value, {bool decimal = false}) {
    final parsed = decimal
        ? double.tryParse((value ?? '').trim().replaceAll(',', '.'))
        : int.tryParse((value ?? '').trim())?.toDouble();
    if (parsed == null || parsed <= 0) return 'Masukkan angka lebih dari 0';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('Catat Latihan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _cardColor,
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: GymStore.instance,
          builder: (context, _) {
            final store = GymStore.instance;
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
                        TextFormField(
                          controller: _exerciseController,
                          decoration: const InputDecoration(
                            labelText: 'Nama latihan',
                            hintText: 'Contoh: Bench Press',
                            prefixIcon: Icon(Icons.fitness_center),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Nama latihan wajib diisi'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Beban (kg)',
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
                          validator: (value) => _positiveNumber(value, decimal: true),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _setsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Set'),
                                validator: _positiveNumber,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _repsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Repetisi'),
                                validator: _positiveNumber,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _isSaving ? null : _saveWorkout,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Latihan'),
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
                    Expanded(child: _statCard('Total Volume', '${store.totalVolumeKg.toStringAsFixed(1)} kg')),
                    const SizedBox(width: 12),
                    Expanded(child: _statCard('Gym Damage', '${store.gymDamage} DMG')),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Riwayat latihan',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (store.logs.isEmpty)
                  const Card(
                    color: _cardColor,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Belum ada catatan latihan.', style: TextStyle(color: Colors.white70)),
                    ),
                  )
                else
                  ...store.logs.reversed.take(10).map(
                    (log) => Card(
                      color: _cardColor,
                      child: ListTile(
                        leading: const Icon(Icons.fitness_center, color: _primaryColor),
                        title: Text(log.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(
                          '${log.weight} kg × ${log.sets} set × ${log.reps} repetisi',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: Text(
                          '${log.volume.toStringAsFixed(0)} kg',
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
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
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
