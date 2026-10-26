import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';

class NovoCartaoDialog extends StatefulWidget {
  final Map<String, dynamic>? cartaoParaEditar;
  final Future<bool> Function(Map<String, dynamic> dados) onSalvar;

  const NovoCartaoDialog({
    super.key,
    this.cartaoParaEditar,
    required this.onSalvar,
  });

  @override
  State<NovoCartaoDialog> createState() => _NovoCartaoDialogState();
}

class _NovoCartaoDialogState extends State<NovoCartaoDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeController;
  late final TextEditingController _fechamentoController;
  late final TextEditingController _vencimentoController;
  late final TextEditingController _limiteController;
  late String _escopo;
  late bool _ativo;
  bool _isSalvando = false;

  bool get _isEdicao => widget.cartaoParaEditar != null;

  @override
  void initState() {
    super.initState();
    final c = widget.cartaoParaEditar;
    _nomeController = TextEditingController(text: c?['nome'] ?? '');
    _fechamentoController = TextEditingController(text: c?['dia_fechamento']?.toString() ?? '18');
    _vencimentoController = TextEditingController(text: c?['dia_vencimento']?.toString() ?? '25');

    final limiteVal = (c?['limite'] as num?)?.toDouble() ?? 10000.0;
    _limiteController = TextEditingController(
      text: NumberFormat.currency(locale: 'pt_BR', symbol: '').format(limiteVal).trim(),
    );
    _escopo = c?['escopo']?.toString() ?? 'PJ';
    _ativo = c?['ativo'] ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _fechamentoController.dispose();
    _vencimentoController.dispose();
    _limiteController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSalvando = true);

    final dados = {
      'nome': _nomeController.text.trim(),
      'escopo': _escopo,
      'dia_fechamento': int.parse(_fechamentoController.text.trim()),
      'dia_vencimento': int.parse(_vencimentoController.text.trim()),
      'limite': MoedaInputFormatter.parse(_limiteController.text),
      'ativo': _ativo,
    };

    final sucesso = await widget.onSalvar(dados);
    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.pjClinical.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _isEdicao ? Icons.edit_note : Icons.credit_card,
                            color: AppColors.pjClinical,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isEdicao ? 'Editar Cartão' : 'Cadastrar Novo Cartão / Conta',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                TextFormField(
                  controller: _nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Identificação do Cartão *',
                    hintText: 'Ex: Nubank Black PJ Clínica',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do cartão.' : null,
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fechamentoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dia Fechamento *',
                          hintText: 'Ex: 18',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1 || n > 31) return 'Dia inválido (1-31)';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _vencimentoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Dia Vencimento *',
                          hintText: 'Ex: 25',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = int.tryParse(v ?? '');
                          if (n == null || n < 1 || n > 31) return 'Dia inválido (1-31)';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _limiteController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    MoedaInputFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Limite Total (R\$)',
                    hintText: '0,00',
                    prefixIcon: Icon(Icons.attach_money),
                    prefixText: 'R\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                // Escopo (PJ / PF)
                Row(
                  children: [
                    const Text('Regime: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('PJ (Clínica)'),
                      selected: _escopo == 'PJ',
                      onSelected: (val) => setState(() => _escopo = 'PJ'),
                      selectedColor: AppColors.pjClinical.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('PF (Dra. Camila)'),
                      selected: _escopo == 'PF',
                      onSelected: (val) => setState(() => _escopo = 'PF'),
                      selectedColor: AppColors.pfPersonal.withValues(alpha: 0.2),
                    ),
                  ],
                ),

                if (_isEdicao) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Cartão Ativo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Habilita este cartão para novos lançamentos', style: TextStyle(fontSize: 11)),
                    value: _ativo,
                    activeThumbColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _ativo = val),
                  ),
                ],

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSalvando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSalvando ? null : _submeter,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSalvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              _isEdicao ? 'Salvar Alterações' : 'Salvar Cartão',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
