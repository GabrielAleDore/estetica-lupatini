import 'package:equatable/equatable.dart';

enum DashboardStatus { initial, loading, loaded, submitting, success, error }

class DashboardState extends Equatable {
  final DashboardStatus status;
  final String mesReferencia; // Formato 'YYYY-MM'
  final Map<String, dynamic>? dre;
  final Map<String, dynamic>? resumoAgregado;
  final List<Map<String, dynamic>> alertasEstoque;
  final List<Map<String, dynamic>> produtos;
  final int totalItensAlertaEstoque;
  final double totalFaturadoPj;
  final double totalDespesasPf;
  final double balancoLiquido;
  final double vendasEfetivadas;
  final double vendasAReceber;

  // Receitas Avulsas / Manuais (PIX, Aportes, etc.)
  final double receitasAvulsasPJ;
  final double receitasAvulsasPF;
  final List<Map<String, dynamic>> transacoesReceitas;

  // Indicadores de Contas Bancárias (Liquidez Imediata)
  final double saldoTotalPJ;
  final double saldoTotalPF;
  final double saldoTotalGeral;
  final int qtdContasPJ;
  final int qtdContasPF;
  final List<Map<String, dynamic>> contasBancarias;

  final String? errorMessage;
  final String? successMessage;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.mesReferencia = '2026-09',
    this.dre,
    this.resumoAgregado,
    this.alertasEstoque = const [],
    this.produtos = const [],
    this.totalItensAlertaEstoque = 0,
    this.totalFaturadoPj = 0.0,
    this.totalDespesasPf = 0.0,
    this.balancoLiquido = 0.0,
    this.vendasEfetivadas = 0.0,
    this.vendasAReceber = 0.0,
    this.receitasAvulsasPJ = 0.0,
    this.receitasAvulsasPF = 0.0,
    this.transacoesReceitas = const [],
    this.saldoTotalPJ = 0.0,
    this.saldoTotalPF = 0.0,
    this.saldoTotalGeral = 0.0,
    this.qtdContasPJ = 0,
    this.qtdContasPF = 0,
    this.contasBancarias = const [],
    this.errorMessage,
    this.successMessage,
  });

  /// Totalizador de Receitas do Mês: Vendas Efetivadas + Entradas Avulsas Efetivadas
  double get faturamentoTotalConsolidadoPJ => vendasEfetivadas + receitasAvulsasPJ;

  DashboardState copyWith({
    DashboardStatus? status,
    String? mesReferencia,
    Map<String, dynamic>? dre,
    Map<String, dynamic>? resumoAgregado,
    List<Map<String, dynamic>>? alertasEstoque,
    List<Map<String, dynamic>>? produtos,
    int? totalItensAlertaEstoque,
    double? totalFaturadoPj,
    double? totalDespesasPf,
    double? balancoLiquido,
    double? vendasEfetivadas,
    double? vendasAReceber,
    double? receitasAvulsasPJ,
    double? receitasAvulsasPF,
    List<Map<String, dynamic>>? transacoesReceitas,
    double? saldoTotalPJ,
    double? saldoTotalPF,
    double? saldoTotalGeral,
    int? qtdContasPJ,
    int? qtdContasPF,
    List<Map<String, dynamic>>? contasBancarias,
    String? errorMessage,
    String? successMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      mesReferencia: mesReferencia ?? this.mesReferencia,
      dre: dre ?? this.dre,
      resumoAgregado: resumoAgregado ?? this.resumoAgregado,
      alertasEstoque: alertasEstoque ?? this.alertasEstoque,
      produtos: produtos ?? this.produtos,
      totalItensAlertaEstoque: totalItensAlertaEstoque ?? this.totalItensAlertaEstoque,
      totalFaturadoPj: totalFaturadoPj ?? this.totalFaturadoPj,
      totalDespesasPf: totalDespesasPf ?? this.totalDespesasPf,
      balancoLiquido: balancoLiquido ?? this.balancoLiquido,
      vendasEfetivadas: vendasEfetivadas ?? this.vendasEfetivadas,
      vendasAReceber: vendasAReceber ?? this.vendasAReceber,
      receitasAvulsasPJ: receitasAvulsasPJ ?? this.receitasAvulsasPJ,
      receitasAvulsasPF: receitasAvulsasPF ?? this.receitasAvulsasPF,
      transacoesReceitas: transacoesReceitas ?? this.transacoesReceitas,
      saldoTotalPJ: saldoTotalPJ ?? this.saldoTotalPJ,
      saldoTotalPF: saldoTotalPF ?? this.saldoTotalPF,
      saldoTotalGeral: saldoTotalGeral ?? this.saldoTotalGeral,
      qtdContasPJ: qtdContasPJ ?? this.qtdContasPJ,
      qtdContasPF: qtdContasPF ?? this.qtdContasPF,
      contasBancarias: contasBancarias ?? this.contasBancarias,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        mesReferencia,
        dre,
        resumoAgregado,
        alertasEstoque,
        produtos,
        totalItensAlertaEstoque,
        totalFaturadoPj,
        totalDespesasPf,
        balancoLiquido,
        vendasEfetivadas,
        vendasAReceber,
        receitasAvulsasPJ,
        receitasAvulsasPF,
        transacoesReceitas,
        saldoTotalPJ,
        saldoTotalPF,
        saldoTotalGeral,
        qtdContasPJ,
        qtdContasPF,
        contasBancarias,
        errorMessage,
        successMessage,
      ];
}
