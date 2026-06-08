import 'dart:io' show Platform;

/// PostgreSQL connection settings sourced from environment variables.
class DatabaseConfig {
  const DatabaseConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
    required this.sslMode,
  });

  factory DatabaseConfig.fromEnvironment() {
    return DatabaseConfig(
      host: _env('DB_HOST', 'localhost'),
      port: int.parse(_env('DB_PORT', '5432')),
      database: _env('DB_NAME', 'tracker'),
      username: _env('DB_USER', 'tracker'),
      password: _env('DB_PASSWORD', 'tracker_dev_password'),
      sslMode: _env('DB_SSL_MODE', 'disable'),
    );
  }

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;
  final String sslMode;

  static String _env(String key, String fallback) {
    final compileTime = String.fromEnvironment(key);
    if (compileTime.isNotEmpty) {
      return compileTime;
    }
    return Platform.environment[key] ?? fallback;
  }
}
