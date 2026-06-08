import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/ledger_entry.dart';
import '../widgets/wallet_card.dart';
import 'database_helper.dart';

/// Reactive financial data-bus backed by local SQLite storage.
class FinanceService extends ChangeNotifier {
  FinanceService({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

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
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final walletRows = await _databaseHelper.getWallets();
      final transactionRows = await _databaseHelper.getTransactions();
      final incomeTotal =
          await _databaseHelper.sumTransactionAmounts(isExpense: false);
      final expenseTotal =
          await _databaseHelper.sumTransactionAmounts(isExpense: true);

      _wallets = walletRows
          .map(
            (row) => WalletCarouselItem(
              id: row['id'] as int,
              name: row['name'] as String,
              balance: _parseDouble(row['balance']),
              accountType: row['account_type'] as String,
              typeLabel: row['type_label'] as String,
            ),
          )
          .toList();

      _transactions = transactionRows
          .map(
            (row) => LedgerEntry(
              id: row['id'] as int,
              walletId: row['wallet_id'] as int,
              title: row['title'] as String,
              walletSource: row['wallet_name'] as String,
              amount: _parseDouble(row['amount']),
              isExpense: (row['is_expense'] as int) == 1,
              timestampLabel: row['timestamp_label'] as String,
            ),
          )
          .toList();

      _totalBalance = _wallets.fold<double>(
        0.0,
        (sum, wallet) => sum + wallet.balance,
      );
      _periodIncome = incomeTotal;
      _periodExpenses = expenseTotal;
      _errorMessage = null;
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
    double initialBalance = 0.0,
  }) async {
    await _databaseHelper.insertWallet(
      name: name.trim(),
      accountType: accountType,
      typeLabel: typeLabel,
      initialBalance: initialBalance,
    );
    await fetchFinancialData();
  }

  Future<void> addTransaction({
    required int walletId,
    required String title,
    required double amount,
    required bool isExpense,
  }) async {
    await _databaseHelper.insertTransaction(
      walletId: walletId,
      title: title.trim(),
      amount: amount,
      isExpense: isExpense,
      timestampLabel: _buildTimestampLabel(DateTime.now()),
    );
    await fetchFinancialData();
  }

  Future<void> deleteTransaction({required int id}) async {
    await _databaseHelper.deleteTransaction(id: id);
    await fetchFinancialData();
  }

  static String _buildTimestampLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(target).inDays;

    if (difference == 0) {
      return 'Today';
    }
    if (difference == 1) {
      return 'Yesterday';
    }
    return DateFormat('dd MMM').format(dateTime);
  }

  static double _parseDouble(Object? value) {
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
