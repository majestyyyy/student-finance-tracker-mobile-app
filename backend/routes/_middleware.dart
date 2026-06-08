import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:tracker_api/database/database_service.dart';

/// Injects a PostgreSQL [Pool] into every request context.
Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use(databaseProvider);
}

/// Provides the shared connection pool to downstream route handlers.
///
/// Handlers must call [Pool.withConnection] to borrow a live connection for
/// each request — the pool recycles sockets and replaces stale connections.
Middleware databaseProvider = provider<Pool<void>>(
  (context) => DatabaseService.instance.pool,
);
