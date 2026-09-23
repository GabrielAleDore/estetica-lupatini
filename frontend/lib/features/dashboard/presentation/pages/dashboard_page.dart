import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/entrada_estoque_dialog.dart';
import '../widgets/lancamento_avulso_dialog.dart';
import '../../services/relatorio_dre_pdf_service.dart';
import '../../../shell/main_navigation_shell.dart';
import '../../../contas_bancarias/presentation/pages/contas_bancarias_page.dart';

class DashboardPage extends StatelessWidget {
  final DashboardCubit? cubit;
  const DashboardPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: const _DashboardView());
    }
    try {
      context.read<DashboardCubit>();
      return const _DashboardView();
    } catch (_) {
      return BlocProvider(
        create: (_) => DashboardCubit()..carregarDashboard(),
        child: const _DashboardView(),
      );
    }
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  void _abrirModalEntradaEstoque(BuildContext context, List<Map<String, dynamic>> produtos, [String? produtoId]) {
    final cubit = context.read<DashboardCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EntradaEstoqueDialog(
        produtos: produtos,
        produtoIdInicial: produtoId,
        onSalvar: ({required produtoId, required quantidade, custoUnitario, motivo}) =>
            cubit.darEntradaEstoque(
          produtoId: produtoId,
          quantidade: quantidade,
          custoUnitario: custoUnitario,
          motivo: motivo,
        ),
      ),
    );
  }

  void _abrirModalLancamentoAvulso(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LancamentoAvulsoDialog(
        onSalvar: (dados) => cubit.registrarTransacaoAvulsa(dados),
      ),
    );
  }

  void _abrirModalGerarDre(BuildContext context, String mesReferenciaAtual) {
    showDialog(
      context: context,
      builder: (_) => _GerarDreDialog(mesReferenciaInicial: mesReferenciaAtual),
    );
  }

  void _navegarParaContasBancarias(BuildContext context) {
    try {
      MainNavigationShell.navegarPara('Contas Bancárias');
    } catch (_) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ContasBancariasPage()),
      );
    }
  }

  String _ajustarMes(String mesAtual, int delta) {
    try {
      final partes = mesAtual.split('-');
      final ano = int.parse(partes[0]);
      final mes = int.parse(partes[1]);
      final dt = DateTime(ano, mes + delta, 1);
      return DateFormat('yyyy-MM').format(dt);
    } catch (_) {
      return mesAtual;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Executivo & DRE Gerencial'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Dados',
            onPressed: () => context.read<DashboardCubit>().carregarDashboard(),
          ),
        ],
      ),
      body: BlocConsumer<DashboardCubit, DashboardState>(
        listener: (context, state) {
          if (state.status == DashboardStatus.success && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.success, content: Text(state.successMessage!)),
            );
          } else if (state.status == DashboardStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.error, content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<DashboardCubit>();

          // Exibe Shimmer Skeleton Loading durante o carregamento inicial dos dados
          if (state.status == DashboardStatus.loading && state.dre == null) {
            return const _DashboardSkeletonLoading();
          }

          final dre = state.dre ?? {};
          final receitaLiquida = state.totalFaturadoPj > 0
              ? state.totalFaturadoPj
              : (double.tryParse(dre['receita_liquida']?.toString() ?? '0') ?? 0.0);
          final despesasOperacionais = double.tryParse(dre['despesas_operacionais_pj']?.toString() ?? '0') ?? 0.0;
          final cpv = double.tryParse(dre['custo_produtos_vendidos']?.toString() ?? '0') ?? 0.0;
          final cis = double.tryParse(dre['custo_insumos_procedimentos']?.toString() ??
              dre['custo_insumos_servicos']?.toString() ?? '0') ?? 0.0;
          final totalCustosPj = despesasOperacionais + cpv + cis;
          final lucroOperacionalPj = double.tryParse(dre['resultado_operacional_pj']?.toString() ?? '0') ??
              (receitaLiquida - totalCustosPj);
          final gastosSociosPf = state.totalDespesasPf > 0
              ? state.totalDespesasPf
              : (double.tryParse(dre['gastos_pessoais_pf']?.toString() ?? '0') ?? 0.0);
          final saldoFinal = state.balancoLiquido != 0.0
              ? state.balancoLiquido
              : (double.tryParse(dre['saldo_caixa_final']?.toString() ?? '0') ?? (lucroOperacionalPj - gastosSociosPf));

          final totalAlertaEstoque = state.totalItensAlertaEstoque;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barra de Mês + Ações Rápidas (Responsivo)
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Seletor de Mês de Competência
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            onPressed: () => cubit.mudarMes(_ajustarMes(state.mesReferencia, -1)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                            child: Text(
                              'Competência: ${state.mesReferencia}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            onPressed: () => cubit.mudarMes(_ajustarMes(state.mesReferencia, 1)),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Botões de Ação Rápida
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _abrirModalEntradaEstoque(context, state.produtos),
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text('ENTRADA DE ESTOQUE'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _abrirModalLancamentoAvulso(context),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text(
                            'NOVO GASTO AVULSO',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _abrirModalGerarDre(context, state.mesReferencia),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text(
                            'GERAR RELATÓRIO DRE',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 1. Bloco de Liquidez Financeira Imediata (Contas Bancárias PJ e PF)
                _BankLiquidityBlock(
                  saldoTotalPJ: state.saldoTotalPJ,
                  saldoTotalPF: state.saldoTotalPF,
                  saldoTotalGeral: state.saldoTotalGeral,
                  qtdContasPJ: state.qtdContasPJ,
                  qtdContasPF: state.qtdContasPF,
                  saldoOperacionalMes: lucroOperacionalPj,
                  onGerenciarContas: () => _navegarParaContasBancarias(context),
                ),
                const SizedBox(height: 24),

                // 2 Cards Destaque: Vendas Efetivadas vs A Receber
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    if (!isWide) {
                      return Column(
                        children: [
                          _HighlightCard(
                            title: 'Vendas Efetivadas (Recebidas)',
                            value: currencyFormat.format(state.vendasEfetivadas),
                            subtitle: 'Recebimentos confirmados e liquidados no caixa',
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF2E7D32),
                            accentBg: const Color(0xFFE8F5E9),
                          ),
                          const SizedBox(height: 12),
                          _HighlightCard(
                            title: 'Vendas a Receber (Pendentes)',
                            value: currencyFormat.format(state.vendasAReceber),
                            subtitle: 'Vendas a prazo / Fiado pendente de liquidação',
                            icon: Icons.pending_actions_outlined,
                            color: const Color(0xFFE65100),
                            accentBg: const Color(0xFFFFF3E0),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: _HighlightCard(
                            title: 'Vendas Efetivadas (Recebidas)',
                            value: currencyFormat.format(state.vendasEfetivadas),
                            subtitle: 'Recebimentos confirmados e liquidados no caixa',
                            icon: Icons.check_circle_outline,
                            color: const Color(0xFF2E7D32),
                            accentBg: const Color(0xFFE8F5E9),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _HighlightCard(
                            title: 'Vendas a Receber (Pendentes)',
                            value: currencyFormat.format(state.vendasAReceber),
                            subtitle: 'Vendas a prazo / Fiado pendente de liquidação',
                            icon: Icons.pending_actions_outlined,
                            color: const Color(0xFFE65100),
                            accentBg: const Color(0xFFFFF3E0),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 4 Cards de Métricas DRE (Grid)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isWide ? 1.6 : 1.3,
                      children: [
                        _MetricCard(
                          title: 'Total Faturado (PJ)',
                          value: currencyFormat.format(receitaLiquida),
                          subtitle: 'Receita Líquida no Mês',
                          icon: Icons.trending_up,
                          color: AppColors.pjClinical,
                        ),
                        _MetricCard(
                          title: 'Despesas Fixas (PJ)',
                          value: currencyFormat.format(despesasOperacionais),
                          subtitle: 'Custos operacionais clínica',
                          icon: Icons.business,
                          color: Colors.orange.shade700,
                        ),
                        _MetricCard(
                          title: 'Gastos Pessoais (PF)',
                          value: currencyFormat.format(gastosSociosPf),
                          subtitle: 'Segregado: Sócios',
                          icon: Icons.person_pin,
                          color: AppColors.pfPersonal,
                        ),
                        _MetricCard(
                          title: 'Balanço Líquido (Caixa)',
                          value: currencyFormat.format(saldoFinal),
                          subtitle: saldoFinal >= 0 ? 'Resultado Positivo' : 'Alerta de Déficit',
                          icon: Icons.account_balance_wallet,
                          color: saldoFinal >= 0 ? AppColors.success : AppColors.error,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Seção DRE Detalhado com Segregação Cirúrgica
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.analytics_outlined, color: AppColors.primaryDark),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Demonstrativo do Resultado do Exercício (DRE) Gerencial',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _DRELineItem(
                        label: '(+) Receita Bruta Total',
                        value: currencyFormat.format(double.tryParse(dre['receita_bruta']?.toString() ?? '0') ?? 0.0),
                        isBold: true,
                      ),
                      _DRELineItem(
                        label: '(-) Descontos Comerciais Concedidos',
                        value: currencyFormat.format(double.tryParse(dre['descontos_concedidos']?.toString() ?? '0') ?? 0.0),
                        color: AppColors.textSecondaryLight,
                      ),
                      _DRELineItem(
                        label: '(=) Receita Líquida da Clínica (PJ)',
                        value: currencyFormat.format(receitaLiquida),
                        isBold: true,
                        color: AppColors.pjClinical,
                      ),
                      const Divider(height: 16),
                      _DRELineItem(
                        label: '(-) CPV - Custo Produtos Vendidos (Home Care)',
                        value: currencyFormat.format(cpv),
                        color: Colors.red.shade700,
                      ),
                      _DRELineItem(
                        label: '(-) CIS - Insumos Técnicos Consumidos (Procedimentos)',
                        value: currencyFormat.format(cis),
                        color: Colors.red.shade700,
                      ),
                      _DRELineItem(
                        label: '(-) Despesas Fixas e Operacionais da Clínica (PJ)',
                        value: currencyFormat.format(despesasOperacionais),
                        color: Colors.red.shade700,
                      ),
                      _DRELineItem(
                        label: '(=) Resultado Operacional da Clínica (PJ)',
                        value: currencyFormat.format(lucroOperacionalPj),
                        isBold: true,
                        color: lucroOperacionalPj >= 0 ? AppColors.success : AppColors.error,
                      ),
                      const Divider(height: 16),
                      _DRELineItem(
                        label: '(-) Gastos e Retiradas Pessoais dos Sócios (PF)',
                        value: currencyFormat.format(gastosSociosPf),
                        isBold: true,
                        color: AppColors.pfPersonal,
                      ),
                      const Divider(height: 16),
                      _DRELineItem(
                        label: '(=) Saldo Final em Caixa (Resultado Líquido)',
                        value: currencyFormat.format(saldoFinal),
                        isBold: true,
                        color: saldoFinal >= 0 ? AppColors.success : AppColors.error,
                        isHighlighted: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Seção de Alertas de Estoque Crítico
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                              const SizedBox(width: 8),
                              const Text(
                                'Alertas de Estoque Crítico',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              if (totalAlertaEstoque > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$totalAlertaEstoque itens',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => _abrirModalEntradaEstoque(context, state.produtos),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Dar Entrada'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (state.alertasEstoque.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              'Nenhum produto com estoque crítico ou abaixo do mínimo no momento.',
                              style: TextStyle(color: AppColors.textSecondaryLight),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.alertasEstoque.length,
                          separatorBuilder: (_, __) => const Divider(height: 8),
                          itemBuilder: (context, index) {
                            final item = state.alertasEstoque[index];
                            final statusAlerta = item['status_alerta'] ?? 'BAIXO';
                            final isCritico = statusAlerta == 'CRITICO';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isCritico
                                    ? AppColors.error.withValues(alpha: 0.15)
                                    : AppColors.warning.withValues(alpha: 0.15),
                                child: Icon(
                                  isCritico ? Icons.error_outline : Icons.warning_amber_outlined,
                                  color: isCritico ? AppColors.error : AppColors.warning,
                                ),
                              ),
                              title: Text(item['nome'] ?? 'Produto', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                'Saldo: ${item['quantidade_estoque']} ${item['unidade_medida']} (Mínimo: ${item['estoque_minimo']})  •  Déficit: ${item['deficit']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: ElevatedButton.icon(
                                onPressed: () => _abrirModalEntradaEstoque(
                                  context,
                                  state.produtos,
                                  item['id'],
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                icon: const Icon(Icons.add_shopping_cart, size: 14),
                                label: const Text('Repor', style: TextStyle(fontSize: 12)),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color accentBg;

  const _HighlightCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.accentBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// BLOCO DE LIQUIDEZ FINANCEIRA IMEDIATA (CONTAS BANCÁRIAS PJ E PF)
// =====================================================================

class _BankLiquidityBlock extends StatelessWidget {
  final double saldoTotalPJ;
  final double saldoTotalPF;
  final double saldoTotalGeral;
  final int qtdContasPJ;
  final int qtdContasPF;
  final double saldoOperacionalMes;
  final VoidCallback onGerenciarContas;

  const _BankLiquidityBlock({
    required this.saldoTotalPJ,
    required this.saldoTotalPF,
    required this.saldoTotalGeral,
    required this.qtdContasPJ,
    required this.qtdContasPF,
    required this.saldoOperacionalMes,
    required this.onGerenciarContas,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do Bloco com Segregação e Ação Rápida
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liquidez Financeira Imediata • Contas Bancárias',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Disponibilidade em tempo real com segregação entre Clínica (PJ) e Sócios (PF)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onGerenciarContas,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('VER CONTAS BANCÁRIAS'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 3 Cards Responsivos
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 950;
              final isTablet = constraints.maxWidth > 650;

              final cardPj = _BankLiquidityCard(
                badgeLabel: 'PJ • CLÍNICA',
                badgeColor: AppColors.pjClinical,
                badgeTextColor: Colors.white,
                title: 'Saldo Disponível Clínica (PJ)',
                value: currencyFormat.format(saldoTotalPJ),
                subtitle: qtdContasPJ == 0
                    ? 'Nenhuma conta PJ ativa'
                    : '$qtdContasPJ ${qtdContasPJ == 1 ? "conta operacional ativa" : "contas operacionais ativas"}',
                description: 'Recursos para custeio, insumos e operação clínica',
                icon: Icons.business_center_rounded,
                accentColor: AppColors.pjClinical,
                accentBg: const Color(0xFFF7ECE8),
                onTap: onGerenciarContas,
              );

              final cardPf = _BankLiquidityCard(
                badgeLabel: 'PF • SÓCIOS',
                badgeColor: const Color(0xFFB07D4F),
                badgeTextColor: Colors.white,
                title: 'Saldo Pessoal / Sócios (PF)',
                value: currencyFormat.format(saldoTotalPF),
                subtitle: qtdContasPF == 0
                    ? 'Nenhuma conta PF ativa'
                    : '$qtdContasPF ${qtdContasPF == 1 ? "conta pessoal ativa" : "contas pessoais ativas"}',
                description: 'Patrimônio segregado dos sócios (PF)',
                icon: Icons.person_pin_rounded,
                accentColor: const Color(0xFFB07D4F),
                accentBg: const Color(0xFFFAF3EC),
                onTap: onGerenciarContas,
              );

              final cardTotal = _BankLiquidityCard(
                badgeLabel: 'PATRIMÔNIO LÍQUIDO BANCÁRIO',
                badgeColor: const Color(0xFF1B5E20),
                badgeTextColor: Colors.white,
                title: 'Patrimônio Líquido (Total)',
                value: currencyFormat.format(saldoTotalGeral),
                subtitle: '${qtdContasPJ + qtdContasPF} contas bancárias ativas',
                description: 'Saldo Operacional Mês: ${currencyFormat.format(saldoOperacionalMes)}',
                icon: Icons.account_balance_wallet_rounded,
                accentColor: const Color(0xFF2E7D32),
                accentBg: const Color(0xFFE8F5E9),
                isHighlighted: true,
                onTap: onGerenciarContas,
              );

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cardPj),
                    const SizedBox(width: 14),
                    Expanded(child: cardPf),
                    const SizedBox(width: 14),
                    Expanded(child: cardTotal),
                  ],
                );
              }

              if (isTablet) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: cardPj),
                        const SizedBox(width: 14),
                        Expanded(child: cardPf),
                      ],
                    ),
                    const SizedBox(height: 14),
                    cardTotal,
                  ],
                );
              }

              return Column(
                children: [
                  cardPj,
                  const SizedBox(height: 12),
                  cardPf,
                  const SizedBox(height: 12),
                  cardTotal,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BankLiquidityCard extends StatelessWidget {
  final String badgeLabel;
  final Color badgeColor;
  final Color badgeTextColor;
  final String title;
  final String value;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final Color accentBg;
  final bool isHighlighted;
  final VoidCallback onTap;

  const _BankLiquidityCard({
    required this.badgeLabel,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.accentBg,
    this.isHighlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? accentColor.withValues(alpha: 0.5)
                : accentColor.withValues(alpha: 0.25),
            width: isHighlighted ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Badge + Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Título
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 6),

            // Valor R$
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 6),

            // Subtítulo (contas ativas)
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 13, color: accentColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),

            // Detalhe / Descrição
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: accentColor.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DRELineItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  final bool isHighlighted;

  const _DRELineItem({
    required this.label,
    required this.value,
    this.isBold = false,
    this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? AppColors.textPrimaryLight;

    return Container(
      padding: EdgeInsets.symmetric(vertical: isHighlighted ? 10 : 4, horizontal: isHighlighted ? 12 : 0),
      decoration: isHighlighted
          ? BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isHighlighted ? 14 : 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 16 : 13,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// SHIMMER / SKELETON LOADING WIDGETS
// =====================================================================

class _DashboardSkeletonLoading extends StatefulWidget {
  const _DashboardSkeletonLoading();

  @override
  State<_DashboardSkeletonLoading> createState() => _DashboardSkeletonLoadingState();
}

class _DashboardSkeletonLoadingState extends State<_DashboardSkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacityAnim = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnim,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar placeholder
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildShimmerBox(width: 220, height: 42, radius: 10),
                    Row(
                      children: [
                        _buildShimmerBox(width: 170, height: 42, radius: 10),
                        const SizedBox(width: 12),
                        _buildShimmerBox(width: 170, height: 42, radius: 10),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bank Liquidity Skeleton Block
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildShimmerBox(width: 260, height: 20, radius: 6),
                          _buildShimmerBox(width: 160, height: 32, radius: 8),
                        ],
                      ),
                      const SizedBox(height: 18),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 950;
                          return isWide
                              ? Row(
                                  children: [
                                    Expanded(child: _buildShimmerBox(width: double.infinity, height: 150, radius: 14)),
                                    const SizedBox(width: 14),
                                    Expanded(child: _buildShimmerBox(width: double.infinity, height: 150, radius: 14)),
                                    const SizedBox(width: 14),
                                    Expanded(child: _buildShimmerBox(width: double.infinity, height: 150, radius: 14)),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _buildShimmerBox(width: double.infinity, height: 130, radius: 14),
                                    const SizedBox(height: 12),
                                    _buildShimmerBox(width: double.infinity, height: 130, radius: 14),
                                    const SizedBox(height: 12),
                                    _buildShimmerBox(width: double.infinity, height: 130, radius: 14),
                                  ],
                                );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // KPI 4 Cards Skeleton
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isWide ? 1.6 : 1.3,
                      children: List.generate(4, (_) {
                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildShimmerBox(width: 110, height: 16, radius: 4),
                                  _buildShimmerBox(width: 32, height: 32, radius: 16),
                                ],
                              ),
                              _buildShimmerBox(width: 130, height: 26, radius: 6),
                              _buildShimmerBox(width: 90, height: 12, radius: 4),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // DRE Skeleton Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(width: 280, height: 22, radius: 4),
                      const SizedBox(height: 24),
                      for (int i = 0; i < 7; i++) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildShimmerBox(width: 200, height: 16, radius: 4),
                            _buildShimmerBox(width: 90, height: 16, radius: 4),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Alertas de estoque skeleton
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildShimmerBox(width: 260, height: 20, radius: 4),
                          _buildShimmerBox(width: 100, height: 32, radius: 6),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (int i = 0; i < 3; i++) ...[
                        Row(
                          children: [
                            _buildShimmerBox(width: 40, height: 40, radius: 20),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildShimmerBox(width: 180, height: 16, radius: 4),
                                  const SizedBox(height: 6),
                                  _buildShimmerBox(width: 120, height: 12, radius: 4),
                                ],
                              ),
                            ),
                            _buildShimmerBox(width: 80, height: 30, radius: 6),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerBox({required double width, required double height, required double radius}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _GerarDreDialog extends StatefulWidget {
  final String mesReferenciaInicial;
  const _GerarDreDialog({required this.mesReferenciaInicial});

  @override
  State<_GerarDreDialog> createState() => _GerarDreDialogState();
}

class _GerarDreDialogState extends State<_GerarDreDialog> {
  late int _mes;
  late int _ano;
  bool _carregando = false;
  String? _erro;
  Map<String, dynamic>? _resumoDre;

  final List<String> _nomesMeses = const [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    final partes = widget.mesReferenciaInicial.split('-');
    if (partes.length == 2) {
      _ano = int.tryParse(partes[0]) ?? DateTime.now().year;
      _mes = int.tryParse(partes[1]) ?? DateTime.now().month;
    } else {
      _ano = DateTime.now().year;
      _mes = DateTime.now().month;
    }
    _carregarResumo();
  }

  Future<void> _carregarResumo() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final dados = await RelatorioDrePdfService.carregarDadosDre(mes: _mes, ano: _ano);
      if (mounted) {
        setState(() {
          _resumoDre = dados;
          _carregando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao pré-visualizar dados: $e';
          _carregando = false;
        });
      }
    }
  }

  Future<void> _exportarPdf() async {
    setState(() => _carregando = true);
    try {
      await RelatorioDrePdfService.imprimirRelatorioDre(
        mes: _mes,
        ano: _ano,
        dadosDre: _resumoDre,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Erro ao gerar PDF: $e';
          _carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final anosDisponiveis = List.generate(5, (i) => DateTime.now().year - 2 + i);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: Color(0xFF2E7D32), size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exportação de DRE Contábil',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Demonstração do Resultado do Exercício com separação PJ e PF',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Seletores de Mês e Ano
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: _mes,
                      decoration: InputDecoration(
                        labelText: 'Mês de Competência',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.calendar_month, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: List.generate(12, (i) {
                        final m = i + 1;
                        return DropdownMenuItem(
                          value: m,
                          child: Text('${m.toString().padLeft(2, '0')} - ${_nomesMeses[i]}'),
                        );
                      }),
                      onChanged: (val) {
                        if (val != null && val != _mes) {
                          setState(() => _mes = val);
                          _carregarResumo();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      initialValue: _ano,
                      decoration: InputDecoration(
                        labelText: 'Ano',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        prefixIcon: const Icon(Icons.calendar_today, color: AppColors.primary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: anosDisponiveis.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text(a.toString()),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _ano) {
                          setState(() => _ano = val);
                          _carregarResumo();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Prévia resumida das linhas contábeis
              if (_carregando) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2),
                        SizedBox(height: 12),
                        Text('Calculando balanço contábil...', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ] else if (_erro != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_erro!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ] else if (_resumoDre != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      _buildLinhaResumo(
                        '(+) Receita Bruta Total',
                        currencyFormat.format(
                          ((_resumoDre!['receita_bruta_servicos'] as num?)?.toDouble() ?? 0.0) +
                          ((_resumoDre!['receita_bruta_produtos'] as num?)?.toDouble() ?? 0.0)
                        ),
                        isBold: false,
                        cor: const Color(0xFF2E7D32),
                      ),
                      _buildLinhaResumo(
                        '(-) Descontos Concedidos',
                        currencyFormat.format((_resumoDre!['descontos_concedidos'] as num?)?.toDouble() ?? 0.0),
                        isBold: false,
                        cor: Colors.red.shade700,
                      ),
                      const Divider(height: 12),
                      _buildLinhaResumo(
                        '(=) Receita Líquida Operacional',
                        currencyFormat.format((_resumoDre!['receita_liquida'] as num?)?.toDouble() ?? 0.0),
                        isBold: true,
                      ),
                      _buildLinhaResumo(
                        '(-) Custos e Despesas PJ',
                        currencyFormat.format(
                          ((_resumoDre!['custo_insumos_consumidos'] as num?)?.toDouble() ?? 0.0) +
                          ((_resumoDre!['despesas_operacionais_pj'] as num?)?.toDouble() ?? 0.0) +
                          ((_resumoDre!['despesas_variaveis_pj'] as num?)?.toDouble() ?? 0.0)
                        ),
                        isBold: false,
                        cor: Colors.red.shade700,
                      ),
                      const Divider(height: 12),
                      _buildLinhaResumo(
                        '(=) Lucro / Prejuízo Líquido PJ',
                        currencyFormat.format((_resumoDre!['lucro_operacional_liquido'] as num?)?.toDouble() ?? 0.0),
                        isBold: true,
                        cor: ((_resumoDre!['lucro_operacional_liquido'] as num?)?.toDouble() ?? 0.0) >= 0
                            ? const Color(0xFF2E7D32)
                            : Colors.red.shade700,
                      ),
                      const SizedBox(height: 6),
                      _buildLinhaResumo(
                        '(*) Retiradas / Despesas PF (Informativo)',
                        currencyFormat.format((_resumoDre!['retiradas_pessoais_pf'] as num?)?.toDouble() ?? 0.0),
                        isBold: false,
                        cor: Colors.purple.shade700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Ações do Modal
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _carregando ? null : _exportarPdf,
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text(
                      'VISUALIZAR / IMPRIMIR PDF',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinhaResumo(String rotulo, String valor, {bool isBold = false, Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            rotulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: cor ?? (isBold ? AppColors.textPrimaryLight : AppColors.textPrimaryLight),
            ),
          ),
        ],
      ),
    );
  }
}

