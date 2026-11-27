import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/exchange_rate_response.dart';

class ConvertersScreen extends StatefulWidget {
  const ConvertersScreen({super.key});

  @override
  State<ConvertersScreen> createState() => _ConvertersScreenState();
}

class _ConvertersScreenState extends State<ConvertersScreen> {
  static const String _exchangeApiUrl = 'https://open.er-api.com/v6/latest/USD';

  // Controller dengan teks awal terformat
  final TextEditingController _idrController =
      TextEditingController(text: '100.000');

  String _selectedCurrency = 'USD';
  double _result = 6.45;

  // Kurs default (fallback jika offline)
  final Map<String, double> _defaultRates = {
    'USD': 0.0000645, // 1 IDR ke USD
    'EUR': 0.0000590, // 1 IDR ke EUR
    'SGD': 0.0000860, // 1 IDR ke SGD
  };

  late Map<String, double> _rates = Map<String, double>.from(_defaultRates);
  bool _isLoadingRates = false;
  bool _isLiveApi = false;
  String? _lastUpdatedUtc;

  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _recalculateResult();
    _fetchExchangeRates();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _idrController.dispose();
    super.dispose();
  }

  double _currentIdrAmount() {
    final cleanValue = _idrController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleanValue) ?? 0.0;
  }

  void _recalculateResult() {
    final amount = _currentIdrAmount();
    _result = amount * (_rates[_selectedCurrency] ?? 0.0000645);
  }

  Future<void> _fetchExchangeRates() async {
    if (_isLoadingRates) return;
    setState(() {
      _isLoadingRates = true;
    });

    try {
      final response = await http
          .get(Uri.parse(_exchangeApiUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final parsed = ExchangeRateResponse.fromJson(decoded);

        final usdRate = parsed.idrToCurrencyRate('USD');
        final eurRate = parsed.idrToCurrencyRate('EUR');
        final sgdRate = parsed.idrToCurrencyRate('SGD');

        if (parsed.result == 'success' &&
            usdRate != null &&
            eurRate != null &&
            sgdRate != null) {
          if (!mounted) return;
          setState(() {
            _rates = {
              'USD': usdRate,
              'EUR': eurRate,
              'SGD': sgdRate,
            };
            _isLiveApi = true;
            _lastUpdatedUtc = parsed.timeLastUpdateUtc;
            _recalculateResult();
          });
          return;
        }
      }
      _applyOfflineFallback();
    } catch (_) {
      _applyOfflineFallback();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRates = false;
        });
      }
    }
  }

  void _applyOfflineFallback() {
    if (!mounted) return;
    setState(() {
      _rates = Map<String, double>.from(_defaultRates);
      _isLiveApi = false;
      _recalculateResult();
    });
  }

  // Fungsi untuk memformat angka dengan titik otomatis saat diketik
  void _onIdrChanged(String value) {
    final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanValue.isEmpty) {
      _idrController.text = '';
      _idrController.selection = const TextSelection.collapsed(offset: 0);
      setState(() {
        _result = 0.0;
      });
      return;
    }

    final double? parsedValue = double.tryParse(cleanValue);
    if (parsedValue == null) {
      setState(() {
        _result = 0.0;
      });
      return;
    }

    // Format angka menggunakan pemisah titik ala Indonesia
    final formatter = NumberFormat('#,###', 'id_ID');
    final String formatted = formatter.format(parsedValue).replaceAll(',', '.');

    _idrController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    // Hitung hasil konversi
    setState(() {
      _result = parsedValue * (_rates[_selectedCurrency] ?? 0.0000645);
    });
  }

  void _onCurrencyChanged(String? newCurrency) {
    if (newCurrency != null) {
      setState(() {
        _selectedCurrency = newCurrency;
        _recalculateResult();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime utcTime = _currentTime.toUtc();
    final DateTime wibTime = utcTime.add(const Duration(hours: 7));
    final DateTime witaTime = utcTime.add(const Duration(hours: 8));
    final DateTime witTime = utcTime.add(const Duration(hours: 9));
    final DateTime londonTime = utcTime;

    String formatDigits(int n) => n.toString().padLeft(2, '0');
    String getTimeString(DateTime dt) =>
        '${formatDigits(dt.hour)}:${formatDigits(dt.minute)}:${formatDigits(dt.second)}';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Modul Konversi & Zona Waktu',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Refresh Kurs Live',
            onPressed: _isLoadingRates ? null : _fetchExchangeRates,
            icon: _isLoadingRates
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Konversi Poin Reward (IDR ke Valuta Asing)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (_isLiveApi ? Colors.greenAccent : Colors.orange)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isLiveApi ? Colors.greenAccent : Colors.orange,
                    ),
                  ),
                  child: Text(
                    _isLiveApi ? 'Live API' : 'Offline Fallback',
                    style: TextStyle(
                      color: _isLiveApi ? Colors.greenAccent : Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoadingRates) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(
                color: Color(0xFF6C5CE7),
                backgroundColor: Colors.white10,
              ),
            ],
            if (_isLiveApi &&
                _lastUpdatedUtc != null &&
                _lastUpdatedUtc!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Update API: $_lastUpdatedUtc',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jumlah dalam IDR (Rp)',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),

                  // Input Nominal dengan Format Titik Otomatis
                  TextField(
                    controller: _idrController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    onChanged: _onIdrChanged,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Dropdown Pilihan Valuta Asing (USD, EUR, SGD)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCurrency,
                              dropdownColor: const Color(0xFF1E1E2C),
                              icon: const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              items: ['USD', 'EUR', 'SGD'].map((String currency) {
                                return DropdownMenuItem<String>(
                                  value: currency,
                                  child: Text(currency),
                                );
                              }).toList(),
                              onChanged: _onCurrencyChanged,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C5CE7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed:
                            _isLoadingRates ? null : _fetchExchangeRates,
                        icon: const Icon(
                          Icons.sync,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'Kurs Live',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Kotak Hasil Konversi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Hasil:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_result.toStringAsFixed(2)} $_selectedCurrency',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // ZONA WAKTU GLOBAL MARATHON (REAL-TIME)
            const Text(
              'Zona Waktu Global Marathon',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    title: const Text(
                      'WIB (Jakarta)',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      getTimeString(wibTime),
                      style: const TextStyle(
                        color: Color(0xFF9C88FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  ListTile(
                    title: const Text(
                      'WITA (Makassar)',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      getTimeString(witaTime),
                      style: const TextStyle(
                        color: Color(0xFF9C88FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  ListTile(
                    title: const Text(
                      'WIT (Jayapura)',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      getTimeString(witTime),
                      style: const TextStyle(
                        color: Color(0xFF9C88FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  ListTile(
                    title: const Text(
                      'London (UTC)',
                      style: TextStyle(color: Colors.white),
                    ),
                    trailing: Text(
                      getTimeString(londonTime),
                      style: const TextStyle(
                        color: Color(0xFF9C88FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
