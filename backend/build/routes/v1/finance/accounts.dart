import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:tracker_api/finance/finance_repository.dart';
import 'package:tracker_api/finance/wallet_math.dart';
import 'package:tracker_api/models/api_error.dart';
import 'package:tracker_api/validation/request_validators.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: 405,
      body: const ApiError(
        code: 'method_not_allowed',
        message: 'Only POST is supported on /v1/finance/accounts',
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

    final validationErrors = <String, String>{};
    final azureUserId = decoded['azure_user_id'];
    final name = decoded['name'];
    final accountType = decoded['account_type'];
    final typeLabel = decoded['type_label'];
    final typeGroup = decoded['type_group'];
    final balance = decoded['balance'];
    final creditLimit = decoded['credit_limit'];
    final remainingDebt = decoded['remaining_debt'];
    final dueDateFlag = decoded['due_date_flag'];
    final currencyCode = decoded['currency_code'];

    final azureUserIdError = RequestValidators.validateAzureUserId(azureUserId);
    if (azureUserIdError != null) {
      validationErrors['azure_user_id'] = azureUserIdError;
    }

    final nameError = RequestValidators.validateAccountName(name);
    if (nameError != null) {
      validationErrors['name'] = nameError;
    }

    final accountTypeError =
        RequestValidators.validateAccountTypeCode(accountType);
    if (accountTypeError != null) {
      validationErrors['account_type'] = accountTypeError;
    }

    if (typeLabel is! String || typeLabel.trim().isEmpty) {
      validationErrors['type_label'] = 'type_label is required';
    }

    if (typeGroup is! String ||
        !WalletTypeGroup.values.contains(typeGroup.trim())) {
      validationErrors['type_group'] =
          'type_group must be asset, credit, or debt';
    }

    final balanceError = RequestValidators.validateBalance(balance);
    if (balanceError != null) {
      validationErrors['balance'] = balanceError;
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

    final connection = await context.read<Future<Connection>>();
    final repository = FinanceRepository(connection);
    final userId =
        await repository.resolveUserId((azureUserId as String).trim());

    if (userId == null) {
      return Response(
        statusCode: 404,
        body: const ApiError(
          code: 'user_not_found',
          message: 'No user record exists. Call /v1/users/sync first.',
        ).toJsonString(),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final parsedBalance = _parseAmount(balance);
    final parsedCreditLimit =
        creditLimit == null ? null : _parseAmount(creditLimit);
    final parsedRemainingDebt =
        remainingDebt == null ? null : _parseAmount(remainingDebt);

    final accountId = await repository.insertAccount(
      userId: userId,
      name: name as String,
      accountType: accountType as String,
      typeLabel: (typeLabel as String).trim(),
      typeGroup: (typeGroup as String).trim(),
      balance: parsedBalance,
      creditLimit: parsedCreditLimit,
      remainingDebt: parsedRemainingDebt,
      dueDateFlag: dueDateFlag is String ? dueDateFlag.trim() : null,
      currencyCode: currencyCode is String ? currencyCode.trim().toUpperCase() : 'PHP',
    );

    return Response.json(
      statusCode: 201,
      body: {'account_id': accountId},
    );
  } on ServerException catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'database_error',
        message: 'Failed to create account',
        details: {'code': error.code},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'internal_error',
        message: 'Unexpected error creating account',
        details: {'reason': error.toString()},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  }
}

Response _badRequest(String message) {
  return Response(
    statusCode: 400,
    body: ApiError(code: 'bad_request', message: message).toJsonString(),
    headers: {'Content-Type': 'application/json'},
  );
}

double _parseAmount(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is num) {
    return double.parse(value.toStringAsFixed(2));
  }
  if (value is String) {
    return double.parse(double.parse(value.trim()).toStringAsFixed(2));
  }
  throw const FormatException('Invalid amount');
}
