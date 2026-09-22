import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/usuario_perfil.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  Future<UsuarioPerfil?> obterUsuarioAtual() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final res = await _supabase
          .from('perfis_usuarios')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (res != null) {
        return UsuarioPerfil.fromJson(res);
      }

      // Se não encontrou na tabela, constrói a partir dos metadados
      return UsuarioPerfil(
        id: user.id,
        nome: user.userMetadata?['nome'] as String? ?? user.email?.split('@').first ?? 'Usuário',
        email: user.email ?? '',
        role: (user.userMetadata?['role'] as String? ?? 'ATENDIMENTO').toUpperCase(),
        ativo: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<UsuarioPerfil> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final authRes = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = authRes.user;
      if (user == null) {
        throw Exception('Usuário não autenticado.');
      }

      final perfilRes = await _supabase
          .from('perfis_usuarios')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      if (perfilRes != null) {
        final perfil = UsuarioPerfil.fromJson(perfilRes);
        if (!perfil.ativo) {
          await _supabase.auth.signOut();
          throw Exception('Este usuário foi desativado pela administração.');
        }
        return perfil;
      }

      return UsuarioPerfil(
        id: user.id,
        nome: user.userMetadata?['nome'] as String? ?? user.email?.split('@').first ?? 'Usuário',
        email: user.email ?? '',
        role: (user.userMetadata?['role'] as String? ?? 'ATENDIMENTO').toUpperCase(),
        ativo: true,
      );
    } on AuthException catch (e) {
      throw Exception('Falha no login: ${e.message}');
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<List<UsuarioPerfil>> listarUsuarios() async {
    try {
      final res = await _supabase.from('perfis_usuarios').select('*').order('nome');
      return (res as List).map((json) => UsuarioPerfil.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Erro ao listar colaboradores no Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> criarUsuarioAdmin({
    required String nome,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final res = await _supabase.rpc(
        'admin_criar_usuario',
        params: {
          'p_nome': nome.trim(),
          'p_email': email.trim().toLowerCase(),
          'p_password': password,
          'p_role': role.toUpperCase(),
        },
      );
      return Map<String, dynamic>.from(res as Map);
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Erro ao cadastrar usuário: $e');
    }
  }

  Future<void> atualizarStatusUsuario(String id, bool ativo) async {
    try {
      await _supabase.from('perfis_usuarios').update({'ativo': ativo}).eq('id', id);
    } catch (e) {
      throw Exception('Erro ao alterar status do colaborador: $e');
    }
  }
}
