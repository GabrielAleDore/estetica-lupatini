import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class VendasHistoricoRepository {
  final SupabaseClient _supabase;

  VendasHistoricoRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  Stream<List<Map<String, dynamic>>> streamVendas() {
    return _supabase.from('vendas').stream(primaryKey: ['id']);
  }

  Future<List<Map<String, dynamic>>> listarVendas({
    String? statusPagamento,
    String? buscaCliente,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      var query = _supabase.from('vendas').select(
        '*, clientes(nome, telefone, cpf), itens_venda(*, produtos(nome, codigo_sequencial), servicos(nome, codigo_sequencial))',
      );

      if (statusPagamento != null && statusPagamento != 'TODOS') {
        query = query.eq('status_pagamento', statusPagamento);
      }

      if (dataInicio != null) {
        query = query.gte('data_hora', dataInicio.toIso8601String());
      }

      if (dataFim != null) {
        query = query.lte('data_hora', dataFim.toIso8601String());
      }

      final response = await query.order('data_hora', ascending: false);

      var lista = List<Map<String, dynamic>>.from(response);

      if (buscaCliente != null && buscaCliente.trim().isNotEmpty) {
        final termo = buscaCliente.trim().toLowerCase();
        lista = lista.where((v) {
          final cliente = v['clientes'] as Map<String, dynamic>?;
          final nome = cliente?['nome']?.toString().toLowerCase() ?? '';
          return nome.contains(termo);
        }).toList();
      }

      return lista;
    } catch (e) {
      throw Exception('Erro ao carregar histórico de vendas: $e');
    }
  }

  Future<Map<String, dynamic>> darBaixaVenda(String vendaId, String formaPagamento) async {
    try {
      final res = await _supabase.rpc(
        'dar_baixa_venda_pendente',
        params: {
          'p_venda_id': vendaId,
          'p_forma_pagamento': formaPagamento,
        },
      );
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      throw Exception('Erro ao liquidar venda pendente: $e');
    }
  }

  Future<void> cancelarVenda(String vendaId) async {
    try {
      await _supabase.from('vendas').update({'status': 'CANCELADA'}).eq('id', vendaId);
      await _supabase.from('transacoes_financeiras').update({'status': 'CANCELADA'}).eq('venda_id', vendaId);
    } catch (e) {
      throw Exception('Erro ao cancelar venda: $e');
    }
  }
}
