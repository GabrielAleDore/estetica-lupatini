import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';
import '../../../../core/utils/forma_pagamento_util.dart';
import '../../../cartoes/data/cartoes_repository.dart';
import '../../../contas_bancarias/domain/models/conta_bancaria_model.dart';
import '../../../contas_bancarias/presentation/cubit/contas_bancarias_cubit.dart';
import '../cubit/contas_pagar_cubit.dart';
import '../cubit/contas_pagar_state.dart';
import '../widgets/editar_parcela_dialog.dart';

class ContasPagarPage extends StatelessWidget {
  final ContasPagarCubit? cubit;
  const ContasPagarPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: const _ContasPagarView());
    }
    try {
      context.read<ContasPagarCubit>();
      return const _ContasPagarView();
    } catch (_) {
      return BlocProvider(
        create: (_) => ContasPagarCubit()..carregarContas(),
        child: const _ContasPagarView(),
      );
    }
  }
}

class _ContasPagarView extends StatefulWidget {
  const _ContasPagarView();

  @override
  State<_ContasPagarView> createState() => _ContasPagarViewState();
}

class _ContasPagarViewState extends State<_ContasPagarView> {
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    context.read<ContasPagarCubit>().carregarContas();
  }

  void _abrirModalNovaDespesa(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<ContasPagarCubit>(),
        child: const ModalNovaDespesa(),
      ),
    );
  }

  void _confirmarPagamento(BuildContext context, Map<String, dynamic> contaItem) {
    final cubit = context.read<ContasPagarCubit>();
    String? contaSelecionada = contaItem['conta_bancaria_id']?.toString();
    final valor = (contaItem['valor_total'] as num?)?.toDouble() ?? 0.0;
    final desc = contaItem['descricao'] ?? 'Despesa';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          List<ContaBancariaModel> contasAtivas = [];
          try {
            final bCubit = ctx.watch<ContasBancariasCubit>();
            contasAtivas = bCubit.state.contas.where((c) => c.ativo).toList();
            if (contaSelecionada == null && contasAtivas.isNotEmpty) {
              contaSelecionada = contasAtivas.first.id;
            }
          } catch (_) {}

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.payment, color: AppColors.success),
                SizedBox(width: 8),
                Text('Confirmar Pagamento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deseja liquidar a despesa "$desc"?', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('Valor: ${_currencyFormat.format(valor)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.error)),
                  const SizedBox(height: 16),
                  if (contasAtivas.isNotEmpty) ...[
                    const Text('Debitar da Conta Bancária:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      isExpanded: true,
                      initialValue: contaSelecionada,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.account_balance),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Sem débito em conta bancária')),
                        ...contasAtivas.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.nomeConta} (${c.bancoNome})', overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (val) => setModalState(() => contaSelecionada = val),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  cubit.marcarComoPago(contaItem['id'], contaBancariaId: contaSelecionada);
                },
                child: const Text('Confirmar Pagamento'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirModalEditarParcela(BuildContext context, Map<String, dynamic> conta) {
    final cubit = context.read<ContasPagarCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditarParcelaDialog(
        parcela: conta,
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
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: BlocConsumer<ContasPagarCubit, ContasPagarState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: AppColors.error),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.successMessage!), backgroundColor: AppColors.success),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<ContasPagarCubit>();
          final contas = state.contasFiltradas;
          final hojeStr = DateTime.now().toIso8601String().substring(0, 10);

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topo com Título e KPIs
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registro de Despesas',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Controle e liquidação de obrigações financeiras e pagamentos por conta bancária',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _KpiDespesaCard(
                          titulo: 'Pendentes a Pagar',
                          valor: _currencyFormat.format(state.totalPendenteGeral),
                          cor: Colors.orange.shade800,
                          icone: Icons.pending_actions,
                        ),
                        _KpiDespesaCard(
                          titulo: 'Pagas no Mês',
                          valor: _currencyFormat.format(state.totalPagoMes),
                          cor: AppColors.success,
                          icone: Icons.check_circle_outline,
                        ),
                        if (state.totalVencidasGeral > 0)
                          _KpiDespesaCard(
                            titulo: 'Vencidas em Atraso',
                            valor: _currencyFormat.format(state.totalVencidasGeral),
                            cor: AppColors.error,
                            icone: Icons.warning_amber_rounded,
                          ),
                        ElevatedButton.icon(
                          onPressed: () => _abrirModalNovaDespesa(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Nova Despesa', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Barra de Filtros
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.borderLight),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Abas de Status
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'PENDENTE', label: Text('A Vencer / Pendentes')),
                            ButtonSegment(value: 'TODAS', label: Text('Todas')),
                            ButtonSegment(value: 'PAGO', label: Text('Pagas')),
                            ButtonSegment(value: 'VENCIDAS', label: Text('Vencidas')),
                          ],
                          selected: {state.filtroAba},
                          onSelectionChanged: (val) => cubit.mudarAba(val.first),
                        ),

                        // Filtro de Mês de Vencimento
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.borderLight),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: state.filtroMes,
                              icon: const Icon(Icons.calendar_month, size: 18),
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight),
                              items: [
                                const DropdownMenuItem(value: 'TODOS', child: Text('Todos os Meses')),
                                ...List.generate(12, (i) {
                                  final dt = DateTime(DateTime.now().year, DateTime.now().month + (i - 2), 1);
                                  final mesStr = DateFormat('yyyy-MM').format(dt);
                                  final label = DateFormat('MMMM / yyyy', 'pt_BR').format(dt);
                                  final capLabel = label[0].toUpperCase() + label.substring(1);
                                  return DropdownMenuItem(value: mesStr, child: Text(capLabel));
                                }),
                              ],
                              onChanged: (val) {
                                if (val != null) cubit.mudarMes(val);
                              },
                            ),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Recarregar',
                          onPressed: () => cubit.carregarContas(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tabela de Despesas em Formato de Linhas e Colunas
                Expanded(
                  child: state.status == ContasPagarStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : contas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Nenhuma despesa encontrada para os filtros selecionados.',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  // Cabeçalho das Colunas
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                    ),
                                    child: const Row(
                                      children: [
                                        SizedBox(
                                          width: 120,
                                          child: Text('VENCIMENTO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: Text('DESCRIÇÃO / FORNECEDOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Text('CATEGORIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Text('FORMA / CONTA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 110,
                                          child: Text('VALOR', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 105,
                                          child: Center(child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 125,
                                          child: Center(child: Text('AÇÕES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey))),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Linhas da Tabela
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: contas.length,
                                      separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
                                      itemBuilder: (context, index) {
                                        final c = contas[index];
                                        final isPago = c['status'] == 'PAGO';
                                        final vencStr = c['data_vencimento']?.toString() ?? '';
                                        final isVencido = !isPago && vencStr.isNotEmpty && vencStr.compareTo(hojeStr) < 0;
                                        final isHoje = !isPago && vencStr == hojeStr;
                                        final valor = (c['valor_total'] as num?)?.toDouble() ?? 0.0;
                                        final categoria = c['categorias'] as Map<String, dynamic>?;
                                        final contaBancaria = c['contas_bancarias'] as Map<String, dynamic>?;
                                        final cartao = c['contas_cartoes'] as Map<String, dynamic>?;
                                        final forma = c['forma_pagamento']?.toString();
                                        final formaStr = forma ?? (cartao != null ? 'CARTAO_CREDITO' : null);

                                        return Container(
                                          color: isVencido
                                              ? Colors.red.shade50.withValues(alpha: 0.3)
                                              : (isPago ? Colors.white : (isHoje ? Colors.amber.shade50.withValues(alpha: 0.25) : Colors.white)),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: Row(
                                            children: [
                                              // Coluna 1: Vencimento
                                              SizedBox(
                                                width: 120,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      vencStr.isEmpty ? '--/--/----' : vencStr,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: isVencido ? AppColors.error : AppColors.textPrimaryLight,
                                                      ),
                                                    ),
                                                    if (isVencido)
                                                      const Text('Vencida', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold))
                                                    else if (isHoje)
                                                      Text('Vence Hoje', style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.bold))
                                                    else if (isPago && c['data_pagamento'] != null)
                                                      Text('Pago: ${c['data_pagamento']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 2: Descrição / Favorecido
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        c['descricao'] ?? 'Despesa',
                                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if ((c['forma_pagamento'] ?? '').toString().isNotEmpty) ...[
                                                       const SizedBox(width: 6),
                                                       Tooltip(
                                                         message: FormaPagamentoUtil.label(c['forma_pagamento']?.toString()),
                                                         child: Icon(FormaPagamentoUtil.icone(c['forma_pagamento']?.toString()), size: 14, color: Colors.grey.shade600),
                                                       ),
                                                     ],
                                                     if (c['tipo_recorrencia'] == 'FIXA_MENSAL') ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.blue.withValues(alpha: 0.1),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: const Text('Fixa', style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 3: Categoria
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  categoria?['nome'] ?? 'Geral',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 4: Conta de Débito
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    if (formaStr != null && formaStr.isNotEmpty) ...[
                                                      Icon(
                                                        FormaPagamentoUtil.icone(formaStr),
                                                        size: 14,
                                                        color: Colors.grey.shade700,
                                                      ),
                                                      const SizedBox(width: 6),
                                                    ],
                                                    Flexible(
                                                      child: Text(
                                                        cartao != null
                                                            ? 'Cartão ${cartao['nome'] ?? ''}'
                                                            : (formaStr != null
                                                                ? FormaPagamentoUtil.label(formaStr)
                                                                : (contaBancaria?['nome_conta'] ?? (isPago ? 'Conta Bancária' : 'A definir no pgto'))),
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: cartao != null || formaStr != null ? AppColors.textPrimaryLight : Colors.grey,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 5: Valor
                                              SizedBox(
                                                width: 110,
                                                child: Text(
                                                  _currencyFormat.format(valor),
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: isPago ? Colors.grey.shade700 : AppColors.error,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 6: Status
                                              SizedBox(
                                                width: 105,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isPago
                                                          ? AppColors.success.withValues(alpha: 0.15)
                                                          : (isVencido ? AppColors.error.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15)),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      isPago ? 'PAGO' : (isVencido ? 'VENCIDA' : 'PENDENTE'),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: isPago
                                                            ? AppColors.success
                                                            : (isVencido ? AppColors.error : Colors.orange.shade900),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 7: Ações
                                              SizedBox(
                                                width: 125,
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      if (!isPago)
                                                        ElevatedButton(
                                                          onPressed: () => _confirmarPagamento(context, c),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: AppColors.success,
                                                            foregroundColor: Colors.white,
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                                            minimumSize: Size.zero,
                                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                          ),
                                                          child: const Text('Pagar', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                                        ),
                                                      if (!isPago) const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                                        tooltip: 'Editar Parcela / Vencimento',
                                                        padding: EdgeInsets.zero,
                                                        visualDensity: VisualDensity.compact,
                                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                        onPressed: () => _abrirModalEditarParcela(context, c),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                                        tooltip: 'Excluir',
                                                        padding: EdgeInsets.zero,
                                                        visualDensity: VisualDensity.compact,
                                                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                        onPressed: () async {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (ctx) => AlertDialog(
                                                              title: const Text('Excluir Despesa?'),
                                                              content: const Text('Deseja remover este registro financeiro?'),
                                                              actions: [
                                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                                                                ElevatedButton(
                                                                  onPressed: () => Navigator.pop(ctx, true),
                                                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                                  child: const Text('Excluir'),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                          if (confirm == true) {
                                                            cubit.excluirDespesa(c['id']);
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
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

class _KpiDespesaCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final IconData icone;

  const _KpiDespesaCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 18, color: cor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cor)),
              Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cor)),
            ],
          ),
        ],
      ),
    );
  }
}

class ModalNovaDespesa extends StatefulWidget {
  const ModalNovaDespesa({super.key});

  @override
  State<ModalNovaDespesa> createState() => _ModalNovaDespesaState();
}

class _ModalNovaDespesaState extends State<ModalNovaDespesa> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final String _escopo = 'PJ';
  String _tipoRecorrencia = 'AVULSA';
  String? _categoriaId;
  String? _contaBancariaId;
  DateTime _dataVencimento = DateTime.now();
  bool _jaPago = false;
  bool _isLoading = false;
  String _formaPagamento = 'PIX';
  String? _cartaoId;
  int _parcelas = 1;
  List<Map<String, dynamic>> _cartoes = [];

  bool get _isCartao => _formaPagamento == 'CARTAO_CREDITO';

  @override
  void initState() {
    super.initState();
    _carregarCartoes();
  }

  Future<void> _carregarCartoes() async {
    try {
      final lista = await CartoesRepository().listarCartoes();
      if (mounted) {
        setState(() {
          _cartoes = lista;
          if (_cartoes.isNotEmpty && _cartaoId == null) {
            _cartaoId = _cartoes.first['id'] as String;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_isCartao && _cartaoId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione o cartão de crédito.')),
        );
        return;
      }
      setState(() => _isLoading = true);

      final valor = MoedaInputFormatter.parse(_valorController.text);
      final vencStr = _dataVencimento.toIso8601String().substring(0, 10);
      final cubit = context.read<ContasPagarCubit>();

      final bool ok;
      if (_isCartao || _parcelas > 1) {
        ok = await cubit.cadastrarDespesaCartao({
          'cartao_id': _isCartao ? _cartaoId : null,
          'descricao': _descricaoController.text.trim(),
          'valor_total': valor,
          'parcelas': _parcelas,
          'data_competencia': vencStr,
          'categoria_id': _categoriaId,
          'escopo': _escopo,
          'forma_pagamento': _formaPagamento,
        });
      } else {
        final dados = {
          'descricao': _descricaoController.text.trim(),
          'escopo': _escopo,
          'valor_total': valor,
          'categoria_id': _categoriaId,
          'data_vencimento': vencStr,
          'tipo_recorrencia': _tipoRecorrencia,
          'status': _jaPago ? 'PAGO' : 'PENDENTE',
          'data_pagamento': _jaPago ? DateTime.now().toIso8601String().substring(0, 10) : null,
          'forma_pagamento': _formaPagamento,
          if (_contaBancariaId != null) 'conta_bancaria_id': _contaBancariaId,
        };
        ok = await cubit.cadastrarDespesa(dados);
      }
      if (mounted) {
        setState(() => _isLoading = false);
        if (ok) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categorias = context.read<ContasPagarCubit>().state.categorias;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.post_add, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Novo Lançamento de Despesa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição da Despesa *',
                    hintText: 'Ex: Aluguel da Clínica, Conta de Energia, Reposição de Luvas...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Informe a descrição' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _valorController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          MoedaInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Valor da Despesa (R\$) *',
                          prefixText: 'R\$ ',
                          hintText: '0,00',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          final v = MoedaInputFormatter.parse(val);
                          if (v <= 0) return 'Informe um valor válido.';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _tipoRecorrencia,
                        decoration: const InputDecoration(labelText: 'Tipo / Recorrência *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'AVULSA', child: Text('Gasto Pontual/Avulso')),
                          DropdownMenuItem(value: 'FIXA_MENSAL', child: Text('Fixa Mensal')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _tipoRecorrencia = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dataVencimento,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _dataVencimento = picked);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Data de Vencimento *',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today, size: 16),
                          ),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(_dataVencimento),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    if (categorias.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _categoriaId,
                          decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Sem Categoria')),
                            ...categorias.map(
                              (cat) => DropdownMenuItem(
                                value: cat['id'] as String,
                                child: Text(cat['nome'] as String, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _categoriaId = val),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _formaPagamento,
                  decoration: const InputDecoration(labelText: 'Forma de Pagamento *', border: OutlineInputBorder()),
                  items: FormaPagamentoUtil.itens(FormaPagamentoUtil.codigosDespesa),
                  onChanged: (val) {
                    if (val != null) setState(() => _formaPagamento = val);
                  },
                ),
                if (_isCartao) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _cartaoId,
                    decoration: const InputDecoration(
                      labelText: 'Cartão de Crédito *',
                      prefixIcon: Icon(Icons.credit_card),
                      border: OutlineInputBorder(),
                    ),
                    hint: Text(_cartoes.isEmpty ? 'Nenhum cartão cadastrado' : 'Selecione o cartão'),
                    items: _cartoes
                        .map((c) => DropdownMenuItem<String>(
                              value: c['id'] as String,
                              child: Text('${c['nome']} (${c['escopo']})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _cartaoId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _parcelas,
                    decoration: const InputDecoration(labelText: 'Parcelas', border: OutlineInputBorder()),
                    items: List.generate(
                      24,
                      (i) => DropdownMenuItem(value: i + 1, child: Text(i == 0 ? 'À vista (1x)' : '${i + 1}x')),
                    ),
                    onChanged: (val) {
                      if (val != null) setState(() => _parcelas = val);
                    },
                  ),
                  if (_parcelas > 1) ...[
                    const SizedBox(height: 6),
                    Builder(
                      builder: (_) {
                        final v = MoedaInputFormatter.parse(_valorController.text);
                        if (v <= 0) return const SizedBox.shrink();
                        final valorParcela = v / _parcelas;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.calendar_month, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_parcelas parcelas de R\$ ${valorParcela.toStringAsFixed(2)}',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _isCartao
                                    ? 'Cada parcela será lançada como pendente no seu mês correspondente conforme o vencimento da fatura do cartão.'
                                    : 'Cada parcela será lançada como pendente mês a mês nos próximos meses.',
                                style: TextStyle(fontSize: 11, color: Colors.blue.shade800),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                if (!_isCartao)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Esta conta já foi paga agora', style: TextStyle(fontSize: 13)),
                    value: _jaPago,
                    onChanged: (val) => setState(() => _jaPago = val ?? false),
                  ),
                if (!_isCartao) ...[
                  Builder(
                    builder: (ctx) {
                      try {
                        final bCubit = ctx.watch<ContasBancariasCubit>();
                        final contasAtivas = bCubit.state.contas.where((c) => c.ativo).toList();
                        if (contasAtivas.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _contaBancariaId,
                            decoration: InputDecoration(
                              labelText: _jaPago
                                  ? 'Conta Bancária de Débito (Imediato)'
                                  : 'Conta Bancária Prevista para Pagamento',
                              helperText: _jaPago
                                  ? 'O saldo desta conta será reduzido imediatamente'
                                  : 'Será debitada quando você marcar a conta como paga',
                              prefixIcon: const Icon(Icons.account_balance),
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Sem Vínculo com Conta Bancária')),
                              ...contasAtivas.map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.nomeConta} (${c.bancoNome})'),
                                ),
                              ),
                            ],
                            onChanged: (val) => setState(() => _contaBancariaId = val),
                          ),
                        );
                      } catch (_) {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isLoading ? null : _salvar,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
          child: _isLoading
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Salvar Despesa'),
        ),
      ],
    );
  }
}
