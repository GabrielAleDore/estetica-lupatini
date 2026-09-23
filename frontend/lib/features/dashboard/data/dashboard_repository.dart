import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class DashboardRepository {
  final SupabaseClient _supabase;

  DashboardRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  /// Obtém o saldo consolidado e contagem das contas bancárias ativas (PJ e PF)
  Future<Map<String, dynamic>> obterResumoContasBancarias() async {
    try {
      final res = await _supabase
          .from('contas_bancarias')
          .select('id, nome_conta, banco_nome, tipo_conta, escopo, saldo_atual, ativo')
          .eq('ativo', true);

      final list = List<Map<String, dynamic>>.from(res as List);
      double saldoPj = 0.0;
      double saldoPf = 0.0;
      int qtdPj = 0;
      int qtdPf = 0;

      for (final item in list) {
        final saldo = (item['saldo_atual'] as num?)?.toDouble() ?? 0.0;
        final escopo = (item['escopo'] as String? ?? 'PJ').toUpperCase();
        if (escopo == 'PF') {
          saldoPf += saldo;
          qtdPf++;
        } else {
          saldoPj += saldo;
          qtdPj++;
        }
      }

      return {
        'saldo_total_pj': saldoPj,
        'saldo_total_pf': saldoPf,
        'saldo_total_geral': saldoPj + saldoPf,
        'qtd_contas_pj': qtdPj,
        'qtd_contas_pf': qtdPf,
        'total_contas_ativas': list.length,
        'contas': list,
      };
    } catch (_) {
      // Fallback defensivo para não quebrar o dashboard caso a tabela ainda não esteja provisionada
      return {
        'saldo_total_pj': 0.0,
        'saldo_total_pf': 0.0,
        'saldo_total_geral': 0.0,
        'qtd_contas_pj': 0,
        'qtd_contas_pf': 0,
        'total_contas_ativas': 0,
        'contas': <Map<String, dynamic>>[],
      };
    }
  }

  Future<Map<String, dynamic>> obterDashboardResumo(String mes) async {
    try {
      // Executa a Stored Procedure agregada de alta performance do PostgreSQL
      final response = await _supabase.rpc('obter_dashboard_resumo');
      final data = Map<String, dynamic>.from(response as Map);

      final faturamentoPj = (data['faturamento_pj'] as num?)?.toDouble() ?? 0.0;
      final despesasPf = (data['despesas_pf'] as num?)?.toDouble() ?? 0.0;
      final despesasPj = (data['despesas_pj'] as num?)?.toDouble() ?? 0.0;
      final balancoLiquido = (data['balanco_liquido'] as num?)?.toDouble() ?? 0.0;
      final vendasEfetivadas = (data['vendas_efetivadas'] as num?)?.toDouble() ?? faturamentoPj;
      final vendasAReceber = (data['vendas_a_receber'] as num?)?.toDouble() ?? 0.0;
      final totalVendas = data['total_vendas_mes'] ?? 0;
      final totalAlertas = data['total_alertas_estoque'] ?? 0;
      final alertas = List<Map<String, dynamic>>.from(data['alertas_estoque'] ?? []);

      return {
        'mes_referencia': mes,
        'total_faturado_pj': faturamentoPj,
        'total_despesas_pf': despesasPf,
        'total_despesas_pj': despesasPj,
        'balanco_liquido': balancoLiquido,
        'vendas_efetivadas': vendasEfetivadas,
        'vendas_a_receber': vendasAReceber,
        'total_vendas_mes': totalVendas,
        'total_itens_alerta_estoque': totalAlertas,
        'alertas_estoque': alertas,
        'dre': {
          'receita_liquida': faturamentoPj,
          'despesas_operacionais_pj': despesasPj,
          'custo_produtos_vendidos': 0.0,
          'custo_insumos_servicos': 0.0,
          'lucro_operacional_liquido_pj': balancoLiquido,
          'gastos_pessoais_pf_mes': despesasPf,
        },
      };
    } catch (e) {
      throw Exception('Erro ao carregar resumo do dashboard do Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> obterDRE(String mes) async {
    final resumo = await obterDashboardResumo(mes);
    return resumo['dre'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listarAlertasEstoque() async {
    try {
      final res = await _supabase
          .from('produtos')
          .select('id, nome, codigo_barras, quantidade_estoque, estoque_minimo, unidade_medida')
          .order('quantidade_estoque');

      final List<Map<String, dynamic>> alertas = [];
      for (final p in res) {
        final saldo = (p['quantidade_estoque'] as num).toDouble();
        final minimo = (p['estoque_minimo'] as num).toDouble();
        if (saldo <= minimo) {
          alertas.add({
            'id': p['id'],
            'nome': p['nome'],
            'codigo_barras': p['codigo_barras'],
            'quantidade_estoque': saldo,
            'estoque_minimo': minimo,
            'unidade_medida': p['unidade_medida'],
            'deficit': (minimo - saldo).clamp(0.0, double.infinity),
            'status_alerta': saldo <= 0 ? 'CRITICO' : 'BAIXO',
          });
        }
      }
      return alertas;
    } catch (e) {
      throw Exception('Erro ao listar alertas de estoque do Supabase: $e');
    }
  }

  Future<List<Map<String, dynamic>>> listarProdutos() async {
    try {
      final res = await _supabase.from('produtos').select('*').order('nome');
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw Exception('Erro ao carregar produtos do Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> darEntradaEstoque({
    required String produtoId,
    required double quantidade,
    double? custoUnitario,
    String? motivo,
  }) async {
    try {
      // 1. Busca saldo atual do produto
      final prod = await _supabase.from('produtos').select('*').eq('id', produtoId).single();
      final saldoAnt = (prod['quantidade_estoque'] as num).toDouble();
      final saldoNovo = saldoAnt + quantidade;

      final updateMap = <String, dynamic>{
        'quantidade_estoque': saldoNovo,
      };
      if (custoUnitario != null && custoUnitario > 0) {
        updateMap['preco_custo'] = custoUnitario;
      }

      final prodAtualizado = await _supabase
          .from('produtos')
          .update(updateMap)
          .eq('id', produtoId)
          .select()
          .single();

      // 2. Registra movimentação de estoque
      await _supabase.from('movimentacoes_estoque').insert({
        'produto_id': produtoId,
        'tipo': 'ENTRADA',
        'quantidade': quantidade,
        'saldo_anterior': saldoAnt,
        'saldo_posterior': saldoNovo,
        'motivo': motivo ?? 'Compra / Reposição de estoque',
      });

      return Map<String, dynamic>.from(prodAtualizado);
    } catch (e) {
      throw Exception('Erro ao registrar entrada de estoque no Supabase: $e');
    }
  }

  /// Obtém a soma de receitas manuais/avulsas efetivadas no mês especificado
  Future<Map<String, dynamic>> obterReceitasManuaisMes(String mes) async {
    try {
      final partes = mes.split('-');
      final ano = int.parse(partes[0]);
      final mesNum = int.parse(partes[1]);
      final inicio = '$mes-01';
      final ultimoDia = DateTime(ano, mesNum + 1, 0).day;
      final fim = '$mes-$ultimoDia';

      final res = await _supabase
          .from('transacoes_financeiras')
          .select('id, descricao, valor, valor_total, tipo, status, escopo, categoria_nome, data_transacao, data_competencia, conta_bancaria_id');

      final list = List<Map<String, dynamic>>.from(res as List);
      double totalPj = 0.0;
      double totalPf = 0.0;
      final List<Map<String, dynamic>> doMes = [];

      for (final item in list) {
        final tipo = (item['tipo'] as String? ?? '').toUpperCase();
        final status = (item['status'] as String? ?? '').toUpperCase();
        if (tipo != 'RECEITA' && tipo != 'ENTRADA') continue;
        if (status != 'EFETIVADO' && status != 'PAGO') continue;

        final data = (item['data_transacao'] ?? item['data_competencia'] ?? '').toString();
        if (data.compareTo(inicio) >= 0 && data.compareTo(fim) <= 0) {
          doMes.add(item);
          final val = (item['valor'] as num?)?.toDouble() ?? (item['valor_total'] as num?)?.toDouble() ?? 0.0;
          final escopo = (item['escopo'] as String? ?? 'PJ').toUpperCase();
          if (escopo == 'PF') {
            totalPf += val;
          } else {
            totalPj += val;
          }
        }
      }

      return {
        'total_receitas_pj': totalPj,
        'total_receitas_pf': totalPf,
        'total_receitas_geral': totalPj + totalPf,
        'transacoes': doMes,
      };
    } catch (_) {
      return {
        'total_receitas_pj': 0.0,
        'total_receitas_pf': 0.0,
        'total_receitas_geral': 0.0,
        'transacoes': <Map<String, dynamic>>[],
      };
    }
  }

  /// Registra uma receita ou entrada avulsa e atualiza o saldo bancário
  Future<Map<String, dynamic>> registrarReceitaAvulsa(Map<String, dynamic> dados) async {
    try {
      final valor = (dados['valor'] as num?)?.toDouble() ?? (dados['valor_total'] as num?)?.toDouble() ?? 0.0;
      final payload = Map<String, dynamic>.from(dados);
      payload['valor'] = valor;
      payload['valor_total'] = valor;
      payload['tipo'] = dados['tipo'] ?? 'RECEITA';
      payload['status'] = dados['status'] ?? 'EFETIVADO';
      payload['origem'] = dados['origem'] ?? 'MANUAL';
      if (payload['data_transacao'] == null && payload['data_competencia'] != null) {
        payload['data_transacao'] = payload['data_competencia'];
      }
      if (payload['data_competencia'] == null && payload['data_transacao'] != null) {
        payload['data_competencia'] = payload['data_transacao'];
      }

      final res = await _supabase.from('transacoes_financeiras').insert(payload).select().single();

      // Atualiza o saldo bancário da conta de destino se a transação estiver EFETIVADA
      final contaBancariaId = payload['conta_bancaria_id']?.toString();
      if (contaBancariaId != null && contaBancariaId.isNotEmpty && (payload['status'] == 'EFETIVADO' || payload['status'] == 'PAGO')) {
        try {
          final conta = await _supabase.from('contas_bancarias').select('saldo_atual, updated_at').eq('id', contaBancariaId).single();
          final updatedAt = conta['updated_at'] != null ? DateTime.tryParse(conta['updated_at'].toString()) : null;
          final agora = DateTime.now().toUtc();
          final rodouTrigger = updatedAt != null && agora.difference(updatedAt.toUtc()).inSeconds.abs() <= 2;
          if (!rodouTrigger) {
            final saldoAtual = (conta['saldo_atual'] as num?)?.toDouble() ?? 0.0;
            await _supabase.from('contas_bancarias').update({
              'saldo_atual': saldoAtual + valor,
            }).eq('id', contaBancariaId);
          }
        } catch (_) {}
      }

      return Map<String, dynamic>.from(res);
    } catch (e) {
      throw Exception('Erro ao registrar receita avulsa no Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> registrarTransacaoAvulsa(Map<String, dynamic> dados) async {
    try {
      final res = await _supabase.from('transacoes_financeiras').insert(dados).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      throw Exception('Erro ao registrar transação financeira no Supabase: $e');
    }
  }
}

