import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../domain/models/movimentacao_estoque_model.dart';

class EstoqueRepository {
  final SupabaseClient _supabase;

  EstoqueRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  /// Obtém histórico de movimentações com os dados dos produtos vinculados
  Future<List<MovimentacaoEstoqueModel>> obterMovimentacoes({
    String? tipo,
    String? produtoId,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async {
    try {
      var query = _supabase
          .from('movimentacoes_estoque')
          .select('*, produto:produtos(nome, codigo_barras, unidade_medida, preco_custo, quantidade_estoque)');

      if (tipo != null && tipo != 'TODOS') {
        query = query.eq('tipo', tipo);
      }

      if (produtoId != null && produtoId.isNotEmpty) {
        query = query.eq('produto_id', produtoId);
      }

      if (dataInicio != null) {
        query = query.gte('created_at', dataInicio.toIso8601String());
      }

      if (dataFim != null) {
        query = query.lte('created_at', dataFim.toIso8601String());
      }

      final response = await query.order('created_at', ascending: false).limit(500);

      final list = (response as List)
          .map((item) => MovimentacaoEstoqueModel.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      return list;
    } catch (e) {
      throw Exception('Erro ao carregar movimentações de estoque: $e');
    }
  }

  /// Escuta alterações em tempo real na tabela de movimentações
  Stream<List<Map<String, dynamic>>> streamMovimentacoes() {
    return _supabase
        .from('movimentacoes_estoque')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(200);
  }

  /// Lista todos os produtos com seu estoque atual e estoque mínimo para seleção e alertas
  Future<List<Map<String, dynamic>>> obterProdutos() async {
    try {
      final res = await _supabase
          .from('produtos')
          .select('id, nome, codigo_barras, quantidade_estoque, estoque_minimo, preco_custo, preco_venda, unidade_medida, categoria_id')
          .order('nome');

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      throw Exception('Erro ao listar produtos para controle de estoque: $e');
    }
  }

  /// Registra uma nova entrada de estoque (compra ou reposição)
  Future<MovimentacaoEstoqueModel> registrarEntrada({
    required String produtoId,
    required double quantidade,
    double? custoUnitario,
    String? motivo,
    DateTime? dataLancamento,
  }) async {
    if (quantidade <= 0) {
      throw Exception('A quantidade da entrada deve ser maior que zero.');
    }

    try {
      // 1. Busca produto atual
      final prodData = await _supabase
          .from('produtos')
          .select('id, nome, codigo_barras, unidade_medida, quantidade_estoque, preco_custo')
          .eq('id', produtoId)
          .single();

      final saldoAnt = (prodData['quantidade_estoque'] as num?)?.toDouble() ?? 0.0;
      final saldoNovo = saldoAnt + quantidade;

      // 2. Atualiza produto
      final updateMap = <String, dynamic>{
        'quantidade_estoque': saldoNovo,
      };
      if (custoUnitario != null && custoUnitario > 0) {
        updateMap['preco_custo'] = custoUnitario;
      }

      await _supabase.from('produtos').update(updateMap).eq('id', produtoId);

      // 3. Registra movimentação de estoque
      final movRes = await _supabase
          .from('movimentacoes_estoque')
          .insert({
            'produto_id': produtoId,
            'tipo': 'ENTRADA',
            'quantidade': quantidade,
            'saldo_anterior': saldoAnt,
            'saldo_posterior': saldoNovo,
            'motivo': motivo?.trim().isNotEmpty == true ? motivo!.trim() : 'Compra / Reposição de estoque',
            if (dataLancamento != null) 'created_at': _dataParaIso(dataLancamento),
          })
          .select('*, produto:produtos(nome, codigo_barras, unidade_medida, preco_custo)')
          .single();

      return MovimentacaoEstoqueModel.fromJson(Map<String, dynamic>.from(movRes));
    } catch (e) {
      throw Exception('Erro ao registrar entrada de estoque no Supabase: $e');
    }
  }

  /// Registra uma saída manual de estoque (avaria, vencimento, descarte ou consumo em cabine)
  Future<MovimentacaoEstoqueModel> registrarSaida({
    required String produtoId,
    required double quantidade,
    required String motivo,
    String tipo = 'SAIDA', // 'SAIDA' ou 'CONSUMO'
    DateTime? dataLancamento,
  }) async {
    if (quantidade <= 0) {
      throw Exception('A quantidade da saída deve ser maior que zero.');
    }

    try {
      // 1. Busca produto atual
      final prodData = await _supabase
          .from('produtos')
          .select('id, nome, codigo_barras, unidade_medida, quantidade_estoque')
          .eq('id', produtoId)
          .single();

      final saldoAnt = (prodData['quantidade_estoque'] as num?)?.toDouble() ?? 0.0;
      final saldoNovo = (saldoAnt - quantidade < 0) ? 0.0 : (saldoAnt - quantidade);

      // 2. Atualiza produto
      await _supabase.from('produtos').update({
        'quantidade_estoque': saldoNovo,
      }).eq('id', produtoId);

      // 3. Registra movimentação de saída
      final movRes = await _supabase
          .from('movimentacoes_estoque')
          .insert({
            'produto_id': produtoId,
            'tipo': tipo,
            'quantidade': quantidade,
            'saldo_anterior': saldoAnt,
            'saldo_posterior': saldoNovo,
            'motivo': motivo.trim().isNotEmpty ? motivo.trim() : 'Saída manual / Ajuste de estoque',
            if (dataLancamento != null) 'created_at': _dataParaIso(dataLancamento),
          })
          .select('*, produto:produtos(nome, codigo_barras, unidade_medida, preco_custo)')
          .single();

      return MovimentacaoEstoqueModel.fromJson(Map<String, dynamic>.from(movRes));
    } catch (e) {
      throw Exception('Erro ao registrar saída de estoque no Supabase: $e');
    }
  }

  /// Converte a data escolhida em ISO-8601 preservando a hora atual (data retroativa/futura)
  String _dataParaIso(DateTime data) {
    final agora = DateTime.now();
    return DateTime(data.year, data.month, data.day, agora.hour, agora.minute, agora.second)
        .toUtc()
        .toIso8601String();
  }
}
