import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class NovaDespesaCartaoDialog extends StatefulWidget {
  final List<Map<String, dynamic>> cartoes;
  final String? cartaoIdInicial;
  final Future<bool> Function(Map<String, dynamic> dados) onSalvar;

  const NovaDespesaCartaoDialog({
    super.key,
    required this.cartoes,
    this.cartaoIdInicial,
    required this.onSalvar,
  });

  @override
  State<NovaDespesaCartaoDialog> createState() => _NovaDespesaCartaoDialogState();
}

class _NovaDespesaCartaoDialogState extends State<NovaDespesaCartaoDialog> {
  final _formKey = GlobalKey<FormState>();
  final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  late String? _cartaoIdSelecionado;
  final _descricaoController = TextEditingController();
  final _valorController = TextEditingController();
  final _dataCompraController = TextEditingController(
    text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
  );
  int _parcelas = 1;
  bool _isSalvando = false;

  @override
  void initState() {
    super.initState();
    _cartaoIdSelecionado = widget.cartaoIdInicial ?? (widget.cartoes.isNotEmpty ? widget.cartoes.first['id'] : null);
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    _dataCompraController.dispose();
    super.dispose();
  }

  double get _valorTotal {
    final v = double.tryParse(_valorController.text.trim().replaceAll(',', '.')) ?? 0.0;
    return v > 0 ? v : 0.0;
  }

  double get _valorParcela => _valorTotal / _parcelas;

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cartaoIdSelecionado == null) return;

    final cartao = widget.cartoes.firstWhere((c) => c['id'] == _cartaoIdSelecionado);

    setState(() => _isSalvando = true);

    final dados = {
      'descricao': _descricaoController.text.trim(),
      'escopo': cartao['escopo'],
      'cartao_id': _cartaoIdSelecionado,
      'valor_total': _valorTotal,
      'parcelas': _parcelas,
      'data_compra': _dataCompraController.text.trim(),
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
        constraints: const BoxConstraints(maxWidth: 540),
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
                            color: AppColors.pfPersonal.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_card_outlined, color: AppColors.pfPersonal),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lançar Compra / Dívida no Cartão',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Cálculo automático de parcelas e faturas futuras',
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
                // Seletor de Cartão
                DropdownButtonFormField<String>(
                  initialValue: _cartaoIdSelecionado,
                  decoration: const InputDecoration(
                    labelText: 'Selecione o Cartão *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.credit_card),
                  ),
                  items: widget.cartoes.map((c) {
                    final escopo = c['escopo'] == 'PJ' ? 'Clínica (PJ)' : 'Sócios (PF)';
                    return DropdownMenuItem<String>(
                      value: c['id'],
                      child: Text('${c['nome']}  [$escopo]'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _cartaoIdSelecionado = v),
                  validator: (v) => v == null ? 'Selecione um cartão.' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descricaoController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição da Compra *',
                    hintText: 'Ex: Aparelho Laser Lavieen, Reforma da Recepção, etc.',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a descrição da compra.' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _valorController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Valor Total (R\$) *',
                          hintText: '1500.00',
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
                      child: DropdownButtonFormField<int>(
                        initialValue: _parcelas,
                        decoration: const InputDecoration(
                          labelText: 'Parcelas',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(48, (i) => i + 1).map((p) {
                          return DropdownMenuItem<int>(
                            value: p,
                            child: Text(p == 1 ? 'À vista (1x)' : '${p}x'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _parcelas = v ?? 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _dataCompraController,
                  decoration: const InputDecoration(
                    labelText: 'Data da Compra (AAAA-MM-DD)',
                    hintText: '2026-09-14',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Card de Pré-visualização da Parcela
                if (_valorTotal > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Projeção das Parcelas:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          _parcelas == 1
                              ? currencyFormat.format(_valorTotal)
                              : '$_parcelas x de aprox. ${currencyFormat.format(_valorParcela)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 14),
                        ),
                      ],
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
                          : const Text('Lançar Compra', style: TextStyle(fontWeight: FontWeight.bold)),
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
