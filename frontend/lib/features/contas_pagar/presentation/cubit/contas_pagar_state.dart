import 'package:equatable/equatable.dart';

enum ContasPagarStatus { initial, loading, loaded, error }

class ContasPagarState extends Equatable {
  final ContasPagarStatus status;
  final List<Map<String, dynamic>> contas;
  final List<Map<String, dynamic>> categorias;
  final String filtroAba; // 'TODAS', 'PENDENTE', 'PAGO', 'VENCIDAS'
  final String filtroEscopo; // 'TODOS', 'PJ', 'PF'
  final String filtroMes; // 'TODOS' ou 'yyyy-MM'
  final String? errorMessage;
  final String? successMessage;

  const ContasPagarState({
    this.status = ContasPagarStatus.initial,
    this.contas = const [],
    this.categorias = const [],
    this.filtroAba = 'PENDENTE',
    this.filtroEscopo = 'TODOS',
    this.filtroMes = 'TODOS',
    this.errorMessage,
    this.successMessage,
  });

  double get totalPendenteGeral => contas
      .where((c) => c['status'] == 'PENDENTE')
      .fold(0.0, (acc, c) => acc + ((c['valor_total'] as num?)?.toDouble() ?? 0.0));

  double get totalVencidasGeral {
    final hojeStr = DateTime.now().toIso8601String().substring(0, 10);
    return contas
        .where((c) => c['status'] == 'PENDENTE' && (c['data_vencimento']?.toString() ?? '').isNotEmpty && (c['data_vencimento']?.toString() ?? '').compareTo(hojeStr) < 0)
        .fold(0.0, (acc, c) => acc + ((c['valor_total'] as num?)?.toDouble() ?? 0.0));
  }

  double get totalPendentePj => totalPendenteGeral;

  double get totalPendentePf => 0.0;

  double get totalPagoMes => contas
      .where((c) => c['status'] == 'PAGO')
      .fold(0.0, (acc, c) => acc + ((c['valor_total'] as num?)?.toDouble() ?? 0.0));

  List<Map<String, dynamic>> get contasFiltradas {
    final hojeStr = DateTime.now().toIso8601String().substring(0, 10);

    return contas.where((c) {
      // Filtro por escopo
      if (filtroEscopo != 'TODOS' && c['escopo'] != filtroEscopo) {
        return false;
      }

      // Filtro por mês de vencimento
      if (filtroMes != 'TODOS') {
        final venc = c['data_vencimento']?.toString() ?? '';
        if (!venc.startsWith(filtroMes)) {
          return false;
        }
      }

      // Filtro por aba
      if (filtroAba == 'PENDENTE') {
        return c['status'] == 'PENDENTE';
      } else if (filtroAba == 'PAGO') {
        return c['status'] == 'PAGO';
      } else if (filtroAba == 'VENCIDAS') {
        final venc = c['data_vencimento']?.toString() ?? '';
        return c['status'] == 'PENDENTE' && venc.compareTo(hojeStr) < 0;
      }
      return true;
    }).toList();
  }

  ContasPagarState copyWith({
    ContasPagarStatus? status,
    List<Map<String, dynamic>>? contas,
    List<Map<String, dynamic>>? categorias,
    String? filtroAba,
    String? filtroEscopo,
    String? filtroMes,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return ContasPagarState(
      status: status ?? this.status,
      contas: contas ?? this.contas,
      categorias: categorias ?? this.categorias,
      filtroAba: filtroAba ?? this.filtroAba,
      filtroEscopo: filtroEscopo ?? this.filtroEscopo,
      filtroMes: filtroMes ?? this.filtroMes,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        contas,
        categorias,
        filtroAba,
        filtroEscopo,
        filtroMes,
        errorMessage,
        successMessage,
      ];
}
