import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/security_provider.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _authenticationRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _authenticationRequested = false;
      context.read<SecurityProvider>().lock();
    }
  }

  Future<void> _requestUnlock(SecurityProvider security) async {
    if (_authenticationRequested ||
        security.isAuthenticating ||
        security.isUnlocked) {
      return;
    }

    _authenticationRequested = true;
    await security.unlock();

    if (mounted) {
      _authenticationRequested = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final security = context.watch<SecurityProvider>();

    if (!security.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!security.appLockEnabled || security.isUnlocked) {
      return widget.child;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _requestUnlock(security);
      }
    });

    return _LockScreen(
      loading: security.isAuthenticating,
      message: security.message,
      onUnlock: () => security.unlock(),
    );
  }
}

class _LockScreen extends StatelessWidget {
  final bool loading;
  final String? message;
  final VoidCallback onUnlock;

  const _LockScreen({
    required this.loading,
    required this.message,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 38,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'CashBook Locked',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Authenticate with fingerprint, face, PIN, pattern, '
                    'or device password to continue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: loading ? null : onUnlock,
                    icon: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      loading ? 'Authenticating...' : 'Unlock CashBook',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
