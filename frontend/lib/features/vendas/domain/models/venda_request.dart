import 'item_carrinho.dart';

class VendaRequest {
  final String? clienteId;
  final double desconto;
  final String tipoDesconto; // 'AVULSO', 'PROMOCIONAL', 'FIDELIDADE', 'NENHUM'
  final String formaPagamento;
  final String? cartaoId;
  final int parcelas;
  final String? observacoes;
  final String statusPagamento; // 'EFETIVADO' ou 'PENDENTE'
  final String? dataPrevistaPagamento; // YYYY-MM-DD
  final List<ItemCarrinho> itens;

  VendaRequest({
    this.clienteId,
    this.desconto = 0.0,
    this.tipoDesconto = 'NENHUM',
    required this.formaPagamento,
    this.cartaoId,
    this.parcelas = 1,
    this.observacoes,
    this.statusPagamento = 'EFETIVADO',
    this.dataPrevistaPagamento,
    required this.itens,
  });

  Map<String, dynamic> toJson() {
    return {
      'cliente_id': clienteId,
      'desconto': desconto,
      'tipo_desconto': tipoDesconto,
      'forma_pagamento': formaPagamento,
      'cartao_id': cartaoId,
      'parcelas': parcelas,
      'observacoes': observacoes,
      'status_pagamento': statusPagamento,
      'data_prevista_pagamento': dataPrevistaPagamento,
      'itens': itens.map((e) => e.toApiJson()).toList(),
    };
  }
}
