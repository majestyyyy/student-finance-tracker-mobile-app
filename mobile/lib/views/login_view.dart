import 'package:flutter/material.dart';
import 'package:tracker_mobile/services/auth_service.dart';
import 'package:tracker_mobile/theme/app_theme.dart';
import 'package:tracker_mobile/views/dashboard_view.dart';

/// Entry screen for Microsoft Entra External ID sign-in.
class LoginView extends StatefulWidget {
  const LoginView({
    super.key,
    this.authService,
  });

  final AuthService? authService;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  late final AuthService _authService;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final signedIn = await _authService.isSignedIn();
    if (!mounted || !signedIn) {
      return;
    }

    final displayName = await _authService.getDisplayName();
    _navigateToDashboard(displayName);
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _authService.signIn();

    if (!mounted) {
      return;
    }

    setState(() => _isLoading = false);

    if (result.success) {
      _navigateToDashboard(result.displayName);
      return;
    }

    setState(() {
      _errorMessage = result.errorMessage ?? 'Sign-in failed';
    });
  }

  void _navigateToDashboard(String? displayName) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DashboardView(userDisplayName: displayName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false, // Allows clean spacer push when layout fits, scrolls when full
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const Text(
                      'Student\nFinance Tracker',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Sign in with your school Microsoft account. '
                      'Create an account, reset your password, and sync '
                      'your wallets — all in one secure flow.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 36),
                    if (_errorMessage != null) ...[
                      Container(
                        constraints: const BoxConstraints(maxHeight: 220), // Caps how far the error box expands
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.accentRed.withValues(alpha: 0.4),
                          ),
                        ),
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppTheme.accentRed,
                              fontSize: 13,
                              fontFamily: 'monospace', // Makes raw debug logs easier to read
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _handleSignIn,
                      icon: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.backgroundDark,
                              ),
                            )
                          : const Icon(Icons.login_rounded),
                      label: Text(
                        _isLoading ? 'Signing in...' : 'Continue with Microsoft',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: AppTheme.backgroundDark,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                    const Spacer(flex: 2),
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Phase 1 — Account sync & dashboard prototype',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}