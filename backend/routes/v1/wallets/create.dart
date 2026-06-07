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
        message: 'Only POST is supported on /v1/wallets/create',
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
    final accountType = decoded['account_type'];
    final name = decoded['name'];
    final balance = decoded['balance'];
    final currencyCode = decoded['currency_code'];

    final validationErrors = <String, String>{};

    final azureUserIdError = RequestValidators.validateAzureUserId(azureUserId);
    if (azureUserIdError != null) {
      validationErrors['azure_user_id'] = azureUserIdError;
    }

    final accountTypeError =
        RequestValidators.validateAccountTypeCode(accountType);
    if (accountTypeError != null) {
      validationErrors['account_type'] = accountTypeError;
    }

    final nameError = RequestValidators.validateAccountName(name);
    if (nameError != null) {
      validationErrors['name'] = nameError;
    }

    final balanceError = RequestValidators.validateBalance(balance);
    if (balanceError != null) {
      validationErrors['balance'] = balanceError;
    }

    final currencyError = RequestValidators.validateCurrencyCode(currencyCode);
    if (currencyError != null) {
      validationErrors['currency_code'] = currencyError;
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
    final normalizedAccountType = (accountType as String).trim().toLowerCase();
    final normalizedName = (name as String).trim();
    final normalizedCurrency =
        currencyCode is String ? currencyCode.trim().toUpperCase() : 'USD';

    final parsedBalance = _parseBalance(balance);

    final connection = await context.read<Future<Connection>>();

    final userLookup = await connection.execute(
      Sql.named(
        '''
        SELECT id
        FROM users
        WHERE azure_user_id = @azure_user_id
        LIMIT 1
        ''',
      ),
      parameters: {'azure_user_id': normalizedAzureUserId},
    );

    if (userLookup.isEmpty) {
      return Response(
        statusCode: 404,
        body: const ApiError(
          code: 'user_not_found',
          message:
              'No local user record exists for the provided azure_user_id. '
              'Call /v1/users/sync first.',
        ).toJsonString(),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final userId = userLookup.first[0]! as int;

    final accountTypeLookup = await connection.execute(
      Sql.named(
        '''
        SELECT id, code, display_name
        FROM account_types
        WHERE code = @code AND is_active = TRUE
        LIMIT 1
        ''',
      ),
      parameters: {'code': normalizedAccountType},
    );

    if (accountTypeLookup.isEmpty) {
      return Response(
        statusCode: 422,
        body: ApiError(
          code: 'invalid_account_type',
          message: 'The requested account_type is not available',
          details: {'account_type': normalizedAccountType},
        ).toJsonString(),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final accountTypeId = accountTypeLookup.first[0]! as int;
    final accountTypeCode = accountTypeLookup.first[1]! as String;
    final accountTypeDisplayName = accountTypeLookup.first[2]! as String;

    final insertResult = await connection.execute(
      Sql.named(
        '''
        INSERT INTO accounts (
          user_id,
          account_type_id,
          name,
          balance,
          currency_code
        )
        VALUES (
          @user_id,
          @account_type_id,
          @name,
          @balance::DECIMAL(15, 2),
          @currency_code
        )
        RETURNING id, balance, currency_code, created_at
        ''',
      ),
      parameters: {
        'user_id': userId,
        'account_type_id': accountTypeId,
        'name': normalizedName,
        'balance': parsedBalance.toStringAsFixed(2),
        'currency_code': normalizedCurrency,
      },
    );

    final insertedRow = insertResult.first;
    final accountId = insertedRow[0]! as int;
    final insertedBalance = _decimalFromRow(insertedRow[1]);
    final insertedCurrency = insertedRow[2]! as String;
    final createdAt = insertedRow[3]!.toString();

    return Response.json(
      statusCode: 201,
      body: {
        'account': {
          'id': accountId,
          'user_id': userId,
          'name': normalizedName,
          'account_type': accountTypeCode,
          'account_type_display_name': accountTypeDisplayName,
          'balance': insertedBalance,
          'currency_code': insertedCurrency,
          'created_at': createdAt,
        },
      },
    );
  } on ServerException catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'database_error',
        message: 'A database error occurred while creating the wallet',
        details: {'code': error.code},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'internal_error',
        message: 'An unexpected error occurred while creating the wallet',
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

double _parseBalance(dynamic balance) {
  if (balance == null) {
    return 0.0;
  }
  if (balance is int) {
    return balance.toDouble();
  }
  if (balance is double) {
    return double.parse(balance.toStringAsFixed(2));
  }
  if (balance is String) {
    final parsed = double.tryParse(balance.trim());
    if (parsed == null) {
      throw const FormatException('balance is not a valid decimal number');
    }
    return double.parse(parsed.toStringAsFixed(2));
  }
  throw const FormatException('balance must be a number');
}

String _decimalFromRow(dynamic value) {
  if (value == null) {
    return '0.00';
  }
  if (value is String) {
    final parsed = double.parse(value);
    return parsed.toStringAsFixed(2);
  }
  if (value is num) {
    return double.parse(value.toString()).toStringAsFixed(2);
  }
  return '0.00';
}
