import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class EntradaEstoqueDialog extends StatefulWidget {
  final List<Map<String, dynamic>> produtos;
  final String? produtoIdInicial;
  final Future<bool> Function({
    required String produtoId,
    required double quantidade,
    double? custoUnitario,
    String? motivo,
  }) onSalvar;

  const EntradaEstoqueDialog({
    super.key,
    required this.produtos,
    this.produtoIdInicial,
    required this.onSalvar,
  });

  @override
  State<EntradaEstoqueDialog> createState() => _EntradaEstoqueDialogState();
}

class _EntradaEstoqueDialogState extends State<EntradaEstoqueDialog> {
  final _formKey = GlobalKey<FormState>();

  late String? _produtoId;
  final _quantidadeController = TextEditingController(text: '10.0');
  final _custoController = TextEditingController();
  final _motivoController = TextEditingController(text: 'Compra / Reposição de Fornecedor');
  bool _isSalvando = false;

  @override
  void initState() {
    super.initState();
    _produtoId = widget.produtoIdInicial ?? (widget.produtos.isNotEmpty ? widget.produtos.first['id'] : null);
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    _custoController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;
    if (_produtoId == null) return;

    setState(() => _isSalvando = true);

    final qtd = double.parse(_quantidadeController.text.trim().replaceAll(',', '.'));
    final custo = _custoController.text.trim().isNotEmpty
        ? double.tryParse(_custoController.text.trim().replaceAll(',', '.'))
        : null;

    final sucesso = await widget.onSalvar(
      produtoId: _produtoId!,
      quantidade: qtd,
      custoUnitario: custo,
      motivo: _motivoController.text.trim(),
    );

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
                          child: const Icon(Icons.inventory_2_outlined, color: AppColors.pjClinical),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Entrada de Estoque / Compra',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Reposição de produtos e insumos clínicos',
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

                // Seletor de Produto
                DropdownButtonFormField<String>(
                  initialValue: _produtoId,
                  decoration: const InputDecoration(
                    labelText: 'Produto / Insumo *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.medication),
                  ),
                  items: widget.produtos.map((p) {
                    final estoque = p['quantidade_estoque'];
                    final un = p['unidade_medida'] ?? 'UN';
                    return DropdownMenuItem<String>(
                      value: p['id'],
                      child: Text('${p['nome']} (Atual: $estoque $un)'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _produtoId = v),
                  validator: (v) => v == null ? 'Selecione um produto.' : null,
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _quantidadeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantidade Comprada *',
                          hintText: 'Ex: 10.0',
                          prefixIcon: Icon(Icons.add_shopping_cart),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                          if (n == null || n <= 0) return 'Qtd. inválida';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _custoController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Novo Custo Unit. (R\$)',
                          hintText: 'Ex: 45.00',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Nota / Fornecedor',
                    hintText: 'Ex: NF 4580 Distribuidora Dermato',
                    prefixIcon: Icon(Icons.note_alt_outlined),
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
                          : const Text('Confirmar Entrada', style: TextStyle(fontWeight: FontWeight.bold)),
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
