import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/cartoes_cubit.dart';
import '../cubit/cartoes_state.dart';
import '../widgets/novo_cartao_dialog.dart';
import '../widgets/nova_despesa_cartao_dialog.dart';
import '../../../contas_pagar/presentation/widgets/editar_parcela_dialog.dart';

class CartoesPage extends StatelessWidget {
  final CartoesCubit? cubit;
  const CartoesPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: const _CartoesView());
    }
    try {
      context.read<CartoesCubit>();
      return const _CartoesView();
    } catch (_) {
      return BlocProvider(
        create: (_) => CartoesCubit()..carregarCartoes(),
        child: const _CartoesView(),
      );
    }
  }
}

class _CartoesView extends StatelessWidget {
  const _CartoesView();

  void _abrirModalNovoCartao(BuildContext context) {
    final cubit = context.read<CartoesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovoCartaoDialog(
        onSalvar: (dados) => cubit.cadastrarCartao(dados),
      ),
    );
  }

  void _abrirModalEditarCartao(BuildContext context, Map<String, dynamic> cartao) {
    final cubit = context.read<CartoesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovoCartaoDialog(
        cartaoParaEditar: cartao,
        onSalvar: (dados) => cubit.atualizarCartao(cartao['id'], dados),
      ),
    );
  }

  void _abrirModalNovaDespesa(BuildContext context, List<Map<String, dynamic>> cartoes, String? cartaoSelecionadoId) {
    final cubit = context.read<CartoesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovaDespesaCartaoDialog(
        cartoes: cartoes,
        cartaoIdInicial: cartaoSelecionadoId,
        onSalvar: (dados) => cubit.registrarDespesaCartao(dados),
      ),
    );
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
        title: const Text('Gestão de Cartões & Faturas'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Faturas',
            onPressed: () => context.read<CartoesCubit>().carregarCartoes(),
          ),
        ],
      ),
      body: BlocConsumer<CartoesCubit, CartoesState>(
        listener: (context, state) {
          if (state.status == CartoesStatus.success && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.success, content: Text(state.successMessage!)),
            );
          } else if (state.status == CartoesStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.error, content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<CartoesCubit>();

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Action Bar: Botões de Ação
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 10,
                    children: [
                      Text(
                        'Cartões Cadastrados (${state.cartoes.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _abrirModalNovoCartao(context),
                            icon: const Icon(Icons.add_circle_outline, size: 18),
                            label: const Text('NOVO CARTÃO'),
                          ),
                          ElevatedButton.icon(
                            onPressed: state.cartoes.isEmpty
                                ? null
                                : () => _abrirModalNovaDespesa(
                                      context,
                                      state.cartoes,
                                      state.cartaoSelecionado?['id'],
                                    ),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            icon: const Icon(Icons.receipt_long, color: Colors.white, size: 18),
                            label: const Text(
                              'REGISTRAR DESPESA NO CARTÃO',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                // Banner Informativo: Controle Integrado pelo Registro de Despesas
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Controle Integrado: Todas as compras parceladas no cartão são geridas no Registro de Despesas (Contas a Pagar) e distribuídas automaticamente nos próximos meses.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de Cartões (Carrossel / Horizontal)
                if (state.cartoes.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.credit_card_off, size: 48, color: AppColors.textSecondaryLight),
                          const SizedBox(height: 12),
                          const Text('Nenhum cartão cadastrado neste regime.', style: TextStyle(fontSize: 15)),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _abrirModalNovoCartao(context),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                            child: const Text('Cadastrar Primeiro Cartão'),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  SizedBox(
                    height: 135,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: state.cartoes.length,
                      itemBuilder: (context, index) {
                        final c = state.cartoes[index];
                        final isSelected = state.cartaoSelecionado?['id'] == c['id'];
                        return GestureDetector(
                          onTap: () => cubit.selecionarCartao(c),
                          child: Container(
                            width: 250,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? Colors.transparent : AppColors.borderLight,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.credit_card,
                                          color: isSelected ? Colors.white : AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: isSelected ? Colors.white70 : AppColors.primary,
                                          ),
                                          tooltip: 'Editar Cartão',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _abrirModalEditarCartao(context, c),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white.withValues(alpha: 0.2)
                                            : AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'VENCE DIA ${c['dia_vencimento']}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  c['nome'] ?? 'Cartão',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Fecha dia ${c['dia_fechamento']}  •  Vence dia ${c['dia_vencimento']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? Colors.white70 : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Seção da Fatura do Cartão Selecionado
                  if (state.cartaoSelecionado != null) ...[
                    // Barra Reativa de Limite Disponível do Cartão
                    _PainelLimiteCartao(
                      cartao: state.cartaoSelecionado!,
                      fatura: state.faturaDetalhada,
                      currencyFormat: currencyFormat,
                    ),
                    const SizedBox(height: 12),

                    // Seletor de Mês da Fatura
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.receipt_long_outlined, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Fatura: ${state.cartaoSelecionado!['nome']}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () => cubit.mudarMesReferencia(_ajustarMes(state.mesReferencia, -1)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundLight,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Text(
                                  'Mês ${state.mesReferencia}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () => cubit.mudarMesReferencia(_ajustarMes(state.mesReferencia, 1)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Detalhe da Fatura
                    state.faturaDetalhada == null
                        ? const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Nenhuma informação de fatura para este mês.')))
                        : _FaturaDetalhesView(
                            fatura: state.faturaDetalhada!,
                            currencyFormat: currencyFormat,
                          ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
      ),
    );
  }
}

class _FaturaDetalhesView extends StatelessWidget {
  final Map<String, dynamic> fatura;
  final NumberFormat currencyFormat;

  const _FaturaDetalhesView({
    required this.fatura,
    required this.currencyFormat,
  });

  void _abrirModalEditarParcela(BuildContext context, Map<String, dynamic> parcela) {
    final cubit = context.read<CartoesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditarParcelaDialog(
        parcela: parcela,
        onSalvar: ({
          required String transacaoId,
          required String novaDataVencimentoStr,
          double? novoValor,
          String? novaDescricao,
          String? novaCategoriaId,
          required bool aplicarEmTodasSeguintes,
        }) =>
            cubit.atualizarParcelaDespesa(
          transacaoId: transacaoId,
          novaDataVencimentoStr: novaDataVencimentoStr,
          novoValor: novoValor,
          novaDescricao: novaDescricao,
          novaCategoriaId: novaCategoriaId,
          aplicarEmTodasSeguintes: aplicarEmTodasSeguintes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parcelas = fatura['parcelas'] as List? ?? [];
    final valorTotal = double.tryParse(fatura['valor_total']?.toString() ?? '0') ?? 0.0;
    final statusFatura = fatura['status_fatura'] ?? 'ABERTA';
    final vencimentoReal = fatura['data_vencimento_real'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da Fatura com Total e Vencimento
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total da Fatura deste Mês', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(valorTotal),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusFatura == 'PAGA'
                            ? AppColors.success.withValues(alpha: 0.15)
                            : (statusFatura == 'FECHADA' ? AppColors.warning.withValues(alpha: 0.2) : AppColors.info.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'STATUS: $statusFatura',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusFatura == 'PAGA'
                              ? AppColors.success
                              : (statusFatura == 'FECHADA' ? Colors.orange.shade800 : AppColors.info),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Vencimento: $vencimentoReal (Regra Febraban)',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 28),

          const Text(
            'Lançamentos e Parcelas Vinculadas a Esta Fatura:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),

          parcelas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Nenhum lançamento ou parcela com vencimento nesta fatura.',
                      style: TextStyle(color: AppColors.textSecondaryLight),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: parcelas.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final p = parcelas[index];
                    final valor = double.tryParse(p['valor_parcela']?.toString() ?? '0') ?? 0.0;
                    final numParcela = p['numero_parcela'];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                        child: Text(
                          '#$numParcela',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryDark),
                        ),
                      ),
                      title: Text('${p['descricao']} - Vencimento ${p['data_vencimento']}'),
                      subtitle: Text('Status: ${p['status']}  •  Fatura Ref: ${p['mes_fatura_referencia']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currencyFormat.format(valor),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.edit_calendar_outlined, size: 20, color: AppColors.primary),
                            tooltip: 'Editar Parcela / Vencimento',
                            onPressed: () => _abrirModalEditarParcela(context, p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _PainelLimiteCartao extends StatelessWidget {
  final Map<String, dynamic> cartao;
  final Map<String, dynamic>? fatura;
  final NumberFormat currencyFormat;

  const _PainelLimiteCartao({
    required this.cartao,
    this.fatura,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final limiteTotal = double.tryParse(cartao['limite']?.toString() ?? '0') ?? 0.0;
    final limiteUtilizado = double.tryParse(cartao['limite_utilizado']?.toString() ??
        fatura?['limite_utilizado']?.toString() ?? '0') ?? 0.0;
    final limiteDisponivel = double.tryParse(cartao['limite_disponivel']?.toString() ??
        fatura?['limite_disponivel']?.toString() ?? (limiteTotal - limiteUtilizado).toString()) ?? 0.0;

    final pctUtilizado = limiteTotal > 0 ? (limiteUtilizado / limiteTotal).clamp(0.0, 1.0) : 0.0;

    Color statusColor;
    String statusTexto;
    if (pctUtilizado >= 0.90) {
      statusColor = AppColors.error;
      statusTexto = 'Limite Quase Esgotado (${(pctUtilizado * 100).toStringAsFixed(1)}%)';
    } else if (pctUtilizado >= 0.70) {
      statusColor = AppColors.warning;
      statusTexto = 'Atenção ao Limite (${(pctUtilizado * 100).toStringAsFixed(1)}%)';
    } else {
      statusColor = AppColors.success;
      statusTexto = 'Limite Saudável (${(pctUtilizado * 100).toStringAsFixed(1)}% comprometido)';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
                  Icon(Icons.speed, size: 20, color: statusColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Limite Operacional',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusTexto,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pctUtilizado,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Limite Total', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  Text(currencyFormat.format(limiteTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Comprometido (A Pagar)', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  Text(currencyFormat.format(limiteUtilizado), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange.shade800)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Disponível Imediato', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  Text(currencyFormat.format(limiteDisponivel), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
