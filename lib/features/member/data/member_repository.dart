import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/member.dart';

class MemberRepository {
  MemberRepository(this._client);
  final SupabaseClient _client;

  /// Ficha del miembro vinculada al usuario actual, o null si aún no
  /// ha introducido su código. RLS (members_self_select) limita el resultado.
  Future<Member?> fetchMyMember(String userId) async {
    final row = await _client
        .from('members')
        .select('id, name, email, phone, join_date')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : Member.fromMap(row);
  }

  /// Llama a la RPC claim_member. Lanza PostgrestException con el mensaje
  /// de la función ('Código inválido o caducado', etc.).
  Future<String> claimWithCode(String code) async {
    final id = await _client.rpc(
      'claim_member',
      params: {'p_code': code.trim().toUpperCase()},
    );
    return id as String;
  }
}
