import 'package:equatable/equatable.dart';
import 'produto_servico_item.dart';

class ItemCarrinho extends Equatable {
  final String id;
  final ProdutoServicoItem item;
  final double quantidade;
  final double precoUnitario;
  final double? precoOriginal;
  final String tipoDesconto;

  const ItemCarrinho({
    required this.id,
    required this.item,
    required this.quantidade,
    required this.precoUnitario,
    this.precoOriginal,
    this.tipoDesconto = 'NENHUM',
  });

  double get subtotal => quantidade * precoUnitario;
  double get valorOriginal => (precoOriginal ?? item.preco) * quantidade;
  double get valorDesconto => (valorOriginal - subtotal).clamp(0, double.infinity);

  ItemCarrinho copyWith({
    String? id,
    ProdutoServicoItem? item,
    double? quantidade,
    double? precoUnitario,
    double? precoOriginal,
    String? tipoDesconto,
  }) {
    return ItemCarrinho(
      id: id ?? this.id,
      item: item ?? this.item,
      quantidade: quantidade ?? this.quantidade,
      precoUnitario: precoUnitario ?? this.precoUnitario,
      precoOriginal: precoOriginal ?? this.precoOriginal,
      tipoDesconto: tipoDesconto ?? this.tipoDesconto,
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'tipo_item': item.tipo == TipoCatalogo.produto ? 'PRODUTO' : 'SERVICO',
      'produto_id': item.tipo == TipoCatalogo.produto ? item.id : null,
      'servico_id': item.tipo == TipoCatalogo.servico ? item.id : null,
      'quantidade': quantidade,
      'preco_original': precoOriginal ?? item.preco,
      'preco_unitario': precoUnitario,
      'tipo_desconto': tipoDesconto,
    };
  }

  @override
  List<Object?> get props => [id, item, quantidade, precoUnitario, precoOriginal, tipoDesconto];
}
