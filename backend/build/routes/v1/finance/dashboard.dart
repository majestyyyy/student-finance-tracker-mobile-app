import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';
import 'package:tracker_api/finance/finance_repository.dart';
import 'package:tracker_api/models/api_error.dart';
import 'package:tracker_api/validation/request_validators.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(
      statusCode: 405,
      body: const ApiError(
        code: 'method_not_allowed',
        message: 'Only GET is supported on /v1/finance/dashboard',
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  }

  try {
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

    final connection = await context.read<Future<Connection>>();
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

    final dashboard = await repository.fetchDashboard(userId);
    return Response.json(body: dashboard);
  } on ServerException catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'database_error',
        message: 'Failed to load finance dashboard',
        details: {'code': error.code},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  } catch (error) {
    return Response(
      statusCode: 500,
      body: ApiError(
        code: 'internal_error',
        message: 'Unexpected error loading finance dashboard',
        details: {'reason': error.toString()},
      ).toJsonString(),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
