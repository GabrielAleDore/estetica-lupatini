import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/responsive/responsive_layout.dart';
import '../../domain/models/produto_servico_item.dart';
import '../cubit/vendas_cubit.dart';
import '../cubit/vendas_state.dart';
import '../widgets/cart_summary_panel.dart';
import '../widgets/product_catalog_card.dart';

class PdvPage extends StatelessWidget {
  const PdvPage({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      context.read<VendasCubit>();
      return const _PdvView();
    } catch (_) {
      return BlocProvider(
        create: (_) => VendasCubit()..carregarDadosIniciais(),
        child: const _PdvView(),
      );
    }
  }
}

class _PdvView extends StatelessWidget {
  const _PdvView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Frente de Caixa (PDV) & Procedimentos'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<VendasCubit>().carregarDadosIniciais(),
          ),
        ],
      ),
      body: const ResponsiveLayout(
        desktop: _PdvDesktopLayout(),
        mobile: _PdvMobileLayout(),
      ),
    );
  }
}

class _PdvDesktopLayout extends StatelessWidget {
  const _PdvDesktopLayout();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Catálogo de Produtos e Procedimentos (Esquerda)
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CatalogSearchBar(),
                const SizedBox(height: 16),
                const _CatalogFilterChips(),
                const SizedBox(height: 16),
                Expanded(
                  child: BlocBuilder<VendasCubit, VendasState>(
                    builder: (context, state) {
                      if (state.status == VendasStatus.loading) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (state.status == VendasStatus.error && state.catalogo.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.error),
                              const SizedBox(height: 12),
                              const Text(
                                'Não foi possível carregar o catálogo',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                state.errorMessage ?? 'Verifique sua conexão com o Supabase.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => context.read<VendasCubit>().carregarDadosIniciais(),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Tentar Novamente'),
                              ),
                            ],
                          ),
                        );
                      }
                      if (state.itensFiltrados.isEmpty) {
                        return Center(
                          child: Text(
                            'Nenhum item encontrado no catálogo.',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        );
                      }
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: state.itensFiltrados.length,
                        itemBuilder: (context, index) {
                          final item = state.itensFiltrados[index];
                          return ProductCatalogCard(
                            item: item,
                            onAdd: () => context
                                .read<VendasCubit>()
                                .adicionarItemAoCarrinho(item),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Painel Fixo de Checkout / Carrinho (Direita)
          const Expanded(
            flex: 5,
            child: CartSummaryPanel(),
          ),
        ],
      ),
    );
  }
}

class _PdvMobileLayout extends StatelessWidget {
  const _PdvMobileLayout();

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const _CatalogSearchBar(),
              const SizedBox(height: 12),
              const _CatalogFilterChips(),
              const SizedBox(height: 12),
              Expanded(
                child: BlocBuilder<VendasCubit, VendasState>(
                  builder: (context, state) {
                    if (state.status == VendasStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.status == VendasStatus.error && state.catalogo.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            const Text(
                              'Falha de conexão',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              state.errorMessage ?? 'Verifique se a API está ativa.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => context.read<VendasCubit>().carregarDadosIniciais(),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reconectar'),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: state.itensFiltrados.length,
                      itemBuilder: (context, index) {
                        final item = state.itensFiltrados[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: ProductCatalogCard(
                            item: item,
                            onAdd: () => context
                                .read<VendasCubit>()
                                .adicionarItemAoCarrinho(item),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 70), // Espaço para a barra inferior
            ],
          ),
        ),
        // Barra Flutuante de Fechamento Mobile
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: BlocBuilder<VendasCubit, VendasState>(
            builder: (context, state) {
              if (state.itensCarrinho.isEmpty) return const SizedBox.shrink();

              return Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: AppColors.primary,
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => BlocProvider.value(
                        value: context.read<VendasCubit>(),
                        child: const FractionallySizedBox(
                          heightFactor: 0.85,
                          child: CartSummaryPanel(),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                            const SizedBox(width: 10),
                            Text(
                              '${state.totalItens.toInt()} itens no carrinho',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          currencyFormat.format(state.totalLiquido),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatalogSearchBar extends StatelessWidget {
  const _CatalogSearchBar();

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Buscar por procedimento, produto ou código de barras...',
        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => context.read<VendasCubit>().filtrarBusca(''),
        ),
      ),
      onChanged: (val) => context.read<VendasCubit>().filtrarBusca(val),
    );
  }
}

class _CatalogFilterChips extends StatelessWidget {
  const _CatalogFilterChips();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VendasCubit, VendasState>(
      builder: (context, state) {
        final cubit = context.read<VendasCubit>();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Todos'),
                selected: state.filtroTipo == null,
                onSelected: (_) => cubit.filtrarTipo(null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Procedimentos'),
                selected: state.filtroTipo == TipoCatalogo.servico,
                onSelected: (_) => cubit.filtrarTipo(TipoCatalogo.servico),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Produtos & Home Care'),
                selected: state.filtroTipo == TipoCatalogo.produto,
                onSelected: (_) => cubit.filtrarTipo(TipoCatalogo.produto),
              ),
            ],
          ),
        );
      },
    );
  }
}
