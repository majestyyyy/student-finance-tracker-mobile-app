import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:tracker_api/finance/finance_repository.dart';
import 'package:tracker_api/models/api_error.dart';
import 'package:tracker_api/validation/request_validators.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.delete) {
    return Response(
      statusCode: 405,
      body: const ApiError(
        code: 'method_not_allowed',
        message: 'Only DELETE is supported on /v1/finance/transactions/:id',
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
    final transactionId = int.tryParse(id);
    if (transactionId == null) {
      return Response(
        statusCode: 400,
        body: const ApiError(
          code: 'bad_request',
          message: 'Transaction id must be a valid integer',
        ).toJsonString(),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final azureUserId = context.request.uri.queryParameters['azure_user_id'];
    final validationError = RequestValidators.validateAzureUserId(azureUserId);
    if (validationError != null) {
      return Response(
        statusCode: 422,
        body: ApiError(
          code: 'validation_error',
          message: validationError,
        ).toJsonString(),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final pool = context.read<Pool<void>>();

    return await pool.withConnection((connection) async {
      final repository = FinanceRepository(connection);
      final userId = await repository.resolveUserId(azureUserId!.trim());

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

      await repository.deleteTransaction(
        userId: userId,
        transactionId: transactionId,
      );

      return Response.json(body: {'success': true});
    });
  } on StateError catch (error) {
    return Response(
      statusCode: 404,
      body: ApiError(
        code: 'not_found',
        message: error.message,
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  } on ServerException catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'database_error',
        message: 'Failed to delete transaction',
        details: {'code': error.code},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'internal_error',
        message: 'Unexpected error deleting transaction',
        details: {'reason': error.toString()},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
