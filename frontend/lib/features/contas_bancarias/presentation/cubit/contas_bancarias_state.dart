import 'package:equatable/equatable.dart';
import '../../domain/models/conta_bancaria_model.dart';

enum ContasBancariasStatus { initial, loading, success, error }

class ContasBancariasState extends Equatable {
  final ContasBancariasStatus status;
  final List<ContaBancariaModel> contas;
  final String filtroEscopo; // 'TODOS', 'PJ', 'PF'
  final bool apenasAtivas;
  final String? errorMessage;
  final String? successMessage;

  const ContasBancariasState({
    this.status = ContasBancariasStatus.initial,
    this.contas = const [],
    this.filtroEscopo = 'TODOS',
    this.apenasAtivas = false,
    this.errorMessage,
    this.successMessage,
  });

  /// Saldo Total das Contas PJ ativas da clínica
  double get saldoTotalPj => contas
      .where((c) => c.isPj && c.ativo)
      .fold(0.0, (sum, c) => sum + c.saldoAtual);

  /// Saldo Total das Contas PF ativas dos sócios
  double get saldoTotalPf => contas
      .where((c) => c.isPf && c.ativo)
      .fold(0.0, (sum, c) => sum + c.saldoAtual);

  /// Saldo Total Consolidado de todas as contas ativas
  double get saldoTotalGeral => contas
      .where((c) => c.ativo)
      .fold(0.0, (sum, c) => sum + c.saldoAtual);

  /// Quantidade total de contas ativas
  int get contasAtivasCount => contas.where((c) => c.ativo).length;

  /// Lista de contas filtradas pela visualização atual
  List<ContaBancariaModel> get contasFiltradas {
    return contas.where((c) {
      if (apenasAtivas && !c.ativo) return false;
      if (filtroEscopo == 'PJ' && !c.isPj) return false;
      if (filtroEscopo == 'PF' && !c.isPf) return false;
      return true;
    }).toList();
  }

  int get totalPjCount => contas.where((c) => c.isPj && c.ativo).length;
  int get totalPfCount => contas.where((c) => c.isPf && c.ativo).length;

  ContasBancariasState copyWith({
    ContasBancariasStatus? status,
    List<ContaBancariaModel>? contas,
    String? filtroEscopo,
    bool? apenasAtivas,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return ContasBancariasState(
      status: status ?? this.status,
      contas: contas ?? this.contas,
      filtroEscopo: filtroEscopo ?? this.filtroEscopo,
      apenasAtivas: apenasAtivas ?? this.apenasAtivas,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        contas,
        filtroEscopo,
        apenasAtivas,
        errorMessage,
        successMessage,
      ];
}
