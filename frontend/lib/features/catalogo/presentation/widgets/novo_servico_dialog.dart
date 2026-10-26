import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/moeda_input_formatter.dart';

class NovoServicoDialog extends StatefulWidget {
  final Map<String, dynamic>? servicoParaEditar;
  final List<Map<String, dynamic>> categorias;
  final List<Map<String, dynamic>> produtosInsumos;
  final Future<bool> Function(Map<String, dynamic> dados, {String? servicoId}) onSalvar;

  const NovoServicoDialog({
    super.key,
    this.servicoParaEditar,
    required this.categorias,
    required this.produtosInsumos,
    required this.onSalvar,
  });

  @override
  State<NovoServicoDialog> createState() => _NovoServicoDialogState();
}

class _NovoServicoDialogState extends State<NovoServicoDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeController;
  late final TextEditingController _duracaoController;
  late final TextEditingController _precoController;
  String? _categoriaId;
  bool _ativo = true;
  bool _isSalvando = false;
  String? _erroInline;

  // Lista dinâmica de insumos técnicos vinculados (BOM)
  final List<Map<String, dynamic>> _insumosSelecionados = [];

  @override
  void initState() {
    super.initState();
    final s = widget.servicoParaEditar;
    _nomeController = TextEditingController(text: s?['nome'] ?? '');
    _duracaoController = TextEditingController(text: (s?['duracao_minutos'] ?? 60).toString());
    _precoController = TextEditingController(
      text: MoedaInputFormatter.formatar(double.tryParse(s?['preco']?.toString() ?? '') ?? 150.0),
    );
    _categoriaId = s?['categoria_id'];
    _ativo = s?['ativo'] ?? true;

    if (s != null && s['insumos'] != null) {
      final lista = s['insumos'] as List;
      for (final item in lista) {
        _insumosSelecionados.add({
          'produto_id': item['produto_id'],
          'quantidade_consumo': TextEditingController(
            text: (double.tryParse(item['quantidade_consumo']?.toString() ?? '1') ?? 1.0).toString(),
          ),
        });
      }
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _duracaoController.dispose();
    _precoController.dispose();
    for (final item in _insumosSelecionados) {
      if (item['quantidade_consumo'] is TextEditingController) {
        (item['quantidade_consumo'] as TextEditingController).dispose();
      }
    }
    super.dispose();
  }

  void _adicionarInsumo() {
    if (widget.produtosInsumos.isEmpty) return;
    setState(() {
      _insumosSelecionados.add({
        'produto_id': widget.produtosInsumos.first['id'],
        'quantidade_consumo': TextEditingController(text: '1.0'),
      });
    });
  }

  void _removerInsumo(int index) {
    setState(() {
      final item = _insumosSelecionados.removeAt(index);
      if (item['quantidade_consumo'] is TextEditingController) {
        (item['quantidade_consumo'] as TextEditingController).dispose();
      }
    });
  }

  Future<void> _submeter() async {
    setState(() => _erroInline = null);
    if (!_formKey.currentState!.validate()) return;

    final preco = MoedaInputFormatter.parse(_precoController.text);
    final duracao = int.tryParse(_duracaoController.text.trim()) ?? 60;

    final insumosPayload = <Map<String, dynamic>>[];
    for (final item in _insumosSelecionados) {
      final pid = item['produto_id'];
      final ctrl = item['quantidade_consumo'] as TextEditingController;
      final qtd = double.tryParse(ctrl.text.trim().replaceAll(',', '.')) ?? 1.0;
      if (pid != null && qtd > 0) {
        insumosPayload.add({
          'produto_id': pid,
          'quantidade_consumo': qtd,
        });
      }
    }

    setState(() => _isSalvando = true);

    final dados = {
      'nome': _nomeController.text.trim(),
      'categoria_id': _categoriaId,
      'duracao_minutos': duracao,
      'preco': preco,
      'ativo': _ativo,
      'insumos': insumosPayload,
    };

    final sucesso = await widget.onSalvar(
      dados,
      servicoId: widget.servicoParaEditar?['id']?.toString(),
    );

    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _erroInline = 'Erro ao salvar procedimento. Verifique os campos e tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.servicoParaEditar != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isEdicao ? Icons.edit_note : Icons.spa,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdicao ? 'Editar Procedimento' : 'Novo Procedimento / Serviço',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Configure preço, tempo estimado e insumos técnicos gastos',
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

                if (_erroInline != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text(_erroInline!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nome do Procedimento
                        TextFormField(
                          controller: _nomeController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do Procedimento *',
                            hintText: 'Ex: Toxina Botulínica - Terço Superior',
                            prefixIcon: Icon(Icons.medical_services_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do procedimento.' : null,
                        ),
                        const SizedBox(height: 16),

                        // Categoria & Duração
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: _categoriaId,
                                decoration: const InputDecoration(
                                  labelText: 'Categoria',
                                  prefixIcon: Icon(Icons.category_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Sem Categoria')),
                                  ...widget.categorias.map(
                                    (cat) => DropdownMenuItem(
                                      value: cat['id'].toString(),
                                      child: Text(cat['nome'] ?? ''),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() => _categoriaId = v),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _duracaoController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Duração (min)',
                                  hintText: '60',
                                  prefixIcon: Icon(Icons.timer_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Inválido' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Preço Base & Toggle Ativo
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _precoController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  MoedaInputFormatter(),
                                ],
                                decoration: const InputDecoration(
                                  labelText: 'Preço Base (R\$) *',
                                  hintText: '0,00',
                                  prefixIcon: Icon(Icons.attach_money),
                                  prefixText: 'R\$ ',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || MoedaInputFormatter.parse(v) <= 0)
                                    ? 'Informe um preço válido.'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppColors.borderLight),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Text('Ativo no PDV:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Switch(
                                    value: _ativo,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (v) => setState(() => _ativo = v),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Insumos Técnicos / BOM
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Insumos Técnicos Gastos (Baixa Automática no Estoque)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryDark),
                                ),
                                Text(
                                  'Ao vender este procedimento no PDV, estes materiais serão deduzidos do inventário',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: _adicionarInsumo,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Adicionar Insumo'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        if (_insumosSelecionados.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: const Center(
                              child: Text(
                                'Nenhum insumo vinculado a este procedimento.\n(Opcional: vincule seringas, ampolas, descartáveis, etc.)',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _insumosSelecionados.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _insumosSelecionados[index];
                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.borderLight),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: DropdownButtonFormField<String>(
                                        initialValue: item['produto_id'],
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Insumo / Material',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                        items: widget.produtosInsumos.map((prod) {
                                          return DropdownMenuItem(
                                            value: prod['id'].toString(),
                                            child: Text(
                                              '${prod['nome']} (${prod['unidade_medida'] ?? 'UN'})',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() => item['produto_id'] = val);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: item['quantidade_consumo'],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Qtd.',
                                          isDense: true,
                                          border: OutlineInputBorder(),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                      onPressed: () => _removerInsumo(index),
                                      tooltip: 'Remover insumo',
                                    ),
                                  ],
                                ),
                              );
                            },
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
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      icon: _isSalvando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSalvando ? 'Salvando...' : (isEdicao ? 'Salvar Alterações' : 'Cadastrar Procedimento'),
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
