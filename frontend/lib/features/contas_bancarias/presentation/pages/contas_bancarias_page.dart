import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/conta_bancaria_model.dart';
import '../cubit/contas_bancarias_cubit.dart';
import '../cubit/contas_bancarias_state.dart';
import '../widgets/conta_bancaria_dialog.dart';

class ContasBancariasPage extends StatelessWidget {
  final ContasBancariasCubit? cubit;

  const ContasBancariasPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: const _ContasBancariasView(),
      );
    }

    return BlocProvider(
      create: (_) => ContasBancariasCubit()..carregarContas(),
      child: const _ContasBancariasView(),
    );
  }
}

class _ContasBancariasView extends StatelessWidget {
  const _ContasBancariasView();

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _abrirModalNovaConta(BuildContext context) {
    final cubit = context.read<ContasBancariasCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContaBancariaDialog(
        onSalvar: (conta) => cubit.criarConta(conta),
      ),
    );
  }

  void _abrirModalEditarConta(BuildContext context, ContaBancariaModel conta) {
    final cubit = context.read<ContasBancariasCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContaBancariaDialog(
        contaExistente: conta,
        onSalvar: (contaAtualizada) => cubit.atualizarConta(contaAtualizada),
      ),
    );
  }

  void _confirmarAlternarStatus(BuildContext context, ContaBancariaModel conta) {
    final cubit = context.read<ContasBancariasCubit>();
    final novoStatus = !conta.ativo;
    final acao = novoStatus ? 'ativar' : 'inativar';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${novoStatus ? "Ativar" : "Inativar"} Conta'),
        content: Text('Deseja realmente $acao a conta "${conta.nomeConta}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: novoStatus ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              cubit.alternarStatus(conta.id, novoStatus);
            },
            child: Text(novoStatus ? 'Ativar' : 'Inativar'),
          ),
        ],
      ),
    );
  }

  void _confirmarExcluirConta(BuildContext context, ContaBancariaModel conta) {
    final cubit = context.read<ContasBancariasCubit>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Conta Bancária'),
        content: Text(
          'Deseja excluir a conta "${conta.nomeConta}"? '
          'Caso haja lançamentos vinculados, recomenda-se inativá-la em vez de excluir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              cubit.excluirConta(conta.id);
            },
            child: const Text('Excluir Definitivamente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Contas Bancárias'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recarregar Contas',
            onPressed: () => context.read<ContasBancariasCubit>().carregarContas(),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _abrirModalNovaConta(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Nova Conta', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: BlocConsumer<ContasBancariasCubit, ContasBancariasState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.error, content: Text(state.errorMessage!)),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: Colors.green.shade700, content: Text(state.successMessage!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == ContasBancariasStatus.loading && state.contas.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final cubit = context.read<ContasBancariasCubit>();
          final contasExibidas = state.contasFiltradas;

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cards de Resumo e Indicadores (KPIs)
                _buildKpiCards(context, state, currencyFormat),
                const SizedBox(height: 20),

                // Barra de Filtros e Abas de Escopo
                _buildFiltrosBar(context, state, cubit),
                const SizedBox(height: 16),

                // Lista / Grid de Cards de Contas
                Expanded(
                  child: contasExibidas.isEmpty
                      ? _buildEmptyState(context, state)
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = constraints.maxWidth > 1200
                                ? 3
                                : (constraints.maxWidth > 750 ? 2 : 1);

                            return GridView.builder(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 245,
                              ),
                              itemCount: contasExibidas.length,
                              itemBuilder: (context, index) {
                                final conta = contasExibidas[index];
                                return _buildContaCard(context, conta, currencyFormat);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKpiCards(BuildContext context, ContasBancariasState state, NumberFormat currencyFormat) {
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            titulo: 'Saldo Total PJ (Clínica)',
            valor: currencyFormat.format(state.saldoTotalPj),
            subtitulo: '${state.totalPjCount} contas operacionais ativas',
            corIcone: AppColors.primary,
            icone: Icons.business,
            backgroundGradiente: [
              AppColors.primaryLight.withValues(alpha: 0.15),
              Colors.white,
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildKpiCard(
            titulo: 'Saldo Total PF (Pessoal/Sócios)',
            valor: currencyFormat.format(state.saldoTotalPf),
            subtitulo: '${state.totalPfCount} contas de sócios ativas',
            corIcone: const Color(0xFF6D4C41),
            icone: Icons.person,
            backgroundGradiente: [
              const Color(0xFFEFEBE9),
              Colors.white,
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildKpiCard(
            titulo: 'Saldo Consolidado Total',
            valor: currencyFormat.format(state.saldoTotalGeral),
            subtitulo: '${state.contas.where((c) => c.ativo).length} contas bancárias ativas no total',
            corIcone: Colors.green.shade700,
            icone: Icons.account_balance,
            backgroundGradiente: [
              Colors.green.shade50,
              Colors.white,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String titulo,
    required String valor,
    required String subtitulo,
    required Color corIcone,
    required IconData icone,
    required List<Color> backgroundGradiente,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: backgroundGradiente,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: corIcone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: corIcone, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: corIcone == Colors.green.shade700 ? Colors.green.shade800 : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltrosBar(BuildContext context, ContasBancariasState state, ContasBancariasCubit cubit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Botões de Segmentação por Escopo
        Row(
          children: [
            _buildTabFilterButton('TODOS', 'Todas as Contas', state.filtroEscopo == 'TODOS', () {
              cubit.mudarFiltroEscopo('TODOS');
            }),
            const SizedBox(width: 8),
            _buildTabFilterButton('PJ', 'Contas PJ (Clínica)', state.filtroEscopo == 'PJ', () {
              cubit.mudarFiltroEscopo('PJ');
            }),
            const SizedBox(width: 8),
            _buildTabFilterButton('PF', 'Contas PF (Pessoal)', state.filtroEscopo == 'PF', () {
              cubit.mudarFiltroEscopo('PF');
            }),
          ],
        ),

        // Checkbox para Ocultar Inativas
        Row(
          children: [
            Checkbox(
              value: state.apenasAtivas,
              activeColor: AppColors.primary,
              onChanged: (val) => cubit.alternarApenasAtivas(val ?? false),
            ),
            const Text(
              'Ocultar Contas Inativas',
              style: TextStyle(fontSize: 13, color: AppColors.textPrimaryLight),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabFilterButton(String chave, String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildContaCard(BuildContext context, ContaBancariaModel conta, NumberFormat currencyFormat) {
    final corIdentificadora = _parseColor(conta.corIdentificadora);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Cor, Nome, Badge PJ/PF e Status
            Row(
              children: [
                Container(
                  width: 12,
                  height: 36,
                  decoration: BoxDecoration(
                    color: corIdentificadora,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conta.nomeConta,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${conta.bancoNome} • ${conta.tipoContaFormatado}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Badge PJ vs PF
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: conta.isPj
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : const Color(0xFF6D4C41).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: conta.isPj ? AppColors.primary : const Color(0xFF6D4C41),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    conta.escopo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: conta.isPj ? AppColors.primary : const Color(0xFF6D4C41),
                    ),
                  ),
                ),
                if (!conta.ativo) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'INATIVA',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 18),

            // Detalhes da Conta
            if (conta.agencia != null || conta.numeroConta != null) ...[
              Text(
                'Ag: ${conta.agencia ?? "--"} | Conta: ${conta.numeroConta ?? "--"}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 4),
            ],

            // Chave PIX com ação de copiar
            if (conta.chavePix != null && conta.chavePix!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.pix_outlined, size: 14, color: Colors.teal),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'PIX: ${conta.chavePix!}',
                      style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Copiar Chave PIX',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: conta.chavePix!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chave PIX copiada para a área de transferência!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ] else ...[
              const SizedBox(height: 18),
            ],

            // Saldo Atual
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Saldo Atual em Conta',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                      ),
                      Text(
                        currencyFormat.format(conta.saldoAtual),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: conta.saldoAtual >= 0 ? Colors.green.shade800 : AppColors.error,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Ações Rápidas
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Editar Conta',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => _abrirModalEditarConta(context, conta),
                    ),
                    IconButton(
                      icon: Icon(
                        conta.ativo ? Icons.block_outlined : Icons.check_circle_outline,
                        size: 18,
                        color: conta.ativo ? Colors.orange : Colors.green,
                      ),
                      tooltip: conta.ativo ? 'Inativar Conta' : 'Ativar Conta',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => _confirmarAlternarStatus(context, conta),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      tooltip: 'Excluir Conta',
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(6),
                      onPressed: () => _confirmarExcluirConta(context, conta),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ContasBancariasState state) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance, size: 48, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma conta bancária encontrada',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cadastre as contas bancárias da clínica (PJ) e dos sócios (PF) para segregar as movimentações financeiras.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _abrirModalNovaConta(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar Primeira Conta'),
          ),
        ],
      ),
    );
  }
}
