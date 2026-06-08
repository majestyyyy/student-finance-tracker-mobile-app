import 'package:flutter/material.dart';

import '../models/wallet_carousel_item.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.item,
    required this.isDark,
  });

  final WalletCarouselItem item;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardGradient = _gradientForAccountType(item.accountType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cardGradient.colors.first
                .withValues(alpha: isDark ? 0.15 : 0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Icon(
              _iconForTypeGroup(item.typeGroup),
              size: 120,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
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
                      item.amountLabel.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
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
                  item.displaySubtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _formatPeso(item.displayAmount),
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

  static LinearGradient _gradientForAccountType(String accountType) {
    switch (accountType) {
      case 'cash':
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'savings':
      case 'traditional_bank':
        return const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'credit_card':
        return const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'bnpl':
        return const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'digital_bank':
      default:
        return const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  static IconData _iconForTypeGroup(String typeGroup) {
    switch (typeGroup) {
      case WalletTypeGroup.credit:
        return Icons.credit_card_rounded;
      case WalletTypeGroup.debt:
        return Icons.schedule_rounded;
      case WalletTypeGroup.asset:
      default:
        return Icons.account_balance_wallet_rounded;
    }
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
