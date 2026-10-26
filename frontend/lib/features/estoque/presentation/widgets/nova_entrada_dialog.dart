import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';

class NovaEntradaDialog extends StatefulWidget {
  final List<Map<String, dynamic>> produtos;
  final String? produtoIdInicial;
  final Future<bool> Function({
    required String produtoId,
    required double quantidade,
    double? custoUnitario,
    String? motivo,
    DateTime? dataLancamento,
  }) onSalvar;

  const NovaEntradaDialog({
    super.key,
    required this.produtos,
    this.produtoIdInicial,
    required this.onSalvar,
  });

  @override
  State<NovaEntradaDialog> createState() => _NovaEntradaDialogState();
}

class _NovaEntradaDialogState extends State<NovaEntradaDialog> {
  final _formKey = GlobalKey<FormState>();

  late String? _produtoId;
  final _quantidadeController = TextEditingController(text: '10');
  final _custoController = TextEditingController();
  final _motivoController = TextEditingController(text: 'Compra / Reposição de Fornecedor');
  bool _isSalvando = false;
  DateTime _dataLancamento = DateTime.now();

  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataLancamento,
      firstDate: DateTime(hoje.year - 5),
      lastDate: DateTime(hoje.year + 5),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) setState(() => _dataLancamento = picked);
  }

  @override
  void initState() {
    super.initState();
    _produtoId = widget.produtoIdInicial ?? (widget.produtos.isNotEmpty ? widget.produtos.first['id'] : null);
    _atualizarCustoSugerido();
  }

  void _atualizarCustoSugerido() {
    if (_produtoId == null) return;
    final prod = widget.produtos.firstWhere((p) => p['id'] == _produtoId, orElse: () => {});
    final custo = (prod['preco_custo'] as num?)?.toDouble() ?? 0.0;
    if (custo > 0) {
      _custoController.text = MoedaInputFormatter.formatar(custo);
    } else {
      _custoController.clear();
    }
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
        ? MoedaInputFormatter.parse(_custoController.text)
        : null;

    final sucesso = await widget.onSalvar(
      produtoId: _produtoId!,
      quantidade: qtd,
      custoUnitario: custo,
      motivo: _motivoController.text.trim(),
      dataLancamento: _dataLancamento,
    );

    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prodSelecionado = widget.produtos.firstWhere(
      (p) => p['id'] == _produtoId,
      orElse: () => {},
    );
    final saldoAtual = (prodSelecionado['quantidade_estoque'] as num?)?.toDouble() ?? 0.0;
    final unidade = prodSelecionado['unidade_medida']?.toString() ?? 'UN';

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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_shopping_cart, color: AppColors.success, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Entrada de Estoque / Compra',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Reposição de produtos e mercadorias',
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
                  isExpanded: true,
                  initialValue: _produtoId,
                  decoration: const InputDecoration(
                    labelText: 'Produto a Repor *',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: widget.produtos.map((p) {
                    final estoque = (p['quantidade_estoque'] as num?)?.toDouble() ?? 0.0;
                    final u = p['unidade_medida'] ?? 'UN';
                    return DropdownMenuItem<String>(
                      value: p['id'],
                      child: Text(
                        '${p['nome']} (Estoque: ${estoque.toStringAsFixed(estoque.truncateToDouble() == estoque ? 0 : 2)} $u)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _produtoId = val;
                      _atualizarCustoSugerido();
                    });
                  },
                  validator: (v) => v == null ? 'Selecione um produto' : null,
                ),

                if (_produtoId != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Saldo Físico Atual:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(
                          '${saldoAtual.toStringAsFixed(saldoAtual.truncateToDouble() == saldoAtual ? 0 : 2)} $unidade',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Quantidade e Custo Unitário
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _quantidadeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Quantidade Adicional ($unidade) *',
                          hintText: '10',
                          prefixIcon: const Icon(Icons.numbers),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                          if (n == null || n <= 0) return 'Qtd inválida';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: TextFormField(
                        controller: _custoController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          MoedaInputFormatter(),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Custo Unitário (R\$)',
                          hintText: '0,00',
                          prefixText: 'R\$ ',
                          prefixIcon: Icon(Icons.attach_money),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Data do Lançamento (retroativa ou futura)
                InkWell(
                  onTap: _selecionarData,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Data do Lançamento *',
                      prefixIcon: Icon(Icons.event),
                      suffixIcon: Icon(Icons.arrow_drop_down),
                      border: OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(_dataLancamento)),
                  ),
                ),
                const SizedBox(height: 14),

                // Motivo / Fornecedor / NF
                TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Fornecedor / NF',
                    hintText: 'Ex: Compra Distribuidora XYZ, NF 12345, Reposição',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 24),

                // Ações
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSalvando ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSalvando ? null : _submeter,
                      icon: _isSalvando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isSalvando ? 'Gravando Entrada...' : 'Confirmar Entrada'),
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
