import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/vendas_historico_cubit.dart';
import '../cubit/vendas_historico_state.dart';

class MovimentacoesVendasPage extends StatelessWidget {
  final VendasHistoricoCubit? cubit;
  const MovimentacoesVendasPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: const _MovimentacoesVendasView());
    }
    try {
      context.read<VendasHistoricoCubit>();
      return const _MovimentacoesVendasView();
    } catch (_) {
      return BlocProvider(
        create: (_) => VendasHistoricoCubit()..carregarVendas(),
        child: const _MovimentacoesVendasView(),
      );
    }
  }
}

class _MovimentacoesVendasView extends StatefulWidget {
  const _MovimentacoesVendasView();

  @override
  State<_MovimentacoesVendasView> createState() => _MovimentacoesVendasViewState();
}

class _MovimentacoesVendasViewState extends State<_MovimentacoesVendasView> {
  final _buscaController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    context.read<VendasHistoricoCubit>().carregarVendas();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _abrirModalRecebimento(BuildContext context, Map<String, dynamic> venda) {
    String formaSelecionada = 'PIX';
    final vendaId = venda['id'] as String;
    final valorLiquido = (venda['valor_liquido'] as num?)?.toDouble() ?? 0.0;
    final cliente = venda['clientes'] as Map<String, dynamic>?;
    final clienteNome = cliente?['nome'] ?? 'Cliente';

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.payments_outlined, color: AppColors.success),
                SizedBox(width: 8),
                Text('Dar Baixa / Receber Venda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paciente: $clienteNome', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  'Valor a Receber: ${_currencyFormat.format(valorLiquido)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.success),
                ),
                const SizedBox(height: 16),
                const Text('Selecione a forma como o pagamento foi recebido:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: formaSelecionada,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'PIX', child: Text('PIX')),
                    DropdownMenuItem(value: 'DINHEIRO', child: Text('Dinheiro em Espécie')),
                    DropdownMenuItem(value: 'CARTAO_DEBITO', child: Text('Cartão de Débito')),
                    DropdownMenuItem(value: 'CARTAO_CREDITO', child: Text('Cartão de Crédito')),
                    DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferência Bancária')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => formaSelecionada = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(dialogCtx).pop();
                  final cubit = context.read<VendasHistoricoCubit>();
                  final ok = await cubit.liquidarVendaPendente(vendaId, formaSelecionada);
                  if (ok && mounted) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Venda liquidada com sucesso! Receita registrada no caixa.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar Recebimento'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _abrirComprovante(BuildContext context, Map<String, dynamic> venda) {
    final cliente = venda['clientes'] as Map<String, dynamic>?;
    final itens = venda['itens_venda'] as List? ?? [];
    final dataHora = DateTime.tryParse(venda['data_hora'] ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        title: const Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long, size: 36, color: AppColors.primary),
              SizedBox(height: 8),
              Text('Comprovante de Atendimento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Estética Lupatini', style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight)),
            ],
          ),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Data/Hora:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(_dateFormat.format(dataHora), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Paciente:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(cliente?['nome'] ?? 'Consumidor Final', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status Pagamento:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      venda['status_pagamento'] ?? 'EFETIVADO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: venda['status_pagamento'] == 'PENDENTE' ? Colors.amber.shade800 : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text('Itens Realizados / Comercializados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...itens.map((it) {
                  final prod = it['produtos'] as Map<String, dynamic>?;
                  final serv = it['servicos'] as Map<String, dynamic>?;
                  final nome = prod?['nome'] ?? serv?['nome'] ?? 'Item';
                  final codigo = prod?['codigo_sequencial'] ?? serv?['codigo_sequencial'];
                  final qtd = (it['quantidade'] as num?)?.toDouble() ?? 1.0;
                  final subtotal = (it['subtotal'] as num?)?.toDouble() ?? 0.0;
                  final valorOrig = (it['valor_original'] as num?)?.toDouble();

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              if (codigo != null)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.borderLight),
                                  ),
                                  child: Text(
                                    '#$codigo',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.textSecondaryLight),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  '${qtd.toStringAsFixed(0)}x $nome',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (valorOrig != null && valorOrig > subtotal)
                              Text(
                                _currencyFormat.format(valorOrig),
                                style: const TextStyle(fontSize: 10, decoration: TextDecoration.lineThrough, color: Colors.grey),
                              ),
                            Text(
                              _currencyFormat.format(subtotal),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                // Comparativo Contábil do Comprovante
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal Original:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      _currencyFormat.format(
                        (venda['valor_original'] as num?)?.toDouble() ?? 
                        (venda['valor_bruto'] as num?)?.toDouble() ?? 
                        0.0,
                      ),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (((venda['valor_desconto'] as num?)?.toDouble() ?? (venda['desconto'] as num?)?.toDouble() ?? 0.0) > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Desconto Total Aplicado:', style: TextStyle(fontSize: 12, color: AppColors.error)),
                          if (venda['tipo_desconto'] != null && venda['tipo_desconto'] != 'NENHUM') ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                venda['tipo_desconto'],
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        '- ${_currencyFormat.format((venda['valor_desconto'] as num?)?.toDouble() ?? (venda['desconto'] as num?)?.toDouble() ?? 0.0)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.error),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Pago / a Receber:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(
                      _currencyFormat.format((venda['valor_liquido'] as num?)?.toDouble() ?? (venda['valor_final'] as num?)?.toDouble() ?? 0.0),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: BlocConsumer<VendasHistoricoCubit, VendasHistoricoState>(
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
          final cubit = context.read<VendasHistoricoCubit>();

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topo com Título e Indicadores Rápidos
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
                          'Movimentações de Vendas & Contas a Receber',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Acompanhamento de atendimentos concluídos, vendas pagas e fiado a receber',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _IndicadorCard(
                          titulo: 'Recebido / Efetivado',
                          valor: _currencyFormat.format(state.totalEfetivado),
                          cor: AppColors.success,
                          icone: Icons.check_circle,
                        ),
                        const SizedBox(width: 12),
                        _IndicadorCard(
                          titulo: 'Pendente / Fiado',
                          valor: _currencyFormat.format(state.totalPendente),
                          cor: Colors.amber.shade800,
                          icone: Icons.schedule,
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
                        // Filtro Status de Pagamento
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'TODOS', label: Text('Todas')),
                            ButtonSegment(value: 'EFETIVADO', label: Text('Pagas')),
                            ButtonSegment(value: 'PENDENTE', label: Text('Fiado / A Receber')),
                          ],
                          selected: {state.filtroStatusPagamento},
                          onSelectionChanged: (val) => cubit.mudarFiltroStatus(val.first),
                        ),

                        // Filtro Período
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'MES', label: Text('Mês Atual')),
                            ButtonSegment(value: '7DIAS', label: Text('7 Dias')),
                            ButtonSegment(value: 'HOJE', label: Text('Hoje')),
                            ButtonSegment(value: 'TODOS', label: Text('Tudo')),
                          ],
                          selected: {state.filtroPeriodo},
                          onSelectionChanged: (val) => cubit.mudarFiltroPeriodo(val.first),
                        ),

                        // Campo de Busca por Cliente
                        SizedBox(
                          width: 240,
                          child: TextField(
                            controller: _buscaController,
                            decoration: InputDecoration(
                              hintText: 'Buscar paciente...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (val) => cubit.mudarBuscaCliente(val),
                          ),
                        ),

                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Atualizar',
                          onPressed: () => cubit.carregarVendas(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lista de Vendas
                Expanded(
                  child: state.status == HistoricoStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : state.vendas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text('Nenhuma venda encontrada para os filtros selecionados.',
                                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: state.vendas.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final v = state.vendas[index];
                                final cliente = v['clientes'] as Map<String, dynamic>?;
                                final itens = v['itens_venda'] as List? ?? [];
                                final isPendente = v['status_pagamento'] == 'PENDENTE';
                                final isCancelada = v['status'] == 'CANCELADA';
                                final dataHora = DateTime.tryParse(v['data_hora'] ?? '') ?? DateTime.now();
                                final dataPrevista = v['data_prevista_pagamento'];

                                // Resumo dos itens
                                final resumoItens = itens.map((it) {
                                  final prod = it['produtos'] as Map<String, dynamic>?;
                                  final serv = it['servicos'] as Map<String, dynamic>?;
                                  final nome = prod?['nome'] ?? serv?['nome'] ?? 'Item';
                                  final qtd = (it['quantidade'] as num?)?.toDouble() ?? 1.0;
                                  return '${qtd.toStringAsFixed(0)}x $nome';
                                }).join(', ');

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: isPendente ? Colors.amber.shade300 : AppColors.borderLight,
                                      width: isPendente ? 1.5 : 1.0,
                                    ),
                                  ),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Ícone de Status
                                        CircleAvatar(
                                          backgroundColor: isCancelada
                                              ? Colors.grey.shade200
                                              : isPendente
                                                  ? Colors.amber.withValues(alpha: 0.15)
                                                  : AppColors.success.withValues(alpha: 0.15),
                                          child: Icon(
                                            isCancelada
                                                ? Icons.cancel_outlined
                                                : isPendente
                                                    ? Icons.schedule
                                                    : Icons.check_circle_outline,
                                            color: isCancelada
                                                ? Colors.grey
                                                : isPendente
                                                    ? Colors.amber.shade800
                                                    : AppColors.success,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Informações Principais
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      cliente?['nome'] ?? 'Consumidor Final',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isCancelada
                                                          ? Colors.grey.shade200
                                                          : isPendente
                                                              ? Colors.amber.withValues(alpha: 0.15)
                                                              : AppColors.success.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      isCancelada
                                                          ? 'CANCELADA'
                                                          : isPendente
                                                              ? 'FIADO / PENDENTE'
                                                              : 'PAGO',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: isCancelada
                                                          ? Colors.grey.shade700
                                                          : isPendente
                                                              ? Colors.amber.shade900
                                                              : AppColors.success,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                resumoItens.isEmpty ? 'Sem itens registrados' : resumoItens,
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Realizada em: ${_dateFormat.format(dataHora)}${isPendente && dataPrevista != null ? '  •  Vencimento: $dataPrevista' : ''}',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Comparativo Contábil: Subtotal Original, Desconto Total Aplicado, Total Pago
                                        Builder(
                                          builder: (context) {
                                            final valorOrig = (v['valor_original'] as num?)?.toDouble() ?? (v['valor_bruto'] as num?)?.toDouble() ?? 0.0;
                                            final valorDesc = (v['valor_desconto'] as num?)?.toDouble() ?? (v['desconto'] as num?)?.toDouble() ?? 0.0;
                                            final valorLiq = (v['valor_liquido'] as num?)?.toDouble() ?? (v['valor_final'] as num?)?.toDouble() ?? 0.0;
                                            final tipoDesc = v['tipo_desconto'] as String?;

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                if (valorDesc > 0) ...[
                                                  Text(
                                                    'Orig: ${_currencyFormat.format(valorOrig)}',
                                                    style: const TextStyle(fontSize: 10, decoration: TextDecoration.lineThrough, color: Colors.grey),
                                                  ),
                                                  Text(
                                                    'Desc: -${_currencyFormat.format(valorDesc)}${tipoDesc != null && tipoDesc != 'NENHUM' ? ' ($tipoDesc)' : ''}',
                                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
                                                  ),
                                                ],
                                                Text(
                                                  _currencyFormat.format(valorLiq),
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: isCancelada
                                                        ? Colors.grey
                                                        : isPendente
                                                            ? Colors.amber.shade900
                                                            : AppColors.primary,
                                                  ),
                                                ),
                                                Text(
                                                  v['forma_pagamento'] ?? 'PIX',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 16),

                                        // Ações Rápidas
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (isPendente && !isCancelada)
                                              ElevatedButton.icon(
                                                onPressed: () => _abrirModalRecebimento(context, v),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.success,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                ),
                                                icon: const Icon(Icons.check, size: 14),
                                                label: const Text('Receber', style: TextStyle(fontSize: 12)),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.receipt_outlined, size: 20),
                                              tooltip: 'Ver Recibo',
                                              onPressed: () => _abrirComprovante(context, v),
                                            ),
                                            if (!isCancelada)
                                              IconButton(
                                                icon: const Icon(Icons.cancel_outlined, size: 20, color: AppColors.error),
                                                tooltip: 'Cancelar Venda',
                                                onPressed: () async {
                                                  final confirm = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: const Text('Cancelar Venda?'),
                                                      content: const Text('Esta ação marcará a venda como cancelada.'),
                                                      actions: [
                                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Não')),
                                                        ElevatedButton(
                                                          onPressed: () => Navigator.pop(ctx, true),
                                                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                                          child: const Text('Sim, Cancelar'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirm == true) {
                                                    cubit.cancelarVenda(v['id']);
                                                  }
                                                },
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
}

class _IndicadorCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;
  final IconData icone;

  const _IndicadorCard({
    required this.titulo,
    required this.valor,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
