import 'package:equatable/equatable.dart';
import '../../domain/models/movimentacao_estoque_model.dart';

enum EstoqueStatus { initial, loading, success, error }

class EstoqueState extends Equatable {
  final EstoqueStatus status;
  final List<MovimentacaoEstoqueModel> movimentacoes;
  final List<Map<String, dynamic>> produtos;
  final String filtroTipo; // 'TODOS', 'ENTRADA', 'SAIDA', 'CONSUMO'
  final String? filtroProdutoId;
  final String filtroBusca;
  final String filtroPeriodo; // 'MES_ATUAL', '7_DIAS', 'HOJE', 'TODOS'
  final String? mensagemErro;

  const EstoqueState({
    this.status = EstoqueStatus.initial,
    this.movimentacoes = const [],
    this.produtos = const [],
    this.filtroTipo = 'TODOS',
    this.filtroProdutoId,
    this.filtroBusca = '',
    this.filtroPeriodo = 'MES_ATUAL',
    this.mensagemErro,
  });

  /// Total de unidades físicas em estoque somando todos os produtos
  double get totalItensEstoque {
    return produtos.fold(0.0, (acc, p) {
      final q = (p['quantidade_estoque'] as num?)?.toDouble() ?? 0.0;
      return acc + (q > 0 ? q : 0.0);
    });
  }

  /// Quantidade de produtos que estão com estoque crítico (menor ou igual ao mínimo configurado)
  List<Map<String, dynamic>> get produtosComEstoqueBaixo {
    return produtos.where((p) {
      final atual = (p['quantidade_estoque'] as num?)?.toDouble() ?? 0.0;
      final minimo = (p['estoque_minimo'] as num?)?.toDouble() ?? 5.0;
      return atual <= minimo;
    }).toList();
  }

  /// Total de unidades que entraram no mês atual
  double get totalEntradasMes {
    final now = DateTime.now();
    return movimentacoes
        .where((m) =>
            m.tipo == 'ENTRADA' &&
            m.createdAt.year == now.year &&
            m.createdAt.month == now.month)
        .fold(0.0, (acc, m) => acc + m.quantidade);
  }

  /// Total de unidades que saíram no mês atual (vendas ou baixas)
  double get totalSaidasMes {
    final now = DateTime.now();
    return movimentacoes
        .where((m) =>
            (m.tipo == 'SAIDA' || m.tipo == 'CONSUMO') &&
            m.createdAt.year == now.year &&
            m.createdAt.month == now.month)
        .fold(0.0, (acc, m) => acc + m.quantidade);
  }

  /// Lista de movimentações filtradas de acordo com as seleções do usuário
  List<MovimentacaoEstoqueModel> get movimentacoesFiltradas {
    final now = DateTime.now();
    final hojeInicio = DateTime(now.year, now.month, now.day);
    final seteDiasAtras = hojeInicio.subtract(const Duration(days: 7));
    final mesInicio = DateTime(now.year, now.month, 1);

    return movimentacoes.where((m) {
      // Filtro por Tipo
      if (filtroTipo != 'TODOS' && m.tipo != filtroTipo) {
        return false;
      }

      // Filtro por Produto Específico
      if (filtroProdutoId != null && filtroProdutoId!.isNotEmpty && m.produtoId != filtroProdutoId) {
        return false;
      }

      // Filtro por Período
      if (filtroPeriodo == 'HOJE') {
        if (m.createdAt.isBefore(hojeInicio)) return false;
      } else if (filtroPeriodo == '7_DIAS') {
        if (m.createdAt.isBefore(seteDiasAtras)) return false;
      } else if (filtroPeriodo == 'MES_ATUAL') {
        if (m.createdAt.isBefore(mesInicio)) return false;
      }

      // Filtro por Texto de Busca (Nome do Produto ou SKU ou Motivo)
      if (filtroBusca.trim().isNotEmpty) {
        final termo = filtroBusca.trim().toLowerCase();
        final nome = m.produtoNome.toLowerCase();
        final sku = (m.produtoSku ?? '').toLowerCase();
        final motivo = (m.motivo ?? '').toLowerCase();
        if (!nome.contains(termo) && !sku.contains(termo) && !motivo.contains(termo)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  EstoqueState copyWith({
    EstoqueStatus? status,
    List<MovimentacaoEstoqueModel>? movimentacoes,
    List<Map<String, dynamic>>? produtos,
    String? filtroTipo,
    String? filtroProdutoId,
    bool clearFiltroProduto = false,
    String? filtroBusca,
    String? filtroPeriodo,
    String? mensagemErro,
  }) {
    return EstoqueState(
      status: status ?? this.status,
      movimentacoes: movimentacoes ?? this.movimentacoes,
      produtos: produtos ?? this.produtos,
      filtroTipo: filtroTipo ?? this.filtroTipo,
      filtroProdutoId: clearFiltroProduto ? null : (filtroProdutoId ?? this.filtroProdutoId),
      filtroBusca: filtroBusca ?? this.filtroBusca,
      filtroPeriodo: filtroPeriodo ?? this.filtroPeriodo,
      mensagemErro: mensagemErro,
    );
  }

  @override
  List<Object?> get props => [
        status,
        movimentacoes,
        produtos,
        filtroTipo,
        filtroProdutoId,
        filtroBusca,
        filtroPeriodo,
        mensagemErro,
      ];
}
