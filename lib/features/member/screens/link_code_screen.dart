import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/member_providers.dart';

class LinkCodeScreen extends ConsumerStatefulWidget {
  const LinkCodeScreen({super.key});

  @override
  ConsumerState<LinkCodeScreen> createState() => _LinkCodeScreenState();
}

class _LinkCodeScreenState extends ConsumerState<LinkCodeScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'El código tiene 6 caracteres');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(memberRepositoryProvider).claimWithCode(code);
      // Recargar la ficha: AuthGate pasa automáticamente al Home.
      ref.invalidate(myMemberProvider);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular cuenta'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.qr_code_2,
                      size: 72, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Introduce tu código',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Pídelo en recepción. Lo necesitas solo una vez para '
                    'conectar tu cuenta con tu ficha del gimnasio.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codeCtrl,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(letterSpacing: 8, fontWeight: FontWeight.bold),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                      _UpperCaseFormatter(),
                    ],
                    decoration: InputDecoration(
                      hintText: 'A1B2C3',
                      counterText: '',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Vincular'),
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

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
