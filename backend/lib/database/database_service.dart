import 'package:postgres/postgres.dart';

import 'package:tracker_api/database/database_config.dart';

/// Manages a process-wide PostgreSQL connection pool for the API.
///
/// Connections are opened lazily on first use and recycled by the pool.
/// Route handlers must borrow a connection via [withConnection] (or
/// [Pool.withConnection]) for the duration of a request — never cache a
/// [Connection] across requests.
class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  final DatabaseConfig _config = DatabaseConfig.fromEnvironment();

  Pool<void>? _pool;

  bool get isInitialized => _pool != null;

  /// Lazily creates the pool on first access and reuses it for the process.
  Pool<void> get pool => _pool ??= _createPool();

  /// Borrows a live connection from the pool for the duration of [fn].
  Future<R> withConnection<R>(
    Future<R> Function(Connection connection) fn,
  ) {
    return pool.withConnection(fn);
  }

  Future<void> close() async {
    final pool = _pool;
    _pool = null;
    if (pool != null) {
      await pool.close();
    }
  }

  Pool<void> _createPool() {
    return Pool.withEndpoints(
      [
        Endpoint(
          host: _config.host,
          port: _config.port,
          database: _config.database,
          username: _config.username,
          password: _config.password,
        ),
      ],
      settings: PoolSettings(
        sslMode: _config.sslMode == 'require'
            ? SslMode.require
            : SslMode.disable,
        connectTimeout: const Duration(seconds: 10),
        maxConnectionCount: _config.maxPoolSize,
        maxConnectionAge: const Duration(minutes: 30),
      ),
    );
  }
}
