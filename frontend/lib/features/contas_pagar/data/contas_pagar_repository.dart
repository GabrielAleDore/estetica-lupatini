import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
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
          .select('*, categorias(nome), contas_cartoes(nome), contas_bancarias(nome_conta)')
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

  /// Calcula a data de vencimento da fatura do cartão para cada parcela
  DateTime calcularVencimentoFatura({
    required DateTime dataCompra,
    required int diaFechamento,
    required int diaVencimento,
    required int numeroParcela,
  }) {
    // Se comprou no dia do fechamento ou após, a compra vai para a fatura seguinte
    int mesOffset = (dataCompra.day >= diaFechamento) ? 1 : 0;
    // Se dia de vencimento <= dia de fechamento (ex: fecha dia 28 e vence dia 5), o vencimento é no mês seguinte
    if (diaVencimento <= diaFechamento) {
      mesOffset += 1;
    }
    final totalOffset = mesOffset + (numeroParcela - 1);
    final totalMeses = (dataCompra.year * 12 + dataCompra.month - 1) + totalOffset;
    final targetYear = totalMeses ~/ 12;
    final targetMonth = (totalMeses % 12) + 1;
    final maxDias = DateTime(targetYear, targetMonth + 1, 0).day;
    final diaFinal = diaVencimento > maxDias ? maxDias : diaVencimento;
    return DateTime(targetYear, targetMonth, diaFinal);
  }

  /// Cadastra uma despesa no cartão de crédito ou parcelada, distribuindo as parcelas pendentes nos próximos meses
  Future<List<Map<String, dynamic>>> cadastrarDespesaParcelada(Map<String, dynamic> dados) async {
    try {
      final cartaoId = dados['cartao_id']?.toString();
      final descricao = dados['descricao']?.toString() ?? 'Despesa no Cartão';
      final valorTotal = (dados['valor_total'] as num?)?.toDouble() ?? 0.0;
      final parcelasQtd = (dados['parcelas'] as num?)?.toInt() ?? 1;
      final dataCompetenciaStr = dados['data_competencia']?.toString() ??
          dados['data_compra']?.toString() ??
          dados['data_vencimento']?.toString() ??
          DateTime.now().toIso8601String().substring(0, 10);
      final dataCompra = DateTime.tryParse(dataCompetenciaStr) ?? DateTime.now();
      final categoriaId = dados['categoria_id']?.toString();
      final escopo = dados['escopo']?.toString() ?? 'PJ';
      final formaPagamento = dados['forma_pagamento']?.toString() ?? 'CARTAO_CREDITO';
      final grupoParcelaId = parcelasQtd > 1 ? const Uuid().v4() : null;

      int diaFechamento = 18;
      int diaVencimento = 25;
      String escopoFinal = escopo;

      if (cartaoId != null && cartaoId.isNotEmpty) {
        try {
          final cartaoRes = await _supabase.from('contas_cartoes').select('*').eq('id', cartaoId).single();
          diaFechamento = (cartaoRes['dia_fechamento'] as num?)?.toInt() ?? 18;
          diaVencimento = (cartaoRes['dia_vencimento'] as num?)?.toInt() ?? 25;
          if (cartaoRes['escopo'] != null) {
            escopoFinal = cartaoRes['escopo'].toString();
          }
        } catch (_) {}
      }

      final List<Map<String, dynamic>> criadas = [];
      final valorBaseParcela = double.parse((valorTotal / parcelasQtd).toStringAsFixed(2));
      double soma = 0.0;

      for (int i = 1; i <= parcelasQtd; i++) {
        final double valorEstaParcela;
        if (i == parcelasQtd) {
          valorEstaParcela = double.parse((valorTotal - soma).toStringAsFixed(2));
        } else {
          valorEstaParcela = valorBaseParcela;
          soma += valorEstaParcela;
        }

        final DateTime dataVenc;
        if (formaPagamento == 'CARTAO_CREDITO' || (cartaoId != null && cartaoId.isNotEmpty)) {
          dataVenc = calcularVencimentoFatura(
            dataCompra: dataCompra,
            diaFechamento: diaFechamento,
            diaVencimento: diaVencimento,
            numeroParcela: i,
          );
        } else {
          final totalOffset = (i - 1);
          final totalMeses = (dataCompra.year * 12 + dataCompra.month - 1) + totalOffset;
          final targetYear = totalMeses ~/ 12;
          final targetMonth = (totalMeses % 12) + 1;
          final maxDias = DateTime(targetYear, targetMonth + 1, 0).day;
          final diaFinal = dataCompra.day > maxDias ? maxDias : dataCompra.day;
          dataVenc = DateTime(targetYear, targetMonth, diaFinal);
        }

        final dataVencStr = DateFormat('yyyy-MM-dd').format(dataVenc);
        final descricaoParcela = parcelasQtd > 1 ? '$descricao ($i/$parcelasQtd)' : descricao;

        final payload = <String, dynamic>{
          'descricao': descricaoParcela,
          'escopo': escopoFinal,
          'tipo': 'SAIDA',
          'valor_total': valorEstaParcela,
          'valor': valorEstaParcela,
          'parcelas': parcelasQtd,
          'status': 'PENDENTE',
          'data_competencia': dataCompetenciaStr,
          'data_vencimento': dataVencStr,
          'forma_pagamento': formaPagamento,
          if (grupoParcelaId != null) 'grupo_parcela_id': grupoParcelaId,
          if (cartaoId != null && cartaoId.isNotEmpty) 'cartao_id': cartaoId,
          if (categoriaId != null && categoriaId.isNotEmpty) 'categoria_id': categoriaId,
          if (dados['tipo_recorrencia'] != null) 'tipo_recorrencia': dados['tipo_recorrencia'],
          if (dados['observacoes'] != null) 'observacoes': dados['observacoes'],
        };

        final transacaoRes = await _supabase.from('transacoes_financeiras').insert(payload).select().single();
        criadas.add(Map<String, dynamic>.from(transacaoRes));

        // Vincula também na tabela parcelas_financeiras para rastreabilidade de fatura de cartão
        if (cartaoId != null && cartaoId.isNotEmpty) {
          try {
            final mesRef = '${dataVenc.year}-${dataVenc.month.toString().padLeft(2, '0')}';
            await _supabase.from('parcelas_financeiras').insert({
              'transacao_id': transacaoRes['id'],
              'cartao_id': cartaoId,
              'numero_parcela': i,
              'valor_parcela': valorEstaParcela,
              'data_vencimento': dataVencStr,
              'status': 'PENDENTE',
              'mes_fatura_referencia': mesRef,
              if (grupoParcelaId != null) 'grupo_parcela_id': grupoParcelaId,
            });
          } catch (_) {}
        }
      }

      return criadas;
    } catch (e) {
      throw Exception('Erro ao cadastrar despesa parcelada no cartão: $e');
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

      final res = await _supabase.from('transacoes_financeiras').insert(payload).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      throw Exception('Erro ao cadastrar despesa: $e');
    }
  }

  /// Atualiza uma parcela de despesa, podendo propagar o novo vencimento para as parcelas seguintes
  Future<void> atualizarParcelaDespesa({
    required String transacaoId,
    required String novaDataVencimentoStr,
    double? novoValor,
    String? novaDescricao,
    String? novaCategoriaId,
    required bool aplicarEmTodasSeguintes,
  }) async {
    try {
      // 1. Busca a transação atual
      final trans = await _supabase
          .from('transacoes_financeiras')
          .select('*')
          .eq('id', transacaoId)
          .single();

      final dataVencOriginalStr = trans['data_vencimento']?.toString() ?? novaDataVencimentoStr;
      final dtOriginal = DateTime.tryParse(dataVencOriginalStr) ?? DateTime.now();
      final dtNova = DateTime.tryParse(novaDataVencimentoStr) ?? DateTime.now();

      final deltaMeses = (dtNova.year - dtOriginal.year) * 12 + (dtNova.month - dtOriginal.month);
      final novoDia = dtNova.day;

      final grupoParcelaId = trans['grupo_parcela_id']?.toString();
      final totalParcelas = (trans['parcelas'] as num?)?.toInt() ?? 1;

      // Se for apenas para esta parcela ou se não fizer parte de um grupo parcelado:
      if (!aplicarEmTodasSeguintes || (grupoParcelaId == null && totalParcelas <= 1)) {
        final updateTrans = <String, dynamic>{
          'data_vencimento': novaDataVencimentoStr,
          if (novoValor != null) 'valor_total': novoValor,
          if (novoValor != null) 'valor': novoValor,
          if (novaDescricao != null && novaDescricao.isNotEmpty) 'descricao': novaDescricao,
          if (novaCategoriaId != null && novaCategoriaId.isNotEmpty) 'categoria_id': novaCategoriaId,
        };
        await _supabase.from('transacoes_financeiras').update(updateTrans).eq('id', transacaoId);

        final mesRef = novaDataVencimentoStr.length >= 7 ? novaDataVencimentoStr.substring(0, 7) : null;
        final updatePf = <String, dynamic>{
          'data_vencimento': novaDataVencimentoStr,
          if (mesRef != null) 'mes_fatura_referencia': mesRef,
          if (novoValor != null) 'valor_parcela': novoValor,
        };
        try {
          await _supabase.from('parcelas_financeiras').update(updatePf).eq('transacao_id', transacaoId);
        } catch (_) {}
        return;
      }

      // Se deve aplicar a esta e a todas as seguintes da mesma compra:
      int parcelaAtualNum = 1;
      final matchAtual = RegExp(r'\((\d+)/\d+\)').firstMatch(trans['descricao']?.toString() ?? '');
      if (matchAtual != null) {
        parcelaAtualNum = int.tryParse(matchAtual.group(1)!) ?? 1;
      } else {
        try {
          final pfRes = await _supabase
              .from('parcelas_financeiras')
              .select('numero_parcela')
              .eq('transacao_id', transacaoId)
              .maybeSingle();
          if (pfRes != null && pfRes['numero_parcela'] != null) {
            parcelaAtualNum = (pfRes['numero_parcela'] as num).toInt();
          }
        } catch (_) {}
      }

      // Busca todas as transações irmãs do grupo
      List<Map<String, dynamic>> grupoTrans = [];
      if (grupoParcelaId != null && grupoParcelaId.isNotEmpty) {
        final res = await _supabase
            .from('transacoes_financeiras')
            .select('*')
            .eq('grupo_parcela_id', grupoParcelaId)
            .order('data_vencimento');
        grupoTrans = List<Map<String, dynamic>>.from(res);
      } else {
        final baseDescMatch = RegExp(r'^(.*?)\s*\(\d+/\d+\)$').firstMatch(trans['descricao']?.toString() ?? '');
        final baseDesc = baseDescMatch?.group(1)?.trim() ?? trans['descricao']?.toString() ?? '';
        var q = _supabase.from('transacoes_financeiras').select('*').ilike('descricao', '$baseDesc%');
        if (trans['cartao_id'] != null) {
          q = q.eq('cartao_id', trans['cartao_id']);
        }
        final res = await q.order('data_vencimento');
        grupoTrans = List<Map<String, dynamic>>.from(res);
      }

      for (int i = 0; i < grupoTrans.length; i++) {
        final item = grupoTrans[i];
        final itemId = item['id'].toString();

        int itemNum = i + 1;
        final m = RegExp(r'\((\d+)/\d+\)').firstMatch(item['descricao']?.toString() ?? '');
        if (m != null) {
          itemNum = int.tryParse(m.group(1)!) ?? (i + 1);
        }

        // Se for a parcela editada ou qualquer subsequente:
        if (itemNum >= parcelaAtualNum) {
          final itemVencOriginalStr = item['data_vencimento']?.toString() ?? '';
          final dtItem = DateTime.tryParse(itemVencOriginalStr) ?? dtOriginal;

          final DateTime newDate;
          if (deltaMeses != 0) {
            final totalMonths = (dtItem.year * 12 + dtItem.month - 1) + deltaMeses;
            final targetYear = totalMonths ~/ 12;
            final targetMonth = (totalMonths % 12) + 1;
            final maxDays = DateTime(targetYear, targetMonth + 1, 0).day;
            final targetDay = novoDia > maxDays ? maxDays : novoDia;
            newDate = DateTime(targetYear, targetMonth, targetDay);
          } else {
            final maxDays = DateTime(dtItem.year, dtItem.month + 1, 0).day;
            final targetDay = novoDia > maxDays ? maxDays : novoDia;
            newDate = DateTime(dtItem.year, dtItem.month, targetDay);
          }

          final newDateStr = DateFormat('yyyy-MM-dd').format(newDate);
          final newMesRef = DateFormat('yyyy-MM').format(newDate);

          final updateTrans = <String, dynamic>{
            'data_vencimento': newDateStr,
            if (novoValor != null) 'valor_total': novoValor,
            if (novoValor != null) 'valor': novoValor,
            if (novaCategoriaId != null && novaCategoriaId.isNotEmpty) 'categoria_id': novaCategoriaId,
          };
          await _supabase.from('transacoes_financeiras').update(updateTrans).eq('id', itemId);

          try {
            await _supabase.from('parcelas_financeiras').update({
              'data_vencimento': newDateStr,
              'mes_fatura_referencia': newMesRef,
              if (novoValor != null) 'valor_parcela': novoValor,
            }).eq('transacao_id', itemId);
          } catch (_) {}
        }
      }
    } catch (e) {
      throw Exception('Erro ao atualizar parcela: $e');
    }
  }

  Future<void> marcarComoPago(String transacaoId, {String? contaBancariaId}) async {
    try {
      final updateData = <String, dynamic>{
        'status': 'PAGO',
        'data_pagamento': DateTime.now().toIso8601String().substring(0, 10),
      };
      if (contaBancariaId != null && contaBancariaId.isNotEmpty) {
        updateData['conta_bancaria_id'] = contaBancariaId;
      }
      await _supabase.from('transacoes_financeiras').update(updateData).eq('id', transacaoId);
      try {
        await _supabase.from('parcelas_financeiras').update({
          'status': 'PAGO',
          'data_pagamento': DateTime.now().toIso8601String().substring(0, 10),
        }).eq('transacao_id', transacaoId);
      } catch (_) {}
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
