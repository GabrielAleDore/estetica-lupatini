import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';
import '../../../../core/utils/forma_pagamento_util.dart';
import '../../../contas_bancarias/domain/models/conta_bancaria_model.dart';
import '../../../contas_bancarias/presentation/cubit/contas_bancarias_cubit.dart';
import '../../../contas_bancarias/data/contas_bancarias_repository.dart';

class NovaReceitaDialog extends StatefulWidget {
  final Future<bool> Function(Map<String, dynamic> dados) onSalvar;
  final String? escopoInicial;
  final List<ContaBancariaModel>? contasPreCarregadas;

  const NovaReceitaDialog({
    super.key,
    required this.onSalvar,
    this.escopoInicial,
    this.contasPreCarregadas,
  });

  @override
  State<NovaReceitaDialog> createState() => _NovaReceitaDialogState();
}

class _NovaReceitaDialogState extends State<NovaReceitaDialog> {
  final _formKey = GlobalKey<FormState>();

  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _dataController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  final _observacoesController = TextEditingController();

  late String _escopo; // 'PJ' ou 'PF'
  String _categoria = 'Receitas Extras';
  String? _contaBancariaIdOrigem;
  String? _contaBancariaIdDestino;
  String _formaPagamento = 'PIX';
  bool _jaRecebido = true; // true = EFETIVADO, false = PENDENTE
  bool _isSalvando = false;
  bool _carregandoContas = false;

  List<ContaBancariaModel> _contasDisponiveis = [];

  bool get _isTransferencia => _formaPagamento == 'TRANSFERENCIA';

  final List<String> _categoriasReceita = const [
    'Receitas Extras',
    'Aporte de Sócios',
    'Rendimentos',
    'Parcerias',
    'Reembolsos',
    'Outros',
  ];

  @override
  void initState() {
    super.initState();
    _escopo = widget.escopoInicial ?? 'PJ';
    if (widget.contasPreCarregadas != null && widget.contasPreCarregadas!.isNotEmpty) {
      _atualizarListaContas(widget.contasPreCarregadas!);
    } else {
      _carregarContasBancarias();
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _dataController.dispose();
    _observacoesController.dispose();
    super.dispose();
  }

  Future<void> _carregarContasBancarias() async {
    setState(() => _carregandoContas = true);
    try {
      try {
        final cubit = context.read<ContasBancariasCubit>();
        final contas = cubit.state.contas;
        if (contas.isNotEmpty) {
          _atualizarListaContas(contas);
          setState(() => _carregandoContas = false);
          return;
        }
      } catch (_) {}

      final repo = ContasBancariasRepository();
      final contas = await repo.getContas(apenasAtivas: true);
      if (mounted) {
        _atualizarListaContas(contas);
      }
    } catch (_) {
      // Ignora erro e mantém lista vazia se offline
    } finally {
      if (mounted) {
        setState(() => _carregandoContas = false);
      }
    }
  }

  void _atualizarListaContas(List<ContaBancariaModel> contas) {
    _contasDisponiveis = contas.where((c) => c.ativo).toList();
    _ajustarContasSelecionadas();
  }

  void _ajustarContasSelecionadas() {
    if (_contasDisponiveis.isNotEmpty) {
      if (_contaBancariaIdOrigem == null ||
          !_contasDisponiveis.any((c) => c.id == _contaBancariaIdOrigem)) {
        _contaBancariaIdOrigem = _contasDisponiveis.first.id;
      }
      if (_contaBancariaIdDestino == null ||
          !_contasDisponiveis.any((c) => c.id == _contaBancariaIdDestino)) {
        if (_contasDisponiveis.length > 1) {
          _contaBancariaIdDestino = _contasDisponiveis[1].id;
        } else {
          _contaBancariaIdDestino = _contasDisponiveis.first.id;
        }
      }
    } else {
      _contaBancariaIdOrigem = null;
      _contaBancariaIdDestino = null;
    }
  }

  Future<void> _selecionarData() async {
    DateTime dataInicial = DateTime.now();
    try {
      dataInicial = DateTime.parse(_dataController.text.trim());
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: dataInicial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null) {
      setState(() {
        _dataController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    final valor = MoedaInputFormatter.parse(_valorController.text);

    if (_isTransferencia) {
      if (_contasDisponiveis.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('São necessárias pelo menos 2 contas bancárias ativas para realizar uma transferência.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      if (_contaBancariaIdOrigem == null || _contaBancariaIdDestino == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione a conta de origem e a conta de destino.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      if (_contaBancariaIdOrigem == _contaBancariaIdDestino) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A conta de origem e a conta de destino não podem ser a mesma.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() => _isSalvando = true);

    final status = _jaRecebido ? 'PAGO' : 'PENDENTE';

    final dados = _isTransferencia
        ? {
            'descricao': _descricaoController.text.trim().isEmpty
                ? 'Transferência entre Contas'
                : _descricaoController.text.trim(),
            'tipo': 'ENTRADA',
            'escopo': _escopo,
            'categoria_nome': 'Transferência entre Contas',
            'valor': valor,
            'valor_total': valor,
            'data_transacao': _dataController.text.trim(),
            'data_competencia': _dataController.text.trim(),
            'data_vencimento': _dataController.text.trim(),
            'status': 'PAGO',
            'forma_pagamento': 'TRANSFERENCIA',
            'is_transferencia': true,
            'conta_origem_id': _contaBancariaIdOrigem,
            'conta_destino_id': _contaBancariaIdDestino,
            'conta_bancaria_id': _contaBancariaIdDestino,
            'observacoes': _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
            'origem': 'MANUAL',
          }
        : {
            'descricao': _descricaoController.text.trim(),
            'tipo': 'ENTRADA',
            'escopo': _escopo,
            'categoria_nome': _categoria,
            'valor': valor,
            'valor_total': valor,
            'data_transacao': _dataController.text.trim(),
            'data_competencia': _dataController.text.trim(),
            'data_vencimento': _dataController.text.trim(),
            'status': status,
            'conta_bancaria_id': _contaBancariaIdDestino,
            'observacoes': _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
            'origem': 'MANUAL',
            'forma_pagamento': _formaPagamento,
          };

    final sucesso = await widget.onSalvar(dados);
    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isTransferencia
                                    ? Colors.blue.withValues(alpha: 0.15)
                                    : AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _isTransferencia ? Icons.swap_horiz_rounded : Icons.add_circle_outline,
                                color: _isTransferencia ? AppColors.primary : AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isTransferencia ? 'Transferência entre Contas' : 'Nova Entrada / Receita Avulsa',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    _isTransferencia
                                        ? 'Movimentação entre contas com débito e crédito automático'
                                        : 'Registro de PIX, aportes de sócios e receitas extras',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Seletor de Escopo (PJ vs PF)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text('Destino do Recurso: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ChoiceChip(
                        label: const Text('PJ (Clínica)'),
                        selected: _escopo == 'PJ',
                        onSelected: (val) => setState(() => _escopo = 'PJ'),
                        selectedColor: AppColors.pjClinical.withValues(alpha: 0.2),
                      ),
                      ChoiceChip(
                        label: const Text('PF (Dra. Camila)'),
                        selected: _escopo == 'PF',
                        onSelected: (val) => setState(() => _escopo = 'PF'),
                        selectedColor: AppColors.pfPersonal.withValues(alpha: 0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Descrição
                  TextFormField(
                    controller: _descricaoController,
                    decoration: InputDecoration(
                      labelText: _isTransferencia ? 'Descrição da Transferência *' : 'Descrição da Receita *',
                      hintText: _isTransferencia
                          ? 'Ex: Transferência Caixa Físico para Nubank'
                          : 'Ex: Aporte inicial de sócio, Parceria estética...',
                      prefixIcon: Icon(_isTransferencia ? Icons.swap_horiz : Icons.edit_note),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição.' : null,
                  ),
                  const SizedBox(height: 14),

                  // Valor e Data
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _valorController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            MoedaInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: _isTransferencia ? 'Valor a Transferir (R\$) *' : 'Valor Recebido (R\$) *',
                            hintText: '0,00',
                            prefixIcon: const Icon(Icons.attach_money),
                            prefixText: 'R\$ ',
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = MoedaInputFormatter.parse(v);
                            if (n <= 0) return 'Informe um valor válido.';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _selecionarData,
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: _dataController,
                              decoration: InputDecoration(
                                labelText: _isTransferencia ? 'Data da Transferência *' : 'Data do Recebimento *',
                                prefixIcon: const Icon(Icons.calendar_today_outlined),
                                suffixIcon: const Icon(Icons.arrow_drop_down),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Categoria da Receita (oculta se for transferência)
                  if (!_isTransferencia) ...[
                    DropdownButtonFormField<String>(
                      initialValue: _categoria,
                      decoration: const InputDecoration(
                        labelText: 'Categoria de Receita *',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: _categoriasReceita.map((cat) {
                        return DropdownMenuItem(value: cat, child: Text(cat));
                      }).toList(),
                      onChanged: (v) => setState(() => _categoria = v!),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Forma de Recebimento
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _formaPagamento,
                    decoration: const InputDecoration(
                      labelText: 'Forma de Recebimento / Movimentação *',
                      border: OutlineInputBorder(),
                    ),
                    items: FormaPagamentoUtil.itens(FormaPagamentoUtil.codigosReceita),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _formaPagamento = v;
                          _ajustarContasSelecionadas();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // CONTAS BANCÁRIAS:
                  // Se for TRANSFERÊNCIA: exibe Origem (Débito) e Destino (Crédito)
                  // Se for normal: exibe apenas Destino (Crédito)
                  if (_isTransferencia) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.compare_arrows, color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Contas da Transferência',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue.shade900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // 1. Conta de Origem
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _contaBancariaIdOrigem,
                            decoration: const InputDecoration(
                              labelText: 'Conta Bancária de Origem (De onde SAI) *',
                              prefixIcon: Icon(Icons.arrow_upward, color: AppColors.error),
                              helperText: 'O saldo desta conta será DEBITADO (-)',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _contasDisponiveis.map((conta) {
                              return DropdownMenuItem(
                                value: conta.id,
                                child: Row(
                                  children: [
                                    Text(conta.nomeConta, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    Text('(${conta.bancoNome})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _contaBancariaIdOrigem = val);
                            },
                            validator: (v) => (v == null || v.isEmpty) ? 'Selecione a conta de origem.' : null,
                          ),

                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.arrow_downward, color: AppColors.primary, size: 18),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 2. Conta de Destino
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _contaBancariaIdDestino,
                            decoration: const InputDecoration(
                              labelText: 'Conta Bancária de Destino (Para onde VAI) *',
                              prefixIcon: Icon(Icons.arrow_downward, color: AppColors.success),
                              helperText: 'O saldo desta conta será CREDITADO (+)',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _contasDisponiveis.map((conta) {
                              return DropdownMenuItem(
                                value: conta.id,
                                child: Row(
                                  children: [
                                    Text(conta.nomeConta, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 6),
                                    Text('(${conta.bancoNome})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _contaBancariaIdDestino = val);
                            },
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Selecione a conta de destino.';
                              if (v == _contaBancariaIdOrigem) return 'Conta de destino não pode ser igual à de origem.';
                              return null;
                            },
                          ),

                          if (_contaBancariaIdOrigem != null && _contaBancariaIdOrigem == _contaBancariaIdDestino) ...[
                            const SizedBox(height: 8),
                            Text(
                              '⚠️ A conta de origem e destino devem ser diferentes.',
                              style: TextStyle(color: Colors.red.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    // Modo padrão de Receita: única conta destino
                    _carregandoContas
                        ? const LinearProgressIndicator()
                        : DropdownButtonFormField<String>(
                            initialValue: _contaBancariaIdDestino,
                            decoration: InputDecoration(
                              labelText: 'Conta Bancária de Destino *',
                              prefixIcon: const Icon(Icons.account_balance),
                              border: const OutlineInputBorder(),
                              helperText: _contasDisponiveis.isEmpty
                                  ? 'Nenhuma conta bancária ativa cadastrada'
                                  : 'O saldo desta conta será creditado imediatamente',
                              helperStyle: TextStyle(
                                color: _contasDisponiveis.isEmpty ? AppColors.warning : AppColors.textSecondaryLight,
                              ),
                            ),
                            items: _contasDisponiveis.map((conta) {
                              return DropdownMenuItem(
                                value: conta.id,
                                child: Row(
                                  children: [
                                    Text(
                                      conta.nomeConta,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${conta.bancoNome})',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: _contasDisponiveis.isEmpty
                                ? null
                                : (val) {
                                    setState(() => _contaBancariaIdDestino = val);
                                  },
                            validator: (v) {
                              if (_contasDisponiveis.isNotEmpty && (v == null || v.isEmpty)) {
                                return 'Selecione a conta bancária de destino.';
                              }
                              return null;
                            },
                          ),
                    const SizedBox(height: 12),

                    // Status de Liquidação (Já Recebido vs A Receber)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _jaRecebido ? 'Já Recebido (Efetivado no Caixa/Banco)' : 'A Receber (Pendente)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        _jaRecebido
                            ? 'O saldo bancário e as receitas serão creditados no mesmo instante.'
                            : 'Ficará registrado como previsão pendente até ser liquidado.',
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: _jaRecebido,
                      activeThumbColor: AppColors.success,
                      onChanged: (val) => setState(() => _jaRecebido = val),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Observações
                  TextFormField(
                    controller: _observacoesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Observações (Opcional)',
                      hintText: _isTransferencia
                          ? 'Motivo da transferência, código do TED/DOC, etc.'
                          : 'Número do comprovante PIX, detalhes do pagador, etc.',
                      prefixIcon: const Icon(Icons.notes_outlined),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botões de Ação
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: _isSalvando ? null : () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSalvando ? null : _submeter,
                          icon: _isSalvando
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Icon(
                                  _isTransferencia ? Icons.swap_horiz : Icons.check_circle_outline,
                                  size: 18,
                                ),
                          label: Text(
                            _isTransferencia ? 'Confirmar Transferência' : 'Salvar e Creditar Receita',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTransferencia ? AppColors.primary : AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
