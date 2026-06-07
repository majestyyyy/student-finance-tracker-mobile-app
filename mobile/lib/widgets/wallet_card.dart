import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tracker_mobile/models/wallet_account.dart';
import 'package:tracker_mobile/theme/app_theme.dart';

/// Swipeable wallet card with dynamic theming per account type.
class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.account,
    this.onTap,
  });

  final WalletAccount account;
  final VoidCallback? onTap;

  static final _currencyFormat = NumberFormat.currency(symbol: r'$');

  @override
  Widget build(BuildContext context) {
    final theme = _WalletCardTheme.forAccountType(account.accountType);
    final formattedBalance = _currencyFormat.format(account.balance);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: theme.gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.accentColor.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                theme.backgroundIcon,
                size: 140,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          theme.icon,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          theme.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    account.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (account.institutionLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      account.institutionLabel!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    formattedBalance,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    account.currencyCode,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCardTheme {
  const _WalletCardTheme({
    required this.label,
    required this.icon,
    required this.backgroundIcon,
    required this.gradientColors,
    required this.accentColor,
  });

  final String label;
  final IconData icon;
  final IconData backgroundIcon;
  final List<Color> gradientColors;
  final Color accentColor;

  static _WalletCardTheme forAccountType(String accountType) {
    switch (accountType) {
      case 'cash':
        return const _WalletCardTheme(
          label: 'Cash',
          icon: Icons.payments_rounded,
          backgroundIcon: Icons.attach_money_rounded,
          gradientColors: [Color(0xFF1DB954), Color(0xFF0E7A3E)],
          accentColor: Color(0xFF7CFF6B),
        );
      case 'traditional_bank':
        return const _WalletCardTheme(
          label: 'Traditional Bank',
          icon: Icons.account_balance_rounded,
          backgroundIcon: Icons.domain_rounded,
          gradientColors: [Color(0xFF2C3446), Color(0xFF151A24)],
          accentColor: Color(0xFF8A97B0),
        );
      case 'digital_bank':
        return const _WalletCardTheme(
          label: 'Digital Bank',
          icon: Icons.smartphone_rounded,
          backgroundIcon: Icons.wifi_tethering_rounded,
          gradientColors: [Color(0xFF2563EB), Color(0xFF0EA5E9)],
          accentColor: AppTheme.accentCyan,
        );
      case 'credit_card':
        return const _WalletCardTheme(
          label: 'Credit Card',
          icon: Icons.credit_card_rounded,
          backgroundIcon: Icons.credit_score_rounded,
          gradientColors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
          accentColor: AppTheme.accentPurple,
        );
      case 'bnpl':
        return const _WalletCardTheme(
          label: 'Buy Now Pay Later',
          icon: Icons.schedule_rounded,
          backgroundIcon: Icons.receipt_long_rounded,
          gradientColors: [Color(0xFFF97316), Color(0xFFEA580C)],
          accentColor: AppTheme.accentOrange,
        );
      case 'savings':
        return const _WalletCardTheme(
          label: 'Savings',
          icon: Icons.savings_rounded,
          backgroundIcon: Icons.trending_up_rounded,
          gradientColors: [Color(0xFF0D9488), Color(0xFF047857)],
          accentColor: Color(0xFF34D399),
        );
      default:
        return const _WalletCardTheme(
          label: 'Account',
          icon: Icons.account_balance_wallet_rounded,
          backgroundIcon: Icons.wallet_rounded,
          gradientColors: [Color(0xFF374151), Color(0xFF1F2937)],
          accentColor: AppTheme.textSecondary,
        );
    }
  }
}
