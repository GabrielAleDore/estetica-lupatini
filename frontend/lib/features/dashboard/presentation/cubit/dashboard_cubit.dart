import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/dashboard_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final DashboardRepository _repository;

  DashboardCubit({DashboardRepository? repository})
      : _repository = repository ?? DashboardRepository(),
        super(const DashboardState());

  Future<void> carregarDashboard({String? mes}) async {
    final mesConsulta = mes ?? state.mesReferencia;
    emit(state.copyWith(status: DashboardStatus.loading, mesReferencia: mesConsulta));

    try {
      // 1. Chamada concorrente: resumo gerencial agregado + saldos bancários + receitas avulsas manuais
      final results = await Future.wait([
        _repository.obterDashboardResumo(mesConsulta),
        _repository.obterResumoContasBancarias(),
        _repository.obterReceitasManuaisMes(mesConsulta),
      ]);

      final resumo = results[0];
      final resumoBancario = results[1];
      final receitasManuais = results[2];

      final dre = Map<String, dynamic>.from(resumo['dre'] as Map? ?? {});
      final alertas = (resumo['alertas_estoque'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final totalAlerta = resumo['total_itens_alerta_estoque'] as int? ?? alertas.length;
      final faturadoPjBase = double.tryParse(resumo['total_faturado_pj']?.toString() ?? '0') ?? 0.0;
      final despesasPf = double.tryParse(resumo['total_despesas_pf']?.toString() ?? '0') ?? 0.0;
      final balancoBase = double.tryParse(resumo['balanco_liquido']?.toString() ?? '0') ?? 0.0;
      final vendasEfetivadas = double.tryParse(resumo['vendas_efetivadas']?.toString() ?? '0') ?? faturadoPjBase;
      final vendasAReceber = double.tryParse(resumo['vendas_a_receber']?.toString() ?? '0') ?? 0.0;

      // Dados de receitas avulsas manuais (todas as contas)
      final recAvulsasPJ = double.tryParse(receitasManuais['total_receitas_pj']?.toString() ?? '0') ?? 0.0;
      final recAvulsasPF = double.tryParse(receitasManuais['total_receitas_pf']?.toString() ?? '0') ?? 0.0;
      final totalRecAvulsas = recAvulsasPJ + recAvulsasPF;
      final listaReceitas = (receitasManuais['transacoes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // A procedure do banco já inclui as receitas avulsas nos totais (fonte única da verdade)
      final faturadoConsolidadoPj = faturadoPjBase;
      final balancoConsolidado = balancoBase;
      final vendasEfetivadasTotal = vendasEfetivadas;

      // Atualiza no DRE em memória
      dre['receita_liquida'] = faturadoConsolidadoPj;
      dre['receitas_avulsas_pj'] = totalRecAvulsas;

      // Dados de liquidez bancária
      final saldoPJ = double.tryParse(resumoBancario['saldo_total_pj']?.toString() ?? '0') ?? 0.0;
      final saldoPF = double.tryParse(resumoBancario['saldo_total_pf']?.toString() ?? '0') ?? 0.0;
      final saldoGeral = double.tryParse(resumoBancario['saldo_total_geral']?.toString() ?? '0') ?? (saldoPJ + saldoPF);
      final qtdPJ = resumoBancario['qtd_contas_pj'] as int? ?? 0;
      final qtdPF = resumoBancario['qtd_contas_pf'] as int? ?? 0;
      final contasBancarias = (resumoBancario['contas'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      emit(state.copyWith(
        status: DashboardStatus.loaded,
        resumoAgregado: resumo,
        dre: dre,
        alertasEstoque: alertas,
        totalItensAlertaEstoque: totalAlerta,
        totalFaturadoPj: faturadoConsolidadoPj,
        totalDespesasPf: despesasPf,
        balancoLiquido: balancoConsolidado,
        vendasEfetivadas: vendasEfetivadasTotal,
        vendasAReceber: vendasAReceber,
        receitasAvulsasPJ: recAvulsasPJ,
        receitasAvulsasPF: recAvulsasPF,
        transacoesReceitas: listaReceitas,
        saldoTotalPJ: saldoPJ,
        saldoTotalPF: saldoPF,
        saldoTotalGeral: saldoGeral,
        qtdContasPJ: qtdPJ,
        qtdContasPF: qtdPF,
        contasBancarias: contasBancarias,
        mesReferencia: mesConsulta,
      ));

      // 2. Carrega catálogo de produtos em segundo plano (apenas para o dropdown de entrada de estoque)
      if (state.produtos.isEmpty) {
        _repository.listarProdutos().then((prods) {
          if (!isClosed) {
            emit(state.copyWith(produtos: prods));
          }
        }).catchError((_) {});
      }
    } catch (e) {
      // Fallback gracioso caso endpoint agregado encontre erro
      try {
        final resultsFallback = await Future.wait([
          _repository.obterDRE(mesConsulta),
          _repository.listarAlertasEstoque(),
          _repository.obterResumoContasBancarias(),
          _repository.obterReceitasManuaisMes(mesConsulta),
        ]);
        final dre = Map<String, dynamic>.from(resultsFallback[0] as Map? ?? {});
        final alertas = resultsFallback[1] as List<Map<String, dynamic>>;
        final resumoBancario = resultsFallback[2] as Map<String, dynamic>;
        final receitasManuais = resultsFallback[3] as Map<String, dynamic>;

        final saldoPJ = double.tryParse(resumoBancario['saldo_total_pj']?.toString() ?? '0') ?? 0.0;
        final saldoPF = double.tryParse(resumoBancario['saldo_total_pf']?.toString() ?? '0') ?? 0.0;
        final saldoGeral = double.tryParse(resumoBancario['saldo_total_geral']?.toString() ?? '0') ?? (saldoPJ + saldoPF);
        final qtdPJ = resumoBancario['qtd_contas_pj'] as int? ?? 0;
        final qtdPF = resumoBancario['qtd_contas_pf'] as int? ?? 0;
        final contasBancarias = (resumoBancario['contas'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        final recAvulsasPJ = double.tryParse(receitasManuais['total_receitas_pj']?.toString() ?? '0') ?? 0.0;
        final recAvulsasPF = double.tryParse(receitasManuais['total_receitas_pf']?.toString() ?? '0') ?? 0.0;
        final listaReceitas = (receitasManuais['transacoes'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        emit(state.copyWith(
          status: DashboardStatus.loaded,
          dre: dre,
          alertasEstoque: alertas,
          receitasAvulsasPJ: recAvulsasPJ,
          receitasAvulsasPF: recAvulsasPF,
          transacoesReceitas: listaReceitas,
          saldoTotalPJ: saldoPJ,
          saldoTotalPF: saldoPF,
          saldoTotalGeral: saldoGeral,
          qtdContasPJ: qtdPJ,
          qtdContasPF: qtdPF,
          contasBancarias: contasBancarias,
          mesReferencia: mesConsulta,
        ));
      } catch (errFallback) {
        emit(state.copyWith(
          status: DashboardStatus.error,
          errorMessage: errFallback.toString(),
        ));
      }
    }
  }

  void mudarMes(String novoMes) {
    carregarDashboard(mes: novoMes);
  }

  Future<bool> darEntradaEstoque({
    required String produtoId,
    required double quantidade,
    double? custoUnitario,
    String? motivo,
  }) async {
    emit(state.copyWith(status: DashboardStatus.submitting));
    try {
      await _repository.darEntradaEstoque(
        produtoId: produtoId,
        quantidade: quantidade,
        custoUnitario: custoUnitario,
        motivo: motivo,
      );
      emit(state.copyWith(
        status: DashboardStatus.success,
        successMessage: 'Entrada de estoque registrada com sucesso!',
      ));
      await carregarDashboard();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> registrarReceitaAvulsa(Map<String, dynamic> dados) async {
    emit(state.copyWith(status: DashboardStatus.submitting));
    try {
      await _repository.registrarReceitaAvulsa(dados);
      emit(state.copyWith(
        status: DashboardStatus.success,
        successMessage: 'Entrada / Receita avulsa registrada e saldo creditado com sucesso!',
      ));
      await carregarDashboard();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }

  Future<bool> registrarTransacaoAvulsa(Map<String, dynamic> dados) async {
    emit(state.copyWith(status: DashboardStatus.submitting));
    try {
      await _repository.registrarTransacaoAvulsa(dados);
      emit(state.copyWith(
        status: DashboardStatus.success,
        successMessage: 'Lançamento financeiro registrado com sucesso!',
      ));
      await carregarDashboard();
      return true;
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.toString(),
      ));
      return false;
    }
  }
}
