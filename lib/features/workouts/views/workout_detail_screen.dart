import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/gym_store.dart';

class WorkoutDetailScreen extends StatelessWidget {
  final GymLog log;

  const WorkoutDetailScreen({super.key, required this.log});

  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _cardColor = Color(0xFF1E1E2C);
  static const Color _bgColor = Color(0xFF121212);

  @override
  Widget build(BuildContext context) {
    final bossDamageContribution = (log.volume * 0.08).round();
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(log.date);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text(
          'Detail Latihan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _cardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _primaryColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: _primaryColor,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      log.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    _detailRow('Beban', '${log.weight} kg'),
                    const Divider(color: Colors.white10, height: 24),
                    _detailRow('Jumlah Set', '${log.sets} set'),
                    const Divider(color: Colors.white10, height: 24),
                    _detailRow('Repetisi per Set', '${log.reps} repetisi'),
                    const Divider(color: Colors.white10, height: 24),
                    _detailRow(
                      'Total Volume',
                      '${log.volume.toStringAsFixed(1)} kg',
                      valueColor: Colors.greenAccent,
                    ),
                    const Divider(color: Colors.white10, height: 24),
                    _detailRow(
                      'Kontribusi Boss Damage',
                      '+$bossDamageContribution DMG',
                      valueColor: _primaryColor,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text(
                    'Kembali ke Daftar Latihan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    Color valueColor = Colors.white,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 14)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
