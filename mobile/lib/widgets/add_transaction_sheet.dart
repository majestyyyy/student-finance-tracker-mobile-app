import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/finance_service.dart';
import 'wallet_card.dart'; // Handles WalletCarouselItem

class AddTransactionSheet extends StatefulWidget {
  const AddTransactionSheet({super.key});

  /// Static helper method to match main.dart invoker targets
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddTransactionSheet(),
    );
  }

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  
  bool _isExpense = true;
  String? _selectedWalletName;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final financeService = context.watch<FinanceService>();
    final wallets = financeService.wallets;

    if (_selectedWalletName == null && wallets.isNotEmpty) {
      _selectedWalletName = wallets.first.name;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Record Transaction',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Expense')),
                    selected: _isExpense,
                    selectedColor: Colors.redAccent.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: _isExpense ? Colors.redAccent : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) => setState(() => _isExpense = true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Income')),
                    selected: !_isExpense,
                    // Fixed: Changed emeraldAccent to greenAccent
                    selectedColor: Colors.greenAccent.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: !_isExpense ? Colors.greenAccent : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                    onSelected: (val) => setState(() => _isExpense = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Books, Lunch, Stipend',
                border: OutlineInputBorder(),
              ),
              validator: (val) => (val == null || val.isEmpty) ? 'Please fill out a transaction description' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₱)',
                prefixText: '₱ ',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Please enter an amount';
                if (double.tryParse(val) == null || double.parse(val) <= 0) {
                  return 'Please enter a valid amount greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedWalletName,
              decoration: const InputDecoration(
                labelText: 'Select Account Source',
                border: OutlineInputBorder(),
              ),
              items: wallets.map((WalletCarouselItem wallet) {
                return DropdownMenuItem<String>(
                  value: wallet.name,
                  child: Text(wallet.name),
                );
              }).toList(),
              onChanged: (String? newWalletName) {
                setState(() {
                  _selectedWalletName = newWalletName;
                });
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () async {
                if (_formKey.currentState!.validate() && _selectedWalletName != null) {
                  final String title = _titleController.text.trim();
                  final double amount = double.parse(_amountController.text.trim());
                  
                  final targetWallet = wallets.firstWhere((w) => w.name == _selectedWalletName);

                  // Fixed: Utilizing explicitly named parameters to fit your service declaration signature
                  await context.read<FinanceService>().addTransaction(
                        walletId: targetWallet.id,
                        title: title,
                        amount: amount,
                        isExpense: _isExpense,
                      );

                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Save Transaction Entry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}