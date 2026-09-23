import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../domain/models/conta_bancaria_model.dart';

class ContasBancariasRepository {
  final SupabaseClient _supabase;

  ContasBancariasRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  /// Stream em tempo real das contas bancárias
  Stream<List<Map<String, dynamic>>> streamContas() {
    return _supabase.from('contas_bancarias').stream(primaryKey: ['id']);
  }

  /// Lista as contas bancárias com filtros opcionais
  Future<List<ContaBancariaModel>> getContas({
    String? escopo,
    bool apenasAtivas = false,
  }) async {
    try {
      var query = _supabase.from('contas_bancarias').select('*');

      if (apenasAtivas) {
        query = query.eq('ativo', true);
      }

      if (escopo != null && escopo != 'TODOS') {
        query = query.eq('escopo', escopo.toUpperCase());
      }

      final res = await query.order('nome_conta', ascending: true);
      final list = res as List<dynamic>;
      return list.map((item) => ContaBancariaModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Erro ao listar contas bancárias do Supabase: $e');
    }
  }

  /// Cadastra uma nova conta bancária
  Future<ContaBancariaModel> createConta(ContaBancariaModel conta) async {
    try {
      final res = await _supabase
          .from('contas_bancarias')
          .insert(conta.toSupabaseInsert())
          .select()
          .single();

      return ContaBancariaModel.fromJson(res);
    } catch (e) {
      throw Exception('Erro ao criar conta bancária no Supabase: $e');
    }
  }

  /// Atualiza os dados de uma conta bancária
  Future<ContaBancariaModel> updateConta(ContaBancariaModel conta) async {
    try {
      final res = await _supabase
          .from('contas_bancarias')
          .update(conta.toSupabaseUpdate())
          .eq('id', conta.id)
          .select()
          .single();

      return ContaBancariaModel.fromJson(res);
    } catch (e) {
      throw Exception('Erro ao atualizar conta bancária no Supabase: $e');
    }
  }

  /// Alterna o status ativo/inativo da conta
  Future<void> toggleAtivo(String id, bool ativo) async {
    try {
      await _supabase.from('contas_bancarias').update({
        'ativo': ativo,
      }).eq('id', id);
    } catch (e) {
      throw Exception('Erro ao alterar status da conta bancária: $e');
    }
  }

  /// Inativa a conta logicamente ou remove definitivamente caso solicitado
  Future<void> deleteOuInativarConta(String id, {bool deleteDefinitivo = false}) async {
    try {
      if (deleteDefinitivo) {
        await _supabase.from('contas_bancarias').delete().eq('id', id);
      } else {
        await toggleAtivo(id, false);
      }
    } catch (e) {
      throw Exception('Erro ao inativar/excluir conta bancária: $e');
    }
  }
}
