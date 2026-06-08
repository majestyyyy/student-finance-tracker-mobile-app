import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/wallet_carousel_item.dart';
import '../services/finance_service.dart';

/// Bottom sheet for creating a new wallet card.
class AddWalletSheet extends StatefulWidget {
  const AddWalletSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWalletSheet(),
    );
  }

  @override
  State<AddWalletSheet> createState() => _AddWalletSheetState();
}

class _AddWalletSheetState extends State<AddWalletSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  final _creditLimitController = TextEditingController(text: '0');
  final _debtTotalController = TextEditingController(text: '0');
  final _dueDateController = TextEditingController();

  String _selectedAccountType = 'cash';
  bool _isSubmitting = false;

  String get _selectedTypeGroup =>
      FinanceService.resolveTypeGroup(_selectedAccountType);

  bool get _isCreditWallet => _selectedTypeGroup == WalletTypeGroup.credit;
  bool get _isDebtWallet => _selectedTypeGroup == WalletTypeGroup.debt;
  bool get _isAssetWallet => _selectedTypeGroup == WalletTypeGroup.asset;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _creditLimitController.dispose();
    _debtTotalController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                        color: colorScheme.outline.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    'Add Wallet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _walletTypeDescription(_selectedTypeGroup),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Wallet name',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a wallet name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedAccountType,
                    decoration: const InputDecoration(
                      labelText: 'Account type',
                      border: OutlineInputBorder(),
                    ),
                    items: kAccountTypeLabels.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: _isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedAccountType = value);
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  if (_isAssetWallet) ...[
                    TextFormField(
                      controller: _balanceController,
                      decoration: const InputDecoration(
                        labelText: 'Starting balance (₱)',
                        border: OutlineInputBorder(),
                        prefixText: '₱ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: _validateAmountField,
                    ),
                  ],
                  if (_isCreditWallet) ...[
                    TextFormField(
                      controller: _creditLimitController,
                      decoration: const InputDecoration(
                        labelText: 'Credit limit (₱)',
                        border: OutlineInputBorder(),
                        prefixText: '₱ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a credit limit';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Credit limit must be greater than zero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _balanceController,
                      decoration: const InputDecoration(
                        labelText: 'Current utilization (₱)',
                        helperText: 'Amount already charged to the card',
                        border: OutlineInputBorder(),
                        prefixText: '₱ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: _validateAmountField,
                    ),
                  ],
                  if (_isDebtWallet) ...[
                    TextFormField(
                      controller: _debtTotalController,
                      decoration: const InputDecoration(
                        labelText: 'Outstanding debt total (₱)',
                        border: OutlineInputBorder(),
                        prefixText: '₱ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter the outstanding debt amount';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed < 0) {
                          return 'Enter a valid debt amount';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (_isCreditWallet || _isDebtWallet) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dueDateController,
                      decoration: InputDecoration(
                        labelText: _isCreditWallet
                            ? 'Payment due schedule'
                            : 'Installment due schedule',
                        hintText: 'Every 15th',
                        border: const OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Wallet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _walletTypeDescription(String typeGroup) {
    switch (typeGroup) {
      case WalletTypeGroup.credit:
        return 'Credit cards track utilization against a limit. Expenses increase owed balance.';
      case WalletTypeGroup.debt:
        return 'BNPL and installment accounts track outstanding debt separately from cash assets.';
      case WalletTypeGroup.asset:
      default:
        return 'Asset wallets hold spendable cash, bank, or e-wallet balances.';
    }
  }

  String? _validateAmountField(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter an amount';
    }
    if (double.tryParse(value.trim()) == null) {
      return 'Enter a valid amount';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final walletName = _nameController.text.trim();
    final accountType = _selectedAccountType;
    final typeLabel = kAccountTypeLabels[accountType] ?? 'Account';
    final typeGroup = FinanceService.resolveTypeGroup(accountType);

    double initialBalance = 0.0;
    double? creditLimit;
    double? remainingDebt;
    String? dueDateFlag;

    if (_isAssetWallet) {
      initialBalance = double.parse(_balanceController.text.trim());
    } else if (_isCreditWallet) {
      creditLimit = double.parse(_creditLimitController.text.trim());
      initialBalance = double.parse(_balanceController.text.trim());
      dueDateFlag = _dueDateController.text.trim();
    } else if (_isDebtWallet) {
      remainingDebt = double.parse(_debtTotalController.text.trim());
      dueDateFlag = _dueDateController.text.trim();
    }

    setState(() => _isSubmitting = true);

    try {
      await context.read<FinanceService>().addWallet(
            name: walletName,
            accountType: accountType,
            typeLabel: typeLabel,
            typeGroup: typeGroup,
            initialBalance: initialBalance,
            creditLimit: creditLimit,
            remainingDebt: remainingDebt,
            dueDateFlag: dueDateFlag,
          );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create wallet: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
