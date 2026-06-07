import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tracker_mobile/models/wallet_account.dart';
import 'package:tracker_mobile/theme/app_theme.dart';

enum QuickAddType { expense, income, transfer }

/// Modal bottom sheet for rapid ledger entry via the central FAB.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({
    super.key,
    required this.accounts,
    this.onSubmit,
  });

  final List<WalletAccount> accounts;
  final void Function(QuickAddSubmission submission)? onSubmit;

  static Future<void> show(
    BuildContext context, {
    required List<WalletAccount> accounts,
    void Function(QuickAddSubmission submission)? onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: QuickAddSheet(
            accounts: accounts,
            onSubmit: onSubmit,
          ),
        );
      },
    );
  }

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet> {
  QuickAddType _selectedType = QuickAddType.expense;
  final TextEditingController _amountController = TextEditingController();
  WalletAccount? _selectedAccount;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Quick Add',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Log spending, income, or transfers in seconds.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 22),
            SegmentedButton<QuickAddType>(
              segments: const [
                ButtonSegment(
                  value: QuickAddType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.remove_circle_outline),
                ),
                ButtonSegment(
                  value: QuickAddType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.add_circle_outline),
                ),
                ButtonSegment(
                  value: QuickAddType.transfer,
                  label: Text('Transfer'),
                  icon: Icon(Icons.swap_horiz_rounded),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() {
                  _selectedType = selection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 52,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary.withValues(alpha: 0.45),
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                ),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, top: 18),
                  child: Text(
                    r'$',
                    style: TextStyle(
                      color: AppTheme.accentCyan,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                errorText: _amountError,
              ),
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() => _amountError = null);
                }
              },
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<WalletAccount>(
              // ignore: deprecated_member_use — controlled selection requires value
              value: _selectedAccount,
              decoration: const InputDecoration(
                labelText: 'Source account',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
              dropdownColor: AppTheme.surfaceElevated,
              items: widget.accounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account,
                      child: Text(
                        account.name,
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: widget.accounts.isEmpty
                  ? null
                  : (value) => setState(() => _selectedAccount = value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _handleSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: _typeAccentColor(_selectedType),
                foregroundColor: AppTheme.backgroundDark,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                _submitLabel(_selectedType),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeAccentColor(QuickAddType type) {
    switch (type) {
      case QuickAddType.expense:
        return AppTheme.accentRed;
      case QuickAddType.income:
        return AppTheme.accentLime;
      case QuickAddType.transfer:
        return AppTheme.accentCyan;
    }
  }

  String _submitLabel(QuickAddType type) {
    switch (type) {
      case QuickAddType.expense:
        return 'Add Expense';
      case QuickAddType.income:
        return 'Add Income';
      case QuickAddType.transfer:
        return 'Record Transfer';
    }
  }

  void _handleSubmit() {
    final rawAmount = _amountController.text.trim();
    final parsedAmount = double.tryParse(rawAmount.isEmpty ? '0' : rawAmount);

    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() {
        _amountError = 'Enter an amount greater than zero';
      });
      return;
    }

    if (_selectedAccount == null) {
      setState(() {
        _amountError = 'Select a source account';
      });
      return;
    }

    final normalizedAmount =
        double.parse(parsedAmount.toStringAsFixed(2));

    final submission = QuickAddSubmission(
      type: _selectedType,
      amount: normalizedAmount,
      account: _selectedAccount!,
    );

    widget.onSubmit?.call(submission);
    Navigator.of(context).pop();
  }
}

class QuickAddSubmission {
  const QuickAddSubmission({
    required this.type,
    required this.amount,
    required this.account,
  });

  final QuickAddType type;
  final double amount;
  final WalletAccount account;
}
