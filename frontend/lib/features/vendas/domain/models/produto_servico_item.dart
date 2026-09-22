import 'package:equatable/equatable.dart';

enum TipoCatalogo { produto, servico }

class ProdutoServicoItem extends Equatable {
  final String id;
  final String nome;
  final TipoCatalogo tipo;
  final double preco;
  final double estoqueAtual;
  final double estoqueMinimo;
  final String unidadeMedida;
  final int duracaoMinutos;
  final bool permiteVenda;
  final int? codigoSequencial;
  final double? precoPromocional;
  final bool emPromocao;
  final DateTime? inicioPromocao;
  final DateTime? fimPromocao;

  const ProdutoServicoItem({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.preco,
    this.estoqueAtual = 0.0,
    this.estoqueMinimo = 5.0,
    this.unidadeMedida = 'UN',
    this.duracaoMinutos = 60,
    this.permiteVenda = true,
    this.codigoSequencial,
    this.precoPromocional,
    this.emPromocao = false,
    this.inicioPromocao,
    this.fimPromocao,
  });

  bool get isPromocaoAtiva => emPromocao && precoPromocional != null && precoPromocional! > 0;
  double get precoEfetivo => isPromocaoAtiva ? precoPromocional! : preco;
  String get codigoExibicao => codigoSequencial != null ? '#$codigoSequencial' : '';

  bool get isEstoqueBaixo => tipo == TipoCatalogo.produto && estoqueAtual <= estoqueMinimo;
  bool get isSemEstoque => tipo == TipoCatalogo.produto && estoqueAtual <= 0;

  factory ProdutoServicoItem.fromJson(Map<String, dynamic> json, TipoCatalogo tipo) {
    return ProdutoServicoItem(
      id: json['id'] as String,
      nome: json['nome'] as String,
      tipo: tipo,
      preco: (json['preco_venda'] ?? json['preco'] ?? 0.0).toDouble(),
      estoqueAtual: (json['quantidade_estoque'] ?? 0.0).toDouble(),
      estoqueMinimo: (json['estoque_minimo'] ?? 5.0).toDouble(),
      unidadeMedida: (json['unidade_medida'] ?? 'UN') as String,
      duracaoMinutos: (json['duracao_minutos'] ?? 60) as int,
      permiteVenda: (json['permite_venda'] ?? true) as bool,
      codigoSequencial: json['codigo_sequencial'] != null ? (json['codigo_sequencial'] as num).toInt() : null,
      precoPromocional: json['preco_promocional'] != null ? (json['preco_promocional'] as num).toDouble() : null,
      emPromocao: (json['em_promocao'] ?? false) as bool,
      inicioPromocao: json['inicio_promocao'] != null ? DateTime.tryParse(json['inicio_promocao'].toString()) : null,
      fimPromocao: json['fim_promocao'] != null ? DateTime.tryParse(json['fim_promocao'].toString()) : null,
    );
  }

  @override
  List<Object?> get props => [id, nome, tipo, preco, estoqueAtual, estoqueMinimo, codigoSequencial, precoPromocional, emPromocao];
}
