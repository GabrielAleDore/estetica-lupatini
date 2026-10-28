import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';

class NovoPacoteDialog extends StatefulWidget {
  final String clienteId;
  final String clienteNome;
  final List<Map<String, dynamic>> servicos;
  final Future<bool> Function({
    required String clienteId,
    required String servicoId,
    required int quantidadeTotal,
    required double valorTotal,
    String? tituloPersonalizado,
    int? validadeMeses,
    String? observacoes,
  }) onSalvar;

  const NovoPacoteDialog({
    super.key,
    required this.clienteId,
    required this.clienteNome,
    required this.servicos,
    required this.onSalvar,
  });

  @override
  State<NovoPacoteDialog> createState() => _NovoPacoteDialogState();
}

class _NovoPacoteDialogState extends State<NovoPacoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  String? _servicoId;
  String? _servicoNome;
  final _qtdController = TextEditingController(text: '10');
  final _valorTotalController = TextEditingController();
  final _tituloController = TextEditingController();
  final _validadeController = TextEditingController(text: '6');
  final _obsController = TextEditingController();
  bool _salvando = false;

  @override
  void dispose() {
    _qtdController.dispose();
    _valorTotalController.dispose();
    _tituloController.dispose();
    _validadeController.dispose();
    _obsController.dispose();
    super.dispose();
  }

  void _aoSelecionarServico(String? id) {
    if (id == null) return;
    final serv = widget.servicos.firstWhere((s) => s['id'] == id, orElse: () => {});
    setState(() {
      _servicoId = id;
      _servicoNome = serv['nome']?.toString();
      final preco = (serv['preco'] as num?)?.toDouble() ?? 0.0;
      final qtd = int.tryParse(_qtdController.text) ?? 10;
      final total = preco * qtd;
      _valorTotalController.text = _currencyFormat.format(total).replaceAll('R\$', '').trim();
      _tituloController.text = 'Pacote ${qtd}x $_servicoNome';
    });
  }

  void _recalcularValorSugerido() {
    if (_servicoId == null) return;
    final serv = widget.servicos.firstWhere((s) => s['id'] == _servicoId, orElse: () => {});
    final preco = (serv['preco'] as num?)?.toDouble() ?? 0.0;
    final qtd = int.tryParse(_qtdController.text) ?? 1;
    final total = preco * qtd;
    _valorTotalController.text = _currencyFormat.format(total).replaceAll('R\$', '').trim();
    if (_servicoNome != null) {
      _tituloController.text = 'Pacote ${qtd}x $_servicoNome';
    }
  }

  Future<void> _submeter() async {
    if (!_formKey.currentState!.validate() || _servicoId == null) return;

    final qtd = int.tryParse(_qtdController.text) ?? 1;
    final valorStr = _valorTotalController.text.replaceAll('.', '').replaceAll(',', '.').trim();
    final valor = double.tryParse(valorStr) ?? 0.0;
    final validade = int.tryParse(_validadeController.text);

    setState(() => _salvando = true);
    final ok = await widget.onSalvar(
      clienteId: widget.clienteId,
      servicoId: _servicoId!,
      quantidadeTotal: qtd,
      valorTotal: valor,
      tituloPersonalizado: _tituloController.text.trim().isEmpty ? null : _tituloController.text.trim(),
      validadeMeses: validade,
      observacoes: _obsController.text.trim().isEmpty ? null : _obsController.text.trim(),
    );

    if (mounted) {
      setState(() => _salvando = false);
      if (ok) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.collections_bookmark_outlined, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Contratar Novo Pacote Clínico',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Paciente: ${widget.clienteNome}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Dropdown de Serviços
              DropdownButtonFormField<String>(
                initialValue: _servicoId,
                decoration: const InputDecoration(
                  labelText: 'Procedimento / Serviço Clínico *',
                  prefixIcon: Icon(Icons.spa_outlined),
                  border: OutlineInputBorder(),
                ),
                items: widget.servicos.map((s) {
                  final preco = (s['preco'] as num?)?.toDouble() ?? 0.0;
                  return DropdownMenuItem<String>(
                    value: s['id'].toString(),
                    child: Text('${s['nome']} (${_currencyFormat.format(preco)})'),
                  );
                }).toList(),
                onChanged: _aoSelecionarServico,
                validator: (val) => val == null ? 'Selecione um serviço' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  // Quantidade de Sessões
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _qtdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nº de Sessões *',
                        prefixIcon: Icon(Icons.repeat),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _recalcularValorSugerido(),
                      validator: (val) {
                        final n = int.tryParse(val ?? '');
                        if (n == null || n <= 0) return 'Mínimo 1';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Valor Total
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _valorTotalController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoedaInputFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Valor Total do Pacote (R\$) *',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => (val == null || val.isEmpty) ? 'Informe o valor' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Título Personalizado
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(
                  labelText: 'Identificação do Pacote (Opcional)',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _validadeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Validade (Meses)',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _obsController,
                      decoration: const InputDecoration(
                        labelText: 'Observações Internas',
                        prefixIcon: Icon(Icons.notes_outlined),
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
                    onPressed: _salvando ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _salvando ? null : _submeter,
                    icon: _salvando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_salvando ? 'Contratando...' : 'Confirmar Pacote'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
