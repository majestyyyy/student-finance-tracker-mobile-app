import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/ledger_entry.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/finance_service.dart';
import 'services/theme_service.dart';
import 'widgets/add_transaction_sheet.dart';
import 'widgets/add_wallet_sheet.dart';
import 'widgets/wallet_carousel.dart';

// ---------------------------------------------------------------------------
// Semantic design tokens
// ---------------------------------------------------------------------------

abstract final class AppColors {
  static const Color darkCanvas = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF181A20);
  static const Color darkBorder = Color(0xFF22252D);

  static const Color lightCanvas = Color(0xFFF5F7FA);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Color(0xFFE2E8F0);

  static const Color incomeEmerald = Color(0xFF10B981);
  static const Color expenseCrimson = Color(0xFFEF4444);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color primaryBlueDeep = Color(0xFF1D4ED8);

  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);

  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

// ---------------------------------------------------------------------------
// Application entry
// ---------------------------------------------------------------------------

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService();
  final themeService = ThemeService();
  final financeService = FinanceService();

  final bool isLoggedIn = await authService.checkAutoLoginState();
  await financeService.fetchFinancialData();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: authService),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        ChangeNotifierProvider<FinanceService>.value(value: financeService),
      ],
      child: MyApp(isLoggedIn: isLoggedIn),
    ),
  );
}

// ---------------------------------------------------------------------------
// Root application shell
// ---------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      title: 'Student Finance Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: themeService.themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/dashboard': (_) => const DashboardScreen(),
      },
      home: isLoggedIn ? const DashboardScreen() : const LoginScreen(),
    );
  }
}

ThemeData _buildDarkTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryBlue,
    brightness: Brightness.dark,
    surface: AppColors.darkSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.darkCanvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.darkTextPrimary,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    textTheme: _buildTextTheme(
      primary: AppColors.darkTextPrimary,
      secondary: AppColors.darkTextSecondary,
    ),
    iconTheme: const IconThemeData(color: AppColors.darkTextPrimary),
    dividerColor: AppColors.darkBorder,
  );
}

ThemeData _buildLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primaryBlue,
    brightness: Brightness.light,
    surface: AppColors.lightSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.lightCanvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.lightTextPrimary,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
    ),
    textTheme: _buildTextTheme(
      primary: AppColors.lightTextPrimary,
      secondary: AppColors.lightTextSecondary,
    ),
    iconTheme: const IconThemeData(color: AppColors.lightTextPrimary),
    dividerColor: AppColors.lightBorder,
  );
}

TextTheme _buildTextTheme({
  required Color primary,
  required Color secondary,
}) {
  return TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      color: primary,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: primary,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: primary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: secondary,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: secondary,
    ),
  );
}

// ---------------------------------------------------------------------------
// Phase 2 — Dashboard core (SQLite-backed)
// ---------------------------------------------------------------------------

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceService>().fetchFinancialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final financeService = context.watch<FinanceService>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: _DashboardAppBar(
        textTheme: textTheme,
        surfaceColor: surfaceColor,
        borderColor: borderColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddTransactionSheet.show(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Log'),
      ),
      body: SafeArea(
        child: financeService.isLoading && financeService.wallets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: financeService.fetchFinancialData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (financeService.errorMessage != null) ...[
                        _ErrorBanner(message: financeService.errorMessage!),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _AggregateBalanceBanner(
                        textTheme: textTheme,
                        totalBalance: financeService.totalBalance,
                        periodIncome: financeService.periodIncome,
                        periodExpenses: financeService.periodExpenses,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _SectionHeader(
                        title: 'My Accounts & Wallets',
                        trailing: IconButton(
                          onPressed: () => AddWalletSheet.show(context),
                          icon: Icon(
                            Icons.add_circle_outline_rounded,
                            color: colorScheme.primary,
                          ),
                          tooltip: 'Add wallet',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      financeService.wallets.isEmpty
                          ? _EmptyWalletsCard(
                              onAddWallet: () => AddWalletSheet.show(context),
                            )
                          : WalletCarousel(wallets: financeService.wallets),
                      const SizedBox(height: AppSpacing.xxl),
                      _SectionHeader(
                        title: 'Recent Ledger Stream',
                        trailing: TextButton(
                          onPressed: () => AddTransactionSheet.show(context),
                          child: const Text('Log entry'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      financeService.transactions.isEmpty
                          ? _EmptyTransactionsCard(
                              onLogTransaction: () =>
                                  AddTransactionSheet.show(context),
                            )
                          : _TransactionFeed(
                              entries: financeService.transactions,
                              surfaceColor: surfaceColor,
                              borderColor: borderColor,
                              textTheme: textTheme,
                            ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard sub-components
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.expenseCrimson.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(
          color: AppColors.expenseCrimson.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.expenseCrimson,
              ),
        ),
      ),
    );
  }
}

class _EmptyWalletsCard extends StatelessWidget {
  const _EmptyWalletsCard({required this.onAddWallet});

  final VoidCallback onAddWallet;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Text(
              'No wallets yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add your first wallet to start tracking balances.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: onAddWallet,
              icon: const Icon(Icons.add),
              label: const Text('Add Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyTransactionsCard extends StatelessWidget {
  const _EmptyTransactionsCard({required this.onLogTransaction});

  final VoidCallback onLogTransaction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: [
            Text(
              'No transactions logged',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Record an expense or income to populate your ledger.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onLogTransaction,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Log Transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DashboardAppBar({
    required this.textTheme,
    required this.surfaceColor,
    required this.borderColor,
  });

  final TextTheme textTheme;
  final Color surfaceColor;
  final Color borderColor;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final themeService = context.watch<ThemeService>();
    final displayName = authService.displayName ?? 'Student';

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Great to see you,', style: textTheme.bodySmall),
          Text(displayName, style: textTheme.titleLarge),
        ],
      ),
      actions: [
        _AppBarIconButton(
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          icon: themeService.isDarkMode
              ? Icons.light_mode_rounded
              : Icons.dark_mode_rounded,
          tooltip: themeService.isDarkMode
              ? 'Switch to light mode'
              : 'Switch to dark mode',
          onPressed: themeService.toggleTheme,
        ),
        const SizedBox(width: AppSpacing.sm),
        _AppBarIconButton(
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          icon: Icons.logout_rounded,
          iconColor: AppColors.expenseCrimson,
          tooltip: 'Sign out',
          onPressed: () async {
            await authService.logout();
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
            }
          },
        ),
        const SizedBox(width: AppSpacing.md),
      ],
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.surfaceColor,
    required this.borderColor,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.tooltip,
  });

  final Color surfaceColor;
  final Color borderColor;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: borderColor),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor),
        tooltip: tooltip,
      ),
    );
  }
}

class _AggregateBalanceBanner extends StatelessWidget {
  const _AggregateBalanceBanner({
    required this.textTheme,
    required this.totalBalance,
    required this.periodIncome,
    required this.periodExpenses,
  });

  final TextTheme textTheme;
  final double totalBalance;
  final double periodIncome;
  final double periodExpenses;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryBlue, AppColors.primaryBlueDeep],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
            blurRadius: AppSpacing.xl,
            offset: const Offset(0, AppSpacing.sm),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL AVAILABLE BALANCE',
              style: textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _formatPeso(totalBalance),
              style: textTheme.headlineLarge?.copyWith(
                color: Colors.white,
                fontSize: 36,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _MicroSummaryChip(
                    label: 'Income',
                    amount: periodIncome,
                    icon: Icons.south_west_rounded,
                    color: AppColors.incomeEmerald,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _MicroSummaryChip(
                    label: 'Spent',
                    amount: periodExpenses,
                    icon: Icons.north_east_rounded,
                    color: AppColors.expenseCrimson,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MicroSummaryChip extends StatelessWidget {
  const _MicroSummaryChip({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
              ),
              Text(
                _formatPeso(amount),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _TransactionFeed extends StatelessWidget {
  const _TransactionFeed({
    required this.entries,
    required this.surfaceColor,
    required this.borderColor,
    required this.textTheme,
  });

  final List<LedgerEntry> entries;
  final Color surfaceColor;
  final Color borderColor;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return _TransactionTile(
          entry: entries[index],
          surfaceColor: surfaceColor,
          borderColor: borderColor,
          textTheme: textTheme,
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.entry,
    required this.surfaceColor,
    required this.borderColor,
    required this.textTheme,
  });

  final LedgerEntry entry;
  final Color surfaceColor;
  final Color borderColor;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        entry.isExpense ? AppColors.expenseCrimson : AppColors.incomeEmerald;
    final amountPrefix = entry.isExpense ? '-' : '+';
    final amountText = '$amountPrefix${_formatPeso(entry.amount)}';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: accentColor.withValues(alpha: 0.12),
              child: Icon(
                entry.isExpense
                    ? Icons.arrow_outward_rounded
                    : Icons.call_received_rounded,
                color: accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(entry.walletSource, style: textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amountText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(entry.timestampLabel, style: textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
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
