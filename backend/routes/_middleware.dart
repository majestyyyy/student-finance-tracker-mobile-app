import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:tracker_api/database/database_service.dart';

/// Injects a PostgreSQL [Connection] into every request context.
Handler middleware(Handler handler) {
  return handler.use(requestLogger()).use(databaseProvider);
}

/// Provides the shared database connection to downstream route handlers.
Middleware databaseProvider = provider<Future<Connection>>(
  (context) => DatabaseService.instance.getConnection(),
);
