import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tracker_mobile/models/wallet_account.dart';
import 'package:tracker_mobile/theme/app_theme.dart';
import 'package:tracker_mobile/widgets/budget_progress_bar.dart';
import 'package:tracker_mobile/widgets/quick_add_sheet.dart';
import 'package:tracker_mobile/widgets/wallet_card.dart';

/// Phase 1 dashboard prototype assembling wallets, budgets, and quick-add.
class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    this.userDisplayName,
    this.accounts,
    this.budgetCategories,
  });

  final String? userDisplayName;
  final List<WalletAccount>? accounts;
  final List<BudgetCategory>? budgetCategories;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final PageController _walletPageController = PageController(viewportFraction: 0.88);
  int _activeWalletIndex = 0;

  static final _currencyFormat = NumberFormat.currency(symbol: r'$');

  late final List<WalletAccount> _accounts;
  late final List<BudgetCategory> _budgetCategories;

  @override
  void initState() {
    super.initState();
    _accounts = widget.accounts ?? _placeholderAccounts;
    _budgetCategories = widget.budgetCategories ?? _placeholderBudgets;
  }

  @override
  void dispose() {
    _walletPageController.dispose();
    super.dispose();
  }

  double get _totalBalance {
    return _accounts.fold<double>(
      0.0,
      (sum, account) => sum + account.balance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final greetingName = widget.userDisplayName ?? 'Student';

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      floatingActionButton: FloatingActionButton.large(
        onPressed: _openQuickAddSheet,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hey, $greetingName 👋',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Your money at a glance — stay on track this semester.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _TotalBalanceCard(totalBalance: _totalBalance),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'My Wallets',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${_activeWalletIndex + 1} / ${_accounts.length}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 235, // 👈 Increased from 220 to 235 to resolve the 7.0px RenderFlex overflow error
                child: PageView.builder(
                  controller: _walletPageController,
                  itemCount: _accounts.length,
                  onPageChanged: (index) {
                    setState(() => _activeWalletIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return WalletCard(account: _accounts[index]);
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: _ActionCallout(onTap: _openQuickAddSheet),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: const Text(
                  'Budget Health',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverList.separated(
              itemCount: _budgetCategories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: BudgetProgressBar(category: _budgetCategories[index]),
                );
              },
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  void _openQuickAddSheet() {
    QuickAddSheet.show(
      context,
      accounts: _accounts,
      onSubmit: (submission) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.surfaceElevated,
            content: Text(
              'Logged ${submission.type.name} of '
              '${_currencyFormat.format(submission.amount)} '
              'from ${submission.account.name}',
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
        );
      },
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({required this.totalBalance});

  final double totalBalance;

  static final _currencyFormat = NumberFormat.currency(symbol: r'$');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.accentCyan.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Balance',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(totalBalance),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCallout extends StatelessWidget {
  const _ActionCallout({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentCyan.withValues(alpha: 0.22),
                AppTheme.accentLime.withValues(alpha: 0.14),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppTheme.accentCyan.withValues(alpha: 0.35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: AppTheme.accentCyan,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log it now',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tap to open Quick Add — expenses, income, or transfers.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final List<WalletAccount> _placeholderAccounts = [
  const WalletAccount(
    id: '1',
    name: 'Campus Cash',
    accountType: 'cash',
    balance: 84.50,
    institutionLabel: 'Cash',
  ),
  const WalletAccount(
    id: '2',
    name: 'Chase Checking',
    accountType: 'traditional_bank',
    balance: 1240.75,
    institutionLabel: 'Traditional Bank',
  ),
  const WalletAccount(
    id: '3',
    name: 'Chime',
    accountType: 'digital_bank',
    balance: 312.00,
    institutionLabel: 'Digital Bank',
  ),
  const WalletAccount(
    id: '4',
    name: 'Discover It',
    accountType: 'credit_card',
    balance: -186.40,
    institutionLabel: 'Credit Card',
  ),
  const WalletAccount(
    id: '5',
    name: 'Afterpay',
    accountType: 'bnpl',
    balance: -45.00,
    institutionLabel: 'Buy Now Pay Later',
  ),
  const WalletAccount(
    id: '6',
    name: 'Emergency Fund',
    accountType: 'savings',
    balance: 500.00,
    institutionLabel: 'Savings',
  ),
];

final List<BudgetCategory> _placeholderBudgets = [
  const BudgetCategory(
    name: 'Food & Dining',
    spent: 142.30,
    limit: 200.00,
    iconEmoji: '🍔',
  ),
  const BudgetCategory(
    name: 'Transport',
    spent: 58.00,
    limit: 80.00,
    iconEmoji: '🚌',
  ),
  const BudgetCategory(
    name: 'Entertainment',
    spent: 95.50,
    limit: 90.00,
    iconEmoji: '🎮',
  ),
  const BudgetCategory(
    name: 'Textbooks',
    spent: 120.00,
    limit: 250.00,
    iconEmoji: '📚',
  ),
];