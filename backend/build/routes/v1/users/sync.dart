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

    final azureUserId = decoded['azure_user_id'];
    final email = decoded['email'];
    final displayName = decoded['display_name'];

    final validationErrors = <String, String>{};

    final azureUserIdError = RequestValidators.validateAzureUserId(azureUserId);
    if (azureUserIdError != null) {
      validationErrors['azure_user_id'] = azureUserIdError;
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

    final normalizedAzureUserId = (azureUserId as String).trim();
    final normalizedEmail = (email as String).trim().toLowerCase();
    final normalizedDisplayName = displayName is String
        ? displayName.trim().isEmpty
            ? null
            : displayName.trim()
        : null;

    final connection = await context.read<Future<Connection>>();

    final existingUser = await connection.execute(
      Sql.named(
        '''
        SELECT id, azure_user_id, email
        FROM users
        WHERE azure_user_id = @azure_user_id
        LIMIT 1
        ''',
      ),
      parameters: {'azure_user_id': normalizedAzureUserId},
    );

    if (existingUser.isNotEmpty) {
      final row = existingUser.first;
      final existingEmail = row[2]! as String;

      if (existingEmail != normalizedEmail ||
          (normalizedDisplayName != null)) {
        await connection.execute(
          Sql.named(
            '''
            UPDATE users
            SET
              email = @email,
              display_name = COALESCE(@display_name, display_name),
              updated_at = NOW()
            WHERE azure_user_id = @azure_user_id
            ''',
          ),
          parameters: {
            'azure_user_id': normalizedAzureUserId,
            'email': normalizedEmail,
            'display_name': normalizedDisplayName,
          },
        );
      }

      return Response.json(
        body: {
          'synced': true,
          'created': false,
          'user_id': row[0]! as int,
        },
      );
    }

    final insertResult = await connection.execute(
      Sql.named(
        '''
        INSERT INTO users (azure_user_id, email, display_name)
        VALUES (@azure_user_id, @email, @display_name)
        RETURNING id
        ''',
      ),
      parameters: {
        'azure_user_id': normalizedAzureUserId,
        'email': normalizedEmail,
        'display_name': normalizedDisplayName,
      },
    );

    final newUserId = insertResult.first[0]! as int;

    return Response.json(
      statusCode: 201,
      body: {
        'synced': true,
        'created': true,
        'user_id': newUserId,
      },
    );
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
