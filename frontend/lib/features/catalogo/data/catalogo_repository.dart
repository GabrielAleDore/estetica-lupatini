import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class CatalogoRepository {
  final SupabaseClient _supabase;

  CatalogoRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  // =================== PRODUTOS ===================
  Future<List<Map<String, dynamic>>> listarProdutos({String? busca, String? categoriaId}) async {
    try {
      var query = _supabase.from('produtos').select('*, categoria:categorias(nome)');

      if (categoriaId != null && categoriaId.isNotEmpty) {
        query = query.eq('categoria_id', categoriaId);
      }

      if (busca != null && busca.trim().isNotEmpty) {
        final termo = '%${busca.trim()}%';
        query = query.or('nome.ilike.$termo,codigo_barras.ilike.$termo');
      }

      final response = await query.order('nome');
      return (response as List).map((p) {
        final map = Map<String, dynamic>.from(p);
        final cat = p['categoria'] as Map<String, dynamic>?;
        map['categoria_nome'] = cat?['nome'];
        return map;
      }).toList();
    } catch (e) {
      throw Exception('Erro ao listar catálogo de produtos do Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> salvarProduto(Map<String, dynamic> dados, {String? produtoId}) async {
    try {
      final payload = Map<String, dynamic>.from(dados);
      if (payload['codigo_barras'] != null && (payload['codigo_barras'] as String).trim().isEmpty) {
        payload['codigo_barras'] = null;
      }

      if (produtoId != null) {
        final response = await _supabase.from('produtos').update(payload).eq('id', produtoId).select().single();
        return Map<String, dynamic>.from(response);
      } else {
        final response = await _supabase.from('produtos').insert(payload).select().single();
        
        // Se cadastrou com estoque inicial > 0, cria movimentação de entrada inicial
        final qtdEstoque = (response['quantidade_estoque'] as num?)?.toDouble() ?? 0.0;
        if (qtdEstoque > 0) {
          await _supabase.from('movimentacoes_estoque').insert({
            'produto_id': response['id'],
            'tipo': 'ENTRADA',
            'quantidade': qtdEstoque,
            'saldo_anterior': 0.0,
            'saldo_posterior': qtdEstoque,
            'motivo': 'Saldo inicial de implantação de catálogo',
          });
        }
        return Map<String, dynamic>.from(response);
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw Exception('Código de barras já cadastrado em outro produto.');
      }
      throw Exception('Erro no Supabase: ${e.message}');
    } catch (e) {
      throw Exception('Erro ao salvar produto no Supabase: $e');
    }
  }

  Future<void> excluirProduto(String produtoId) async {
    try {
      // Verifica se possui movimentações ou vínculos
      final movs = await _supabase.from('movimentacoes_estoque').select('id').eq('produto_id', produtoId).limit(1);
      if ((movs as List).isNotEmpty) {
        // Se possui histórico, apenas desativa para vendas diretas preservando integridade
        await _supabase.from('produtos').update({'permite_venda': false}).eq('id', produtoId);
      } else {
        await _supabase.from('produtos').delete().eq('id', produtoId);
      }
    } catch (e) {
      throw Exception('Erro ao excluir/desativar produto no Supabase: $e');
    }
  }

  // =================== SERVIÇOS ===================
  Future<List<Map<String, dynamic>>> listarServicos({String? busca, String? categoriaId}) async {
    try {
      var query = _supabase.from('servicos').select('*, categoria:categorias(nome), servico_insumos(produto_id, quantidade_consumo, produto:produtos(nome, unidade_medida))');

      if (categoriaId != null && categoriaId.isNotEmpty) {
        query = query.eq('categoria_id', categoriaId);
      }

      if (busca != null && busca.trim().isNotEmpty) {
        query = query.ilike('nome', '%${busca.trim()}%');
      }

      final response = await query.order('nome');
      return (response as List).map((s) {
        final map = Map<String, dynamic>.from(s);
        final cat = s['categoria'] as Map<String, dynamic>?;
        map['categoria_nome'] = cat?['nome'];

        final insumosList = s['servico_insumos'] as List? ?? [];
        map['insumos'] = insumosList.map((ins) {
          final prod = ins['produto'] as Map<String, dynamic>?;
          return {
            'produto_id': ins['produto_id'],
            'produto_nome': prod?['nome'] ?? 'Insumo',
            'quantidade_consumo': (ins['quantidade_consumo'] as num).toDouble(),
            'unidade_medida': prod?['unidade_medida'] ?? 'UN',
          };
        }).toList();

        return map;
      }).toList();
    } catch (e) {
      throw Exception('Erro ao listar procedimentos do Supabase: $e');
    }
  }

  Future<Map<String, dynamic>> salvarServico(Map<String, dynamic> dados, {String? servicoId}) async {
    try {
      final insumos = dados['insumos'] as List? ?? [];
      final servicoPayload = {
        'nome': dados['nome'],
        'categoria_id': dados['categoria_id'],
        'duracao_minutos': dados['duracao_minutos'] ?? 60,
        'preco': dados['preco'] ?? 0.0,
        'ativo': dados['ativo'] ?? true,
      };

      Map<String, dynamic> servicoSalvo;
      if (servicoId != null) {
        final res = await _supabase.from('servicos').update(servicoPayload).eq('id', servicoId).select().single();
        servicoSalvo = Map<String, dynamic>.from(res);
        // Atualiza insumos: remove os antigos e reinsere os novos
        await _supabase.from('servico_insumos').delete().eq('servico_id', servicoId);
      } else {
        final res = await _supabase.from('servicos').insert(servicoPayload).select().single();
        servicoSalvo = Map<String, dynamic>.from(res);
      }

      final sId = servicoSalvo['id'] as String;

      // Insere lista técnica de insumos (BOM)
      for (final ins in insumos) {
        final pId = ins['produto_id'] as String?;
        final qtd = (ins['quantidade_consumo'] as num?)?.toDouble() ?? 1.0;
        if (pId != null && pId.isNotEmpty && qtd > 0) {
          await _supabase.from('servico_insumos').insert({
            'servico_id': sId,
            'produto_id': pId,
            'quantidade_consumo': qtd,
          });
        }
      }

      servicoSalvo['insumos'] = insumos;
      return servicoSalvo;
    } catch (e) {
      throw Exception('Erro ao salvar procedimento no Supabase: $e');
    }
  }

  Future<void> excluirServico(String servicoId) async {
    try {
      await _supabase.from('servicos').update({'ativo': false}).eq('id', servicoId);
    } catch (e) {
      throw Exception('Erro ao desativar procedimento no Supabase: $e');
    }
  }

  // =================== CATEGORIAS ===================
  Future<List<Map<String, dynamic>>> listarCategorias({String? tipo}) async {
    try {
      var query = _supabase.from('categorias').select('*');
      if (tipo != null && tipo.isNotEmpty) {
        query = query.eq('tipo', tipo);
      }
      final response = await query.order('nome');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Erro ao carregar categorias do Supabase: $e');
    }
  }
}
