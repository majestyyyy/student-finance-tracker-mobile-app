import 'package:intl/intl.dart';
import 'package:postgres/postgres.dart';

import 'package:tracker_api/finance/wallet_math.dart';

/// Data-access layer for accounts and transactions on Azure PostgreSQL.
class FinanceRepository {
  FinanceRepository(this._connection);

  final Connection _connection;

  Future<int?> resolveUserId(String azureUserId) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        SELECT id
        FROM users
        WHERE azure_user_id = @azure_user_id
        LIMIT 1
        ''',
      ),
      parameters: {'azure_user_id': azureUserId.trim()},
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first[0]! as int;
  }

  Future<Map<String, dynamic>> fetchDashboard(int userId) async {
    final accounts = await _fetchAccounts(userId);
    final transactions = await _fetchTransactions(userId);

    final assetTotal = accounts
        .where((account) => account['type_group'] == WalletTypeGroup.asset)
        .fold<double>(
          0,
          (sum, account) => sum + parseDecimal(account['balance']),
        );

    final creditUtilized = accounts
        .where((account) => account['type_group'] == WalletTypeGroup.credit)
        .fold<double>(
          0,
          (sum, account) => sum + parseDecimal(account['balance']),
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

  Future<List<Map<String, dynamic>>> _fetchAccounts(int userId) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        SELECT
          a.id,
          a.name,
          a.balance,
          a.type_group,
          a.credit_limit,
          a.remaining_debt,
          a.due_date_flag,
          a.currency_code,
          COALESCE(at.code, 'cash') AS account_type,
          COALESCE(at.display_name, a.name) AS type_label
        FROM accounts a
        LEFT JOIN account_types at ON a.account_type_id = at.id
        WHERE a.user_id = @user_id
          AND a.is_active = TRUE
        ORDER BY a.id ASC
        ''',
      ),
      parameters: {'user_id': userId},
    );

    return result
        .map(
          (row) => {
            'id': row[0]! as int,
            'name': row[1]! as String,
            'balance': parseDecimal(row[2]),
            'type_group': row[3]! as String,
            'credit_limit': parseDecimal(row[4]),
            'remaining_debt': parseDecimal(row[5]),
            'due_date_flag': row[6] as String?,
            'currency_code': row[7] as String? ?? 'PHP',
            'account_type': row[8]! as String,
            'type_label': row[9]! as String,
          },
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions(int userId) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        SELECT
          t.id,
          t.account_id,
          t.title,
          t.amount,
          t.is_expense,
          t.timestamp_label,
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

    return result
        .map(
          (row) => {
            'id': row[0]! as int,
            'account_id': row[1]! as int,
            'title': row[2]! as String,
            'amount': parseDecimal(row[3]),
            'is_expense': _parseBool(row[4]),
            'timestamp_label': row[5]! as String,
            'account_name': row[6]! as String,
            'type_group': row[7]! as String,
          },
        )
        .toList();
  }

  Future<double> _sumTransactions(int userId, {required bool isExpense}) async {
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
    required int userId,
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
    final accountTypeId = await _resolveAccountTypeId(accountType);

    final result = await _connection.execute(
      Sql.named(
        '''
        INSERT INTO accounts (
          user_id,
          account_type_id,
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
          @account_type_id,
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
        'account_type_id': accountTypeId,
        'name': name.trim(),
        'type_group': typeGroup,
        'balance': balance.toStringAsFixed(2),
        'credit_limit': creditLimit?.toStringAsFixed(2),
        'remaining_debt': remainingDebt?.toStringAsFixed(2),
        'due_date_flag': dueDateFlag,
        'currency_code': currencyCode,
      },
    );

    return result.first[0]! as int;
  }

  Future<int> _resolveAccountTypeId(String accountType) async {
    final result = await _connection.execute(
      Sql.named(
        '''
        SELECT id
        FROM account_types
        WHERE code = @code AND is_active = TRUE
        LIMIT 1
        ''',
      ),
      parameters: {'code': accountType.trim().toLowerCase()},
    );

    if (result.isEmpty) {
      throw StateError('Unknown account type: $accountType');
    }

    return result.first[0]! as int;
  }

  Future<void> insertTransaction({
    required int userId,
    required int accountId,
    required String title,
    required double amount,
    required bool isExpense,
    int? categoryId,
  }) async {
    final normalizedAmount = double.parse(amount.toStringAsFixed(2));
    final timestampLabel = _buildTimestampLabel(DateTime.now());

    await _connection.runTx((Session txn) async {
      final accountRows = await txn.execute(
        Sql.named(
          '''
          SELECT type_group, balance, remaining_debt
          FROM accounts
          WHERE id = @account_id
            AND user_id = @user_id
            AND is_active = TRUE
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
      final typeGroup = account[0]! as String;
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
            is_expense,
            timestamp_label
          )
          VALUES (
            @user_id,
            @account_id,
            @category_id,
            @title,
            @amount::DECIMAL(15, 2),
            @is_expense,
            @timestamp_label
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
          'timestamp_label': timestampLabel,
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
            SET balance = @balance::DECIMAL(15, 2), updated_at = NOW()
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
            SET remaining_debt = @remaining_debt::DECIMAL(15, 2), updated_at = NOW()
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
    required int userId,
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
      final accountId = row[0]! as int;
      final amount = parseDecimal(row[1]);
      final isExpense = _parseBool(row[2]);

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
      final typeGroup = account[0]! as String;
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
            SET balance = @balance::DECIMAL(15, 2), updated_at = NOW()
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
            SET remaining_debt = @remaining_debt::DECIMAL(15, 2), updated_at = NOW()
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

  static bool _parseBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value == 1;
    }
    if (value is String) {
      return value == 'true' || value == 't' || value == '1';
    }
    return false;
  }
}
