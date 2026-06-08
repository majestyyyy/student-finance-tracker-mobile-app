/// Wallet type hierarchy accounting matrix for Azure PostgreSQL accounts.
abstract final class WalletTypeGroup {
  static const String asset = 'asset';
  static const String credit = 'credit';
  static const String debt = 'debt';

  static const Set<String> values = {asset, credit, debt};
}

/// Applies or inverts balance updates based on [typeGroup].
Map<String, String> computeWalletUpdates({
  required String typeGroup,
  required double currentBalance,
  required double remainingDebt,
  required double amount,
  required bool isExpense,
  required bool revert,
}) {
  final normalizedAmount = double.parse(amount.toStringAsFixed(2));

  switch (typeGroup) {
    case WalletTypeGroup.asset:
      final nextBalance = isExpense
          ? currentBalance + (revert ? normalizedAmount : -normalizedAmount)
          : currentBalance + (revert ? -normalizedAmount : normalizedAmount);
      return {
        'balance': double.parse(nextBalance.toStringAsFixed(2)).toStringAsFixed(2),
      };

    case WalletTypeGroup.credit:
      final nextUtilization = isExpense
          ? currentBalance + (revert ? -normalizedAmount : normalizedAmount)
          : currentBalance + (revert ? normalizedAmount : -normalizedAmount);
      return {
        'balance': double.parse(nextUtilization.toStringAsFixed(2)).toStringAsFixed(2),
      };

    case WalletTypeGroup.debt:
      final nextDebt = isExpense
          ? remainingDebt + (revert ? -normalizedAmount : normalizedAmount)
          : remainingDebt + (revert ? normalizedAmount : -normalizedAmount);
      return {
        'remaining_debt':
            double.parse(nextDebt.toStringAsFixed(2)).toStringAsFixed(2),
      };

    default:
      throw StateError('Unsupported wallet type_group: $typeGroup');
  }
}

double parseDecimal(dynamic value) {
  if (value == null) {
    return 0.0;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is double) {
    return value;
  }
  if (value is BigInt) {
    return value.toDouble();
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 0.0;
    }
    return double.parse(trimmed);
  }
  return double.parse(value.toString());
}

/// Coerces PostgreSQL integer columns (SERIAL, INTEGER) to [int].
int parseIntValue(dynamic value) {
  if (value == null) {
    throw FormatException('Expected integer value, got null');
  }
  if (value is int) {
    return value;
  }
  if (value is BigInt) {
    return value.toInt();
  }
  if (value is String) {
    return int.parse(value.trim());
  }
  return int.parse(value.toString());
}

/// Coerces PostgreSQL text columns to a trimmed [String].
String parseStringValue(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value.trim();
  }
  return value.toString().trim();
}

/// Coerces nullable PostgreSQL text columns.
String? parseNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = parseStringValue(value);
  return text.isEmpty ? null : text;
}

/// Coerces PostgreSQL boolean columns.
bool parseBoolValue(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value == 1;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == 't' ||
        normalized == '1' ||
        normalized == 'yes';
  }
  return false;
}
