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
      // 1. Chamada de alta performance à query agregada única no backend
      final resumo = await _repository.obterDashboardResumo(mesConsulta);

      final dre = resumo['dre'] as Map<String, dynamic>? ?? {};
      final alertas = (resumo['alertas_estoque'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final totalAlerta = resumo['total_itens_alerta_estoque'] as int? ?? alertas.length;
      final faturadoPj = double.tryParse(resumo['total_faturado_pj']?.toString() ?? '0') ?? 0.0;
      final despesasPf = double.tryParse(resumo['total_despesas_pf']?.toString() ?? '0') ?? 0.0;
      final balanco = double.tryParse(resumo['balanco_liquido']?.toString() ?? '0') ?? 0.0;
      final vendasEfetivadas = double.tryParse(resumo['vendas_efetivadas']?.toString() ?? '0') ?? 0.0;
      final vendasAReceber = double.tryParse(resumo['vendas_a_receber']?.toString() ?? '0') ?? 0.0;

      emit(state.copyWith(
        status: DashboardStatus.loaded,
        resumoAgregado: resumo,
        dre: dre,
        alertasEstoque: alertas,
        totalItensAlertaEstoque: totalAlerta,
        totalFaturadoPj: faturadoPj,
        totalDespesasPf: despesasPf,
        balancoLiquido: balanco,
        vendasEfetivadas: vendasEfetivadas,
        vendasAReceber: vendasAReceber,
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
        final dre = await _repository.obterDRE(mesConsulta);
        final alertas = await _repository.listarAlertasEstoque();
        emit(state.copyWith(
          status: DashboardStatus.loaded,
          dre: dre,
          alertasEstoque: alertas,
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
