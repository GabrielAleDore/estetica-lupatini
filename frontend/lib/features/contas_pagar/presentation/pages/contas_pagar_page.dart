import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../contas_bancarias/presentation/cubit/contas_bancarias_cubit.dart';
import '../cubit/contas_pagar_cubit.dart';
import '../cubit/contas_pagar_state.dart';

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
        child: const _ModalNovaDespesa(),
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
                          'Contas a Pagar & Despesas Operacionais',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Controle rigoroso com segregação de Despesas da Clínica (PJ) vs Pessoais (PF)',
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
                          titulo: 'Pendente PJ (Clínica)',
                          valor: _currencyFormat.format(state.totalPendentePj),
                          cor: AppColors.pjClinical,
                          icone: Icons.business,
                        ),
                        _KpiDespesaCard(
                          titulo: 'Pendente PF (Pessoal)',
                          valor: _currencyFormat.format(state.totalPendentePf),
                          cor: AppColors.pfPersonal,
                          icone: Icons.person_outline,
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

                        // Filtro Escopo PF vs PJ
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'TODOS', label: Text('Todos Escopos')),
                            ButtonSegment(value: 'PJ', label: Text('PJ (Clínica)')),
                            ButtonSegment(value: 'PF', label: Text('PF (Pessoal)')),
                          ],
                          selected: {state.filtroEscopo},
                          onSelectionChanged: (val) => cubit.mudarEscopo(val.first),
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

                // Tabela/Lista de Despesas
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
                                    'Nenhuma despesa pendente nesta categoria!',
                                    style: TextStyle(color: Colors.grey, fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: contas.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final c = contas[index];
                                final isPago = c['status'] == 'PAGO';
                                final isPj = c['escopo'] == 'PJ';
                                final vencStr = c['data_vencimento']?.toString() ?? '';
                                final isVencido = !isPago && vencStr.isNotEmpty && vencStr.compareTo(hojeStr) < 0;
                                final valor = (c['valor_total'] as num?)?.toDouble() ?? 0.0;
                                final categoria = c['categorias'] as Map<String, dynamic>?;

                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: isVencido
                                          ? AppColors.error
                                          : isPago
                                              ? AppColors.borderLight
                                              : Colors.orange.shade300,
                                      width: isVencido ? 1.5 : 1.0,
                                    ),
                                  ),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Tag de Escopo
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isPj
                                                ? AppColors.pjClinical.withValues(alpha: 0.12)
                                                : AppColors.pfPersonal.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isPj ? 'PJ CLÍNICA' : 'PF PESSOAL',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isPj ? AppColors.pjClinical : AppColors.pfPersonal,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Informações da Despesa
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      c['descricao'] ?? 'Despesa',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (c['tipo_recorrencia'] == 'FIXA_MENSAL') ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue.withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: const Text('Fixa Mensal', style: TextStyle(fontSize: 10, color: Colors.blue)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Categoria: ${categoria?['nome'] ?? 'Geral'}  •  Vencimento: ${vencStr.isEmpty ? 'Hoje' : vencStr}${isPago ? '  •  Pago em: ${c['data_pagamento'] ?? ''}' : ''}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isVencido ? AppColors.error : AppColors.textSecondaryLight,
                                                  fontWeight: isVencido ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Valor da Despesa
                                        Text(
                                          _currencyFormat.format(valor),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isPago ? Colors.grey.shade600 : AppColors.error,
                                          ),
                                        ),
                                        const SizedBox(width: 16),

                                        // Ações Rápidas
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isPago)
                                              ElevatedButton.icon(
                                                onPressed: () => cubit.marcarComoPago(c['id']),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.success,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                ),
                                                icon: const Icon(Icons.check, size: 14),
                                                label: const Text('Pagar', style: TextStyle(fontSize: 12)),
                                              )
                                            else
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.success.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.check_circle, size: 14, color: AppColors.success),
                                                    SizedBox(width: 4),
                                                    Text('PAGO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                                              tooltip: 'Excluir Lançamento',
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

class _ModalNovaDespesa extends StatefulWidget {
  const _ModalNovaDespesa();

  @override
  State<_ModalNovaDespesa> createState() => _ModalNovaDespesaState();
}

class _ModalNovaDespesaState extends State<_ModalNovaDespesa> {
  final _formKey = GlobalKey<FormState>();
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  String _escopo = 'PJ';
  String _tipoRecorrencia = 'AVULSA';
  String? _categoriaId;
  String? _contaBancariaId;
  DateTime _dataVencimento = DateTime.now();
  bool _jaPago = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);

      final valor = double.tryParse(_valorController.text.replaceAll(',', '.')) ?? 0.0;
      final vencStr = _dataVencimento.toIso8601String().substring(0, 10);

      final dados = {
        'descricao': _descricaoController.text.trim(),
        'escopo': _escopo,
        'valor_total': valor,
        'categoria_id': _categoriaId,
        'data_vencimento': vencStr,
        'tipo_recorrencia': _tipoRecorrencia,
        'status': _jaPago ? 'PAGO' : 'PENDENTE',
        'data_pagamento': _jaPago ? DateTime.now().toIso8601String().substring(0, 10) : null,
        if (_jaPago && _contaBancariaId != null) 'conta_bancaria_id': _contaBancariaId,
      };

      final ok = await context.read<ContasPagarCubit>().cadastrarDespesa(dados);
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
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Valor (R\$) *', border: OutlineInputBorder()),
                        validator: (val) {
                          final v = double.tryParse(val?.replaceAll(',', '.') ?? '');
                          if (v == null || v <= 0) return 'Valor inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _escopo,
                        decoration: const InputDecoration(labelText: 'Escopo *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'PJ', child: Text('PJ (Clínica)')),
                          DropdownMenuItem(value: 'PF', child: Text('PF (Pessoal)')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _escopo = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _tipoRecorrencia,
                        decoration: const InputDecoration(labelText: 'Recorrência *', border: OutlineInputBorder()),
                        items: const [
                          DropdownMenuItem(value: 'AVULSA', child: Text('Gasto Pontual/Avulso')),
                          DropdownMenuItem(value: 'FIXA_MENSAL', child: Text('Fixa Mensal')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _tipoRecorrencia = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            labelText: 'Vencimento *',
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
                  ],
                ),
                if (categorias.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _categoriaId,
                    decoration: const InputDecoration(labelText: 'Categoria (Opcional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sem Categoria Específica')),
                      ...categorias.map(
                        (cat) => DropdownMenuItem(
                          value: cat['id'] as String,
                          child: Text(cat['nome'] as String),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _categoriaId = val),
                  ),
                ],
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Esta conta já foi paga agora', style: TextStyle(fontSize: 13)),
                  value: _jaPago,
                  onChanged: (val) => setState(() => _jaPago = val ?? false),
                ),
                if (_jaPago) ...[
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
                            decoration: const InputDecoration(
                              labelText: 'Conta Bancária de Débito (Opcional)',
                              prefixIcon: Icon(Icons.account_balance),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Sem Vínculo com Conta')),
                              ...contasAtivas.map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.nomeConta} (${c.escopo} - ${c.bancoNome})'),
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
