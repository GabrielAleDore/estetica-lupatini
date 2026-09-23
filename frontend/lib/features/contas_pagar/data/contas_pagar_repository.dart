import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

class ContasPagarRepository {
  final SupabaseClient _supabase;

  ContasPagarRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  Stream<List<Map<String, dynamic>>> streamTransacoes() {
    return _supabase.from('transacoes_financeiras').stream(primaryKey: ['id']);
  }

  Future<List<Map<String, dynamic>>> listarContasPagar({
    String? status,
    String? escopo,
  }) async {
    try {
      var query = _supabase
          .from('transacoes_financeiras')
          .select('*, categorias(nome)')
          .eq('tipo', 'SAIDA');

      if (status != null && status != 'TODAS') {
        query = query.eq('status', status);
      }

      if (escopo != null && escopo != 'TODOS') {
        query = query.eq('escopo', escopo);
      }

      final response = await query.order('data_vencimento', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao listar contas a pagar no Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> cadastrarContaPagar(Map<String, dynamic> dados) async {
    try {
      final payload = Map<String, dynamic>.from(dados);
      payload['tipo'] = 'SAIDA';
      if (payload['data_competencia'] == null) {
        payload['data_competencia'] = payload['data_vencimento'] ?? DateTime.now().toIso8601String().substring(0, 10);
      }
      if (payload['status'] == 'PAGO' && payload['data_pagamento'] == null) {
        payload['data_pagamento'] = DateTime.now().toIso8601String().substring(0, 10);
      }

      Map<String, dynamic> res;
      try {
        res = await _supabase.from('transacoes_financeiras').insert(payload).select().single();
      } catch (insertErr) {
        final errText = insertErr.toString();
        if (errText.contains('PGRST204') || errText.contains('conta_bancaria_id')) {
          final fallbackPayload = Map<String, dynamic>.from(payload);
          fallbackPayload.remove('conta_bancaria_id');
          res = await _supabase.from('transacoes_financeiras').insert(fallbackPayload).select().single();
        } else {
          rethrow;
        }
      }
      return Map<String, dynamic>.from(res);
    } catch (e) {
      throw Exception('Erro ao cadastrar despesa: $e');
    }
  }

  Future<void> marcarComoPago(String transacaoId) async {
    try {
      await _supabase.from('transacoes_financeiras').update({
        'status': 'PAGO',
        'data_pagamento': DateTime.now().toIso8601String().substring(0, 10),
      }).eq('id', transacaoId);
    } catch (e) {
      throw Exception('Erro ao marcar despesa como paga: $e');
    }
  }

  Future<void> excluirContaPagar(String transacaoId) async {
    try {
      await _supabase.from('transacoes_financeiras').delete().eq('id', transacaoId);
    } catch (e) {
      throw Exception('Erro ao remover despesa: $e');
    }
  }

  Future<List<Map<String, dynamic>>> listarCategoriasDespesa() async {
    try {
      final res = await _supabase
          .from('categorias')
          .select('*')
          .eq('tipo', 'DESPESA')
          .order('nome');
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return [];
    }
  }
}
