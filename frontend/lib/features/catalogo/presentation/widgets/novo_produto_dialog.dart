import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class NovoProdutoDialog extends StatefulWidget {
  final Map<String, dynamic>? produtoParaEditar;
  final List<Map<String, dynamic>> categorias;
  final Future<bool> Function(Map<String, dynamic> dados, {String? produtoId}) onSalvar;

  const NovoProdutoDialog({
    super.key,
    this.produtoParaEditar,
    required this.categorias,
    required this.onSalvar,
  });

  @override
  State<NovoProdutoDialog> createState() => _NovoProdutoDialogState();
}

class _NovoProdutoDialogState extends State<NovoProdutoDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nomeController;
  late final TextEditingController _skuController;
  late final TextEditingController _precoCustoController;
  late final TextEditingController _precoVendaController;
  late final TextEditingController _estoqueController;
  late final TextEditingController _estoqueMinimoController;

  String? _categoriaId;
  String _unidadeMedida = 'UN';
  bool _permiteVenda = true;
  bool _isSalvando = false;
  String? _erroInline;

  @override
  void initState() {
    super.initState();
    final p = widget.produtoParaEditar;
    _nomeController = TextEditingController(text: p?['nome'] ?? '');
    _skuController = TextEditingController(text: p?['codigo_barras'] ?? '');
    _precoCustoController = TextEditingController(
      text: p != null ? (double.tryParse(p['preco_custo']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2) : '0.00',
    );
    _precoVendaController = TextEditingController(
      text: p != null ? (double.tryParse(p['preco_venda']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2) : '50.00',
    );
    _estoqueController = TextEditingController(
      text: p != null ? (double.tryParse(p['quantidade_estoque']?.toString() ?? '0') ?? 0.0).toString() : '10',
    );
    _estoqueMinimoController = TextEditingController(
      text: p != null ? (double.tryParse(p['estoque_minimo']?.toString() ?? '5') ?? 5.0).toString() : '5',
    );
    _categoriaId = p?['categoria_id'];
    _unidadeMedida = p?['unidade_medida'] ?? 'UN';
    _permiteVenda = p?['permite_venda'] ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _skuController.dispose();
    _precoCustoController.dispose();
    _precoVendaController.dispose();
    _estoqueController.dispose();
    _estoqueMinimoController.dispose();
    super.dispose();
  }

  Future<void> _submeter() async {
    setState(() => _erroInline = null);
    if (!_formKey.currentState!.validate()) return;

    final custo = double.tryParse(_precoCustoController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final venda = double.tryParse(_precoVendaController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final estoque = double.tryParse(_estoqueController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final estoqueMin = double.tryParse(_estoqueMinimoController.text.trim().replaceAll(',', '.')) ?? 5.0;
    final sku = _skuController.text.trim();

    setState(() => _isSalvando = true);

    final dados = {
      'nome': _nomeController.text.trim(),
      'codigo_barras': sku.isEmpty ? null : sku,
      'categoria_id': _categoriaId,
      'preco_custo': custo,
      'preco_venda': venda,
      'quantidade_estoque': estoque,
      'estoque_minimo': estoqueMin,
      'unidade_medida': _unidadeMedida,
      'permite_venda': _permiteVenda,
    };

    final sucesso = await widget.onSalvar(
      dados,
      produtoId: widget.produtoParaEditar?['id']?.toString(),
    );

    if (mounted) {
      setState(() => _isSalvando = false);
      if (sucesso) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _erroInline = 'Erro ao salvar produto. Verifique os campos e se o SKU já existe.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.produtoParaEditar != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
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
                            isEdicao ? Icons.edit_note : Icons.inventory_2_outlined,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdicao ? 'Editar Produto / Insumo' : 'Novo Produto ou Insumo',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const Text(
                              'Cadastre produtos de revenda ou insumos técnicos com controle de estoque',
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
                        // Nome do Produto
                        TextFormField(
                          controller: _nomeController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do Produto ou Insumo *',
                            hintText: 'Ex: Protetor Solar Facial FPS 70 Toque Seco',
                            prefixIcon: Icon(Icons.shopping_bag_outlined),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome do produto.' : null,
                        ),
                        const SizedBox(height: 16),

                        // SKU / Código de Barras & Categoria
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _skuController,
                                decoration: const InputDecoration(
                                  labelText: 'Código de Barras / SKU (Opcional)',
                                  hintText: '7891234567890',
                                  prefixIcon: Icon(Icons.qr_code_scanner),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
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
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Preço de Custo & Preço de Venda
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _precoCustoController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Preço de Custo (R\$) *',
                                  hintText: '25.00',
                                  prefixIcon: Icon(Icons.money_off_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || double.tryParse(v.replaceAll(',', '.')) == null)
                                    ? 'Custo inválido.'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _precoVendaController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Preço de Venda (R\$) *',
                                  hintText: '69.90',
                                  prefixIcon: Icon(Icons.attach_money),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || double.tryParse(v.replaceAll(',', '.')) == null)
                                    ? 'Preço de venda inválido.'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Estoque Inicial, Mínimo & Unidade de Medida
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _estoqueController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Estoque Atual *',
                                  hintText: '10',
                                  prefixIcon: Icon(Icons.warehouse_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || double.tryParse(v.replaceAll(',', '.')) == null)
                                    ? 'Estoque inválido.'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _estoqueMinimoController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  labelText: 'Estoque Mínimo *',
                                  hintText: '5',
                                  prefixIcon: Icon(Icons.warning_amber_outlined),
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) => (v == null || double.tryParse(v.replaceAll(',', '.')) == null)
                                    ? 'Mínimo inválido.'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _unidadeMedida,
                                decoration: const InputDecoration(
                                  labelText: 'Unidade',
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'UN', child: Text('UN (Unidade)')),
                                  DropdownMenuItem(value: 'ML', child: Text('ML (Mililitro)')),
                                  DropdownMenuItem(value: 'AMPOLA', child: Text('AMPOLA')),
                                  DropdownMenuItem(value: 'CX', child: Text('CX (Caixa)')),
                                  DropdownMenuItem(value: 'PAR', child: Text('PAR')),
                                  DropdownMenuItem(value: 'G', child: Text('G (Grama)')),
                                ],
                                onChanged: (v) => setState(() => _unidadeMedida = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Flag: Permite Venda Direta no PDV vs Insumo Interno
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _permiteVenda
                                ? AppColors.success.withValues(alpha: 0.08)
                                : AppColors.pfPersonal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _permiteVenda
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : AppColors.pfPersonal.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _permiteVenda ? Icons.storefront : Icons.science_outlined,
                                color: _permiteVenda ? AppColors.success : AppColors.pfPersonal,
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _permiteVenda
                                          ? 'Produto de Revenda (Disponível no PDV)'
                                          : 'Insumo Interno Técnico (Apenas Consumo em Procedimentos)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: _permiteVenda ? AppColors.success : AppColors.pfPersonal,
                                      ),
                                    ),
                                    Text(
                                      _permiteVenda
                                          ? 'Aparece no catálogo do Frente de Caixa para venda direta aos pacientes.'
                                          : 'Não aparece no PDV para venda direta; usado exclusivamente em fichas técnicas/BOM.',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _permiteVenda,
                                activeThumbColor: AppColors.success,
                                onChanged: (v) => setState(() => _permiteVenda = v),
                              ),
                            ],
                          ),
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
                        _isSalvando ? 'Salvando...' : (isEdicao ? 'Salvar Alterações' : 'Cadastrar Produto'),
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
