import 'package:supabase_flutter/supabase_flutter.dart';

/// Convierte errores de Supabase en mensajes legibles en español.
String friendlyError(Object error) {
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (msg.contains('email not confirmed')) {
      return 'Confirma tu email antes de iniciar sesión (revisa tu bandeja)';
    }
    if (msg.contains('already registered')) {
      return 'Ya existe una cuenta con ese email';
    }
    if (msg.contains('password')) {
      return 'La contraseña no es válida (mínimo 6 caracteres)';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    // Las RPC lanzan "raise exception '...'" con mensajes ya en español
    return error.message;
  }
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Sin conexión a internet';
  }
  // Mensajes propios lanzados con Exception('...')
  if (text.startsWith('Exception: ')) {
    return text.substring('Exception: '.length);
  }
  return 'Ha ocurrido un error inesperado';
}
