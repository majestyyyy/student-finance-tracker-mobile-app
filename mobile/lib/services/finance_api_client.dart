import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/environment.dart';

/// Secure HTTP client for finance API routes (no database credentials in-app).
class FinanceApiClient {
  FinanceApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<FinanceDashboardResponse> fetchDashboard({
    required String azureUserId,
    String? accessToken,
  }) async {
    final uri = Uri.parse(Environment.financeDashboardEndpoint).replace(
      queryParameters: {'azure_user_id': azureUserId},
    );

    final response = await _client.get(
      uri,
      headers: _authorizedHeaders(accessToken),
    );

    final body = _decodeMap(response.body);
    if (response.statusCode == 200) {
      return FinanceDashboardResponse.fromJson(body);
    }

    throw FinanceApiException(
      _extractErrorMessage(body) ??
          'Dashboard request failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<void> createAccount({
    required String azureUserId,
    required String name,
    required String accountType,
    required String typeLabel,
    required String typeGroup,
    double balance = 0.0,
    double? creditLimit,
    double? remainingDebt,
    String? dueDateFlag,
    String currencyCode = 'PHP',
    String? accessToken,
  }) async {
    final response = await _client.post(
      Uri.parse(Environment.financeAccountsEndpoint),
      headers: _authorizedHeaders(accessToken),
      body: jsonEncode({
        'azure_user_id': azureUserId,
        'name': name,
        'account_type': accountType,
        'type_label': typeLabel,
        'type_group': typeGroup,
        'balance': balance,
        if (creditLimit != null) 'credit_limit': creditLimit,
        if (remainingDebt != null) 'remaining_debt': remainingDebt,
        if (dueDateFlag != null && dueDateFlag.isNotEmpty)
          'due_date_flag': dueDateFlag,
        'currency_code': currencyCode,
      }),
    );

    if (response.statusCode == 201) {
      return;
    }

    final body = _decodeMap(response.body);
    throw FinanceApiException(
      _extractErrorMessage(body) ??
          'Create account failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<void> createTransaction({
    required String azureUserId,
    required int accountId,
    required String title,
    required double amount,
    required bool isExpense,
    int? categoryId,
    String? accessToken,
  }) async {
    final response = await _client.post(
      Uri.parse(Environment.financeTransactionsEndpoint),
      headers: _authorizedHeaders(accessToken),
      body: jsonEncode({
        'azure_user_id': azureUserId,
        'account_id': accountId,
        'title': title,
        'amount': amount,
        'is_expense': isExpense,
        if (categoryId != null) 'category_id': categoryId,
      }),
    );

    if (response.statusCode == 201) {
      return;
    }

    final body = _decodeMap(response.body);
    throw FinanceApiException(
      _extractErrorMessage(body) ??
          'Create transaction failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Future<void> deleteTransaction({
    required String azureUserId,
    required int transactionId,
    String? accessToken,
  }) async {
    final uri = Uri.parse(
      Environment.financeTransactionDeleteEndpoint(transactionId),
    ).replace(queryParameters: {'azure_user_id': azureUserId});

    final response = await _client.delete(
      uri,
      headers: _authorizedHeaders(accessToken),
    );

    if (response.statusCode == 200) {
      return;
    }

    final body = _decodeMap(response.body);
    throw FinanceApiException(
      _extractErrorMessage(body) ??
          'Delete transaction failed (${response.statusCode})',
      statusCode: response.statusCode,
    );
  }

  Map<String, String> _authorizedHeaders(String? accessToken) {
    final headers = Map<String, String>.from(_jsonHeaders);
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  String? _extractErrorMessage(Map<String, dynamic> body) {
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      return error['message'] as String?;
    }
    return body['message'] as String?;
  }
}

class FinanceDashboardResponse {
  const FinanceDashboardResponse({
    required this.accounts,
    required this.transactions,
    required this.summary,
  });

  factory FinanceDashboardResponse.fromJson(Map<String, dynamic> json) {
    final accountsJson = json['accounts'] as List<dynamic>? ?? [];
    final transactionsJson = json['transactions'] as List<dynamic>? ?? [];
    final summaryJson =
        json['summary'] as Map<String, dynamic>? ?? const {};

    return FinanceDashboardResponse(
      accounts: accountsJson
          .map((item) => item as Map<String, dynamic>)
          .toList(),
      transactions: transactionsJson
          .map((item) => item as Map<String, dynamic>)
          .toList(),
      summary: summaryJson,
    );
  }

  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> transactions;
  final Map<String, dynamic> summary;
}

class FinanceApiException implements Exception {
  FinanceApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
