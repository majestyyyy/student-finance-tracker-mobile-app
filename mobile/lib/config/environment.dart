import 'dart:io' show Platform;

/// API runtime configuration via `--dart-define`.
class Environment {
  Environment._();

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _normalizeBaseUrl(_apiBaseUrlOverride);
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
  }

  static String get usersSyncEndpoint => '$apiBaseUrl/v1/users/sync';
  static String get financeDashboardEndpoint =>
      '$apiBaseUrl/v1/finance/dashboard';
  static String get financeAccountsEndpoint =>
      '$apiBaseUrl/v1/finance/accounts';
  static String get financeTransactionsEndpoint =>
      '$apiBaseUrl/v1/finance/transactions';

  static String financeTransactionDeleteEndpoint(int transactionId) =>
      '$apiBaseUrl/v1/finance/transactions/$transactionId';

  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
