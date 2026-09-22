import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

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

      final List<Map<String, dynamic>> resultado = [];
      for (final c in cartoes) {
        final cardMap = Map<String, dynamic>.from(c);
        final cartaoId = cardMap['id'];
        final limiteTotal = (cardMap['limite'] as num?)?.toDouble() ?? 0.0;

        // Calcula limite utilizado em tempo real com parcelas pendentes
        final pendentesRes = await _supabase
            .from('parcelas_financeiras')
            .select('valor_parcela')
            .eq('cartao_id', cartaoId)
            .eq('status', 'PENDENTE');

        double limiteUtilizado = 0.0;
        for (final p in pendentesRes) {
          limiteUtilizado += (p['valor_parcela'] as num?)?.toDouble() ?? 0.0;
        }

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

  Future<Map<String, dynamic>> consultarFatura(String cartaoId, String mesReferencia) async {
    try {
      final cartaoRes = await _supabase.from('contas_cartoes').select('*').eq('id', cartaoId).single();

      final parcelasRes = await _supabase
          .from('parcelas_financeiras')
          .select('id, cartao_id, transacao_id, numero_parcela, valor_parcela, data_vencimento, status, mes_fatura_referencia, data_pagamento, transacoes_financeiras(descricao, escopo)')
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
          'descricao': trans?['descricao'] ?? 'Despesa no Cartão',
          'escopo': trans?['escopo'] ?? cartaoRes['escopo'],
          'numero_parcela': p['numero_parcela'],
          'valor_parcela': valor,
          'data_vencimento': p['data_vencimento'],
          'status': p['status'],
          'data_pagamento': p['data_pagamento'],
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
      final cartaoId = dados['cartao_id'] as String;
      final cartaoRes = await _supabase.from('contas_cartoes').select('*').eq('id', cartaoId).single();

      final descricao = dados['descricao'] as String;
      final valorTotal = (dados['valor_total'] as num).toDouble();
      final parcelasQtd = (dados['parcelas'] as num?)?.toInt() ?? 1;
      final dataCompetenciaStr = dados['data_competencia'] as String? ?? DateTime.now().toIso8601String().substring(0, 10);
      final dataComp = DateTime.parse(dataCompetenciaStr);

      final diaFechamento = cartaoRes['dia_fechamento'] as int;
      final diaVencimento = cartaoRes['dia_vencimento'] as int;

      // 1. Cria transação financeira mestre
      final transacaoRes = await _supabase.from('transacoes_financeiras').insert({
        'descricao': descricao,
        'escopo': cartaoRes['escopo'],
        'tipo': 'SAIDA',
        'cartao_id': cartaoId,
        'valor_total': valorTotal,
        'parcelas': parcelasQtd,
        'data_competencia': dataCompetenciaStr,
      }).select().single();

      final transacaoId = transacaoRes['id'] as String;

      // 2. Calcula e gera cada parcela
      final valorBaseParcela = double.parse((valorTotal / parcelasQtd).toStringAsFixed(2));
      double soma = 0.0;

      // Determina o primeiro mês de fatura
      DateTime baseFatura = dataComp;
      if (dataComp.day >= diaFechamento) {
        baseFatura = DateTime(dataComp.year, dataComp.month + 1, 1);
      }

      for (int i = 1; i <= parcelasQtd; i++) {
        double valorEstaParcela;
        if (i == parcelasQtd) {
          valorEstaParcela = double.parse((valorTotal - soma).toStringAsFixed(2));
        } else {
          valorEstaParcela = valorBaseParcela;
          soma += valorEstaParcela;
        }

        final targetMonth = DateTime(baseFatura.year, baseFatura.month + (i - 1), 1);
        final mesRef = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}';
        
        // Vencimento seguro respeitando fim do mês
        final diasNoMes = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
        final diaVencReal = diaVencimento > diasNoMes ? diasNoMes : diaVencimento;
        final dataVenc = '${targetMonth.year}-${targetMonth.month.toString().padLeft(2, '0')}-${diaVencReal.toString().padLeft(2, '0')}';

        await _supabase.from('parcelas_financeiras').insert({
          'transacao_id': transacaoId,
          'cartao_id': cartaoId,
          'numero_parcela': i,
          'valor_parcela': valorEstaParcela,
          'data_vencimento': dataVenc,
          'mes_fatura_referencia': mesRef,
          'status': 'PENDENTE',
        });
      }

      return transacaoRes;
    } catch (e) {
      throw Exception('Erro ao registrar despesa no cartão no Supabase: $e');
    }
  }
}
