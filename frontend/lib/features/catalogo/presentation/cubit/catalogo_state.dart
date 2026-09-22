import 'package:equatable/equatable.dart';

enum CatalogoStatus { initial, loading, loaded, submitting, success, error }

class CatalogoState extends Equatable {
  final CatalogoStatus status;
  final List<Map<String, dynamic>> produtos;
  final List<Map<String, dynamic>> servicos;
  final List<Map<String, dynamic>> categorias;
  final String filtroBusca;
  final String? filtroCategoriaId;
  final int tabIndex; // 0: Serviços, 1: Produtos
  final String? successMessage;
  final String? errorMessage;

  const CatalogoState({
    this.status = CatalogoStatus.initial,
    this.produtos = const [],
    this.servicos = const [],
    this.categorias = const [],
    this.filtroBusca = '',
    this.filtroCategoriaId,
    this.tabIndex = 0,
    this.successMessage,
    this.errorMessage,
  });

  CatalogoState copyWith({
    CatalogoStatus? status,
    List<Map<String, dynamic>>? produtos,
    List<Map<String, dynamic>>? servicos,
    List<Map<String, dynamic>>? categorias,
    String? filtroBusca,
    String? filtroCategoriaId,
    bool clearCategoriaFiltro = false,
    int? tabIndex,
    String? successMessage,
    String? errorMessage,
  }) {
    return CatalogoState(
      status: status ?? this.status,
      produtos: produtos ?? this.produtos,
      servicos: servicos ?? this.servicos,
      categorias: categorias ?? this.categorias,
      filtroBusca: filtroBusca ?? this.filtroBusca,
      filtroCategoriaId: clearCategoriaFiltro ? null : (filtroCategoriaId ?? this.filtroCategoriaId),
      tabIndex: tabIndex ?? this.tabIndex,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        produtos,
        servicos,
        categorias,
        filtroBusca,
        filtroCategoriaId,
        tabIndex,
        successMessage,
        errorMessage,
      ];
}
