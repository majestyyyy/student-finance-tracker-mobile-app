import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:tracker_api/models/api_error.dart';
import 'package:tracker_api/validation/request_validators.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: 405,
      body: const ApiError(
        code: 'method_not_allowed',
        message: 'Only POST is supported on /v1/users/sync',
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final rawBody = await context.request.body();
    if (rawBody.isEmpty) {
      return _badRequest('Request body is required');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(rawBody);
    } on FormatException {
      return _badRequest('Request body must be valid JSON');
    }

    if (decoded is! Map<String, dynamic>) {
      return _badRequest('Request body must be a JSON object');
    }

    // API contract: azure_user_id in JSON maps to users.id (Entra sub claim).
    final entraUserId = decoded['azure_user_id'];
    final email = decoded['email'];
    final displayName = decoded['display_name'];

    final validationErrors = <String, String>{};

    final userIdError = RequestValidators.validateAzureUserId(entraUserId);
    if (userIdError != null) {
      validationErrors['azure_user_id'] = userIdError;
    }

    final emailError = RequestValidators.validateEmail(email);
    if (emailError != null) {
      validationErrors['email'] = emailError;
    }

    if (displayName != null && displayName is! String) {
      validationErrors['display_name'] = 'display_name must be a string';
    }

    if (validationErrors.isNotEmpty) {
      final errorBody = const ApiError(
        code: 'validation_error',
        message: 'One or more fields failed validation',
        details: {},
      ).toJson();
      (errorBody['error'] as Map<String, dynamic>)['details'] =
          validationErrors;

      return Response.json(statusCode: 422, body: errorBody);
    }

    final normalizedUserId = (entraUserId as String).trim();
    final normalizedEmail = (email as String).trim().toLowerCase();
    final normalizedDisplayName = displayName is String
        ? displayName.trim().isEmpty
            ? null
            : displayName.trim()
        : null;

    final pool = context.read<Pool<void>>();

    return await pool.withConnection((connection) async {
      final existingUser = await connection.execute(
        Sql.named(
          '''
          SELECT id, email, display_name, created_at
          FROM users
          WHERE id = @id
          LIMIT 1
          ''',
        ),
        parameters: {'id': normalizedUserId},
      );

      if (existingUser.isNotEmpty) {
        final row = existingUser.first;
        final existingEmail = row[1]! as String;
        final existingDisplayName = row[2] as String?;

        final shouldUpdate = existingEmail != normalizedEmail ||
            (normalizedDisplayName != null &&
                normalizedDisplayName != existingDisplayName);

        if (shouldUpdate) {
          await connection.execute(
            Sql.named(
              '''
              UPDATE users
              SET
                email = @email,
                display_name = COALESCE(@display_name, display_name)
              WHERE id = @id
              ''',
            ),
            parameters: {
              'id': normalizedUserId,
              'email': normalizedEmail,
              'display_name': normalizedDisplayName,
            },
          );
        }

        return Response.json(
          body: {
            'synced': true,
            'created': false,
            'user_id': row[0]! as String,
            'created_at': row[3]?.toString(),
          },
        );
      }

      final insertResult = await connection.execute(
        Sql.named(
          '''
          INSERT INTO users (id, email, display_name)
          VALUES (@id, @email, @display_name)
          RETURNING id, created_at
          ''',
        ),
        parameters: {
          'id': normalizedUserId,
          'email': normalizedEmail,
          'display_name': normalizedDisplayName,
        },
      );

      final insertedRow = insertResult.first;

      return Response.json(
        statusCode: 201,
        body: {
          'synced': true,
          'created': true,
          'user_id': insertedRow[0]! as String,
          'created_at': insertedRow[1]?.toString(),
        },
      );
    });
  } on ServerException catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'database_error',
        message: 'A database error occurred while syncing the user',
        details: {'code': error.code},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'internal_error',
        message: 'An unexpected error occurred while syncing the user',
        details: {'reason': error.toString()},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Response _badRequest(String message) {
  return Response(
    statusCode: 400,
    body: ApiError(
      code: 'bad_request',
      message: message,
    ).toJsonString(),
    headers: {'Content-Type': 'application/json'},
  );
}
