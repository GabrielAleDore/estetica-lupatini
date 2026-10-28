import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../contas_bancarias/presentation/cubit/contas_bancarias_cubit.dart';
import '../cubit/vendas_cubit.dart';
import '../cubit/vendas_state.dart';
import '../../domain/models/produto_servico_item.dart';
import '../../../pacotes/presentation/widgets/gerenciar_pacotes_cliente_dialog.dart';

class CartSummaryPanel extends StatelessWidget {
  const CartSummaryPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return BlocConsumer<VendasCubit, VendasState>(
      listener: (context, state) {
        if (state.status == VendasStatus.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                'Venda finalizada com sucesso! ID: ${state.vendaConcluidaId?.substring(0, 8) ?? ""}',
              ),
            ),
          );
        } else if (state.status == VendasStatus.error && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(state.errorMessage!),
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<VendasCubit>();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho do Carrinho
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Comanda / Atendimento',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  if (state.itensCarrinho.isNotEmpty)
                    TextButton.icon(
                      onPressed: cubit.limparCarrinho,
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                      label: const Text('Limpar', style: TextStyle(color: AppColors.error, fontSize: 13)),
                    ),
                ],
              ),
              const Divider(height: 24),

              // Seleção de Cliente / Paciente
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: state.clienteSelecionado != null
                        ? AppColors.primary
                        : AppColors.borderLight,
                    width: state.clienteSelecionado != null ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 20,
                      color: state.clienteSelecionado != null
                          ? AppColors.primary
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          hint: const Text(
                            'Selecionar Cliente / Paciente',
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                          ),
                          value: state.clienteSelecionado?.id,
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'Cliente Avulso (Sem cadastro)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            ...state.clientes.map(
                              (cli) => DropdownMenuItem<String?>(
                                value: cli.id,
                                child: Text(
                                  '${cli.nome}${cli.isFidelizada ? ' ⭐ VIP (${cli.descontoFidelidadePadrao.toStringAsFixed(0)}%)' : ''} (${cli.telefone})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: cli.isFidelizada ? FontWeight.bold : FontWeight.w500,
                                    color: cli.isFidelizada ? Colors.amber.shade900 : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (clienteId) {
                            if (clienteId == null) {
                              cubit.selecionarCliente(null);
                            } else {
                              final cliente = state.clientes.firstWhere((c) => c.id == clienteId);
                              cubit.selecionarCliente(cliente);
                            }
                          },
                        ),
                      ),
                    ),
                    if (state.clienteSelecionado != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: AppColors.textSecondaryLight),
                        onPressed: () => cubit.selecionarCliente(null),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Remover cliente',
                      ),
                  ],
                ),
              ),
              if (state.clienteSelecionado?.isFidelizada == true) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, size: 16, color: Colors.amber),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Cliente VIP! Desconto fidelidade de ${state.clienteSelecionado!.descontoFidelidadePadrao.toStringAsFixed(0)}% sugerido e aplicado automaticamente nos itens.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (state.clienteSelecionado != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    final servicos = state.catalogo
                        .where((i) => i.tipo == TipoCatalogo.servico)
                        .map((s) => {'id': s.id, 'nome': s.nome, 'preco': s.preco})
                        .toList();

                    showDialog(
                      context: context,
                      builder: (_) => GerenciarPacotesClienteDialog(
                        clienteId: state.clienteSelecionado!.id,
                        clienteNome: state.clienteSelecionado!.nome,
                        servicos: servicos,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.collections_bookmark_outlined, size: 16, color: AppColors.primary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Carteira de Pacotes & Sessões',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Lista de Itens no Carrinho
              Expanded(
                child: state.itensCarrinho.isEmpty
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.remove_shopping_cart_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum item selecionado',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Clique nos produtos ou procedimentos ao lado',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: state.itensCarrinho.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = state.itensCarrinho[index];
                          return Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (item.item.codigoSequencial != null)
                                          Container(
                                            margin: const EdgeInsets.only(right: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.borderLight),
                                            ),
                                            child: Text(
                                              '#${item.item.codigoSequencial}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: AppColors.textSecondaryLight),
                                            ),
                                          ),
                                        if (item.tipoDesconto == 'PROMOCIONAL')
                                          Container(
                                            margin: const EdgeInsets.only(right: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('PROMO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.deepOrange)),
                                          )
                                        else if (item.tipoDesconto == 'FIDELIDADE')
                                          Container(
                                            margin: const EdgeInsets.only(right: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4)),
                                            child: const Text('VIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.amber)),
                                          ),
                                        Expanded(
                                          child: Text(
                                            item.item.nome,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    if (item.valorDesconto > 0)
                                      Row(
                                        children: [
                                          Text(
                                            '${currencyFormat.format(item.precoOriginal ?? item.item.preco)} ',
                                            style: const TextStyle(fontSize: 11, decoration: TextDecoration.lineThrough, color: Colors.grey),
                                          ),
                                          Text(
                                            '${currencyFormat.format(item.precoUnitario)} un.',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        '${currencyFormat.format(item.precoUnitario)} un.',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                      ),
                                  ],
                                ),
                              ),
                              // Controles de Quantidade
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                                    onPressed: () => cubit.atualizarQuantidade(
                                      item.id,
                                      item.quantidade - 1.0,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                    child: Text(
                                      item.quantidade.toStringAsFixed(0),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, size: 20),
                                    onPressed: () => cubit.atualizarQuantidade(
                                      item.id,
                                      item.quantidade + 1.0,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Text(
                                currencyFormat.format(item.subtotal),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ],
                          );
                        },
                      ),
              ),

              const Divider(height: 24),

              // Condição de Pagamento (À Vista vs A Prazo / Fiado)
              const Text(
                'Condição de Pagamento',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 14),
                          SizedBox(width: 6),
                          Text('Pagamento Imediato', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      selected: state.statusPagamento == 'EFETIVADO',
                      selectedColor: AppColors.success.withValues(alpha: 0.15),
                      onSelected: (selected) {
                        if (selected) {
                          cubit.selecionarStatusPagamento('EFETIVADO');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.schedule, size: 14),
                          SizedBox(width: 6),
                          Text('Pagar Depois (Fiado)', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      selected: state.statusPagamento == 'PENDENTE',
                      selectedColor: Colors.amber.withValues(alpha: 0.25),
                      onSelected: (selected) {
                        if (selected) {
                          // Padrão: 15 dias para acertar
                          final previsao = DateTime.now().add(const Duration(days: 15)).toIso8601String().substring(0, 10);
                          cubit.selecionarStatusPagamento('PENDENTE', dataPrevista: previsao);
                        }
                      },
                    ),
                  ),
                ],
              ),

              // Data Prevista de Pagamento se for Fiado/Pendente
              if (state.statusPagamento == 'PENDENTE') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_note, size: 16, color: Colors.brown),
                              SizedBox(width: 6),
                              Text(
                                'Data Prevista de Acerto:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.brown),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now().add(const Duration(days: 15)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                final dataStr = picked.toIso8601String().substring(0, 10);
                                cubit.selecionarStatusPagamento('PENDENTE', dataPrevista: dataStr);
                              }
                            },
                            icon: const Icon(Icons.edit_calendar, size: 14),
                            label: Text(
                              state.dataPrevistaPagamento ?? 'Definir Data',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'A venda dará baixa de estoque normalmente e entrará como Contas a Receber.',
                        style: TextStyle(fontSize: 11, color: Colors.brown),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Forma de Pagamento
              const Text(
                'Forma de Pagamento',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _PaymentChip(
                    label: 'PIX',
                    selected: state.formaPagamento == 'PIX',
                    onSelected: () => cubit.selecionarFormaPagamento('PIX'),
                  ),
                  _PaymentChip(
                    label: 'Cartão Crédito',
                    selected: state.formaPagamento == 'CARTAO_CREDITO',
                    onSelected: () => cubit.selecionarFormaPagamento('CARTAO_CREDITO'),
                  ),
                  _PaymentChip(
                    label: 'Cartão Débito',
                    selected: state.formaPagamento == 'CARTAO_DEBITO',
                    onSelected: () => cubit.selecionarFormaPagamento('CARTAO_DEBITO'),
                  ),
                  _PaymentChip(
                    label: 'Dinheiro',
                    selected: state.formaPagamento == 'DINHEIRO',
                    onSelected: () => cubit.selecionarFormaPagamento('DINHEIRO'),
                  ),
                ],
              ),

              // Exibe Chave PIX ativa da conta bancária da clínica se PIX selecionado
              if (state.formaPagamento == 'PIX') ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (ctx) {
                    try {
                      final bCubit = ctx.watch<ContasBancariasCubit>();
                      final contasPix = bCubit.state.contas
                          .where((c) => c.ativo && c.chavePix != null && c.chavePix!.isNotEmpty)
                          .toList();
                      if (contasPix.isEmpty) return const SizedBox.shrink();
                      final contaPix = contasPix.first;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.pix_outlined, size: 16, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PIX da Clínica (${contaPix.nomeConta}): ${contaPix.chavePix}',
                                style: const TextStyle(fontSize: 11, color: Colors.teal, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ],

              // Seleção de Conta de Destino se pagamento à vista (PAGO)
              if (state.statusPagamento != 'PENDENTE') ...[
                const SizedBox(height: 10),
                Builder(
                  builder: (ctx) {
                    try {
                      final bCubit = ctx.watch<ContasBancariasCubit>();
                      final contas = bCubit.state.contas.where((c) => c.ativo).toList();
                      if (contas.isEmpty) return const SizedBox.shrink();
                      return DropdownButtonFormField<String?>(
                        decoration: InputDecoration(
                          labelText: 'Conta Destino / Caixa',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.account_balance, size: 16),
                        ),
                        initialValue: contas.any((c) => c.id == state.contaBancariaId) ? state.contaBancariaId : null,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Automática / Padrão', style: TextStyle(fontSize: 12)),
                          ),
                          ...contas.map((c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text('${c.nomeConta} (${c.escopo})', style: const TextStyle(fontSize: 12)),
                          )),
                        ],
                        onChanged: (val) => cubit.selecionarContaBancaria(val),
                      );
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  },
                ),
              ],

              // Parcelamento se Cartão de Crédito
              if (state.formaPagamento == 'CARTAO_CREDITO') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Parcelamento:', style: TextStyle(fontSize: 13)),
                    DropdownButton<int>(
                      value: state.parcelas,
                      items: List.generate(12, (i) => i + 1)
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                '$p x ${currencyFormat.format(state.totalLiquido / p)}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          cubit.configurarCartao(cartaoId: state.cartaoId, parcelas: val);
                        }
                      },
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Botão de Aplicação de Desconto Avulso / Promoção
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => _abrirModalDescontoAvulso(context, cubit, state),
                    icon: const Icon(Icons.discount_outlined, size: 16),
                    label: Text(
                      state.desconto > 0
                          ? 'Desconto Avulso: ${currencyFormat.format(state.desconto)}'
                          : 'Adicionar Desconto Avulso (% ou R\$)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (state.desconto > 0)
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                      tooltip: 'Remover Desconto Avulso',
                      onPressed: () => cubit.aplicarDesconto(0.0),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Resumo Contábil de Totais: Subtotal Original, Desconto Total Aplicado, Total Final
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal Original', style: TextStyle(color: AppColors.textSecondaryLight, fontSize: 13)),
                  Text(
                    currencyFormat.format(state.totalOriginal > 0 ? state.totalOriginal : state.totalBruto),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
              if (state.totalDescontoGeral > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Desconto Total Aplicado', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        if (state.tipoDesconto != 'NENHUM')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              state.tipoDesconto,
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.error),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      '- ${currencyFormat.format(state.totalDescontoGeral)}',
                      style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    state.statusPagamento == 'PENDENTE' ? 'Total a Prazo' : 'Total a Pagar',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    currencyFormat.format(state.totalLiquido),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: state.statusPagamento == 'PENDENTE' ? Colors.amber.shade900 : AppColors.pjClinical,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Botão de Finalizar Venda
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: state.itensCarrinho.isEmpty || state.status == VendasStatus.submitting
                      ? null
                      : () => cubit.finalizarVenda(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.statusPagamento == 'PENDENTE'
                        ? Colors.amber.shade800
                        : AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: state.status == VendasStatus.submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          state.statusPagamento == 'PENDENTE'
                              ? 'CONCLUIR VENDA A PRAZO (FIADO)'
                              : 'FINALIZAR ATENDIMENTO',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _abrirModalDescontoAvulso(BuildContext context, VendasCubit cubit, VendasState state) {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(
          text: state.desconto > 0 ? state.desconto.toStringAsFixed(2) : '',
        );
        bool isPercent = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.discount, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text('Desconto Avulso no Fechamento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Em Reais (R\$)'),
                          selected: !isPercent,
                          onSelected: (val) => setState(() => isPercent = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Percentual (%)'),
                          selected: isPercent,
                          onSelected: (val) => setState(() => isPercent = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: isPercent ? 'Percentual de Desconto (%)' : 'Valor do Desconto (R\$)',
                        prefixText: isPercent ? '% ' : 'R\$ ',
                        border: const OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  onPressed: () {
                    final val = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
                    double finalDiscount = 0.0;
                    if (isPercent) {
                      finalDiscount = (state.totalBruto * val / 100.0);
                    } else {
                      finalDiscount = val;
                    }
                    cubit.aplicarDesconto(finalDiscount, tipoDesconto: 'AVULSO');
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Aplicar Desconto'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _PaymentChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : Colors.black87)),
      selected: selected,
      selectedColor: AppColors.primary,
      onSelected: (_) => onSelected(),
    );
  }
}
