import 'dart:async';

import 'package:postgres/postgres.dart';

import 'package:tracker_api/database/database_config.dart';

/// Manages a singleton PostgreSQL connection for the API process.
///
/// For local debugging a single long-lived connection is sufficient.
/// Scale-out deployments should swap this for a connection pool.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Connection? _connection;
  final DatabaseConfig _config = DatabaseConfig.fromEnvironment();

  bool get isConnected => _connection != null;

  Future<Connection> getConnection() async {
    if (_connection != null) {
      return _connection!;
    }

    _connection = await Connection.open(
      Endpoint(
        host: _config.host,
        port: _config.port,
        database: _config.database,
        username: _config.username,
        password: _config.password,
      ),
      settings: ConnectionSettings(
        sslMode: _config.sslMode == 'require'
            ? SslMode.require
            : SslMode.disable,
        connectTimeout: const Duration(seconds: 10),
      ),
    );

    return _connection!;
  }

  Future<void> close() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      await connection.close();
    }
  }
}
