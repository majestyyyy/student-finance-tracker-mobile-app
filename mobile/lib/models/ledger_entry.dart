/// A single ledger row rendered in the transaction feed.
class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.title,
    required this.walletSource,
    required this.amount,
    required this.isExpense,
    required this.timestampLabel,
    required this.walletId,
  });

  final int id;
  final String title;
  final String walletSource;
  final double amount;
  final bool isExpense;
  final String timestampLabel;
  final int walletId;
}
