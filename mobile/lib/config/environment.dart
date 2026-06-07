import 'dart:io' show Platform;

/// Runtime environment configuration driven by `--dart-define` flags.
/// Hardcoded defaults fallback to local development setups.
class Environment {
  Environment._();

  static const String _appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'local',
  );

  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static bool get isProduction => _appEnv == 'production';

  static bool get isLocal => !isProduction;

  /// Resolves the API base URL with platform-aware local defaults.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _normalizeBaseUrl(_apiBaseUrlOverride);
    }

    if (isProduction) {
      return 'https://api.studenttracker.app';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }

    return 'http://localhost:8080';
  }

  static String get usersSyncEndpoint => '$apiBaseUrl/v1/users/sync';

  static String get walletsCreateEndpoint => '$apiBaseUrl/v1/wallets/create';

  static String _normalizeBaseUrl(String url) {
    var normalized = url.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}