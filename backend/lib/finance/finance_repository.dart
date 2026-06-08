import 'package:intl/intl.dart';
import 'package:postgres/postgres.dart';

import 'package:tracker_api/finance/wallet_math.dart';

/// Data-access layer aligned with Azure live schema:
/// users.id (VARCHAR Entra sub), accounts.account_type/type_label,
/// accounts.remaining_debt, transactions.created_at (no account_types table).
class FinanceRepository {
  FinanceRepository(this._connection);

  final Connection _connection;

  /// Resolves the Entra External ID subject to users.id (VARCHAR PK).
  Future<String?> resolveUserId(String azureUserId) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        SELECT id
        FROM users
        WHERE id = @id
        LIMIT 1
        ''',
      ),
      parameters: {'id': azureUserId.trim()},
    );

    if (result.isEmpty) {
      return null;
    }

    return parseStringValue(result.first[0]);
  }

  Future<Map<String, dynamic>> fetchDashboard(String userId) async {
    final accounts = await _fetchAccounts(userId);
    final transactions = await _fetchTransactions(userId);

    final assetTotal = accounts
        .where((account) => account['type_group'] == WalletTypeGroup.asset)
        .fold<double>(
          0,
          (sum, account) => sum + (account['balance'] as num).toDouble(),
        );

    final creditUtilized = accounts
        .where((account) => account['type_group'] == WalletTypeGroup.credit)
        .fold<double>(
          0,
          (sum, account) => sum + (account['balance'] as num).toDouble(),
        );

    final incomeTotal = await _sumTransactions(userId, isExpense: false);
    final expenseTotal = await _sumTransactions(userId, isExpense: true);

    return {
      'accounts': accounts,
      'transactions': transactions,
      'summary': {
        'total_balance':
            double.parse((assetTotal - creditUtilized).toStringAsFixed(2)),
        'period_income': incomeTotal,
        'period_expenses': expenseTotal,
      },
    };
  }

  Future<List<Map<String, dynamic>>> _fetchAccounts(String userId) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        SELECT
          id,
          name,
          balance,
          type_group,
          credit_limit,
          remaining_debt,
          due_date_flag,
          currency_code,
          account_type,
          type_label
        FROM accounts
        WHERE user_id = @user_id
        ORDER BY id ASC
        ''',
      ),
      parameters: {'user_id': userId},
    );

    return result.map(_mapAccountRow).toList();
  }

  Map<String, dynamic> _mapAccountRow(ResultRow row) {
    return {
      'id': parseIntValue(row[0]),
      'name': parseStringValue(row[1]),
      'balance': parseDecimal(row[2]),
      'type_group': parseStringValue(row[3], fallback: WalletTypeGroup.asset),
      'credit_limit': parseDecimal(row[4]),
      'remaining_debt': parseDecimal(row[5]),
      'due_date_flag': parseNullableString(row[6]),
      'currency_code': parseStringValue(row[7], fallback: 'PHP'),
      'account_type': parseStringValue(row[8], fallback: 'cash'),
      'type_label': parseStringValue(row[9], fallback: 'Cash'),
    };
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions(String userId) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        SELECT
          t.id,
          t.account_id,
          t.title,
          t.amount,
          t.is_expense,
          t.created_at,
          a.name AS account_name,
          a.type_group
        FROM transactions t
        INNER JOIN accounts a ON a.id = t.account_id
        WHERE t.user_id = @user_id
        ORDER BY t.id DESC
        ''',
      ),
      parameters: {'user_id': userId},
    );

    return result.map(_mapTransactionRow).toList();
  }

  Map<String, dynamic> _mapTransactionRow(ResultRow row) {
    final createdAt = _parseTimestamp(row[5]);
    return {
      'id': parseIntValue(row[0]),
      'account_id': parseIntValue(row[1]),
      'title': parseStringValue(row[2]),
      'amount': parseDecimal(row[3]),
      'is_expense': parseBoolValue(row[4]),
      'timestamp_label': _buildTimestampLabel(createdAt),
      'account_name': parseStringValue(row[6]),
      'type_group': parseStringValue(row[7], fallback: WalletTypeGroup.asset),
    };
  }

  Future<double> _sumTransactions(String userId, {required bool isExpense}) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        SELECT COALESCE(SUM(amount), 0) AS total
        FROM transactions
        WHERE user_id = @user_id
          AND is_expense = @is_expense
        ''',
      ),
      parameters: {
        'user_id': userId,
        'is_expense': isExpense,
      },
    );

    return parseDecimal(result.first[0]);
  }

  Future<int> insertAccount({
    required String userId,
    required String name,
    required String accountType,
    required String typeLabel,
    required String typeGroup,
    required double balance,
    double? creditLimit,
    double? remainingDebt,
    String? dueDateFlag,
    String currencyCode = 'PHP',
  }) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        INSERT INTO accounts (
          user_id,
          account_type,
          type_label,
          name,
          type_group,
          balance,
          credit_limit,
          remaining_debt,
          due_date_flag,
          currency_code
        )
        VALUES (
          @user_id,
          @account_type,
          @type_label,
          @name,
          @type_group,
          @balance::DECIMAL(15, 2),
          @credit_limit::DECIMAL(15, 2),
          @remaining_debt::DECIMAL(15, 2),
          @due_date_flag,
          @currency_code
        )
        RETURNING id
        ''',
      ),
      parameters: {
        'user_id': userId,
        'account_type': accountType.trim().toLowerCase(),
        'type_label': typeLabel.trim(),
        'name': name.trim(),
        'type_group': typeGroup,
        'balance': balance.toStringAsFixed(2),
        'credit_limit': creditLimit?.toStringAsFixed(2),
        'remaining_debt': remainingDebt?.toStringAsFixed(2),
        'due_date_flag': dueDateFlag,
        'currency_code': currencyCode,
      },
    );

    return parseIntValue(result.first[0]);
  }

  Future<void> insertTransaction({
    required String userId,
    required int accountId,
    required String title,
    required double amount,
    required bool isExpense,
    int? categoryId,
  }) async {
    final normalizedAmount = double.parse(amount.toStringAsFixed(2));

    await _connection.runTx((Session txn) async {
      final accountRows = await txn.execute(
        Sql.named(
          '''
          SELECT type_group, balance, remaining_debt
          FROM accounts
          WHERE id = @account_id
            AND user_id = @user_id
          FOR UPDATE
          ''',
        ),
        parameters: {
          'account_id': accountId,
          'user_id': userId,
        },
      );

      if (accountRows.isEmpty) {
        throw StateError('Account $accountId not found for user $userId');
      }

      final account = accountRows.first;
      final typeGroup = parseStringValue(account[0], fallback: WalletTypeGroup.asset);
      final currentBalance = parseDecimal(account[1]);
      final remainingDebt = parseDecimal(account[2]);

      await txn.execute(
        Sql.named(
          '''
          INSERT INTO transactions (
            user_id,
            account_id,
            category_id,
            title,
            amount,
            is_expense
          )
          VALUES (
            @user_id,
            @account_id,
            @category_id,
            @title,
            @amount::DECIMAL(15, 2),
            @is_expense
          )
          ''',
        ),
        parameters: {
          'user_id': userId,
          'account_id': accountId,
          'category_id': categoryId,
          'title': title.trim(),
          'amount': normalizedAmount.toStringAsFixed(2),
          'is_expense': isExpense,
        },
      );

      final updates = computeWalletUpdates(
        typeGroup: typeGroup,
        currentBalance: currentBalance,
        remainingDebt: remainingDebt,
        amount: normalizedAmount,
        isExpense: isExpense,
        revert: false,
      );

      if (updates.containsKey('balance')) {
        await txn.execute(
          Sql.named(
            '''
            UPDATE accounts
            SET balance = @balance::DECIMAL(15, 2)
            WHERE id = @account_id
            ''',
          ),
          parameters: {
            'balance': updates['balance'],
            'account_id': accountId,
          },
        );
      }

      if (updates.containsKey('remaining_debt')) {
        await txn.execute(
          Sql.named(
            '''
            UPDATE accounts
            SET remaining_debt = @remaining_debt::DECIMAL(15, 2)
            WHERE id = @account_id
            ''',
          ),
          parameters: {
            'remaining_debt': updates['remaining_debt'],
            'account_id': accountId,
          },
        );
      }
    });
  }

  Future<void> deleteTransaction({
    required String userId,
    required int transactionId,
  }) async {
    await _connection.runTx((Session txn) async {
      final transactionRows = await txn.execute(
        Sql.named(
          '''
          SELECT account_id, amount, is_expense
          FROM transactions
          WHERE id = @id AND user_id = @user_id
          LIMIT 1
          ''',
        ),
        parameters: {
          'id': transactionId,
          'user_id': userId,
        },
      );

      if (transactionRows.isEmpty) {
        throw StateError('Transaction $transactionId not found');
      }

      final row = transactionRows.first;
      final accountId = parseIntValue(row[0]);
      final amount = parseDecimal(row[1]);
      final isExpense = parseBoolValue(row[2]);

      final accountRows = await txn.execute(
        Sql.named(
          '''
          SELECT type_group, balance, remaining_debt
          FROM accounts
          WHERE id = @account_id AND user_id = @user_id
          FOR UPDATE
          ''',
        ),
        parameters: {
          'account_id': accountId,
          'user_id': userId,
        },
      );

      if (accountRows.isEmpty) {
        throw StateError('Account $accountId not found');
      }

      final account = accountRows.first;
      final typeGroup = parseStringValue(account[0], fallback: WalletTypeGroup.asset);
      final currentBalance = parseDecimal(account[1]);
      final remainingDebt = parseDecimal(account[2]);

      final updates = computeWalletUpdates(
        typeGroup: typeGroup,
        currentBalance: currentBalance,
        remainingDebt: remainingDebt,
        amount: amount,
        isExpense: isExpense,
        revert: true,
      );

      await txn.execute(
        Sql.named(
          '''
          DELETE FROM transactions
          WHERE id = @id AND user_id = @user_id
          ''',
        ),
        parameters: {
          'id': transactionId,
          'user_id': userId,
        },
      );

      if (updates.containsKey('balance')) {
        await txn.execute(
          Sql.named(
            '''
            UPDATE accounts
            SET balance = @balance::DECIMAL(15, 2)
            WHERE id = @account_id
            ''',
          ),
          parameters: {
            'balance': updates['balance'],
            'account_id': accountId,
          },
        );
      }

      if (updates.containsKey('remaining_debt')) {
        await txn.execute(
          Sql.named(
            '''
            UPDATE accounts
            SET remaining_debt = @remaining_debt::DECIMAL(15, 2)
            WHERE id = @account_id
            ''',
          ),
          parameters: {
            'remaining_debt': updates['remaining_debt'],
            'account_id': accountId,
          },
        );
      }
    });
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return DateTime.now();
  }

  String _buildTimestampLabel(DateTime dateTime) {
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
}
