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
import '../widgets/liquidar_despesa_dialog.dart';

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
  final _buscaController = TextEditingController();
  String _termoBusca = '';

  @override
  void initState() {
    super.initState();
    context.read<ContasPagarCubit>().carregarContas();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
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

  void _abrirModalLiquidacao(BuildContext context, Map<String, dynamic> contaItem) {
    final cubit = context.read<ContasPagarCubit>();
    List<ContaBancariaModel> contasAtivas = [];
    try {
      final bCubit = context.read<ContasBancariasCubit>();
      contasAtivas = bCubit.state.contas.where((c) => c.ativo).toList();
    } catch (_) {}

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => LiquidarDespesaDialog(
        despesa: contaItem,
        contasBancarias: contasAtivas,
        onConfirmar: ({
          required String transacaoId,
          required DateTime dataPagamento,
          String? contaBancariaId,
          double? valorFinal,
          String? comprovante,
          String? observacoes,
        }) =>
            cubit.marcarComoPago(
          transacaoId,
          contaBancariaId: contaBancariaId,
          dataPagamento: dataPagamento,
          valorFinal: valorFinal,
          comprovante: comprovante,
          observacoes: observacoes,
        ),
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

  String _formatarDataBrasileira(String? isoStr) {
    if (isoStr == null || isoStr.trim().isEmpty) return '--/--/----';
    try {
      final dt = DateTime.parse(isoStr.trim());
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return isoStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
          final todasContas = state.contasFiltradas;
          final hojeStr = DateTime.now().toIso8601String().substring(0, 10);

          // Filtragem instantânea por texto
          final query = _termoBusca.trim().toLowerCase();
          final contas = query.isEmpty
              ? todasContas
              : todasContas.where((c) {
                  final desc = (c['descricao'] ?? '').toString().toLowerCase();
                  final cat = ((c['categorias'] as Map<String, dynamic>?)?['nome'] ?? '').toString().toLowerCase();
                  final bco = ((c['contas_bancarias'] as Map<String, dynamic>?)?['nome_conta'] ?? '').toString().toLowerCase();
                  final doc = (c['comprovante'] ?? c['numero_documento'] ?? '').toString().toLowerCase();
                  final valStr = ((c['valor_total'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2);
                  return desc.contains(query) ||
                      cat.contains(query) ||
                      bco.contains(query) ||
                      doc.contains(query) ||
                      valStr.contains(query);
                }).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Topo & Breadcrumb Corporativo
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'FINANCEIRO',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
                            const Text(
                              'TESOURARIA & OBRIGAÇÕES',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Contas a Pagar & Obrigações',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Gestão unificada de compromissos, fornecedores, conciliação e baixas bancárias',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _abrirModalNovaDespesa(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nova Obrigação', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Faixa Analítica Superior (4 KPI Cards Enterprise)
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _KpiEnterpriseCard(
                          titulo: 'A Vencer no Mês',
                          valor: _currencyFormat.format(state.totalPendenteGeral),
                          subtitulo: '${state.quantidadePendentes} compromissos pendentes',
                          corTema: const Color(0xFF1E293B),
                          icone: Icons.calendar_month_outlined,
                        ),
                        _KpiEnterpriseCard(
                          titulo: 'Em Atraso / Vencidas',
                          valor: _currencyFormat.format(state.totalVencidasGeral),
                          subtitulo: state.quantidadeVencidas > 0
                              ? '${state.quantidadeVencidas} títulos aguardando liquidação'
                              : 'Nenhum título em atraso',
                          corTema: AppColors.error,
                          icone: Icons.warning_amber_rounded,
                          isAlerta: state.totalVencidasGeral > 0,
                        ),
                        _KpiEnterpriseCard(
                          titulo: 'Previsão Próximos 7 Dias',
                          valor: _currencyFormat.format(state.totalPrevisaoProximos7Dias),
                          subtitulo: 'Impacto a curto prazo no caixa',
                          corTema: Colors.amber.shade900,
                          icone: Icons.schedule_outlined,
                        ),
                        _KpiEnterpriseCard(
                          titulo: 'Liquidadas no Mês',
                          valor: _currencyFormat.format(state.totalPagoMes),
                          subtitulo: '${state.quantidadePagas} baixas realizadas',
                          corTema: AppColors.success,
                          icone: Icons.check_circle_outlined,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 3. Barra de Controles & Filtros Avançados
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Campo de Busca Rápida com Clear Button
                      SizedBox(
                        width: 280,
                        child: TextField(
                          controller: _buscaController,
                          onChanged: (val) => setState(() => _termoBusca = val),
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Buscar por descrição, fornecedor...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                            suffixIcon: _termoBusca.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 16),
                                    onPressed: () {
                                      _buscaController.clear();
                                      setState(() => _termoBusca = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),

                      // Segmented Button de Status
                      SegmentedButton<String>(
                        style: SegmentedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          selectedBackgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          selectedForegroundColor: AppColors.primary,
                        ),
                        segments: const [
                          ButtonSegment(value: 'PENDENTE', label: Text('A Vencer')),
                          ButtonSegment(value: 'VENCIDAS', label: Text('Em Atraso')),
                          ButtonSegment(value: 'PAGO', label: Text('Liquidadas')),
                          ButtonSegment(value: 'TODAS', label: Text('Todas')),
                        ],
                        selected: {state.filtroAba},
                        onSelectionChanged: (val) => cubit.mudarAba(val.first),
                      ),

                      // Seletor de Mês de Vencimento
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: state.filtroMes,
                            icon: const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
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
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Recarregar dados',
                        onPressed: () => cubit.carregarContas(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Tabela de Obrigações Financeiras
                Expanded(
                  child: state.status == ContasPagarStatus.loading
                      ? const Center(child: CircularProgressIndicator())
                      : contas.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.assignment_turned_in_outlined, size: 52, color: Colors.grey.shade300),
                                  const SizedBox(height: 12),
                                  Text(
                                    _termoBusca.isNotEmpty
                                        ? 'Nenhuma obrigação encontrada para "$_termoBusca".'
                                        : 'Nenhuma obrigação encontrada para os filtros selecionados.',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                  ),
                                  if (_termoBusca.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {
                                        _buscaController.clear();
                                        setState(() => _termoBusca = '');
                                      },
                                      child: const Text('Limpar busca'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  // Cabeçalho das Colunas
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                                    ),
                                    child: const Row(
                                      children: [
                                        SizedBox(
                                          width: 130,
                                          child: Text('VENCIMENTO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          flex: 3,
                                          child: Text('DESCRIÇÃO & FORNECEDOR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Text('CATEGORIA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          flex: 2,
                                          child: Text('CONTA / LIQUIDAÇÃO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 120,
                                          child: Text('VALOR', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5)),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 110,
                                          child: Center(child: Text('STATUS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5))),
                                        ),
                                        SizedBox(width: 8),
                                        SizedBox(
                                          width: 150,
                                          child: Center(child: Text('AÇÕES', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5))),
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
                                              ? const Color(0xFFFEF2F2).withValues(alpha: 0.5)
                                              : (isHoje
                                                  ? const Color(0xFFFFFBEB).withValues(alpha: 0.6)
                                                  : Colors.white),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                          child: Row(
                                            children: [
                                              // Coluna 1: Vencimento e Datas
                                              SizedBox(
                                                width: 130,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      _formatarDataBrasileira(vencStr),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: FontWeight.w700,
                                                        color: isVencido ? AppColors.error : const Color(0xFF1E293B),
                                                      ),
                                                    ),
                                                    if (isVencido)
                                                      const Text('Vencida em atraso', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w700))
                                                    else if (isHoje)
                                                      Text('Vence Hoje', style: TextStyle(fontSize: 10, color: Colors.amber.shade900, fontWeight: FontWeight.w700))
                                                    else if (isPago && c['data_pagamento'] != null)
                                                      Text('Baixa: ${_formatarDataBrasileira(c['data_pagamento']?.toString())}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600))
                                                    else
                                                      Text('A vencer', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 2: Descrição / Favorecido
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            c['descricao'] ?? 'Obrigação',
                                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
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
                                                    if (c['comprovante'] != null && (c['comprovante'] as String).isNotEmpty)
                                                      Padding(
                                                        padding: const EdgeInsets.only(top: 2),
                                                        child: Row(
                                                          children: [
                                                            Icon(Icons.receipt_outlined, size: 12, color: Colors.grey.shade500),
                                                            const SizedBox(width: 4),
                                                            Flexible(
                                                              child: Text(
                                                                'Doc: ${c['comprovante']}',
                                                                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 3: Categoria
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      categoria?['nome'] ?? 'Geral',
                                                      style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 4: Conta / Forma de Débito
                                              Expanded(
                                                flex: 2,
                                                child: Row(
                                                  children: [
                                                    if (formaStr != null && formaStr.isNotEmpty) ...[
                                                      Icon(
                                                        FormaPagamentoUtil.icone(formaStr),
                                                        size: 14,
                                                        color: Colors.grey.shade600,
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
                                                          color: cartao != null || formaStr != null ? const Color(0xFF334155) : Colors.grey.shade500,
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
                                                width: 120,
                                                child: Text(
                                                  _currencyFormat.format(valor),
                                                  textAlign: TextAlign.right,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    fontFeatures: const [FontFeature.tabularFigures()],
                                                    color: isPago ? const Color(0xFF475569) : (isVencido ? AppColors.error : const Color(0xFF0F172A)),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 6: Status
                                              SizedBox(
                                                width: 110,
                                                child: Center(
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isPago
                                                          ? const Color(0xFFDCFCE7)
                                                          : (isVencido ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7)),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      isPago ? 'LIQUIDADO' : (isVencido ? 'EM ATRASO' : 'A VENCER'),
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w800,
                                                        letterSpacing: 0.4,
                                                        color: isPago
                                                            ? const Color(0xFF166534)
                                                            : (isVencido ? const Color(0xFF991B1B) : const Color(0xFF92400E)),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Coluna 7: Ações
                                              SizedBox(
                                              width: 150,
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (!isPago)
                                                      ElevatedButton.icon(
                                                        onPressed: () => _abrirModalLiquidacao(context, c),
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor: AppColors.success,
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                          elevation: 0,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                                          minimumSize: const Size(0, 30),
                                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                        ),
                                                        icon: const Icon(Icons.check_circle_outline, size: 14),
                                                        label: const Text('Liquidar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                      )
                                                    else
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: Colors.grey.shade300),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.done_all, size: 12, color: Colors.grey.shade600),
                                                            const SizedBox(width: 3),
                                                            Text('Baixado', style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                                                          ],
                                                        ),
                                                      ),
                                                    const SizedBox(width: 4),
                                                    IconButton(
                                                      icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.primary),
                                                      tooltip: 'Editar Parcela / Vencimento',
                                                      padding: EdgeInsets.zero,
                                                      visualDensity: VisualDensity.compact,
                                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                      onPressed: () => _abrirModalEditarParcela(context, c),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 17, color: Colors.grey),
                                                      tooltip: 'Excluir',
                                                      padding: EdgeInsets.zero,
                                                      visualDensity: VisualDensity.compact,
                                                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                      onPressed: () async {
                                                        final confirm = await showDialog<bool>(
                                                          context: context,
                                                          builder: (ctx) => AlertDialog(
                                                            title: const Text('Excluir Obrigação?'),
                                                            content: const Text('Deseja realmente remover esta obrigação financeira? Esta ação não pode ser desfeita.'),
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

class _KpiEnterpriseCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String subtitulo;
  final Color corTema;
  final IconData icone;
  final bool isAlerta;

  const _KpiEnterpriseCard({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.corTema,
    required this.icone,
    this.isAlerta = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAlerta ? corTema.withValues(alpha: 0.5) : Colors.grey.shade200,
          width: isAlerta ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isAlerta ? corTema.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  titulo.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: corTema.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icone, size: 15, color: corTema),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: corTema,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitulo,
            style: TextStyle(
              fontSize: 11,
              color: isAlerta ? corTema : Colors.grey.shade600,
              fontWeight: isAlerta ? FontWeight.w600 : FontWeight.normal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
