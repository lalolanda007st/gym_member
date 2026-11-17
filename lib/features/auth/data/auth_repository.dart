import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  Stream<AuthState> authStateChanges() => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Devuelve true si la cuenta quedó con sesión iniciada; false si
  /// Supabase exige confirmar el email primero.
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    // El rol NUNCA se envía: el trigger handle_new_user crea siempre 'member'.
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    return res.session != null;
  }

  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() => _client.auth.signOut();
}
