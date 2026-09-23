import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
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
  String? _contaBancariaIdSelecionada;
  bool _jaRecebido = true; // true = EFETIVADO, false = PENDENTE
  bool _isSalvando = false;
  bool _carregandoContas = false;

  List<ContaBancariaModel> _contasDisponiveis = [];

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
      // Tenta obter do Cubit se já estiver no contexto
      try {
        final cubit = context.read<ContasBancariasCubit>();
        final contas = cubit.state.contas;
        if (contas.isNotEmpty) {
          _atualizarListaContas(contas);
          setState(() => _carregandoContas = false);
          return;
        }
      } catch (_) {}

      // Fallback para o repositório direto
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
    _ajustarContaSelecionada();
  }

  void _ajustarContaSelecionada() {
    final contasDoEscopo = _contasDisponiveis.where((c) => c.escopo == _escopo).toList();
    if (contasDoEscopo.isNotEmpty) {
      if (_contaBancariaIdSelecionada == null ||
          !contasDoEscopo.any((c) => c.id == _contaBancariaIdSelecionada)) {
        _contaBancariaIdSelecionada = contasDoEscopo.first.id;
      }
    } else {
      _contaBancariaIdSelecionada = null;
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

    setState(() => _isSalvando = true);

    final valor = double.parse(_valorController.text.trim().replaceAll(',', '.'));
    final status = _jaRecebido ? 'EFETIVADO' : 'PENDENTE';

    final dados = {
      'descricao': _descricaoController.text.trim(),
      'tipo': 'RECEITA',
      'escopo': _escopo,
      'categoria_nome': _categoria,
      'valor': valor,
      'valor_total': valor,
      'data_transacao': _dataController.text.trim(),
      'data_competencia': _dataController.text.trim(),
      'status': status,
      'conta_bancaria_id': _contaBancariaIdSelecionada,
      'observacoes': _observacoesController.text.trim().isEmpty ? null : _observacoesController.text.trim(),
      'origem': 'MANUAL',
    };

    final sucesso = await widget.onSalvar(dados);
    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPj = _escopo == 'PJ';
    final contasDoEscopo = _contasDisponiveis.where((c) => c.escopo == _escopo).toList();

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
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.add_card,
                                color: AppColors.success,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nova Entrada / Receita Avulsa',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Registro de PIX, aportes de sócios e receitas extras',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                    overflow: TextOverflow.ellipsis,
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

                  // Seletor de Escopo: PJ vs PF
                  const Text(
                    'Regime / Destinação Financeira *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.business,
                            size: 16,
                            color: isPj ? Colors.white : AppColors.pjClinical,
                          ),
                          label: Text(
                            'PJ • Clínica',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPj ? Colors.white : AppColors.pjClinical,
                            ),
                          ),
                          selected: isPj,
                          selectedColor: AppColors.pjClinical,
                          backgroundColor: Colors.white,
                          side: BorderSide(color: AppColors.pjClinical.withValues(alpha: 0.5)),
                          onSelected: (_) {
                            setState(() {
                              _escopo = 'PJ';
                              _ajustarContaSelecionada();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          avatar: Icon(
                            Icons.person,
                            size: 16,
                            color: !isPj ? Colors.white : const Color(0xFFB07D4F),
                          ),
                          label: Text(
                            'PF • Pessoal Sócios',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !isPj ? Colors.white : const Color(0xFFB07D4F),
                            ),
                          ),
                          selected: !isPj,
                          selectedColor: const Color(0xFFB07D4F),
                          backgroundColor: Colors.white,
                          side: BorderSide(color: const Color(0xFFB07D4F).withValues(alpha: 0.5)),
                          onSelected: (_) {
                            setState(() {
                              _escopo = 'PF';
                              _ajustarContaSelecionada();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Descrição
                  TextFormField(
                    controller: _descricaoController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição da Receita *',
                      hintText: 'Ex: Recebimento PIX - Consultoria, Aporte Inicial',
                      prefixIcon: Icon(Icons.description_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição da receita.' : null,
                  ),
                  const SizedBox(height: 14),

                  // Valor e Data
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _valorController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Valor Recebido (R\$) *',
                            hintText: '0,00',
                            prefixIcon: Icon(Icons.attach_money),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                            if (n == null || n <= 0) return 'Valor inválido';
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
                              decoration: const InputDecoration(
                                labelText: 'Data do Recebimento *',
                                prefixIcon: Icon(Icons.calendar_today_outlined),
                                suffixIcon: Icon(Icons.arrow_drop_down),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Categoria da Receita
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

                  // Conta Bancária de Destino
                  _carregandoContas
                      ? const LinearProgressIndicator()
                      : DropdownButtonFormField<String>(
                          initialValue: _contaBancariaIdSelecionada,
                          decoration: InputDecoration(
                            labelText: 'Conta Bancária de Destino *',
                            prefixIcon: const Icon(Icons.account_balance),
                            border: const OutlineInputBorder(),
                            helperText: contasDoEscopo.isEmpty
                                ? 'Nenhuma conta $_escopo ativa cadastrada'
                                : 'O saldo desta conta será creditado imediatamente',
                            helperStyle: TextStyle(
                              color: contasDoEscopo.isEmpty ? AppColors.warning : AppColors.textSecondaryLight,
                            ),
                          ),
                          items: contasDoEscopo.map((conta) {
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
                          onChanged: contasDoEscopo.isEmpty
                              ? null
                              : (val) {
                                  setState(() => _contaBancariaIdSelecionada = val);
                                },
                          validator: (v) {
                            if (contasDoEscopo.isNotEmpty && (v == null || v.isEmpty)) {
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

                  // Observações
                  TextFormField(
                    controller: _observacoesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Observações (Opcional)',
                      hintText: 'Número do comprovante PIX, detalhes do pagador, etc.',
                      prefixIcon: Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(),
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
                              : const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text(
                            'Salvar e Creditar Receita',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
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
