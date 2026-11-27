/// Model respons dari REST API kurs mata uang (open.er-api.com).
class ExchangeRateResponse {
  final String result;
  final String baseCode;
  final String timeLastUpdateUtc;
  final Map<String, double> rates;

  const ExchangeRateResponse({
    required this.result,
    required this.baseCode,
    required this.timeLastUpdateUtc,
    required this.rates,
  });

  factory ExchangeRateResponse.fromJson(Map<String, dynamic> json) {
    final rawRates = json['rates'] as Map<String, dynamic>? ?? {};
    final parsedRates = <String, double>{};
    for (final entry in rawRates.entries) {
      final value = entry.value;
      if (value is num) {
        parsedRates[entry.key] = value.toDouble();
      }
    }

    return ExchangeRateResponse(
      result: json['result']?.toString() ?? '',
      baseCode: json['base_code']?.toString() ?? 'USD',
      timeLastUpdateUtc: json['time_last_update_utc']?.toString() ?? '',
      rates: parsedRates,
    );
  }

  /// Menghitung nilai tukar 1 IDR terhadap [targetCurrency] berdasarkan base USD.
  double? idrToCurrencyRate(String targetCurrency) {
    final idrPerUsd = rates['IDR'];
    final targetPerUsd =
        targetCurrency == baseCode ? 1.0 : rates[targetCurrency];
    if (idrPerUsd == null || idrPerUsd <= 0 || targetPerUsd == null) {
      return null;
    }
    return targetPerUsd / idrPerUsd;
  }
}
