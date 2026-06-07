/// Represents a financial account displayed in the dashboard carousel.
class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.accountType,
    required this.balance,
    this.currencyCode = 'USD',
    this.institutionLabel,
  });

  final String id;
  final String name;
  final String accountType;
  final double balance;
  final String currencyCode;
  final String? institutionLabel;

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      id: json['id'].toString(),
      name: json['name'] as String,
      accountType: json['account_type'] as String,
      balance: _parseBalance(json['balance']),
      currencyCode: json['currency_code'] as String? ?? 'USD',
      institutionLabel: json['account_type_display_name'] as String?,
    );
  }

  static double _parseBalance(dynamic value) {
    if (value == null) {
      return 0.0;
    }
    if (value is num) {
      return double.parse(value.toStringAsFixed(2));
    }
    if (value is String) {
      return double.parse(double.parse(value).toStringAsFixed(2));
    }
    return 0.0;
  }
}

/// Budget category gauge data for the dashboard health section.
class BudgetCategory {
  const BudgetCategory({
    required this.name,
    required this.spent,
    required this.limit,
    this.iconEmoji = '💸',
  });

  final String name;
  final double spent;
  final double limit;
  final String iconEmoji;

  double get remaining => (limit - spent).clamp(0, limit);

  double get utilizationRatio => limit <= 0 ? 1.0 : spent / limit;
}
