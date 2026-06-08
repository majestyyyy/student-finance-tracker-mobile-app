/// System wallet hierarchy groups governing balance math rules.
abstract final class WalletTypeGroup {
  static const String asset = 'asset';
  static const String credit = 'credit';
  static const String debt = 'debt';

  static const Set<String> values = {asset, credit, debt};
}

/// Carousel-ready wallet projection sourced from Azure PostgreSQL via API.
class WalletCarouselItem {
  const WalletCarouselItem({
    required this.id,
    required this.name,
    required this.balance,
    required this.accountType,
    required this.typeLabel,
    required this.typeGroup,
    this.creditLimit = 0.0,
    this.remainingDebt = 0.0,
    this.dueDateFlag,
  });

  final int id;
  final String name;

  /// Asset / credit utilization balance stored in [balance].
  final double balance;
  final String accountType;
  final String typeLabel;
  final String typeGroup;
  final double creditLimit;

  /// Outstanding obligation for debt/BNPL accounts (maps to `remaining_debt`).
  final double remainingDebt;
  final String? dueDateFlag;

  /// Primary figure rendered on the wallet card face.
  double get displayAmount {
    switch (typeGroup) {
      case WalletTypeGroup.debt:
        return remainingDebt;
      case WalletTypeGroup.credit:
      case WalletTypeGroup.asset:
      default:
        return balance;
    }
  }

  /// Secondary descriptor beneath the wallet name on the card.
  String get displaySubtitle {
    switch (typeGroup) {
      case WalletTypeGroup.credit:
        final limitText = creditLimit > 0
            ? 'Limit ${_formatCompact(creditLimit)}'
            : 'Credit utilization';
        return dueDateFlag != null ? '$limitText · $dueDateFlag' : limitText;
      case WalletTypeGroup.debt:
        return dueDateFlag != null
            ? 'Installment · $dueDateFlag'
            : 'Outstanding debt';
      case WalletTypeGroup.asset:
      default:
        return typeLabel;
    }
  }

  String get amountLabel {
    switch (typeGroup) {
      case WalletTypeGroup.credit:
        return 'Utilized';
      case WalletTypeGroup.debt:
        return 'Owed';
      case WalletTypeGroup.asset:
      default:
        return 'Balance';
    }
  }

  static String _formatCompact(double amount) {
    return '₱${amount.toStringAsFixed(2)}';
  }
}
