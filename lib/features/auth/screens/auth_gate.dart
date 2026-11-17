import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../member/providers/member_providers.dart';
import '../../member/screens/link_code_screen.dart';
import '../../subscription/screens/home_screen.dart';
import '../providers/auth_providers.dart';
import 'login_screen.dart';

/// Decide qué pantalla mostrar:
///   sin sesión            -> Login
///   sesión, sin vincular  -> Código de vinculación
///   sesión y vinculado    -> Home (suscripción)
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);

    return session.when(
      loading: () => const _Splash(),
      error: (e, _) => _ErrorView(message: friendlyError(e)),
      data: (s) {
        if (s == null) return const LoginScreen();

        final member = ref.watch(myMemberProvider);
        return member.when(
          loading: () => const _Splash(),
          error: (e, _) => _ErrorView(
            message: friendlyError(e),
            onRetry: () => ref.invalidate(myMemberProvider),
          ),
          data: (m) => m == null ? const LinkCodeScreen() : const HomeScreen(),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              if (onRetry != null)
                FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).signOut(),
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
