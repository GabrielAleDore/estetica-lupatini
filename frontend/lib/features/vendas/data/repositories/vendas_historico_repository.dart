import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class VendasHistoricoRepository {
  final SupabaseClient _supabase;

  VendasHistoricoRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  Stream<List<Map<String, dynamic>>> streamVendas() {
    return _supabase.from('vendas').stream(primaryKey: ['id']);
  }

  Stream<List<Map<String, dynamic>>> streamTransacoes() {
    return _supabase.from('transacoes_financeiras').stream(primaryKey: ['id']);
  }

  Future<List<Map<String, dynamic>>> listarVendas({
    String? statusPagamento,
    String? buscaCliente,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      // 1. Carrega vendas registradas pelo PDV
      var queryVendas = _supabase.from('vendas').select(
        '*, clientes(nome, telefone, cpf), itens_venda(*, produtos(nome, codigo_sequencial), servicos(nome, codigo_sequencial))',
      );

      if (statusPagamento != null && statusPagamento != 'TODOS') {
        queryVendas = queryVendas.eq('status_pagamento', statusPagamento);
      }

      if (dataInicio != null) {
        queryVendas = queryVendas.gte('data_hora', dataInicio.toIso8601String());
      }

      if (dataFim != null) {
        queryVendas = queryVendas.lte('data_hora', dataFim.toIso8601String());
      }

      final responseVendas = await queryVendas.order('data_hora', ascending: false);
      final listaVendas = List<Map<String, dynamic>>.from(responseVendas);

      // 2. Carrega entradas/receitas avulsas registradas diretamente (tabela transacoes_financeiras)
      List<Map<String, dynamic>> transacoesAvulsas = [];
      try {
        var queryTransacoes = _supabase
            .from('transacoes_financeiras')
            .select('*')
            .inFilter('tipo', ['ENTRADA', 'RECEITA'])
            .filter('venda_id', 'is', null);

        if (dataInicio != null) {
          queryTransacoes = queryTransacoes.gte('data_transacao', dataInicio.toIso8601String().substring(0, 10));
        }
        if (dataFim != null) {
          queryTransacoes = queryTransacoes.lte('data_transacao', dataFim.toIso8601String().substring(0, 10));
        }

        final responseTransacoes = await queryTransacoes.order('data_transacao', ascending: false).limit(100);
        transacoesAvulsas = List<Map<String, dynamic>>.from(responseTransacoes as List);
      } catch (_) {
        transacoesAvulsas = [];
      }

      final listaAvulsasFormatadas = transacoesAvulsas.map((t) {
        final dataStr = (t['data_transacao'] ?? t['data_competencia'] ?? t['created_at'] ?? '').toString();
        final valor = (t['valor_total'] as num?)?.toDouble() ?? (t['valor'] as num?)?.toDouble() ?? 0.0;
        final desc = (t['descricao'] ?? 'Entrada / Receita Avulsa').toString();
        final statusRaw = (t['status'] ?? 'EFETIVADO').toString().toUpperCase();
        final isPendente = statusRaw == 'PENDENTE';
        final statusPag = isPendente ? 'PENDENTE' : 'EFETIVADO';

        String formaPag = (t['forma_pagamento'] ?? '').toString();
        if (formaPag.isEmpty) {
          final upperDesc = desc.toUpperCase();
          if (upperDesc.contains('PIX')) {
            formaPag = 'PIX';
          } else if (upperDesc.contains('DINHEIRO')) {
            formaPag = 'DINHEIRO';
          } else if (upperDesc.contains('CARTÃO') || upperDesc.contains('CARTAO')) {
            formaPag = 'CARTÃO';
          } else {
            formaPag = 'PIX';
          }
        }

        return <String, dynamic>{
          'id': t['id'],
          'is_avulsa': true,
          'data_hora': dataStr.isNotEmpty ? dataStr : DateTime.now().toIso8601String(),
          'data_prevista_pagamento': t['data_vencimento'],
          'status': statusRaw == 'CANCELADA' ? 'CANCELADA' : 'CONCLUIDA',
          'status_pagamento': statusPag,
          'valor_liquido': valor,
          'valor_bruto': valor,
          'valor_original': valor,
          'valor_desconto': 0.0,
          'forma_pagamento': formaPag,
          'observacoes': desc,
          'clientes': {
            'nome': desc,
          },
          'itens_venda': <Map<String, dynamic>>[
            {
              'quantidade': 1.0,
              'preco_unitario': valor,
              'subtotal': valor,
              'produtos': null,
              'servicos': {'nome': desc},
            }
          ],
        };
      }).toList();

      // Aplica filtros nas entradas avulsas
      final avulsasFiltradas = listaAvulsasFormatadas.where((t) {
        if (statusPagamento != null && statusPagamento != 'TODOS') {
          if (t['status_pagamento'] != statusPagamento) return false;
        }

        final dataHoraStr = t['data_hora'] as String?;
        if (dataHoraStr != null && dataHoraStr.isNotEmpty) {
          final dt = DateTime.tryParse(dataHoraStr);
          if (dt != null) {
            if (dataInicio != null && dt.isBefore(dataInicio)) return false;
            if (dataFim != null && dt.isAfter(dataFim)) return false;
          }
        }

        return true;
      }).toList();

      // Concatena vendas PDV e entradas avulsas
      var listaCompleta = [...listaVendas, ...avulsasFiltradas];

      // Filtro de busca por nome/descrição
      if (buscaCliente != null && buscaCliente.trim().isNotEmpty) {
        final termo = buscaCliente.trim().toLowerCase();
        listaCompleta = listaCompleta.where((v) {
          final cliente = v['clientes'] as Map<String, dynamic>?;
          final nome = cliente?['nome']?.toString().toLowerCase() ?? '';
          final obs = v['observacoes']?.toString().toLowerCase() ?? '';
          return nome.contains(termo) || obs.contains(termo);
        }).toList();
      }

      // Ordena por data decrescente
      listaCompleta.sort((a, b) {
        final dtA = DateTime.tryParse(a['data_hora']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dtB = DateTime.tryParse(b['data_hora']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dtB.compareTo(dtA);
      });

      return listaCompleta;
    } catch (e) {
      throw Exception('Erro ao carregar histórico de vendas e receitas: $e');
    }
  }

  Future<Map<String, dynamic>> darBaixaVenda(String vendaId, String formaPagamento, {String? contaBancariaId}) async {
    try {
      try {
        final params = <String, dynamic>{
          'p_venda_id': vendaId,
          'p_forma_pagamento': formaPagamento,
          if (contaBancariaId != null && contaBancariaId.isNotEmpty)
            'p_conta_bancaria_id': contaBancariaId,
        };
        final res = await _supabase.rpc(
          'dar_baixa_venda_pendente',
          params: params,
        );
        return Map<String, dynamic>.from(res as Map);
      } catch (_) {
        // Se for uma entrada avulsa da tabela transacoes_financeiras
        final updateData = <String, dynamic>{
          'status': 'PAGO',
          'data_pagamento': DateTime.now().toIso8601String().substring(0, 10),
          'forma_pagamento': formaPagamento,
        };
        if (contaBancariaId != null && contaBancariaId.isNotEmpty) {
          updateData['conta_bancaria_id'] = contaBancariaId;
        }
        await _supabase.from('transacoes_financeiras').update(updateData).eq('id', vendaId);
        return {'success': true};
      }
    } catch (e) {
      throw Exception('Erro ao liquidar venda pendente: $e');
    }
  }

  Future<void> cancelarVenda(String vendaId) async {
    try {
      await _supabase.from('vendas').update({'status': 'CANCELADA'}).eq('id', vendaId);
      await _supabase.from('transacoes_financeiras').update({'status': 'CANCELADA'}).eq('venda_id', vendaId);
      await _supabase.from('transacoes_financeiras').update({'status': 'CANCELADA'}).eq('id', vendaId);
    } catch (e) {
      throw Exception('Erro ao cancelar venda: $e');
    }
  }
}
