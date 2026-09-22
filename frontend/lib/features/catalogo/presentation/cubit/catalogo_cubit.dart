import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/catalogo_repository.dart';
import 'catalogo_state.dart';

class CatalogoCubit extends Cubit<CatalogoState> {
  final CatalogoRepository _repository;

  CatalogoCubit({CatalogoRepository? repository})
      : _repository = repository ?? CatalogoRepository(),
        super(const CatalogoState());

  Future<void> carregarTudo({String? busca, String? categoriaId}) async {
    emit(state.copyWith(status: CatalogoStatus.loading));
    try {
      final buscaEfetiva = busca ?? state.filtroBusca;
      final catEfetiva = categoriaId ?? state.filtroCategoriaId;

      final categorias = await _repository.listarCategorias();
      final produtos = await _repository.listarProdutos(busca: buscaEfetiva, categoriaId: catEfetiva);
      final servicos = await _repository.listarServicos(busca: buscaEfetiva, categoriaId: catEfetiva);

      emit(state.copyWith(
        status: CatalogoStatus.loaded,
        categorias: categorias,
        produtos: produtos,
        servicos: servicos,
        filtroBusca: buscaEfetiva,
        filtroCategoriaId: catEfetiva,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CatalogoStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void mudarTab(int index) {
    emit(state.copyWith(tabIndex: index));
  }

  void filtrarPorBusca(String busca) {
    carregarTudo(busca: busca);
  }

  void filtrarPorCategoria(String? categoriaId) {
    if (categoriaId == null) {
      emit(state.copyWith(clearCategoriaFiltro: true));
      carregarTudo(categoriaId: '');
    } else {
      carregarTudo(categoriaId: categoriaId);
    }
  }

  // =================== PRODUTOS ===================
  Future<bool> salvarProduto(Map<String, dynamic> dados, {String? produtoId}) async {
    emit(state.copyWith(status: CatalogoStatus.submitting));
    try {
      await _repository.salvarProduto(dados, produtoId: produtoId);
      emit(state.copyWith(
        status: CatalogoStatus.success,
        successMessage: produtoId != null ? 'Produto atualizado com sucesso!' : 'Produto cadastrado com sucesso!',
      ));
      await carregarTudo();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: CatalogoStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> excluirProduto(String produtoId) async {
    emit(state.copyWith(status: CatalogoStatus.submitting));
    try {
      await _repository.excluirProduto(produtoId);
      emit(state.copyWith(
        status: CatalogoStatus.success,
        successMessage: 'Produto atualizado/removido do catálogo!',
      ));
      await carregarTudo();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: CatalogoStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  // =================== SERVIÇOS ===================
  Future<bool> salvarServico(Map<String, dynamic> dados, {String? servicoId}) async {
    emit(state.copyWith(status: CatalogoStatus.submitting));
    try {
      await _repository.salvarServico(dados, servicoId: servicoId);
      emit(state.copyWith(
        status: CatalogoStatus.success,
        successMessage: servicoId != null ? 'Procedimento atualizado com sucesso!' : 'Procedimento cadastrado com sucesso!',
      ));
      await carregarTudo();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: CatalogoStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> excluirServico(String servicoId) async {
    emit(state.copyWith(status: CatalogoStatus.submitting));
    try {
      await _repository.excluirServico(servicoId);
      emit(state.copyWith(
        status: CatalogoStatus.success,
        successMessage: 'Procedimento desativado com sucesso!',
      ));
      await carregarTudo();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: CatalogoStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }
}
