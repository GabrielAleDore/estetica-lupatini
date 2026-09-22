import 'package:equatable/equatable.dart';

enum HistoricoStatus { initial, loading, loaded, error }

class VendasHistoricoState extends Equatable {
  final HistoricoStatus status;
  final List<Map<String, dynamic>> vendas;
  final String filtroStatusPagamento; // 'TODOS', 'EFETIVADO', 'PENDENTE'
  final String filtroPeriodo; // 'HOJE', '7DIAS', 'MES', 'TODOS'
  final String buscaCliente;
  final String? errorMessage;
  final String? successMessage;

  const VendasHistoricoState({
    this.status = HistoricoStatus.initial,
    this.vendas = const [],
    this.filtroStatusPagamento = 'TODOS',
    this.filtroPeriodo = 'MES',
    this.buscaCliente = '',
    this.errorMessage,
    this.successMessage,
  });

  double get totalEfetivado {
    return vendas
        .where((v) => v['status_pagamento'] == 'EFETIVADO' && v['status'] != 'CANCELADA')
        .fold(0.0, (acc, v) => acc + ((v['valor_liquido'] as num?)?.toDouble() ?? 0.0));
  }

  double get totalPendente {
    return vendas
        .where((v) => v['status_pagamento'] == 'PENDENTE' && v['status'] != 'CANCELADA')
        .fold(0.0, (acc, v) => acc + ((v['valor_liquido'] as num?)?.toDouble() ?? 0.0));
  }

  VendasHistoricoState copyWith({
    HistoricoStatus? status,
    List<Map<String, dynamic>>? vendas,
    String? filtroStatusPagamento,
    String? filtroPeriodo,
    String? buscaCliente,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return VendasHistoricoState(
      status: status ?? this.status,
      vendas: vendas ?? this.vendas,
      filtroStatusPagamento: filtroStatusPagamento ?? this.filtroStatusPagamento,
      filtroPeriodo: filtroPeriodo ?? this.filtroPeriodo,
      buscaCliente: buscaCliente ?? this.buscaCliente,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        vendas,
        filtroStatusPagamento,
        filtroPeriodo,
        buscaCliente,
        errorMessage,
        successMessage,
      ];
}
