import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../cubit/clientes_cubit.dart';
import '../cubit/clientes_state.dart';
import '../widgets/novo_cliente_dialog.dart';
import '../../../catalogo/data/catalogo_repository.dart';
import '../../../pacotes/presentation/widgets/gerenciar_pacotes_cliente_dialog.dart';

class ClientesPage extends StatelessWidget {
  final ClientesCubit? cubit;
  const ClientesPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider.value(value: cubit!, child: const _ClientesView());
    }
    try {
      context.read<ClientesCubit>();
      return const _ClientesView();
    } catch (_) {
      return BlocProvider(
        create: (_) => ClientesCubit()..carregarClientes(),
        child: const _ClientesView(),
      );
    }
  }
}

class _ClientesView extends StatefulWidget {
  const _ClientesView();

  @override
  State<_ClientesView> createState() => _ClientesViewState();
}

class _ClientesViewState extends State<_ClientesView> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _abrirModalNovoCliente(BuildContext context) {
    final cubit = context.read<ClientesCubit>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NovoClienteDialog(
        onSalvar: (dados) => cubit.cadastrarCliente(dados),
        getLastError: () => cubit.state.errorMessage,
      ),
    );
  }

  void _abrirModalPacotes(BuildContext context, Map<String, dynamic> cliente) async {
    final clienteId = cliente['id'].toString();
    final nome = cliente['nome']?.toString() ?? 'Paciente';
    final servicos = await CatalogoRepository().listarServicos();

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (_) => GerenciarPacotesClienteDialog(
          clienteId: clienteId,
          clienteNome: nome,
          servicos: servicos,
        ),
      );
    }
  }

  void _abrirModalConfigurarFidelidade(BuildContext context, Map<String, dynamic> cliente) {
    final cubit = context.read<ClientesCubit>();
    final clienteId = cliente['id'] as String;
    final nome = cliente['nome'] ?? 'Cliente';
    bool isFidelizada = (cliente['is_fidelizada'] ?? false) as bool;
    double desconto = (cliente['desconto_fidelidade_padrao'] as num?)?.toDouble() ?? 10.0;
    final totalGasto = (cliente['total_gasto'] as num?)?.toDouble() ?? 0.0;
    final totalCompras = (cliente['total_compras'] as num?)?.toInt() ?? 0;

    final controller = TextEditingController(text: desconto > 0 ? desconto.toStringAsFixed(0) : '10');

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.stars, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Programa Fidelidade & VIP: $nome',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Gasto na Clínica', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                            const SizedBox(height: 2),
                            Text(_currencyFormat.format(totalGasto), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Atendimentos', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                            const SizedBox(height: 2),
                            Text('$totalCompras vendas', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Cliente Fidelizada / VIP ⭐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Habilita descontos automáticos no Frente de Caixa (PDV)', style: TextStyle(fontSize: 11)),
                    value: isFidelizada,
                    activeThumbColor: Colors.amber.shade800,
                    activeTrackColor: Colors.amber.shade200,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => isFidelizada = val),
                  ),
                  const SizedBox(height: 12),
                  if (isFidelizada) ...[
                    const Text('Desconto Padrão de Fidelidade (%):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [5.0, 10.0, 15.0, 20.0].map((perc) {
                        final sel = (double.tryParse(controller.text) ?? 0.0) == perc;
                        return ChoiceChip(
                          label: Text('${perc.toStringAsFixed(0)}%'),
                          selected: sel,
                          selectedColor: Colors.amber.shade200,
                          onSelected: (_) {
                            setDialogState(() {
                              controller.text = perc.toStringAsFixed(0);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Outro Percentual (%)',
                        suffixText: '%',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () {
                  final descPerc = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
                  cubit.atualizarFidelidade(clienteId, isFidelizada, isFidelizada ? descPerc : 0.0);
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Salvar Fidelidade'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Ficha de Clientes, Anamnese & Programa VIP'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar Lista',
            onPressed: () => context.read<ClientesCubit>().carregarClientes(
              busca: _searchController.text.trim(),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Todos os Clientes & Anamnese'),
            Tab(icon: Icon(Icons.stars), text: 'Clientes Fidelidade / VIP ⭐'),
          ],
        ),
      ),
      body: BlocConsumer<ClientesCubit, ClientesState>(
        listener: (context, state) {
          if (state.status == ClientesStatus.success && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.success, content: Text(state.successMessage!)),
            );
          } else if (state.status == ClientesStatus.error && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(backgroundColor: AppColors.error, content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<ClientesCubit>();
          final todosClientes = state.clientes;
          final clientesVip = todosClientes.where((c) => (c['is_fidelizada'] ?? false) == true).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              // ABA 1: TODOS OS CLIENTES & ANAMNESE
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barra de Busca e Cadastro
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => cubit.carregarClientes(busca: val.trim()),
                            decoration: InputDecoration(
                              hintText: 'Buscar paciente por nome, CPF ou telefone...',
                              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        cubit.carregarClientes();
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.borderLight),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () => _abrirModalNovoCliente(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'CADASTRAR PACIENTE',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Lista Geral de Clientes
                    Expanded(
                      child: state.status == ClientesStatus.loading && state.clientes.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : todosClientes.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_search_outlined, size: 64, color: Colors.grey.shade400),
                                      const SizedBox(height: 16),
                                      Text('Nenhum paciente cadastrado ou encontrado', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                                      const SizedBox(height: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _abrirModalNovoCliente(context),
                                        icon: const Icon(Icons.add),
                                        label: const Text('Cadastrar Primeiro Paciente'),
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: todosClientes.length,
                                  itemBuilder: (context, index) {
                                    final cli = todosClientes[index];
                                    final anamnese = cli['anamnese'] as Map<String, dynamic>? ?? {};
                                    final isVip = (cli['is_fidelizada'] ?? false) as bool;
                                    final descVip = (cli['desconto_fidelidade_padrao'] as num?)?.toDouble() ?? 0.0;
                                    final totalGasto = (cli['total_gasto'] as num?)?.toDouble() ?? 0.0;

                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: isVip ? Colors.amber.shade300 : AppColors.borderLight, width: isVip ? 1.5 : 1),
                                      ),
                                      child: ExpansionTile(
                                        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: CircleAvatar(
                                          backgroundColor: isVip ? Colors.amber.shade100 : AppColors.primaryLight.withValues(alpha: 0.4),
                                          child: isVip
                                              ? const Icon(Icons.stars, color: Colors.amber, size: 22)
                                              : Text(
                                                  (cli['nome'] as String? ?? 'C').substring(0, 1).toUpperCase(),
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                                ),
                                        ),
                                        title: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                cli['nome'] ?? 'Sem nome',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                              ),
                                            ),
                                            if (isVip)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.amber.shade400),
                                                ),
                                                child: Text(
                                                  'VIP (${descVip.toStringAsFixed(0)}% desc)',
                                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                ),
                                              ),
                                          ],
                                        ),
                                        subtitle: Text(
                                          'Tel: ${cli['telefone'] ?? 'N/A'}  •  CPF: ${cli['cpf'] ?? 'N/A'}  •  Gasto: ${_currencyFormat.format(totalGasto)}',
                                          style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 12),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.collections_bookmark_outlined, color: AppColors.primary),
                                              tooltip: 'Carteira de Pacotes & Sessões',
                                              onPressed: () => _abrirModalPacotes(context, cli),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                isVip ? Icons.stars : Icons.star_border,
                                                color: isVip ? Colors.amber.shade700 : Colors.grey,
                                              ),
                                              tooltip: isVip ? 'Configurar Fidelidade VIP' : 'Tornar Cliente VIP',
                                              onPressed: () => _abrirModalConfigurarFidelidade(context, cli),
                                            ),
                                          ],
                                        ),
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            width: double.infinity,
                                            color: AppColors.backgroundLight,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    const Text(
                                                      'Ficha de Anamnese Dermatológica:',
                                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryDark),
                                                    ),
                                                    Wrap(
                                                      spacing: 8,
                                                      runSpacing: 6,
                                                      children: [
                                                        OutlinedButton.icon(
                                                          onPressed: () => _abrirModalPacotes(context, cli),
                                                          style: OutlinedButton.styleFrom(
                                                            foregroundColor: AppColors.primaryDark,
                                                            side: const BorderSide(color: AppColors.primary),
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            minimumSize: const Size(0, 32),
                                                          ),
                                                          icon: const Icon(Icons.collections_bookmark_outlined, size: 14),
                                                          label: const Text('Pacotes & Sessões', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                        ),
                                                        ElevatedButton.icon(
                                                          onPressed: () => _abrirModalConfigurarFidelidade(context, cli),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: isVip ? Colors.amber.shade700 : AppColors.primary,
                                                            foregroundColor: Colors.white,
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            minimumSize: const Size(0, 32),
                                                          ),
                                                          icon: const Icon(Icons.stars, size: 14),
                                                          label: Text(
                                                            isVip ? 'Gerenciar VIP (${descVip.toStringAsFixed(0)}%)' : 'Habilitar Fidelidade VIP',
                                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 12,
                                                  runSpacing: 8,
                                                  children: [
                                                    _InfoChip(label: 'Pele', value: anamnese['tipo_pele']?.toString() ?? 'Não inf.'),
                                                    _InfoChip(label: 'Fototipo', value: anamnese['fototipo_fitzpatrick']?.toString() ?? 'Não inf.'),
                                                    _InfoChip(
                                                      label: 'Alergias',
                                                      value: (anamnese['alergias'] as List?)?.join(', ') ?? 'Nenhuma',
                                                    ),
                                                    _InfoChip(
                                                      label: 'Medicamentos',
                                                      value: (anamnese['medicamentos_uso'] as List?)?.join(', ') ?? 'Nenhum',
                                                    ),
                                                  ],
                                                ),
                                                if (anamnese['queixa_principal'] != null && anamnese['queixa_principal'].toString().isNotEmpty) ...[
                                                  const SizedBox(height: 8),
                                                  Text('Queixa Principal: ${anamnese['queixa_principal']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                                ],
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

              // ABA 2: SUBTELA DEDICADA DE CLIENTES FIDELIZADAS / VIP
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Informativo da Fidelidade
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.amber.shade50, Colors.orange.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
                            child: const Icon(Icons.stars, color: Colors.amber, size: 30),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Programa de Fidelidade VIP - Estética Lupatini',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Clientes marcadas como VIP recebem desconto automático calculado diretamente no PDV ao serem selecionadas no atendimento.',
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${clientesVip.length}',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF78350F)),
                              ),
                              const Text('Clientes VIP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF78350F))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Lista de Clientes VIP
                    Expanded(
                      child: clientesVip.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.stars_outlined, size: 64, color: Colors.amber.shade300),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Nenhuma cliente fidelizada no momento',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Vá para a aba "Todos os Clientes" e clique na estrela para adicionar clientes ao programa VIP.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: clientesVip.length,
                              itemBuilder: (context, index) {
                                final cli = clientesVip[index];
                                final clienteId = cli['id'] as String;
                                final totalGasto = (cli['total_gasto'] as num?)?.toDouble() ?? 0.0;
                                final totalCompras = (cli['total_compras'] as num?)?.toInt() ?? 0;
                                final descVip = (cli['desconto_fidelidade_padrao'] as num?)?.toDouble() ?? 0.0;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.amber.shade300),
                                  ),
                                  color: Colors.white,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.stars, color: Colors.amber, size: 28),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    cli['nome'] ?? 'Sem nome',
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.shade100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      '${descVip.toStringAsFixed(0)}% DESCONTO',
                                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Telefone: ${cli['telefone'] ?? 'N/A'}  •  CPF: ${cli['cpf'] ?? 'N/A'}',
                                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'Total Acumulado Gasto: ${_currencyFormat.format(totalGasto)}',
                                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text('$totalCompras compras', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: () => _abrirModalPacotes(context, cli),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: AppColors.primaryDark,
                                                side: const BorderSide(color: AppColors.primary),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              ),
                                              icon: const Icon(Icons.collections_bookmark_outlined, size: 14),
                                              label: const Text('Pacotes', style: TextStyle(fontSize: 12)),
                                            ),
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                ElevatedButton.icon(
                                                  onPressed: () => _abrirModalConfigurarFidelidade(context, cli),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.amber.shade700,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                  ),
                                                  icon: const Icon(Icons.tune, size: 14),
                                                  label: const Text('Ajustar %', style: TextStyle(fontSize: 12)),
                                                ),
                                                const SizedBox(height: 6),
                                                TextButton.icon(
                                                  onPressed: () => cubit.atualizarFidelidade(clienteId, false, 0.0),
                                                  icon: const Icon(Icons.star_border, size: 14, color: AppColors.error),
                                                  label: const Text('Remover VIP', style: TextStyle(fontSize: 11, color: AppColors.error)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: AppColors.textPrimaryLight),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
