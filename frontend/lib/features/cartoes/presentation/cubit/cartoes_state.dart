import 'package:equatable/equatable.dart';

enum CartoesStatus { initial, loading, loaded, submitting, success, error }

class CartoesState extends Equatable {
  final CartoesStatus status;
  final List<Map<String, dynamic>> cartoes;
  final String filtroEscopo; // 'TODOS', 'PJ', 'PF'
  final Map<String, dynamic>? cartaoSelecionado;
  final String mesReferencia; // Formato 'YYYY-MM'
  final Map<String, dynamic>? faturaDetalhada;
  final String? errorMessage;
  final String? successMessage;

  const CartoesState({
    this.status = CartoesStatus.initial,
    this.cartoes = const [],
    this.filtroEscopo = 'TODOS',
    this.cartaoSelecionado,
    this.mesReferencia = '2026-09',
    this.faturaDetalhada,
    this.errorMessage,
    this.successMessage,
  });

  CartoesState copyWith({
    CartoesStatus? status,
    List<Map<String, dynamic>>? cartoes,
    String? filtroEscopo,
    Map<String, dynamic>? cartaoSelecionado,
    String? mesReferencia,
    Map<String, dynamic>? faturaDetalhada,
    bool clearFatura = false,
    String? errorMessage,
    String? successMessage,
  }) {
    return CartoesState(
      status: status ?? this.status,
      cartoes: cartoes ?? this.cartoes,
      filtroEscopo: filtroEscopo ?? this.filtroEscopo,
      cartaoSelecionado: cartaoSelecionado ?? this.cartaoSelecionado,
      mesReferencia: mesReferencia ?? this.mesReferencia,
      faturaDetalhada: clearFatura ? null : (faturaDetalhada ?? this.faturaDetalhada),
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        cartoes,
        filtroEscopo,
        cartaoSelecionado,
        mesReferencia,
        faturaDetalhada,
        errorMessage,
        successMessage,
      ];
}
