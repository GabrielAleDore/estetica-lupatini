import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class NovoCartaoDialog extends StatefulWidget {
  final Future<bool> Function(Map<String, dynamic> dados) onSalvar;

  const NovoCartaoDialog({super.key, required this.onSalvar});

  @override
  State<NovoCartaoDialog> createState() => _NovoCartaoDialogState();
}

class _NovoCartaoDialogState extends State<NovoCartaoDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _fechamentoController = TextEditingController(text: '18');
  final _vencimentoController = TextEditingController(text: '25');
  final _limiteController = TextEditingController(text: '10000.00');
  String _escopo = 'PJ';
  bool _isSalvando = false;

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
      'limite': double.tryParse(_limiteController.text.trim().replaceAll(',', '.')) ?? 0.0,
      'ativo': true,
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
                          child: const Icon(Icons.credit_card, color: AppColors.pjClinical),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Cadastrar Novo Cartão / Conta',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
                DropdownButtonFormField<String>(
                  initialValue: _escopo,
                  decoration: const InputDecoration(
                    labelText: 'Regime / Escopo *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.shield_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'PJ',
                      child: Text('Clínica (PJ) - Despesas Operacionais e Equipamentos'),
                    ),
                    DropdownMenuItem(
                      value: 'PF',
                      child: Text('Pessoal dos Sócios (PF) - Gastos Particulares'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _escopo = v!),
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
                  decoration: const InputDecoration(
                    labelText: 'Limite Total (R\$)',
                    hintText: '10000.00',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
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
                          : const Text('Salvar Cartão', style: TextStyle(fontWeight: FontWeight.bold)),
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
