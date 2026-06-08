import 'package:flutter/material.dart';

class WalletCarouselItem {
  final int id;
  final String name;
  final double balance;
  final String accountType;
  final String typeLabel;

  const WalletCarouselItem({
    required this.id,
    required this.name,
    required this.balance,
    required this.accountType,
    required this.typeLabel,
  });
}

class WalletCard extends StatelessWidget {
  final WalletCarouselItem item;
  final bool isDark;

  const WalletCard({
    super.key,
    required this.item,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    LinearGradient cardGradient;

    switch (item.accountType) {
      case 'cash':
        cardGradient = const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case 'savings':
        cardGradient = const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case 'digital_bank':
      default:
        cardGradient = const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardGradient.colors.first.withValues(alpha: isDark ? 0.15 : 0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 120,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.typeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  item.name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPeso(item.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatPeso(double amount) {
    final formatted = amount.toStringAsFixed(2);
    final parts = formatted.split('.');
    final whole = parts.first;
    final fraction = parts.length > 1 ? parts[1] : '00';

    final buffer = StringBuffer('₱');
    for (var index = 0; index < whole.length; index++) {
      if (index > 0 && (whole.length - index) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(whole[index]);
    }
    buffer.write('.$fraction');
    return buffer.toString();
  }
}