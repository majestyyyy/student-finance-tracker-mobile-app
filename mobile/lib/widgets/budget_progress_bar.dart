import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tracker_mobile/models/wallet_account.dart';
import 'package:tracker_mobile/theme/app_theme.dart';

/// Spending gauge that shifts from green → orange → red by utilization.
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({
    super.key,
    required this.category,
    this.warningThreshold = 0.75,
    this.dangerThreshold = 1.0,
  });

  final BudgetCategory category;
  final double warningThreshold;
  final double dangerThreshold;

  static final _currencyFormat = NumberFormat.currency(symbol: r'$');

  @override
  Widget build(BuildContext context) {
    final ratio = category.utilizationRatio.clamp(0.0, 1.5);
    final fillColor = _resolveFillColor(ratio);
    final statusLabel = _resolveStatusLabel(ratio);
    final displayRatio = ratio > 1.0 ? 1.0 : ratio;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: fillColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                category.iconEmoji,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fillColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: fillColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 14,
              child: Stack(
                children: [
                  Container(color: AppTheme.surfaceElevated),
                  FractionallySizedBox(
                    widthFactor: displayRatio,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            fillColor.withValues(alpha: 0.85),
                            fillColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currencyFormat.format(category.spent)} spent',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'of ${_currencyFormat.format(category.limit)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _resolveFillColor(double ratio) {
    if (ratio >= dangerThreshold) {
      return AppTheme.accentRed;
    }
    if (ratio >= warningThreshold) {
      return AppTheme.accentOrange;
    }
    return AppTheme.accentLime;
  }

  String _resolveStatusLabel(double ratio) {
    if (ratio >= dangerThreshold) {
      return 'OVER BUDGET';
    }
    if (ratio >= warningThreshold) {
      return 'WATCH IT';
    }
    return 'ON TRACK';
  }
}
