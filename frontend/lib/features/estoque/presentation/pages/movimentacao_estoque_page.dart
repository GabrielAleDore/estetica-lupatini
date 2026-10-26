import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/estoque_cubit.dart';
import '../cubit/estoque_state.dart';
import '../widgets/nova_entrada_dialog.dart';
import '../widgets/nova_saida_dialog.dart';

class MovimentacaoEstoquePage extends StatelessWidget {
  final EstoqueCubit? cubit;

  const MovimentacaoEstoquePage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(
        value: cubit!,
        child: const _MovimentacaoEstoqueView(),
      );
    }
    return BlocProvider(
      create: (_) => EstoqueCubit(),
      child: const _MovimentacaoEstoqueView(),
    );
  }
}

class _MovimentacaoEstoqueView extends StatelessWidget {
  const _MovimentacaoEstoqueView();

  void _abrirNovaEntrada(BuildContext context) {
    final cubit = context.read<EstoqueCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovaEntradaDialog(
        produtos: cubit.state.produtos,
        onSalvar: ({required produtoId, required quantidade, custoUnitario, motivo, dataLancamento}) async {
          final ok = await cubit.registrarEntrada(
            produtoId: produtoId,
            quantidade: quantidade,
            custoUnitario: custoUnitario,
            motivo: motivo,
            dataLancamento: dataLancamento,
          );
          if (ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Entrada de estoque registrada com sucesso!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
          return ok;
        },
      ),
    );
  }

  void _abrirNovaSaida(BuildContext context) {
    final cubit = context.read<EstoqueCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovaSaidaDialog(
        produtos: cubit.state.produtos,
        onSalvar: ({required produtoId, required quantidade, required motivo, tipo = 'SAIDA', dataLancamento}) async {
          final ok = await cubit.registrarSaida(
            produtoId: produtoId,
            quantidade: quantidade,
            motivo: motivo,
            tipo: tipo,
            dataLancamento: dataLancamento,
          );
          if (ok && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Saída de estoque registrada com sucesso!'),
                backgroundColor: tipo == 'CONSUMO' ? AppColors.primary : AppColors.error,
              ),
            );
          }
          return ok;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EstoqueCubit, EstoqueState>(
      listener: (context, state) {
        if (state.status == EstoqueStatus.error && state.mensagemErro != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.mensagemErro!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.pjClinical.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.swap_horiz, color: AppColors.pjClinical, size: 26),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Movimentação de Estoque',
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                                  ),
                                  Text(
                                    'Rastreabilidade de entradas, saídas, compras e consumo de produtos',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Recarregar dados',
                          onPressed: () => context.read<EstoqueCubit>().carregarDados(),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _abrirNovaSaida(context),
                          icon: const Icon(Icons.remove_circle_outline, size: 18),
                          label: const Text('Nova Saída / Baixa'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _abrirNovaEntrada(context),
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text('Nova Entrada de Estoque'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Cards de Resumo no Topo
                _buildCardsResumo(context, state),
                const SizedBox(height: 20),

                // Barra de Filtros e Pesquisa
                _buildBarraFiltros(context, state),
                const SizedBox(height: 16),

                // Tabela de Movimentações em Linhas e Colunas
                Expanded(
                  child: _buildTabelaMovimentacoes(context, state),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardsResumo(BuildContext context, EstoqueState state) {
    final alertCount = state.produtosComEstoqueBaixo.length;
    return Row(
      children: [
        Expanded(
          child: _CardMetrica(
            titulo: 'Total Físico em Estoque',
            valor: '${state.totalItensEstoque.toStringAsFixed(0)} itens',
            subtitulo: '${state.produtos.length} produtos cadastrados',
            icone: Icons.inventory_2_outlined,
            cor: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _CardMetrica(
            titulo: 'Alertas de Reposição',
            valor: '$alertCount ${alertCount == 1 ? "produto" : "produtos"}',
            subtitulo: alertCount > 0 ? 'Estoque crítico ou zerado' : 'Todos os estoques em nível seguro',
            icone: Icons.warning_amber_rounded,
            cor: alertCount > 0 ? AppColors.warning : AppColors.success,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _CardMetrica(
            titulo: 'Entradas no Mês',
            valor: '+${state.totalEntradasMes.toStringAsFixed(0)} un',
            subtitulo: 'Reposições e compras do mês',
            icone: Icons.arrow_circle_up_outlined,
            cor: AppColors.success,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _CardMetrica(
            titulo: 'Saídas e Consumos',
            valor: '-${state.totalSaidasMes.toStringAsFixed(0)} un',
            subtitulo: 'Vendas, perdas e procedimentos',
            icone: Icons.arrow_circle_down_outlined,
            cor: AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildBarraFiltros(BuildContext context, EstoqueState state) {
    final cubit = context.read<EstoqueCubit>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Campo de Busca
          Expanded(
            flex: 3,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por produto, SKU ou motivo...',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: cubit.mudarFiltroBusca,
            ),
          ),
          const SizedBox(width: 12),

          // Filtro por Tipo de Movimentação
          Expanded(
            flex: 2,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tipo',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: state.filtroTipo,
                  items: const [
                    DropdownMenuItem(value: 'TODOS', child: Text('Todos os Tipos')),
                    DropdownMenuItem(value: 'ENTRADA', child: Text('Entradas (Compras)')),
                    DropdownMenuItem(value: 'SAIDA', child: Text('Saídas / Baixas')),
                    DropdownMenuItem(value: 'CONSUMO', child: Text('Consumo Clínico')),
                  ],
                  onChanged: (val) {
                    if (val != null) cubit.mudarFiltroTipo(val);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Filtro por Período
          Expanded(
            flex: 2,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Período',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: state.filtroPeriodo,
                  items: const [
                    DropdownMenuItem(value: 'MES_ATUAL', child: Text('Mês Atual')),
                    DropdownMenuItem(value: '7_DIAS', child: Text('Últimos 7 Dias')),
                    DropdownMenuItem(value: 'HOJE', child: Text('Hoje')),
                    DropdownMenuItem(value: 'TODOS', child: Text('Todo o Histórico')),
                  ],
                  onChanged: (val) {
                    if (val != null) cubit.mudarFiltroPeriodo(val);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Filtro por Produto Específico
          Expanded(
            flex: 3,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Produto',
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: state.filtroProdutoId ?? 'TODOS',
                  items: [
                    const DropdownMenuItem(value: 'TODOS', child: Text('Todos os Produtos')),
                    ...state.produtos.map(
                      (p) => DropdownMenuItem(
                        value: p['id'] as String,
                        child: Text(p['nome'] as String, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: cubit.mudarFiltroProduto,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabelaMovimentacoes(BuildContext context, EstoqueState state) {
    if (state.status == EstoqueStatus.loading && state.movimentacoes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final lista = state.movimentacoesFiltradas;

    if (lista.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Nenhuma movimentação de estoque encontrada.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
              ),
              const SizedBox(height: 6),
              const Text(
                'Lance uma nova entrada ou realize uma venda no PDV para ver o histórico.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
              ),
            ],
          ),
        ),
      );
    }

    final df = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Cabeçalho da Tabela
            Container(
              color: AppColors.surfaceLight,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('DATA / HORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryLight))),
                  Expanded(flex: 3, child: Text('PRODUTO / SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryLight))),
                  Expanded(flex: 2, child: Text('TIPO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryLight))),
                  Expanded(flex: 2, child: Text('QUANTIDADE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryLight))),
                  Expanded(flex: 2, child: Text('SALDO (ANT ➔ POST)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryLight))),
                  Expanded(flex: 3, child: Text('MOTIVO / OBSERVAÇÃO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryLight))),
                  Expanded(flex: 2, child: Text('ORIGEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondaryLight))),
                ],
              ),
            ),
            const Divider(height: 1),

            // Linhas de dados
            Expanded(
              child: ListView.separated(
                itemCount: lista.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final mov = lista[index];
                  final isEntrada = mov.tipo == 'ENTRADA';
                  final isConsumo = mov.tipo == 'CONSUMO';

                  Color badgeColor;
                  IconData badgeIcon;
                  String tipoLabel;

                  if (isEntrada) {
                    badgeColor = AppColors.success;
                    badgeIcon = Icons.arrow_upward;
                    tipoLabel = 'ENTRADA';
                  } else if (isConsumo) {
                    badgeColor = AppColors.primary;
                    badgeIcon = Icons.science_outlined;
                    tipoLabel = 'CONSUMO';
                  } else {
                    badgeColor = AppColors.error;
                    badgeIcon = Icons.arrow_downward;
                    tipoLabel = 'SAÍDA';
                  }

                  final qtdFormatada = mov.quantidade.toStringAsFixed(
                    mov.quantidade.truncateToDouble() == mov.quantidade ? 0 : 2,
                  );
                  final saldoAntFormatado = mov.saldoAnterior.toStringAsFixed(
                    mov.saldoAnterior.truncateToDouble() == mov.saldoAnterior ? 0 : 2,
                  );
                  final saldoPostFormatado = mov.saldoPosterior.toStringAsFixed(
                    mov.saldoPosterior.truncateToDouble() == mov.saldoPosterior ? 0 : 2,
                  );

                  final origem = mov.vendaId != null ? 'Venda PDV' : (mov.motivo?.contains('Saldo inicial') == true ? 'Implantação' : 'Lançamento Manual');

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        // Data e Hora
                        Expanded(
                          flex: 2,
                          child: Text(
                            df.format(mov.createdAt),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight),
                          ),
                        ),

                        // Produto e SKU
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mov.produtoNome,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimaryLight),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (mov.produtoSku != null && mov.produtoSku!.isNotEmpty)
                                Text(
                                  'SKU: ${mov.produtoSku}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight),
                                ),
                            ],
                          ),
                        ),

                        // Tipo
                        Expanded(
                          flex: 2,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(badgeIcon, size: 14, color: badgeColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    tipoLabel,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Quantidade
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${isEntrada ? "+" : "-"}$qtdFormatada ${mov.unidadeMedida}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isEntrada ? AppColors.success : (isConsumo ? AppColors.primary : AppColors.error),
                            ),
                          ),
                        ),

                        // Saldo Anterior ➔ Posterior
                        Expanded(
                          flex: 2,
                          child: Text(
                            '$saldoAntFormatado ➔ $saldoPostFormatado',
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimaryLight, fontWeight: FontWeight.w500),
                          ),
                        ),

                        // Motivo / Observação
                        Expanded(
                          flex: 3,
                          child: Text(
                            mov.motivo ?? '—',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),

                        // Origem
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              Icon(
                                mov.vendaId != null ? Icons.shopping_bag_outlined : Icons.person_outline,
                                size: 14,
                                color: AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                origem,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardMetrica extends StatelessWidget {
  final String titulo;
  final String valor;
  final String subtitulo;
  final IconData icone;
  final Color cor;

  const _CardMetrica({
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icone, color: cor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 11, color: cor, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
