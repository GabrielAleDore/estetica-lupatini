import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';

class LancamentoAvulsoDialog extends StatefulWidget {
  final Future<bool> Function(Map<String, dynamic> dados) onSalvar;

  const LancamentoAvulsoDialog({super.key, required this.onSalvar});

  @override
  State<LancamentoAvulsoDialog> createState() => _LancamentoAvulsoDialogState();
}

class _LancamentoAvulsoDialogState extends State<LancamentoAvulsoDialog> {
  final _formKey = GlobalKey<FormState>();

  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _dataController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );

  String _tipo = 'SAIDA'; // 'SAIDA' (Despesa) ou 'ENTRADA' (Receita)
  final String _escopo = 'PJ'; // Default retrocompatível com schema
  bool _isSalvando = false;

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSalvando = true);

    final valor = MoedaInputFormatter.parse(_valorController.text);
    final dados = {
      'descricao': _descricaoController.text.trim(),
      'tipo': _tipo,
      'escopo': _escopo,
      'valor_total': valor,
      'data_competencia': _dataController.text.trim(),
    };

    final sucesso = await widget.onSalvar(dados);
    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaida = _tipo == 'SAIDA';

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
                            color: (isSaida ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isSaida ? Icons.arrow_circle_down : Icons.arrow_circle_up,
                            color: isSaida ? AppColors.error : AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lançamento Avulso (Caixa / Banco)',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Despesa ou Receita à vista (PIX, TED ou Dinheiro)',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
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

                // Seletor Tipo (Despesa vs Receita)
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.remove, size: 16, color: AppColors.error),
                            SizedBox(width: 6),
                            Text('Despesa / Saída', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        selected: _tipo == 'SAIDA',
                        selectedColor: AppColors.error.withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _tipo = 'SAIDA'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 16, color: AppColors.success),
                            SizedBox(width: 6),
                            Text('Receita / Entrada', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        selected: _tipo == 'ENTRADA',
                        selectedColor: AppColors.success.withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _tipo = 'ENTRADA'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),


                TextFormField(
                  controller: _descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição do Lançamento *',
                    hintText: 'Ex: Aluguel da Clínica, Conta de Energia, Café para Recepção',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição.' : null,
                ),
                const SizedBox(height: 14),

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
                          labelText: 'Valor Total (R\$) *',
                          hintText: '0,00',
                          prefixIcon: Icon(Icons.attach_money),
                          prefixText: 'R\$ ',
                          border: OutlineInputBorder(),
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
                      child: TextFormField(
                        controller: _dataController,
                        decoration: const InputDecoration(
                          labelText: 'Data (AAAA-MM-DD)',
                          hintText: '2026-09-14',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
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
                        backgroundColor: isSaida ? AppColors.error : AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSalvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Salvar Lançamento', style: TextStyle(fontWeight: FontWeight.bold)),
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
