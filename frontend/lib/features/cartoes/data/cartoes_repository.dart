import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../contas_pagar/data/contas_pagar_repository.dart';

class CartoesRepository {
  final SupabaseClient _supabase;

  CartoesRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  /// Stream em tempo real das parcelas para refletir lançamentos instantaneamente
  Stream<List<Map<String, dynamic>>> streamParcelas(String cartaoId) {
    return _supabase
        .from('parcelas_financeiras')
        .stream(primaryKey: ['id'])
        .eq('cartao_id', cartaoId);
  }

  Future<List<Map<String, dynamic>>> listarCartoes({String? escopo}) async {
    try {
      var query = _supabase.from('contas_cartoes').select('*').eq('ativo', true);
      if (escopo != null && escopo != 'TODOS') {
        query = query.eq('escopo', escopo);
      }
      final cartoes = await query.order('nome');
      if (cartoes.isEmpty) return [];

      final pendentesRes = await _supabase
          .from('parcelas_financeiras')
          .select('cartao_id, valor_parcela')
          .eq('status', 'PENDENTE');

      final Map<String, double> limitesUtilizados = {};
      for (final p in pendentesRes) {
        final cid = p['cartao_id']?.toString();
        if (cid != null) {
          final val = (p['valor_parcela'] as num?)?.toDouble() ?? 0.0;
          limitesUtilizados[cid] = (limitesUtilizados[cid] ?? 0.0) + val;
        }
      }

      final List<Map<String, dynamic>> resultado = [];
      for (final c in cartoes) {
        final cardMap = Map<String, dynamic>.from(c);
        final cartaoId = cardMap['id']?.toString() ?? '';
        final limiteTotal = (cardMap['limite'] as num?)?.toDouble() ?? 0.0;
        final limiteUtilizado = limitesUtilizados[cartaoId] ?? 0.0;

        cardMap['limite_utilizado'] = limiteUtilizado;
        cardMap['limite_disponivel'] = (limiteTotal - limiteUtilizado).clamp(0.0, double.infinity);
        resultado.add(cardMap);
      }
      return resultado;
    } catch (e) {
      throw Exception('Erro ao listar cartões do Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> cadastrarCartao(Map<String, dynamic> dados) async {
    try {
      final response = await _supabase.from('contas_cartoes').insert(dados).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Erro ao cadastrar cartão no Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> atualizarCartao(String id, Map<String, dynamic> dados) async {
    try {
      final response = await _supabase.from('contas_cartoes').update(dados).eq('id', id).select().single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Erro ao atualizar cartão no Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> consultarFatura(String cartaoId, String mesReferencia) async {
    try {
      final cartaoRes = await _supabase.from('contas_cartoes').select('*').eq('id', cartaoId).single();

      final parcelasRes = await _supabase
          .from('parcelas_financeiras')
          .select('id, cartao_id, transacao_id, numero_parcela, valor_parcela, data_vencimento, status, mes_fatura_referencia, data_pagamento, grupo_parcela_id, transacoes_financeiras(id, descricao, escopo, parcelas, grupo_parcela_id, categoria_id, valor_total)')
          .eq('cartao_id', cartaoId)
          .eq('mes_fatura_referencia', mesReferencia)
          .order('data_vencimento');

      double totalFatura = 0.0;
      final List<Map<String, dynamic>> parcelasFormatadas = [];

      for (final p in parcelasRes) {
        final valor = (p['valor_parcela'] as num?)?.toDouble() ?? 0.0;
        totalFatura += valor;
        final trans = p['transacoes_financeiras'] as Map<String, dynamic>?;

        parcelasFormatadas.add({
          'id': p['id'],
          'transacao_id': p['transacao_id'],
          'cartao_id': p['cartao_id'],
          'descricao': trans?['descricao'] ?? 'Despesa no Cartão',
          'escopo': trans?['escopo'] ?? cartaoRes['escopo'],
          'numero_parcela': p['numero_parcela'],
          'total_parcelas': trans?['parcelas'] ?? 1,
          'grupo_parcela_id': p['grupo_parcela_id'] ?? trans?['grupo_parcela_id'],
          'valor_parcela': valor,
          'data_vencimento': p['data_vencimento'],
          'status': p['status'],
          'mes_fatura_referencia': p['mes_fatura_referencia'],
          'data_pagamento': p['data_pagamento'],
          'categoria_id': trans?['categoria_id'],
        });
      }

      // Calcula limite total e utilizado atual do cartão
      final limiteTotal = (cartaoRes['limite'] as num?)?.toDouble() ?? 0.0;
      final pendentesRes = await _supabase
          .from('parcelas_financeiras')
          .select('valor_parcela')
          .eq('cartao_id', cartaoId)
          .eq('status', 'PENDENTE');

      double limiteUtilizado = 0.0;
      for (final p in pendentesRes) {
        limiteUtilizado += (p['valor_parcela'] as num?)?.toDouble() ?? 0.0;
      }

      final diaFechamento = (cartaoRes['dia_fechamento'] as int).toString().padLeft(2, '0');
      final diaVencimento = (cartaoRes['dia_vencimento'] as int).toString().padLeft(2, '0');

      return {
        'cartao_id': cartaoId,
        'cartao_nome': cartaoRes['nome'],
        'escopo': cartaoRes['escopo'],
        'mes_referencia': mesReferencia,
        'valor_total': totalFatura,
        'limite_total': limiteTotal,
        'limite_utilizado': limiteUtilizado,
        'limite_disponivel': (limiteTotal - limiteUtilizado).clamp(0.0, double.infinity),
        'data_fechamento_estimada': '$mesReferencia-$diaFechamento',
        'data_vencimento_real': '$mesReferencia-$diaVencimento',
        'status_fatura': totalFatura > 0 ? 'ABERTA' : 'FECHADA',
        'parcelas': parcelasFormatadas,
      };
    } catch (e) {
      throw Exception('Erro ao consultar fatura do cartão no Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> registrarDespesaCartao(Map<String, dynamic> dados) async {
    try {
      final criadas = await ContasPagarRepository().cadastrarDespesaParcelada(dados);
      return criadas.isNotEmpty ? criadas.first : {'success': true};
    } catch (e) {
      throw Exception('Erro ao registrar despesa no cartão no Supabase: $e');
    }
  }
}
