import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';
import '../../domain/models/conta_bancaria_model.dart';

class ContaBancariaDialog extends StatefulWidget {
  final ContaBancariaModel? contaExistente;
  final Future<bool> Function(ContaBancariaModel conta) onSalvar;

  const ContaBancariaDialog({
    super.key,
    this.contaExistente,
    required this.onSalvar,
  });

  @override
  State<ContaBancariaDialog> createState() => _ContaBancariaDialogState();
}

class _ContaBancariaDialogState extends State<ContaBancariaDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomeContaController;
  late TextEditingController _agenciaController;
  late TextEditingController _numeroContaController;
  late TextEditingController _chavePixController;
  late TextEditingController _saldoInicialController;
  late TextEditingController _saldoAtualController;

  late String _bancoSelecionado;
  late String _escopoSelecionado; // 'PJ' ou 'PF'
  late String _tipoContaSelecionado; // 'CORRENTE', 'POUPANCA', 'INVESTIMENTO'
  late String _corSelecionada;
  late bool _ativo;
  bool _isSalvando = false;

  static const List<String> _bancosDisponiveis = [
    'Nubank',
    'Itaú Unibanco',
    'Bradesco',
    'Banco do Brasil',
    'Santander',
    'Banco Inter',
    'Caixa Econômica Federal',
    'C6 Bank',
    'Sicoob',
    'Sicredi',
    'BTG Pactual',
    'Mercado Pago',
    'PagBank',
    'Outro',
  ];

  static const List<String> _coresPaleta = [
    '#8D5B4C', // Terracota Lupatini
    '#820AD1', // Roxo Nubank
    '#EC7000', // Laranja Itaú
    '#CC092F', // Vermelho Bradesco
    '#0038A8', // Azul BB
    '#FF7A00', // Laranja Inter
    '#2E7D32', // Verde
    '#00897B', // Ciano / Teal
    '#455A64', // Cinza Azulado
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.contaExistente;
    _nomeContaController = TextEditingController(text: c?.nomeConta ?? '');
    _agenciaController = TextEditingController(text: c?.agencia ?? '');
    _numeroContaController = TextEditingController(text: c?.numeroConta ?? '');
    _chavePixController = TextEditingController(text: c?.chavePix ?? '');

    final sInicial = c?.saldoInicial ?? 0.0;
    final sAtual = c != null ? ((c.saldoAtual == 0.0 && c.saldoInicial > 0.0) ? c.saldoInicial : c.saldoAtual) : 0.0;

    _saldoInicialController = TextEditingController(
      text: sInicial > 0 ? MoedaInputFormatter.formatar(sInicial) : (c != null ? '0,00' : ''),
    );
    _saldoAtualController = TextEditingController(
      text: sAtual > 0 ? MoedaInputFormatter.formatar(sAtual) : (c != null ? '0,00' : ''),
    );

    _bancoSelecionado = c != null && _bancosDisponiveis.contains(c.bancoNome)
        ? c.bancoNome
        : (c != null ? 'Outro' : 'Nubank');

    _escopoSelecionado = c?.escopo ?? 'PJ';
    _tipoContaSelecionado = c?.tipoConta ?? 'CORRENTE';
    _corSelecionada = c?.corIdentificadora ?? '#8D5B4C';
    _ativo = c?.ativo ?? true;
  }

  @override
  void dispose() {
    _nomeContaController.dispose();
    _agenciaController.dispose();
    _numeroContaController.dispose();
    _chavePixController.dispose();
    _saldoInicialController.dispose();
    _saldoAtualController.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  double _parseMonetario(String text) {
    return MoedaInputFormatter.parse(text);
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSalvando = true);

    final saldoInicial = _parseMonetario(_saldoInicialController.text);
    double saldoAtualFinal;

    if (widget.contaExistente == null) {
      saldoAtualFinal = saldoInicial;
    } else {
      final saldoAtualDigitado = _parseMonetario(_saldoAtualController.text);
      final antigoSaldoInicial = widget.contaExistente!.saldoInicial;
      final antigoSaldoAtual = widget.contaExistente!.saldoAtual;

      if (saldoAtualDigitado != antigoSaldoAtual) {
        saldoAtualFinal = saldoAtualDigitado;
      } else if (saldoInicial != antigoSaldoInicial) {
        if (antigoSaldoAtual == 0.0 || antigoSaldoAtual == antigoSaldoInicial) {
          saldoAtualFinal = saldoInicial;
        } else {
          saldoAtualFinal = antigoSaldoAtual + (saldoInicial - antigoSaldoInicial);
        }
      } else {
        saldoAtualFinal = (antigoSaldoAtual == 0.0 && saldoInicial > 0.0) ? saldoInicial : antigoSaldoAtual;
      }
    }

    final conta = ContaBancariaModel(
      id: widget.contaExistente?.id ?? '',
      nomeConta: _nomeContaController.text.trim(),
      bancoNome: _bancoSelecionado,
      agencia: _agenciaController.text.trim().isEmpty ? null : _agenciaController.text.trim(),
      numeroConta: _numeroContaController.text.trim().isEmpty ? null : _numeroContaController.text.trim(),
      tipoConta: _tipoContaSelecionado,
      escopo: _escopoSelecionado,
      chavePix: _chavePixController.text.trim().isEmpty ? null : _chavePixController.text.trim(),
      saldoInicial: saldoInicial,
      saldoAtual: saldoAtualFinal,
      corIdentificadora: _corSelecionada,
      ativo: _ativo,
    );

    final sucesso = await widget.onSalvar(conta);
    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.contaExistente != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _parseColor(_corSelecionada).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.account_balance, color: _parseColor(_corSelecionada), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdicao ? 'Editar Conta Bancária' : 'Nova Conta Bancária',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isEdicao
                                  ? 'Atualize os dados e parâmetros da conta'
                                  : 'Cadastre contas da clínica (PJ) ou sócios (PF)',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Form Scrollable Body
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Seletor de Escopo (PJ vs PF)
                        // Nome Identificador
                        TextFormField(
                          controller: _nomeContaController,
                          decoration: const InputDecoration(
                            labelText: 'Nome Identificador da Conta *',
                            hintText: 'Ex: Nubank Principal, Itaú Operacional, Caixa Espécie',
                            prefixIcon: Icon(Icons.label_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome da conta.' : null,
                        ),
                        const SizedBox(height: 14),

                        // Instituição Financeira e Tipo de Conta
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _bancoSelecionado,
                                decoration: const InputDecoration(
                                  labelText: 'Instituição Financeira *',
                                  prefixIcon: Icon(Icons.account_balance),
                                  border: OutlineInputBorder(),
                                ),
                                items: _bancosDisponiveis.map((banco) {
                                  return DropdownMenuItem(value: banco, child: Text(banco));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _bancoSelecionado = val;
                                      // Sugere cor de acordo com o banco se ainda não definida customizada
                                      if (val == 'Nubank') _corSelecionada = '#820AD1';
                                      if (val.contains('Itaú')) _corSelecionada = '#EC7000';
                                      if (val == 'Bradesco') _corSelecionada = '#CC092F';
                                      if (val == 'Banco Inter') _corSelecionada = '#FF7A00';
                                      if (val == 'Banco do Brasil') _corSelecionada = '#0038A8';
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _tipoContaSelecionado,
                                decoration: const InputDecoration(
                                  labelText: 'Tipo de Conta',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'CORRENTE', child: Text('Corrente')),
                                  DropdownMenuItem(value: 'POUPANCA', child: Text('Poupança')),
                                  DropdownMenuItem(value: 'INVESTIMENTO', child: Text('Aplicação')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setState(() => _tipoContaSelecionado = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Agência e Conta
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _agenciaController,
                                decoration: const InputDecoration(
                                  labelText: 'Agência (Opcional)',
                                  hintText: '0001',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _numeroContaController,
                                decoration: const InputDecoration(
                                  labelText: 'Número da Conta (Opcional)',
                                  hintText: '123456-7',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Chave PIX e Saldo Inicial / Atual
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _chavePixController,
                                decoration: const InputDecoration(
                                  labelText: 'Chave PIX (Opcional)',
                                  hintText: 'CNPJ, CPF, E-mail, Celular ou Aleatória',
                                  prefixIcon: Icon(Icons.pix_outlined),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _saldoInicialController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  MoedaInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Saldo Inicial R\$',
                                  hintText: '0,00',
                                  prefixText: 'R\$ ',
                                  border: OutlineInputBorder(),
                                ),
                                onChanged: (val) {
                                  if (isEdicao && _parseMonetario(_saldoAtualController.text) == 0.0) {
                                    _saldoAtualController.text = val;
                                  }
                                },
                              ),
                            ),
                            if (isEdicao) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _saldoAtualController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    MoedaInputFormatter(),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Saldo Atual R\$ *',
                                    hintText: '0,00',
                                    prefixText: 'R\$ ',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Informe o saldo atual.';
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Seleção de Cor Identificadora
                        const Text(
                          'Cor do Cartão / Identificador Visual:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _coresPaleta.map((corHex) {
                            final cor = _parseColor(corHex);
                            final isSelecionada = _corSelecionada.toUpperCase() == corHex.toUpperCase();
                            return InkWell(
                              onTap: () => setState(() => _corSelecionada = corHex),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: cor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelecionada ? Colors.black87 : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    if (isSelecionada)
                                      BoxShadow(
                                        color: cor.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 2,
                                      ),
                                  ],
                                ),
                                child: isSelecionada
                                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Switch Ativo
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Conta Ativa para Movimentações', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Contas inativas não aparecem nos seletores de baixa do caixa'),
                          value: _ativo,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _ativo = val),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 24),
                // Botões de Ação
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSalvando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSalvando ? null : _submeter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      ),
                      icon: _isSalvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSalvando ? 'Salvando...' : (isEdicao ? 'Atualizar Conta' : 'Salvar Conta'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
