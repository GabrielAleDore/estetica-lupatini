import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/catalogo_cubit.dart';
import '../cubit/catalogo_state.dart';
import '../widgets/novo_servico_dialog.dart';
import '../widgets/novo_produto_dialog.dart';

class CatalogoPage extends StatelessWidget {
  final CatalogoCubit? cubit;
  const CatalogoPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: const _CatalogoView());
    }
    try {
      context.read<CatalogoCubit>();
      return const _CatalogoView();
    } catch (_) {
      return BlocProvider(
        create: (_) => CatalogoCubit()..carregarTudo(),
        child: const _CatalogoView(),
      );
    }
  }
}

class _CatalogoView extends StatefulWidget {
  const _CatalogoView();

  @override
  State<_CatalogoView> createState() => _CatalogoViewState();
}

class _CatalogoViewState extends State<_CatalogoView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _abrirModalNovoServico(BuildContext context, {Map<String, dynamic>? servico}) {
    final cubit = context.read<CatalogoCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovoServicoDialog(
        servicoParaEditar: servico,
        categorias: cubit.state.categorias.where((c) => c['tipo'] == 'SERVICO').toList(),
        produtosInsumos: cubit.state.produtos,
        onSalvar: (dados, {servicoId}) => cubit.salvarServico(dados, servicoId: servicoId),
      ),
    );
  }

  void _abrirModalNovoProduto(BuildContext context, {Map<String, dynamic>? produto}) {
    final cubit = context.read<CatalogoCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovoProdutoDialog(
        produtoParaEditar: produto,
        categorias: cubit.state.categorias.where((c) => c['tipo'] == 'PRODUTO').toList(),
        onSalvar: (dados, {produtoId}) => cubit.salvarProduto(dados, produtoId: produtoId),
      ),
    );
  }

  void _confirmarExclusao(BuildContext context, {required String titulo, required String mensagem, required VoidCallback onConfirmar}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(mensagem),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirmar();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Produtos & Procedimentos'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Catálogo',
            onPressed: () => context.read<CatalogoCubit>().carregarTudo(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.spa_outlined), text: 'Procedimentos & Serviços'),
            Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Produtos & Insumos'),
          ],
        ),
      ),
      body: BlocConsumer<CatalogoCubit, CatalogoState>(
        listener: (context, state) {
          if (state.status == CatalogoStatus.success && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.success, content: Text(state.successMessage!)),
            );
          } else if (state.status == CatalogoStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.error, content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<CatalogoCubit>();

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Top Search & Filter Bar
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por nome, SKU ou procedimento...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    cubit.filtrarPorBusca('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onSubmitted: (val) => cubit.filtrarPorBusca(val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (_tabController.index == 0) {
                          _abrirModalNovoServico(context);
                        } else {
                          _abrirModalNovoProduto(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        _tabController.index == 0 ? 'NOVO PROCEDIMENTO' : 'NOVO PRODUTO',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // ABA 1: SERVIÇOS
                      _buildServicosTab(context, cubit, state),

                      // ABA 2: PRODUTOS
                      _buildProdutosTab(context, cubit, state),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicosTab(BuildContext context, CatalogoCubit cubit, CatalogoState state) {
    if (state.status == CatalogoStatus.loading && state.servicos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.servicos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.spa_outlined, size: 64, color: AppColors.textSecondaryLight),
            const SizedBox(height: 16),
            const Text('Nenhum procedimento cadastrado ou encontrado.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _abrirModalNovoServico(context),
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar Primeiro Procedimento'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.servicos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = state.servicos[index];
        final preco = double.tryParse(s['preco']?.toString() ?? '0') ?? 0.0;
        final duracao = s['duracao_minutos'] ?? 60;
        final ativo = s['ativo'] ?? true;
        final insumos = (s['insumos'] as List?) ?? [];
        final catNome = s['categoria_nome'] ?? 'Geral';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: ativo ? AppColors.primaryLight.withValues(alpha: 0.3) : Colors.grey.shade200,
                  child: Icon(Icons.spa, color: ativo ? AppColors.primaryDark : Colors.grey),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (s['codigo_sequencial'] != null)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Text(
                                '#${s['codigo_sequencial']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                              ),
                            ),
                          Text(
                            s['nome'] ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              decoration: ativo ? null : TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(catNome, style: const TextStyle(fontSize: 11, color: AppColors.primaryDark)),
                          ),
                          const SizedBox(width: 8),
                          if (!ativo)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('INATIVO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Duração: $duracao min  •  ${insumos.isEmpty ? "Sem insumos técnicos vinculados" : "${insumos.length} insumos vinculados (baixa no estoque)"}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
                Text(
                  _currencyFormat.format(preco),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  tooltip: 'Editar Procedimento',
                  onPressed: () => _abrirModalNovoServico(context, servico: s),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Desativar Procedimento',
                  onPressed: () => _confirmarExclusao(
                    context,
                    titulo: 'Desativar Procedimento',
                    mensagem: 'Deseja desativar "${s['nome']}" do catálogo do PDV?',
                    onConfirmar: () => cubit.excluirServico(s['id'].toString()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProdutosTab(BuildContext context, CatalogoCubit cubit, CatalogoState state) {
    if (state.status == CatalogoStatus.loading && state.produtos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.produtos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textSecondaryLight),
            const SizedBox(height: 16),
            const Text('Nenhum produto cadastrado no estoque.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _abrirModalNovoProduto(context),
              icon: const Icon(Icons.add),
              label: const Text('Cadastrar Primeiro Produto'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.produtos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final p = state.produtos[index];
        final estoque = double.tryParse(p['quantidade_estoque']?.toString() ?? '0') ?? 0.0;
        final estoqueMin = double.tryParse(p['estoque_minimo']?.toString() ?? '0') ?? 0.0;
        final precoVenda = double.tryParse(p['preco_venda']?.toString() ?? '0') ?? 0.0;
        final precoCusto = double.tryParse(p['preco_custo']?.toString() ?? '0') ?? 0.0;
        final permiteVenda = p['permite_venda'] ?? true;
        final unidade = p['unidade_medida'] ?? 'UN';
        final sku = p['codigo_barras'];

        final isCritico = estoque <= 0;
        final isBaixo = estoque <= estoqueMin;

        Color badgeEstoqueCor = AppColors.success;
        String badgeEstoqueTexto = 'Estoque OK ($estoque $unidade)';
        if (isCritico) {
          badgeEstoqueCor = AppColors.error;
          badgeEstoqueTexto = 'ESTOQUE ZERADO ($estoque $unidade)';
        } else if (isBaixo) {
          badgeEstoqueCor = AppColors.warning;
          badgeEstoqueTexto = 'ESTOQUE BAIXO ($estoque $unidade - Mín: $estoqueMin)';
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isCritico ? AppColors.error.withValues(alpha: 0.5) : AppColors.borderLight),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: permiteVenda
                      ? AppColors.primaryLight.withValues(alpha: 0.3)
                      : AppColors.pfPersonal.withValues(alpha: 0.2),
                  child: Icon(
                    permiteVenda ? Icons.storefront : Icons.science_outlined,
                    color: permiteVenda ? AppColors.primaryDark : AppColors.pfPersonal,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (p['codigo_sequencial'] != null)
                            Container(
                              margin: const EdgeInsets.only(right: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Text(
                                '#${p['codigo_sequencial']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondaryLight),
                              ),
                            ),
                          Text(
                            p['nome'] ?? '',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          // Badge Revenda vs Insumo
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: permiteVenda
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : AppColors.pfPersonal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              permiteVenda ? 'REVENDA' : 'INSUMO TÉCNICO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: permiteVenda ? AppColors.success : AppColors.pfPersonal,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Badge Status Estoque
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeEstoqueCor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badgeEstoqueTexto,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isBaixo && !isCritico ? Colors.orange.shade900 : badgeEstoqueCor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'SKU: ${sku ?? "N/A"}  •  Custo: ${_currencyFormat.format(precoCusto)}  •  Preço Venda: ${_currencyFormat.format(precoVenda)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(precoVenda),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primaryDark),
                    ),
                    Text(
                      'Saldo: $estoque $unidade',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isBaixo ? AppColors.error : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  tooltip: 'Editar Produto',
                  onPressed: () => _abrirModalNovoProduto(context, produto: p),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Excluir/Desativar Produto',
                  onPressed: () => _confirmarExclusao(
                    context,
                    titulo: 'Excluir Produto',
                    mensagem: 'Deseja remover ou desativar "${p['nome']}" do inventário?',
                    onConfirmar: () => cubit.excluirProduto(p['id'].toString()),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
