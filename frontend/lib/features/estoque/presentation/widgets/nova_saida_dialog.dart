import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

class NovaSaidaDialog extends StatefulWidget {
  final List<Map<String, dynamic>> produtos;
  final String? produtoIdInicial;
  final Future<bool> Function({
    required String produtoId,
    required double quantidade,
    required String motivo,
    String tipo,
    DateTime? dataLancamento,
  }) onSalvar;

  const NovaSaidaDialog({
    super.key,
    required this.produtos,
    this.produtoIdInicial,
    required this.onSalvar,
  });

  @override
  State<NovaSaidaDialog> createState() => _NovaSaidaDialogState();
}

class _NovaSaidaDialogState extends State<NovaSaidaDialog> {
  final _formKey = GlobalKey<FormState>();

  late String? _produtoId;
  String _tipo = 'SAIDA'; // 'SAIDA' ou 'CONSUMO'
  final _quantidadeController = TextEditingController(text: '1');
  final _motivoController = TextEditingController(text: 'Uso Interno / Consumo Clínico');
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
  }

  @override
  void dispose() {
    _quantidadeController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate()) return;
    if (_produtoId == null) return;

    setState(() => _isSalvando = true);

    final qtd = double.parse(_quantidadeController.text.trim().replaceAll(',', '.'));

    final sucesso = await widget.onSalvar(
      produtoId: _produtoId!,
      quantidade: qtd,
      motivo: _motivoController.text.trim(),
      tipo: _tipo,
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
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.remove_shopping_cart, color: AppColors.error, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saída de Estoque / Baixa',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Consumo interno, avarias ou perdas de produtos',
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

                // Seletor de Tipo de Saída
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        avatar: Icon(Icons.science_outlined, size: 16, color: _tipo == 'CONSUMO' ? Colors.white : AppColors.primary),
                        label: const Text('Consumo em Cabine'),
                        selected: _tipo == 'CONSUMO',
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _tipo == 'CONSUMO' ? Colors.white : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _tipo = 'CONSUMO';
                              _motivoController.text = 'Uso interno em procedimento';
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        avatar: Icon(Icons.delete_outline, size: 16, color: _tipo == 'SAIDA' ? Colors.white : AppColors.error),
                        label: const Text('Avaria / Descarte'),
                        selected: _tipo == 'SAIDA',
                        selectedColor: AppColors.error,
                        labelStyle: TextStyle(
                          color: _tipo == 'SAIDA' ? Colors.white : AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _tipo = 'SAIDA';
                              _motivoController.text = 'Avaria / Produto Vencido';
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Seletor de Produto
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _produtoId,
                  decoration: const InputDecoration(
                    labelText: 'Produto a Baixar *',
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
                    setState(() => _produtoId = val);
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
                        const Text('Saldo Atual Disponível:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text(
                          '${saldoAtual.toStringAsFixed(saldoAtual.truncateToDouble() == saldoAtual ? 0 : 2)} $unidade',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: saldoAtual <= 0 ? AppColors.error : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Quantidade
                TextFormField(
                  controller: _quantidadeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Quantidade a Retirar ($unidade) *',
                    hintText: '1',
                    prefixIcon: const Icon(Icons.remove_circle_outline),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                    if (n == null || n <= 0) return 'Quantidade inválida';
                    if (n > saldoAtual) {
                      return 'Quantidade maior que o saldo disponível ($saldoAtual $unidade).';
                    }
                    return null;
                  },
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

                // Motivo / Justificativa
                TextFormField(
                  controller: _motivoController,
                  decoration: const InputDecoration(
                    labelText: 'Motivo / Justificativa da Saída *',
                    hintText: 'Ex: Frasco quebrado, Paciente X - Cabine 2, Vencimento',
                    prefixIcon: Icon(Icons.edit_note),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe a justificativa' : null,
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
                        backgroundColor: _tipo == 'CONSUMO' ? AppColors.primary : AppColors.error,
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
                      label: Text(_isSalvando ? 'Gravando Saída...' : 'Confirmar Saída'),
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
