import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/finance_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Student\nFinance Tracker',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 42,
                      height: 1.1,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in with your school Microsoft account. Create an account, reset your password, and sync your wallets — all in one secure flow.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      height: 1.4,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22252D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: authService.isLoading
                    ? null
                    : () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final financeService = context.read<FinanceService>();
                        final success =
                            await authService.loginWithMicrosoftOrGoogle();
                        if (!context.mounted) {
                          return;
                        }
                        if (success) {
                          await financeService.fetchFinancialData();
                          if (!context.mounted) {
                            return;
                          }
                          navigator.pushReplacementNamed('/dashboard');
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Authentication route was cancelled or failed.',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                child: authService.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 20),
                          SizedBox(width: 12),
                          Text(
                            'Continue with Identity Flow',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
              const Spacer(),
              
              Center(
                child: Text(
                  'Phase 1 — Account sync & dashboard prototype',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}