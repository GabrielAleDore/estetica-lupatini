import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../domain/models/usuario_perfil.dart';

class AuthRepository {
  static const String _keyMasterSession = 'usuario_master_sessao_ativa';
  final SupabaseClient _supabase;

  AuthRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  Future<UsuarioPerfil?> obterUsuarioAtual() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final res = await _supabase
            .from('perfis_usuarios')
            .select('*')
            .eq('id', user.id)
            .maybeSingle();

        if (res != null) {
          return UsuarioPerfil.fromJson(res);
        }

        return UsuarioPerfil(
          id: user.id,
          nome: user.userMetadata?['nome'] as String? ?? user.email?.split('@').first ?? 'Usuário',
          email: user.email ?? '',
          role: (user.userMetadata?['role'] as String? ?? 'ATENDIMENTO').toUpperCase(),
          ativo: true,
        );
      }
    } catch (_) {}

    // Fallback: se Supabase estiver offline, verifica sessão salva localmente
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString(_keyMasterSession);
      if (savedUser != null && savedUser.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(savedUser);
        return UsuarioPerfil.fromJson(data);
      }
    } catch (_) {}

    return null;
  }

  Future<UsuarioPerfil> signIn({
    required String email,
    required String password,
  }) async {
    final cleanInput = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // Verificação de Master Admin (gabriel.dore ou admin)
    final isGabrielMaster = (cleanInput == 'gabriel.dore' ||
            cleanInput == 'gabriel.dore@lupatini.com' ||
            cleanInput == 'gabriel.a.dore2@gmail.com') &&
        (cleanPassword == 'admin123' || cleanPassword == 'Admin@123');

    final isAdminDemo = (cleanInput == 'admin' || cleanInput == 'admin@lupatini.com') &&
        (cleanPassword == 'admin123' || cleanPassword == 'Admin@123');

    if (isGabrielMaster || isAdminDemo) {
      final perfil = UsuarioPerfil(
        id: isGabrielMaster
            ? '00000000-0000-0000-0000-000000000099'
            : '00000000-0000-0000-0000-000000000001',
        nome: isGabrielMaster ? 'Gabriel Doré' : 'Administrador Lupatini',
        email: isGabrielMaster ? 'gabriel.dore@lupatini.com' : 'admin@lupatini.com',
        role: 'MESTRE',
        ativo: true,
      );

      // Tenta login no Supabase em segundo plano ou sincronizar, mas não bloqueia se offline
      try {
        final emailAuth = cleanInput.contains('@') ? cleanInput : '$cleanInput@lupatini.com';
        await _supabase.auth.signInWithPassword(email: emailAuth, password: password);
      } catch (_) {}

      // Salva sessão localmente para persistir no navegador
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyMasterSession, jsonEncode(perfil.toJson()));
      } catch (_) {}

      return perfil;
    }

    try {
      String emailParaAuth = email.trim();
      if (!emailParaAuth.contains('@')) {
        try {
          final perfilLookup = await _supabase
              .from('perfis_usuarios')
              .select('email')
              .or('email.ilike.$emailParaAuth@%,nome.ilike.$emailParaAuth')
              .limit(1)
              .maybeSingle();
          if (perfilLookup != null && perfilLookup['email'] != null) {
            emailParaAuth = perfilLookup['email'] as String;
          } else {
            emailParaAuth = '$emailParaAuth@lupatini.com';
          }
        } catch (_) {
          emailParaAuth = '$emailParaAuth@lupatini.com';
        }
      }

      final authRes = await _supabase.auth.signInWithPassword(
        email: emailParaAuth,
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
      final msg = e.toString().toLowerCase();
      if (msg.contains('failed to fetch') || msg.contains('getaddrinfo') || msg.contains('clientfailed') || msg.contains('network')) {
        throw Exception('O servidor Supabase está inacessível ou pausado no momento. Utilize o usuário master "gabriel.dore" e senha "admin123" para acesso direto.');
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyMasterSession);
    } catch (_) {}
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

  Future<void> excluirUsuario(String id) async {
    try {
      await _supabase.rpc('admin_excluir_usuario', params: {'p_user_id': id});
    } on PostgrestException catch (e) {
      throw Exception('Erro ao excluir colaborador: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao excluir colaborador: $e');
    }
  }
}
