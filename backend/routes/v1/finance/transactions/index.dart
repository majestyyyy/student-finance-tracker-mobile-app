import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:tracker_api/finance/finance_repository.dart';
import 'package:tracker_api/models/api_error.dart';
import 'package:tracker_api/validation/request_validators.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(
      statusCode: 405,
      body: const ApiError(
        code: 'method_not_allowed',
        message: 'Only POST is supported on /v1/finance/transactions',
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
    final accountId = decoded['account_id'];
    final title = decoded['title'];
    final amount = decoded['amount'];
    final isExpense = decoded['is_expense'];
    final categoryId = decoded['category_id'];

    final azureUserIdError = RequestValidators.validateAzureUserId(azureUserId);
    if (azureUserIdError != null) {
      validationErrors['azure_user_id'] = azureUserIdError;
    }

    if (accountId is! int && accountId is! String) {
      validationErrors['account_id'] = 'account_id must be an integer';
    }

    if (title is! String || title.trim().isEmpty) {
      validationErrors['title'] = 'title is required';
    }

    final amountError = RequestValidators.validateBalance(amount);
    if (amountError != null) {
      validationErrors['amount'] = amountError;
    }

    if (isExpense is! bool) {
      validationErrors['is_expense'] = 'is_expense must be a boolean';
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

    final pool = context.read<Pool<void>>();

    return await pool.withConnection((connection) async {
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

      final parsedAccountId =
          accountId is int ? accountId : int.parse(accountId as String);
      final parsedAmount = _parseAmount(amount);
      final parsedCategoryId = categoryId is int ? categoryId : null;

      await repository.insertTransaction(
        userId: userId,
        accountId: parsedAccountId,
        title: title as String,
        amount: parsedAmount,
        isExpense: isExpense as bool,
        categoryId: parsedCategoryId,
      );

      return Response.json(statusCode: 201, body: {'success': true});
    });
  } on ServerException catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'database_error',
        message: 'Failed to create transaction',
        details: {'code': error.code},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'internal_error',
        message: 'Unexpected error creating transaction',
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
  if (value is num) {
    return double.parse(value.toStringAsFixed(2));
  }
  if (value is String) {
    return double.parse(double.parse(value.trim()).toStringAsFixed(2));
  }
  throw const FormatException('Invalid amount');
}
