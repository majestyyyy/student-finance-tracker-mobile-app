import 'package:flutter/foundation.dart';

import '../models/ledger_entry.dart';
import '../models/wallet_carousel_item.dart';
import 'auth_service.dart';
import 'finance_api_client.dart';

/// Reactive financial data-bus backed by the secure Dart Frog API + Azure PostgreSQL.
class FinanceService extends ChangeNotifier {
  FinanceService({
    required AuthService authService,
    FinanceApiClient? apiClient,
  })  : _authService = authService,
        _apiClient = apiClient ?? FinanceApiClient();

  final AuthService _authService;
  final FinanceApiClient _apiClient;

  List<WalletCarouselItem> _wallets = [];
  List<LedgerEntry> _transactions = [];
  double _totalBalance = 0.0;
  double _periodIncome = 0.0;
  double _periodExpenses = 0.0;
  bool _isLoading = false;
  String? _errorMessage;

  List<WalletCarouselItem> get wallets => List.unmodifiable(_wallets);
  List<LedgerEntry> get transactions => List.unmodifiable(_transactions);
  double get totalBalance => _totalBalance;
  double get periodIncome => _periodIncome;
  double get periodExpenses => _periodExpenses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchFinancialData() async {
    final azureUserId = _authService.azureUserId;
    if (azureUserId == null || azureUserId.isEmpty) {
      _wallets = [];
      _transactions = [];
      _totalBalance = 0;
      _periodIncome = 0;
      _periodExpenses = 0;
      _errorMessage = null;
      notifyListeners();
      return;
    }

    if (!_authService.isUserSynced) {
      final synced = await _authService.ensureUserSynced();
      if (!synced) {
        _errorMessage = _authService.lastSyncError ??
            'User must be synced before loading finance data';
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final dashboard = await _apiClient.fetchDashboard(
        azureUserId: azureUserId,
        accessToken: _authService.accessToken,
      );

      _wallets = dashboard.accounts.map(_mapAccount).toList();
      _transactions = dashboard.transactions.map(_mapTransaction).toList();

      _totalBalance = _parseDouble(dashboard.summary['total_balance']);
      _periodIncome = _parseDouble(dashboard.summary['period_income']);
      _periodExpenses = _parseDouble(dashboard.summary['period_expenses']);
      _errorMessage = null;
    } on FinanceApiException catch (error) {
      _errorMessage = error.message;
      debugPrint('Finance API error: ${error.message}');
    } catch (error) {
      _errorMessage = 'Failed to load financial data: $error';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addWallet({
    required String name,
    required String accountType,
    required String typeLabel,
    required String typeGroup,
    double initialBalance = 0.0,
    double? creditLimit,
    double? remainingDebt,
    String? dueDateFlag,
  }) async {
    final azureUserId = _requireAzureUserId();

    await _apiClient.createAccount(
      azureUserId: azureUserId,
      name: name,
      accountType: accountType,
      typeLabel: typeLabel,
      typeGroup: typeGroup,
      balance: initialBalance,
      creditLimit: creditLimit,
      remainingDebt: remainingDebt,
      dueDateFlag: dueDateFlag,
      accessToken: _authService.accessToken,
    );

    await fetchFinancialData();
  }

  Future<void> addTransaction({
    required int walletId,
    required String title,
    required double amount,
    required bool isExpense,
    int? categoryId,
  }) async {
    final azureUserId = _requireAzureUserId();

    await _apiClient.createTransaction(
      azureUserId: azureUserId,
      accountId: walletId,
      title: title,
      amount: amount,
      isExpense: isExpense,
      categoryId: categoryId,
      accessToken: _authService.accessToken,
    );

    await fetchFinancialData();
  }

  Future<void> deleteTransaction({required int id}) async {
    final azureUserId = _requireAzureUserId();

    await _apiClient.deleteTransaction(
      azureUserId: azureUserId,
      transactionId: id,
      accessToken: _authService.accessToken,
    );

    await fetchFinancialData();
  }

  String _requireAzureUserId() {
    final azureUserId = _authService.azureUserId;
    if (azureUserId == null || azureUserId.isEmpty) {
      throw StateError('User is not authenticated with Azure');
    }
    return azureUserId;
  }

  WalletCarouselItem _mapAccount(Map<String, dynamic> row) {
    return WalletCarouselItem(
      id: row['id'] as int,
      name: row['name'] as String,
      balance: _parseDouble(row['balance']),
      accountType: row['account_type'] as String,
      typeLabel: row['type_label'] as String,
      typeGroup: row['type_group'] as String? ?? WalletTypeGroup.asset,
      creditLimit: _parseDouble(row['credit_limit']),
      remainingDebt: _parseDouble(row['remaining_debt']),
      dueDateFlag: row['due_date_flag'] as String?,
    );
  }

  LedgerEntry _mapTransaction(Map<String, dynamic> row) {
    return LedgerEntry(
      id: row['id'] as int,
      walletId: row['account_id'] as int,
      title: row['title'] as String,
      walletSource: row['account_name'] as String,
      amount: _parseDouble(row['amount']),
      isExpense: row['is_expense'] as bool,
      timestampLabel: row['timestamp_label'] as String,
      walletTypeGroup: row['type_group'] as String? ?? WalletTypeGroup.asset,
    );
  }

  static String resolveTypeGroup(String accountType) {
    return kAccountTypeToGroup[accountType] ?? WalletTypeGroup.asset;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    if (value is String) {
      return double.parse(value);
    }
    return double.parse(value.toString());
  }
}

/// Maps account type codes to human-readable type labels.
const Map<String, String> kAccountTypeLabels = {
  'cash': 'Cash',
  'traditional_bank': 'Bank',
  'digital_bank': 'E-Wallet',
  'credit_card': 'Credit Card',
  'bnpl': 'BNPL',
  'savings': 'Savings',
};

/// Maps account type codes to hierarchy group identifiers.
const Map<String, String> kAccountTypeToGroup = {
  'cash': WalletTypeGroup.asset,
  'traditional_bank': WalletTypeGroup.asset,
  'digital_bank': WalletTypeGroup.asset,
  'savings': WalletTypeGroup.asset,
  'credit_card': WalletTypeGroup.credit,
  'bnpl': WalletTypeGroup.debt,
};
