import 'package:equatable/equatable.dart';
import '../../domain/models/produto_servico_item.dart';
import '../../domain/models/item_carrinho.dart';
import '../../domain/models/cliente_resumo.dart';

enum VendasStatus { initial, loading, loaded, submitting, success, error }

class VendasState extends Equatable {
  final VendasStatus status;
  final List<ProdutoServicoItem> catalogo;
  final String filtroTexto;
  final TipoCatalogo? filtroTipo;
  final List<ItemCarrinho> itensCarrinho;
  final List<ClienteResumo> clientes;
  final ClienteResumo? clienteSelecionado;
  final double desconto;
  final String tipoDesconto; // 'AVULSO', 'PROMOCIONAL', 'FIDELIDADE', 'NENHUM'
  final String formaPagamento;
  final String statusPagamento; // 'EFETIVADO' ou 'PENDENTE'
  final String? dataPrevistaPagamento;
  final String? cartaoId;
  final String? contaBancariaId;
  final int parcelas;
  final String? errorMessage;
  final String? vendaConcluidaId;

  const VendasState({
    this.status = VendasStatus.initial,
    this.catalogo = const [],
    this.filtroTexto = '',
    this.filtroTipo,
    this.itensCarrinho = const [],
    this.clientes = const [],
    this.clienteSelecionado,
    this.desconto = 0.0,
    this.tipoDesconto = 'NENHUM',
    this.formaPagamento = 'PIX',
    this.statusPagamento = 'EFETIVADO',
    this.dataPrevistaPagamento,
    this.cartaoId,
    this.contaBancariaId,
    this.parcelas = 1,
    this.errorMessage,
    this.vendaConcluidaId,
  });

  // Getters de Cálculos Financeiros em Tempo Real
  double get totalBruto => itensCarrinho.fold(
        0.0,
        (acc, item) => acc + item.subtotal,
      );

  double get totalOriginal => itensCarrinho.fold(
        0.0,
        (acc, item) => acc + item.valorOriginal,
      );

  double get totalDescontoItens => itensCarrinho.fold(
        0.0,
        (acc, item) => acc + item.valorDesconto,
      );

  double get totalDescontoGeral => totalDescontoItens + desconto;

  double get totalLiquido {
    final liquido = totalBruto - desconto;
    return liquido < 0.0 ? 0.0 : liquido;
  }

  double get totalItens => itensCarrinho.fold(
        0.0,
        (acc, item) => acc + item.quantidade,
      );

  List<ProdutoServicoItem> get itensFiltrados {
    return catalogo.where((item) {
      final matchesTipo = filtroTipo == null || item.tipo == filtroTipo;
      final matchesTexto = filtroTexto.isEmpty ||
          item.nome.toLowerCase().contains(filtroTexto.toLowerCase());
      return matchesTipo && matchesTexto;
    }).toList();
  }

  VendasState copyWith({
    VendasStatus? status,
    List<ProdutoServicoItem>? catalogo,
    String? filtroTexto,
    TipoCatalogo? filtroTipo,
    bool clearFiltroTipo = false,
    List<ItemCarrinho>? itensCarrinho,
    List<ClienteResumo>? clientes,
    ClienteResumo? clienteSelecionado,
    bool clearCliente = false,
    double? desconto,
    String? tipoDesconto,
    String? formaPagamento,
    String? statusPagamento,
    String? dataPrevistaPagamento,
    bool clearDataPrevista = false,
    String? cartaoId,
    String? contaBancariaId,
    bool clearContaBancaria = false,
    int? parcelas,
    String? errorMessage,
    String? vendaConcluidaId,
  }) {
    return VendasState(
      status: status ?? this.status,
      catalogo: catalogo ?? this.catalogo,
      filtroTexto: filtroTexto ?? this.filtroTexto,
      filtroTipo: clearFiltroTipo ? null : (filtroTipo ?? this.filtroTipo),
      itensCarrinho: itensCarrinho ?? this.itensCarrinho,
      clientes: clientes ?? this.clientes,
      clienteSelecionado: clearCliente ? null : (clienteSelecionado ?? this.clienteSelecionado),
      desconto: desconto ?? this.desconto,
      tipoDesconto: tipoDesconto ?? this.tipoDesconto,
      formaPagamento: formaPagamento ?? this.formaPagamento,
      statusPagamento: statusPagamento ?? this.statusPagamento,
      dataPrevistaPagamento: clearDataPrevista ? null : (dataPrevistaPagamento ?? this.dataPrevistaPagamento),
      cartaoId: cartaoId ?? this.cartaoId,
      contaBancariaId: clearContaBancaria ? null : (contaBancariaId ?? this.contaBancariaId),
      parcelas: parcelas ?? this.parcelas,
      errorMessage: errorMessage,
      vendaConcluidaId: vendaConcluidaId,
    );
  }

  @override
  List<Object?> get props => [
        status,
        catalogo,
        filtroTexto,
        filtroTipo,
        itensCarrinho,
        clientes,
        clienteSelecionado,
        desconto,
        tipoDesconto,
        formaPagamento,
        statusPagamento,
        dataPrevistaPagamento,
        cartaoId,
        contaBancariaId,
        parcelas,
        errorMessage,
        vendaConcluidaId,
      ];
}
