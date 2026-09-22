import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../../domain/models/produto_servico_item.dart';
import '../../domain/models/venda_request.dart';

class VendasRepository {
  final SupabaseClient _supabase;

  VendasRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  Future<List<ProdutoServicoItem>> carregarCatalogo() async {
    try {
      // 1. Serviços e Procedimentos Clínicos Ativos
      final servicosRes = await _supabase
          .from('servicos')
          .select('id, nome, preco, duracao_minutos, ativo, codigo_sequencial, preco_promocional, em_promocao, inicio_promocao, fim_promocao')
          .eq('ativo', true)
          .order('nome');

      // 2. Produtos e Insumos de Catálogo
      final produtosRes = await _supabase
          .from('produtos')
          .select('id, nome, preco_venda, permite_venda, quantidade_estoque, estoque_minimo, unidade_medida, codigo_sequencial, preco_promocional, em_promocao, inicio_promocao, fim_promocao')
          .order('nome');

      final List<ProdutoServicoItem> itens = [];

      for (final s in servicosRes) {
        itens.add(
          ProdutoServicoItem.fromJson(
            {
              'id': s['id'],
              'nome': s['nome'],
              'tipo': 'servico',
              'preco': (s['preco'] as num).toDouble(),
              'duracao_minutos': s['duracao_minutos'] ?? 60,
              'permite_venda': true,
              'quantidade_estoque': 999.0,
              'estoque_minimo': 0.0,
              'unidade_medida': 'SESSÃO',
              'codigo_sequencial': s['codigo_sequencial'],
              'preco_promocional': s['preco_promocional'],
              'em_promocao': s['em_promocao'] ?? false,
              'inicio_promocao': s['inicio_promocao'],
              'fim_promocao': s['fim_promocao'],
            },
            TipoCatalogo.servico,
          ),
        );
      }

      for (final p in produtosRes) {
        itens.add(
          ProdutoServicoItem.fromJson(
            {
              'id': p['id'],
              'nome': p['nome'],
              'tipo': 'produto',
              'preco': (p['preco_venda'] as num).toDouble(),
              'duracao_minutos': 0,
              'permite_venda': p['permite_venda'] ?? true,
              'quantidade_estoque': (p['quantidade_estoque'] as num).toDouble(),
              'estoque_minimo': (p['estoque_minimo'] as num).toDouble(),
              'unidade_medida': p['unidade_medida'] ?? 'UN',
              'codigo_sequencial': p['codigo_sequencial'],
              'preco_promocional': p['preco_promocional'],
              'em_promocao': p['em_promocao'] ?? false,
              'inicio_promocao': p['inicio_promocao'],
              'fim_promocao': p['fim_promocao'],
            },
            TipoCatalogo.produto,
          ),
        );
      }

      return itens;
    } catch (e) {
      throw Exception('Erro ao carregar catálogo unificado do Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> finalizarVenda(VendaRequest request) async {
    try {
      // Chamada à Stored Procedure atômica PostgreSQL no Supabase
      final response = await _supabase.rpc(
        'realizar_venda',
        params: {'p_venda': request.toJson()},
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': true, 'data': response};
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Erro ao registrar venda atômica no Supabase: $e');
    }
  }

  Future<List<Map<String, dynamic>>> carregarCartoes(String escopo) async {
    try {
      var query = _supabase.from('contas_cartoes').select('*').eq('ativo', true);
      if (escopo != 'TODOS') {
        query = query.eq('escopo', escopo);
      }
      final response = await query.order('nome');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao carregar cartões do Supabase: $e');
    }
  }

  Future<List<Map<String, dynamic>>> carregarClientes({String? busca}) async {
    try {
      var query = _supabase.from('clientes').select('id, nome, telefone, cpf, is_fidelizada, desconto_fidelidade_padrao').eq('status', 'ATIVO');
      if (busca != null && busca.trim().isNotEmpty) {
        final termo = '%${busca.trim()}%';
        query = query.or('nome.ilike.$termo,cpf.ilike.$termo,telefone.ilike.$termo');
      }
      final response = await query.order('nome').limit(50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao carregar clientes do Supabase: $e');
    }
  }
}
