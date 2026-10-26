import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:estetica_lupatini/features/vendas/data/repositories/vendas_repository.dart';
import 'package:estetica_lupatini/features/vendas/domain/models/produto_servico_item.dart';
import 'package:estetica_lupatini/features/vendas/domain/models/venda_request.dart';
import 'package:estetica_lupatini/features/vendas/presentation/cubit/vendas_cubit.dart';
import 'package:estetica_lupatini/features/vendas/presentation/widgets/cart_summary_panel.dart';
import 'package:estetica_lupatini/features/clientes/data/clientes_repository.dart';
import 'package:estetica_lupatini/features/clientes/presentation/cubit/clientes_cubit.dart';
import 'package:estetica_lupatini/features/clientes/presentation/pages/clientes_page.dart';
import 'package:estetica_lupatini/features/clientes/presentation/widgets/novo_cliente_dialog.dart';
import 'package:estetica_lupatini/features/cartoes/data/cartoes_repository.dart';
import 'package:estetica_lupatini/features/cartoes/presentation/cubit/cartoes_cubit.dart';
import 'package:estetica_lupatini/features/cartoes/presentation/pages/cartoes_page.dart';
import 'package:estetica_lupatini/features/dashboard/data/dashboard_repository.dart';
import 'package:estetica_lupatini/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:estetica_lupatini/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:estetica_lupatini/features/auth/data/auth_repository.dart';
import 'package:estetica_lupatini/features/auth/domain/models/usuario_perfil.dart';
import 'package:estetica_lupatini/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:estetica_lupatini/features/auth/presentation/pages/login_page.dart';
import 'package:estetica_lupatini/features/usuarios/presentation/pages/usuarios_page.dart';
import 'package:estetica_lupatini/features/vendas/data/repositories/vendas_historico_repository.dart';
import 'package:estetica_lupatini/features/vendas/presentation/cubit/vendas_historico_cubit.dart';
import 'package:estetica_lupatini/features/vendas/presentation/pages/movimentacoes_vendas_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:estetica_lupatini/features/contas_pagar/data/contas_pagar_repository.dart';
import 'package:estetica_lupatini/features/contas_pagar/presentation/cubit/contas_pagar_cubit.dart';
import 'package:estetica_lupatini/features/contas_pagar/presentation/pages/contas_pagar_page.dart';
import 'package:estetica_lupatini/features/agenda/data/agenda_repository.dart';
import 'package:estetica_lupatini/features/agenda/domain/models/agendamento.dart';
import 'package:estetica_lupatini/features/agenda/presentation/cubit/agenda_cubit.dart';
import 'package:estetica_lupatini/features/agenda/presentation/pages/agenda_page.dart';
import 'package:estetica_lupatini/features/contas_bancarias/data/contas_bancarias_repository.dart';
import 'package:estetica_lupatini/features/contas_bancarias/domain/models/conta_bancaria_model.dart';
import 'package:estetica_lupatini/features/contas_bancarias/presentation/cubit/contas_bancarias_cubit.dart';
import 'package:estetica_lupatini/features/contas_bancarias/presentation/pages/contas_bancarias_page.dart';
import 'package:estetica_lupatini/features/dashboard/presentation/widgets/nova_receita_dialog.dart';
import 'package:estetica_lupatini/features/operacoes/data/operacoes_repository.dart';
import 'package:estetica_lupatini/features/operacoes/domain/models/cockpit_data.dart';
import 'package:estetica_lupatini/features/operacoes/presentation/cubit/operacoes_cubit.dart';
import 'package:estetica_lupatini/features/operacoes/presentation/pages/cockpit_operacoes_page.dart';

class FakeOperacoesRepository implements OperacoesRepository {
  @override
  Future<CockpitData> carregarCockpitData({DateTime? dataReferencia}) async {
    final hoje = dataReferencia ?? DateTime.now();
    return CockpitData(
      saudeFinanceira: const SaudeFinanceiraDia(
        aReceberHoje: 1250.0,
        aPagarHoje: 800.0,
        recebimentosVencidos: 450.0,
        pagamentosVencidos: 300.0,
        qtdAReceberHoje: 3,
        qtdAPagarHoje: 2,
        qtdRecebimentosVencidos: 1,
        qtdPagamentosVencidos: 1,
      ),
      resumoPeriodo: const ResumoPeriodo(
        receber: LinhaResumoPeriodo(previsto: 15000.0, naoPago: 3000.0, realizado: 12000.0),
        pagar: LinhaResumoPeriodo(previsto: 8000.0, naoPago: 2000.0, realizado: 6000.0),
      ),
      aniversariantesSemana: [
        AniversarianteItem(
          id: 'cli-1',
          nome: 'Camila Ferreira',
          telefone: '11999998888',
          dataNascimento: DateTime(1995, hoje.month, hoje.day),
          diaMesFormatado: '25/09',
          idadeACompletar: 31,
          isHoje: true,
        ),
      ],
      diasComAgendamento: {
        DateTime(hoje.year, hoje.month, hoje.day): 4,
      },
      agendamentosDoDia: [
        AgendamentoMiniItem(
          id: 'ag-1',
          clienteNome: 'Mariana Silveira',
          servicoNome: 'Limpeza de Pele',
          dataHoraInicio: DateTime(hoje.year, hoje.month, hoje.day, 14, 0),
          status: 'AGENDADO',
        ),
      ],
      dataSelecionada: hoje,
    );
  }
}

class FakeContasBancariasRepository implements ContasBancariasRepository {
  @override
  Stream<List<Map<String, dynamic>>> streamContas() => const Stream.empty();

  @override
  Future<List<ContaBancariaModel>> getContas({String? escopo, bool apenasAtivas = false}) async => [
    const ContaBancariaModel(
      id: 'cb-001',
      nomeConta: 'Nubank PJ Clínica',
      bancoNome: 'Nubank',
      tipoConta: 'CORRENTE',
      escopo: 'PJ',
      saldoInicial: 5000.0,
      saldoAtual: 5000.0,
      corIdentificadora: '#820AD1',
      chavePix: 'clinica@pix.com',
      ativo: true,
    ),
    const ContaBancariaModel(
      id: 'cb-002',
      nomeConta: 'Inter PF Sócia',
      bancoNome: 'Banco Inter',
      tipoConta: 'CORRENTE',
      escopo: 'PF',
      saldoInicial: 2500.0,
      saldoAtual: 2500.0,
      corIdentificadora: '#FF7A00',
      chavePix: 'socia@pix.com',
      ativo: true,
    ),
  ];

  @override
  Future<ContaBancariaModel> createConta(ContaBancariaModel conta) async => conta;

  @override
  Future<ContaBancariaModel> updateConta(ContaBancariaModel conta) async => conta;

  @override
  Future<void> toggleAtivo(String id, bool ativo) async {}

  @override
  Future<void> deleteOuInativarConta(String id, {bool deleteDefinitivo = false}) async {}

  @override
  Future<double> reconciliarSaldo(String id) async => 0.0;
}

class FakeAgendaRepository implements AgendaRepository {
  @override
  Future<List<Agendamento>> obterAgendamentos({DateTime? dataInicio, DateTime? dataFim, String? status}) async => [];

  @override
  Future<Agendamento> criarAgendamento({
    required String clienteId,
    required String servicoId,
    required DateTime dataHoraInicio,
    required DateTime dataHoraFim,
    String? observacoes,
  }) async => throw UnimplementedError();

  @override
  Future<void> atualizarStatus(String id, String novoStatus) async {}

  @override
  Future<void> marcarLembreteEnviado(String id) async {}

  @override
  Future<void> excluirAgendamento(String id) async {}

  @override
  Future<List<Map<String, dynamic>>> obterClientesParaSelecao() async => [];

  @override
  Future<List<Map<String, dynamic>>> obterServicosParaSelecao() async => [];

  @override
  Future<Map<String, dynamic>> calcularMetricas({required DateTime dataInicio, required DateTime dataFim}) async => {
    'total': 0,
    'agendados': 0,
    'confirmados': 0,
    'concluidos': 0,
    'cancelados': 0,
    'noShows': 0,
    'taxaComparecimento': 0.0,
    'taxaCancelamento': 0.0,
  };
}

class FakeVendasRepository implements VendasRepository {
  @override
  Future<List<ProdutoServicoItem>> carregarCatalogo() async => [];

  @override
  Future<List<Map<String, dynamic>>> carregarClientes({String? busca}) async => [
    {
      'id': 'c0000000-0000-0000-0000-000000000001',
      'nome': 'Mariana Alcantara Silveira',
      'telefone': '(11) 98765-4321',
      'cpf': '123.456.789-00'
    }
  ];

  @override
  Future<List<Map<String, dynamic>>> carregarCartoes(String escopo) async => [];

  @override
  Future<Map<String, dynamic>> finalizarVenda(VendaRequest request) async => {'id': 'venda-123'};
}

class FakeClientesRepository implements ClientesRepository {
  @override
  Future<List<Map<String, dynamic>>> listarClientes({String? busca}) async => [
    {
      'id': 'c0000000-0000-0000-0000-000000000001',
      'nome': 'Mariana Alcantara Silveira',
      'telefone': '(11) 98765-4321',
      'cpf': '123.456.789-00',
      'anamnese': {
        'tipo_pele': 'Mista',
        'fototipo_fitzpatrick': 'III',
        'alergias': ['Nenhuma'],
      }
    }
  ];

  @override
  Future<Map<String, dynamic>> cadastrarCliente(Map<String, dynamic> dados) async => dados;

  @override
  Future<Map<String, dynamic>> atualizarCliente(String id, Map<String, dynamic> dados) async => dados;

  @override
  Future<void> excluirCliente(String id) async {}

  @override
  Future<void> atualizarFidelidade(String id, bool isFidelizada, double desconto) async {}
}

class FakeCartoesRepository implements CartoesRepository {
  @override
  Stream<List<Map<String, dynamic>>> streamParcelas(String cartaoId) => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> listarCartoes({String? escopo}) async => [
    {
      'id': 'a0000000-0000-0000-0000-000000000001',
      'nome': 'Cartão PJ Clínica',
      'escopo': 'PJ',
      'dia_fechamento': 18,
      'dia_vencimento': 25,
      'limite': 20000.0,
      'ativo': true,
    }
  ];

  @override
  Future<Map<String, dynamic>> cadastrarCartao(Map<String, dynamic> dados) async => dados;

  @override
  Future<Map<String, dynamic>> atualizarCartao(String id, Map<String, dynamic> dados) async => dados;

  @override
  Future<Map<String, dynamic>> consultarFatura(String cartaoId, String mesReferencia) async => {
    'cartao_id': cartaoId,
    'cartao_nome': 'Cartão PJ Clínica',
    'escopo': 'PJ',
    'mes_referencia': mesReferencia,
    'valor_total': 1500.0,
    'data_fechamento_estimada': '2026-09-18',
    'data_vencimento_real': '2026-09-25',
    'status_fatura': 'ABERTA',
    'parcelas': [],
  };

  @override
  Future<Map<String, dynamic>> registrarDespesaCartao(Map<String, dynamic> dados) async => dados;
}

class FakeDashboardRepository implements DashboardRepository {
  @override
  Future<Map<String, dynamic>> obterDashboardResumo(String mes) async => {
    'mes_referencia': mes,
    'dre': await obterDRE(mes),
    'total_itens_alerta_estoque': 0,
    'alertas_estoque': [],
    'total_faturado_pj': 15000.0,
    'total_despesas_pf': 2200.0,
    'balanco_liquido': 7300.0,
    'vendas_efetivadas': 12000.0,
    'vendas_a_receber': 3000.0,
  };

  @override
  Future<Map<String, dynamic>> obterDRE(String mes) async => {
    'receita_liquida': 15000.0,
    'despesas_operacionais_pj': 3500.0,
    'custo_produtos_vendidos': 1200.0,
    'custo_insumos_servicos': 800.0,
    'lucro_operacional_liquido_pj': 9500.0,
    'gastos_pessoais_pf_mes': 2200.0,
  };

  @override
  Future<Map<String, dynamic>> obterResumoContasBancarias() async => {
    'saldo_total_pj': 10000.0,
    'saldo_total_pf': 5000.0,
    'saldo_total_geral': 15000.0,
    'qtd_contas_pj': 2,
    'qtd_contas_pf': 1,
    'total_contas_ativas': 3,
    'contas': [],
  };

  @override
  Future<List<Map<String, dynamic>>> listarAlertasEstoque() async => [];

  @override
  Future<List<Map<String, dynamic>>> listarProdutos() async => [];

  @override
  Future<Map<String, dynamic>> darEntradaEstoque({
    required String produtoId,
    required double quantidade,
    double? custoUnitario,
    String? motivo,
  }) async => {};

  @override
  Future<Map<String, dynamic>> registrarTransacaoAvulsa(Map<String, dynamic> dados) async => dados;

  @override
  Future<Map<String, dynamic>> obterReceitasManuaisMes(String mes) async => {
    'total_receitas_pj': 2500.0,
    'total_receitas_pf': 500.0,
    'total_receitas_geral': 3000.0,
    'transacoes': [],
  };

  @override
  Future<Map<String, dynamic>> registrarReceitaAvulsa(Map<String, dynamic> dados) async => dados;
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<UsuarioPerfil?> obterUsuarioAtual() async {
    return const UsuarioPerfil(
      id: 'u0001',
      nome: 'Administrador Lupatini',
      email: 'admin@lupatini.com',
      role: 'ADMIN',
      ativo: true,
    );
  }

  @override
  Future<UsuarioPerfil> signIn({required String email, required String password}) async {
    return const UsuarioPerfil(
      id: 'u0001',
      nome: 'Administrador Lupatini',
      email: 'admin@lupatini.com',
      role: 'ADMIN',
      ativo: true,
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<List<UsuarioPerfil>> listarUsuarios() async => [
    const UsuarioPerfil(
      id: 'u0001',
      nome: 'Administrador Lupatini',
      email: 'admin@lupatini.com',
      role: 'ADMIN',
      ativo: true,
    ),
    const UsuarioPerfil(
      id: 'u0002',
      nome: 'Recepção Clínica',
      email: 'recepcao@lupatini.com',
      role: 'RECEPCAO',
      ativo: true,
    ),
  ];

  @override
  Future<Map<String, dynamic>> criarUsuarioAdmin({
    required String nome,
    required String email,
    required String password,
    required String role,
  }) async {
    return {
      'id': 'u0003',
      'nome': nome,
      'email': email,
      'role': role,
    };
  }

  @override
  Future<void> atualizarStatusUsuario(String id, bool ativo) async {}

  @override
  Future<void> excluirUsuario(String id) async {}
}

class FakeVendasHistoricoRepository implements VendasHistoricoRepository {
  @override
  Stream<List<Map<String, dynamic>>> streamVendas() => const Stream.empty();

  @override
  Stream<List<Map<String, dynamic>>> streamTransacoes() => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> listarVendas({
    String? statusPagamento,
    String? buscaCliente,
    DateTime? dataInicio,
    DateTime? dataFim,
  }) async => [
    {
      'id': 'v-001',
      'data_hora': '2026-09-15T14:30:00Z',
      'valor_total': 350.0,
      'desconto': 0.0,
      'status_pagamento': 'PENDENTE',
      'forma_pagamento': 'A_PRAZO',
      'data_prevista_pagamento': '2026-09-30',
      'clientes': {'nome': 'Juliana Costa', 'telefone': '11999998888'},
      'itens_venda': [
        {'quantidade': 1, 'valor_unitario': 350.0, 'servicos': {'nome': 'Limpeza de Pele Profunda'}},
      ],
    },
  ];

  @override
  Future<Map<String, dynamic>> darBaixaVenda(String vendaId, String formaPagamento, {String? contaBancariaId}) async => {
    'sucesso': true,
  };

  @override
  Future<void> cancelarVenda(String vendaId) async {}
}

class FakeContasPagarRepository implements ContasPagarRepository {
  @override
  Stream<List<Map<String, dynamic>>> streamTransacoes() => const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> listarContasPagar({
    String? status,
    String? escopo,
  }) async => [
    {
      'id': 'cp-001',
      'descricao': 'Aluguel do Consultório',
      'valor': 2500.0,
      'data_vencimento': '2026-09-20',
      'status': 'PENDENTE',
      'escopo': 'PJ',
      'tipo_recorrencia': 'FIXA_MENSAL',
      'categorias': {'nome': 'Infraestrutura'},
    },
  ];

  @override
  Future<Map<String, dynamic>> cadastrarContaPagar(Map<String, dynamic> dados) async => dados;

  @override
  DateTime calcularVencimentoFatura({
    required DateTime dataCompra,
    required int diaFechamento,
    required int diaVencimento,
    required int numeroParcela,
  }) => DateTime.now();

  @override
  Future<List<Map<String, dynamic>>> cadastrarDespesaParcelada(Map<String, dynamic> dados) async => [dados];

  @override
  Future<void> atualizarParcelaDespesa({
    required String transacaoId,
    required String novaDataVencimentoStr,
    double? novoValor,
    String? novaDescricao,
    String? novaCategoriaId,
    required bool aplicarEmTodasSeguintes,
  }) async {}

  @override
  Future<void> marcarComoPago(String transacaoId, {String? contaBancariaId}) async {}

  @override
  Future<void> excluirContaPagar(String transacaoId) async {}

  @override
  Future<List<Map<String, dynamic>>> listarCategoriasDespesa() async => [];
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
    Intl.defaultLocale = 'pt_BR';
  });

  testWidgets('CartSummaryPanel displays header, client selector and fiado options', (WidgetTester tester) async {
    final cubit = VendasCubit(repository: FakeVendasRepository());
    await cubit.carregarDadosIniciais();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const CartSummaryPanel(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CartSummaryPanel), findsOneWidget);
    expect(find.text('Comanda / Atendimento'), findsOneWidget);
    expect(find.text('Cliente Avulso (Sem cadastro)'), findsOneWidget);
    expect(find.byType(DropdownButton<String?>), findsOneWidget);
    expect(find.text('Pagamento Imediato'), findsOneWidget);
    expect(find.text('Pagar Depois (Fiado)'), findsOneWidget);
    expect(find.text('FINALIZAR ATENDIMENTO'), findsOneWidget);
  });

  testWidgets('ClientesPage displays search bar and action button', (WidgetTester tester) async {
    final cubit = ClientesCubit(repository: FakeClientesRepository());
    await cubit.carregarClientes();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const ClientesPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('CADASTRAR PACIENTE'), findsOneWidget);
  });

  testWidgets('CartoesPage displays invoice and scope filter', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cubit = CartoesCubit(repository: FakeCartoesRepository());
    await cubit.carregarCartoes();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const CartoesPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('REGISTRAR DESPESA NO CARTÃO'), findsOneWidget);
    expect(find.text('NOVO CARTÃO'), findsOneWidget);
  });

  testWidgets('DashboardPage displays DRE KPI cards and quick actions', (WidgetTester tester) async {
    final cubit = DashboardCubit(repository: FakeDashboardRepository());
    await cubit.carregarDashboard();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const DashboardPage(),
        ),
      ),
    );
    await tester.pump();

    // Valida bloco de liquidez bancária
    expect(find.text('Liquidez Financeira Imediata • Contas Bancárias'), findsOneWidget);
    expect(find.text('Total de Saídas'), findsOneWidget);
    expect(find.text('Total de Receitas'), findsOneWidget);
    expect(find.text('Saldo Atual em Contas'), findsOneWidget);
    expect(find.text('VER CONTAS BANCÁRIAS'), findsOneWidget);

    expect(find.text('+ NOVA ENTRADA / PIX'), findsOneWidget);
    expect(find.text('ENTRADA DE ESTOQUE'), findsOneWidget);
    expect(find.text('NOVO GASTO AVULSO'), findsOneWidget);
    expect(find.text('Vendas Efetivadas (Recebidas)'), findsOneWidget);
    expect(find.text('Vendas a Receber (Pendentes)'), findsOneWidget);
    expect(find.text('Resultado Operacional'), findsOneWidget);
  });

  testWidgets('LoginPage displays form, empty fields, and remember access checkbox', (WidgetTester tester) async {
    final authCubit = AuthCubit(repository: FakeAuthRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: authCubit,
          child: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Estética Lupatini'), findsOneWidget);
    expect(find.text('Entrar no Sistema'), findsOneWidget);
    expect(find.text('Lembrar meu acesso'), findsOneWidget);
    expect(find.text('Admin'), findsNothing);
    expect(find.text('Recepção'), findsNothing);
    expect(find.text('Atendimento'), findsNothing);
  });

  testWidgets('UsuariosPage displays users and new user action button', (WidgetTester tester) async {
    final authCubit = AuthCubit(repository: FakeAuthRepository());
    await authCubit.carregarColaboradores();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: authCubit,
          child: const UsuariosPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Gestão de Usuários & Colaboradores'), findsOneWidget);
    expect(find.text('Novo Colaborador'), findsOneWidget);
    expect(find.text('Administrador Lupatini'), findsOneWidget);
  });

  testWidgets('MovimentacoesVendasPage displays filters and sales list with actions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cubit = VendasHistoricoCubit(repository: FakeVendasHistoricoRepository());
    await cubit.carregarVendas();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const MovimentacoesVendasPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Registro de Receitas'), findsOneWidget);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Juliana Costa'), findsOneWidget);
    expect(find.byTooltip('Receber / Liquidar'), findsWidgets);
  });

  testWidgets('ContasPagarPage displays status tabs and new expense button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cubit = ContasPagarCubit(repository: FakeContasPagarRepository());
    await cubit.carregarContas();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const ContasPagarPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Registro de Despesas'), findsOneWidget);
    expect(find.text('Nova Despesa'), findsOneWidget);
    expect(find.text('Aluguel do Consultório'), findsOneWidget);
    expect(find.text('Pagar'), findsOneWidget);
  });

  testWidgets('MultiBlocProvider provides ContasPagarCubit and VendasHistoricoCubit without ProviderNotFoundError', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cpCubit = ContasPagarCubit(repository: FakeContasPagarRepository());
    final vhCubit = VendasHistoricoCubit(repository: FakeVendasHistoricoRepository());

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<ContasPagarCubit>.value(value: cpCubit),
          BlocProvider<VendasHistoricoCubit>.value(value: vhCubit),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Expanded(child: ContasPagarPage()),
                Expanded(child: MovimentacoesVendasPage()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ContasPagarPage), findsOneWidget);
    expect(find.byType(MovimentacoesVendasPage), findsOneWidget);
  });

  testWidgets('MovimentacoesVendasPage and ContasPagarPage accept direct cubit parameter without external provider', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cpCubit = ContasPagarCubit(repository: FakeContasPagarRepository());
    await cpCubit.carregarContas();
    final vhCubit = VendasHistoricoCubit(repository: FakeVendasHistoricoRepository());
    await vhCubit.carregarVendas();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Expanded(child: ContasPagarPage(cubit: cpCubit)),
              Expanded(child: MovimentacoesVendasPage(cubit: vhCubit)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ContasPagarPage), findsOneWidget);
    expect(find.byType(MovimentacoesVendasPage), findsOneWidget);
    expect(find.text('Aluguel do Consultório'), findsOneWidget);
    expect(find.text('Juliana Costa'), findsOneWidget);
  });

  testWidgets('AgendaPage renders correctly with pt_BR date formatting without LocaleDataException', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cubit = AgendaCubit(repository: FakeAgendaRepository());

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        home: AgendaPage(cubit: cubit),
      ),
    );
    await tester.pump();

    expect(find.byType(AgendaPage), findsOneWidget);
    expect(find.text('Agenda de Atendimentos & WhatsApp'), findsOneWidget);
  });

  testWidgets('NovoClienteDialog converts DD/MM/YYYY birthdate to ISO 8601 YYYY-MM-DD on submit', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    Map<String, dynamic>? submittedData;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        home: Scaffold(
          body: NovoClienteDialog(
            onSalvar: (dados) async {
              submittedData = dados;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Fill nome, telefone, and birthdate in DD/MM/YYYY format
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome Completo *'), 'Paciente Teste');
    await tester.enterText(find.widgetWithText(TextFormField, 'Telefone / WhatsApp *'), '11999999999');
    await tester.enterText(find.widgetWithText(TextFormField, 'Data de Nascimento (Opcional)'), '16/06/2003');

    // Click Salvar
    await tester.tap(find.text('Salvar Paciente'));
    await tester.pump();

    expect(submittedData, isNotNull);
    expect(submittedData!['data_nascimento'], '2003-06-16');
  });

  testWidgets('ContasBancariasPage displays KPI cards, tabs and bank cards', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cubit = ContasBancariasCubit(repository: FakeContasBancariasRepository());
    await cubit.carregarContas();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        home: ContasBancariasPage(cubit: cubit),
      ),
    );
    await tester.pump();

    expect(find.byType(ContasBancariasPage), findsOneWidget);
    expect(find.text('Gestão de Contas Bancárias'), findsOneWidget);
    expect(find.text('Saldo Total Consolidado'), findsOneWidget);
    expect(find.text('Contas Bancárias Ativas'), findsOneWidget);
    expect(find.text('Nubank PJ Clínica'), findsOneWidget);
    expect(find.text('Inter PF Sócia'), findsOneWidget);
  });

  testWidgets('NovaReceitaDialog renders all form fields and submits new revenue', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final dashboardCubit = DashboardCubit(repository: FakeDashboardRepository());
    final contas = [
      const ContaBancariaModel(
        id: 'cb-001',
        nomeConta: 'Nubank PJ Clínica',
        bancoNome: 'Nubank',
        tipoConta: 'CORRENTE',
        escopo: 'PJ',
        saldoInicial: 5000.0,
        saldoAtual: 5000.0,
        ativo: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        home: BlocProvider<DashboardCubit>.value(
          value: dashboardCubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => BlocProvider<DashboardCubit>.value(
                      value: dashboardCubit,
                      child: NovaReceitaDialog(
                        escopoInicial: 'PJ',
                        contasPreCarregadas: contas,
                        onSalvar: (dados) async => dashboardCubit.registrarReceitaAvulsa(dados),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir Modal'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Open modal
    await tester.tap(find.text('Abrir Modal'));
    await tester.pumpAndSettle();

    // Verify modal elements
    expect(find.text('Nova Entrada / Receita Avulsa'), findsOneWidget);
    expect(find.text('PJ (Clínica)'), findsOneWidget);
    expect(find.text('PF (Dra. Camila)'), findsOneWidget);
    expect(find.text('Salvar e Creditar Receita'), findsOneWidget);

    // Fill fields
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição da Receita *'), 'Recebimento PIX - Consultoria');
    await tester.enterText(find.widgetWithText(TextFormField, 'Valor Recebido (R\$) *'), '500,00');

    // Submit form
    final salvarBtn = find.text('Salvar e Creditar Receita');
    await tester.ensureVisible(salvarBtn);
    await tester.tap(salvarBtn);
    await tester.pumpAndSettle();

    // Dialog should be closed
    expect(find.byType(NovaReceitaDialog), findsNothing);
  });

  testWidgets('CockpitOperacoesPage displays quick actions, daily KPIs, financial summary, and calendar', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cubit = OperacoesCubit(repository: FakeOperacoesRepository());
    await cubit.carregarCockpit();
    final authCubit = AuthCubit(repository: FakeAuthRepository());

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: authCubit),
            BlocProvider.value(value: cubit),
          ],
          child: CockpitOperacoesPage(cubit: cubit),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Novo Agendamento'), findsOneWidget);
    expect(find.text('Novo Cliente'), findsOneWidget);
    expect(find.text('Nova Venda (PDV)'), findsOneWidget);
    expect(find.text('Nova Despesa'), findsOneWidget);
    expect(find.text('Saúde Financeira do Dia'), findsOneWidget);
    expect(find.text('A RECEBER HOJE'), findsOneWidget);
    expect(find.text('A PAGAR HOJE'), findsOneWidget);
    expect(find.text('Resumo do Período Financeiro'), findsOneWidget);
    expect(find.text('Aniversariantes da Semana'), findsOneWidget);
    expect(find.text('Camila Ferreira'), findsOneWidget);
  });
}

