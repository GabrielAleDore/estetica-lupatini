import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class DashboardRepository {
  final SupabaseClient _supabase;

  DashboardRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

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

  Future<Map<String, dynamic>> registrarTransacaoAvulsa(Map<String, dynamic> dados) async {
    try {
      final res = await _supabase.from('transacoes_financeiras').insert(dados).select().single();
      return Map<String, dynamic>.from(res);
    } catch (e) {
      throw Exception('Erro ao registrar transação financeira no Supabase: $e');
    }
  }
}
