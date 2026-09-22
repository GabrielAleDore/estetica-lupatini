import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/produto_servico_item.dart';
import '../../domain/models/item_carrinho.dart';
import '../../domain/models/cliente_resumo.dart';
import '../../domain/models/venda_request.dart';
import '../../data/repositories/vendas_repository.dart';
import 'vendas_state.dart';

class VendasCubit extends Cubit<VendasState> {
  final VendasRepository _repository;
  final Uuid _uuid = const Uuid();

  VendasCubit({VendasRepository? repository})
      : _repository = repository ?? VendasRepository(),
        super(const VendasState());

  Future<void> carregarDadosIniciais() async {
    emit(state.copyWith(status: VendasStatus.loading));
    try {
      final catalogo = await _repository.carregarCatalogo();
      final clientesData = await _repository.carregarClientes();
      final clientes = clientesData.map((c) => ClienteResumo.fromJson(c)).toList();
      emit(state.copyWith(
        status: VendasStatus.loaded,
        catalogo: catalogo,
        clientes: clientes,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: VendasStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> buscarClientes(String query) async {
    try {
      final clientesData = await _repository.carregarClientes(busca: query);
      final clientes = clientesData.map((c) => ClienteResumo.fromJson(c)).toList();
      emit(state.copyWith(clientes: clientes));
    } catch (_) {
      // Falha silenciosa em digitação rápida
    }
  }

  void filtrarBusca(String texto) {
    emit(state.copyWith(filtroTexto: texto));
  }

  void filtrarTipo(TipoCatalogo? tipo) {
    if (tipo == null) {
      emit(state.copyWith(clearFiltroTipo: true));
    } else {
      emit(state.copyWith(filtroTipo: tipo));
    }
  }

  void adicionarItemAoCarrinho(ProdutoServicoItem item) {
    final itensAtuais = List<ItemCarrinho>.from(state.itensCarrinho);
    final index = itensAtuais.indexWhere((it) => it.item.id == item.id);

    double precoUnitario = item.preco;
    final double precoOriginal = item.preco;
    String tipoDesconto = 'NENHUM';

    if (item.isPromocaoAtiva) {
      precoUnitario = item.precoPromocional!;
      tipoDesconto = 'PROMOCIONAL';
    } else if (state.clienteSelecionado != null &&
        state.clienteSelecionado!.isFidelizada &&
        state.clienteSelecionado!.descontoFidelidadePadrao > 0) {
      final descPerc = state.clienteSelecionado!.descontoFidelidadePadrao / 100.0;
      precoUnitario = double.parse((item.preco * (1.0 - descPerc)).toStringAsFixed(2));
      tipoDesconto = 'FIDELIDADE';
    }

    if (index != -1) {
      // Incrementa quantidade
      final itemExistente = itensAtuais[index];
      itensAtuais[index] = itemExistente.copyWith(
        quantidade: itemExistente.quantidade + 1.0,
      );
    } else {
      // Adiciona novo item ao carrinho
      itensAtuais.add(
        ItemCarrinho(
          id: _uuid.v4(),
          item: item,
          quantidade: 1.0,
          precoUnitario: precoUnitario,
          precoOriginal: precoOriginal,
          tipoDesconto: tipoDesconto,
        ),
      );
    }

    emit(state.copyWith(itensCarrinho: itensAtuais));
  }

  void removerItemDoCarrinho(String id) {
    final itens = state.itensCarrinho.where((it) => it.id != id).toList();
    emit(state.copyWith(itensCarrinho: itens));
  }

  void atualizarQuantidade(String id, double novaQtd) {
    if (novaQtd <= 0) {
      removerItemDoCarrinho(id);
      return;
    }

    final itens = state.itensCarrinho.map((it) {
      if (it.id == id) {
        return it.copyWith(quantidade: novaQtd);
      }
      return it;
    }).toList();

    emit(state.copyWith(itensCarrinho: itens));
  }

  void aplicarDesconto(double desconto, {String tipoDesconto = 'AVULSO'}) {
    emit(state.copyWith(
      desconto: desconto < 0 ? 0.0 : desconto,
      tipoDesconto: desconto > 0 ? tipoDesconto : 'NENHUM',
    ));
  }

  void selecionarCliente(ClienteResumo? cliente) {
    if (cliente == null) {
      // Remove desconto de fidelidade de itens não promocionais
      final itensAtualizados = state.itensCarrinho.map((it) {
        if (it.tipoDesconto == 'FIDELIDADE') {
          return it.copyWith(
            precoUnitario: it.item.preco,
            precoOriginal: it.item.preco,
            tipoDesconto: 'NENHUM',
          );
        }
        return it;
      }).toList();

      emit(state.copyWith(
        clearCliente: true,
        itensCarrinho: itensAtualizados,
      ));
    } else {
      // Ao selecionar cliente com fidelidade, aplica desconto nos itens não promocionais
      final itensAtualizados = state.itensCarrinho.map((it) {
        if (it.item.isPromocaoAtiva) {
          return it; // Mantém preço promocional do produto
        }
        if (cliente.isFidelizada && cliente.descontoFidelidadePadrao > 0) {
          final descPerc = cliente.descontoFidelidadePadrao / 100.0;
          final precoUnit = double.parse((it.item.preco * (1.0 - descPerc)).toStringAsFixed(2));
          return it.copyWith(
            precoUnitario: precoUnit,
            precoOriginal: it.item.preco,
            tipoDesconto: 'FIDELIDADE',
          );
        } else if (it.tipoDesconto == 'FIDELIDADE') {
          return it.copyWith(
            precoUnitario: it.item.preco,
            precoOriginal: it.item.preco,
            tipoDesconto: 'NENHUM',
          );
        }
        return it;
      }).toList();

      emit(state.copyWith(
        clienteSelecionado: cliente,
        itensCarrinho: itensAtualizados,
      ));
    }
  }

  void selecionarFormaPagamento(String forma) {
    emit(state.copyWith(formaPagamento: forma));
  }

  void configurarCartao({required String? cartaoId, required int parcelas}) {
    emit(state.copyWith(
      cartaoId: cartaoId,
      parcelas: parcelas,
    ));
  }

  void limparCarrinho() {
    emit(state.copyWith(
      itensCarrinho: const [],
      desconto: 0.0,
      tipoDesconto: 'NENHUM',
      clearCliente: true,
      formaPagamento: 'PIX',
      parcelas: 1,
    ));
  }

  void selecionarStatusPagamento(String status, {String? dataPrevista}) {
    emit(state.copyWith(
      statusPagamento: status,
      dataPrevistaPagamento: dataPrevista,
      clearDataPrevista: dataPrevista == null,
    ));
  }

  Future<void> finalizarVenda({String? observacoes}) async {
    if (state.itensCarrinho.isEmpty) {
      emit(state.copyWith(
        status: VendasStatus.error,
        errorMessage: 'O carrinho está vazio. Adicione itens antes de finalizar.',
      ));
      return;
    }

    emit(state.copyWith(status: VendasStatus.submitting));

    try {
      final String resolvedTipoDesconto = state.desconto > 0
          ? state.tipoDesconto
          : (state.itensCarrinho.any((i) => i.tipoDesconto != 'NENHUM')
              ? state.itensCarrinho.firstWhere((i) => i.tipoDesconto != 'NENHUM').tipoDesconto
              : 'NENHUM');

      final request = VendaRequest(
        clienteId: state.clienteSelecionado?.id,
        desconto: state.desconto,
        tipoDesconto: resolvedTipoDesconto,
        formaPagamento: state.formaPagamento,
        statusPagamento: state.statusPagamento,
        dataPrevistaPagamento: state.dataPrevistaPagamento,
        cartaoId: state.cartaoId,
        parcelas: state.parcelas,
        observacoes: observacoes,
        itens: state.itensCarrinho,
      );

      final resultado = await _repository.finalizarVenda(request);
      final vendaId = (resultado['venda_id'] ?? resultado['id']) as String?;

      emit(state.copyWith(
        status: VendasStatus.success,
        vendaConcluidaId: vendaId,
        itensCarrinho: const [],
        desconto: 0.0,
        tipoDesconto: 'NENHUM',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: VendasStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
