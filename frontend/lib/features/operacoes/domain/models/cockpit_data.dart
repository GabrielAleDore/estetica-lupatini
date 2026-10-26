import 'package:equatable/equatable.dart';

class SaudeFinanceiraDia extends Equatable {
  final double aReceberHoje;
  final double aPagarHoje;
  final double recebimentosVencidos;
  final double pagamentosVencidos;
  final int qtdAReceberHoje;
  final int qtdAPagarHoje;
  final int qtdRecebimentosVencidos;
  final int qtdPagamentosVencidos;

  const SaudeFinanceiraDia({
    this.aReceberHoje = 0.0,
    this.aPagarHoje = 0.0,
    this.recebimentosVencidos = 0.0,
    this.pagamentosVencidos = 0.0,
    this.qtdAReceberHoje = 0,
    this.qtdAPagarHoje = 0,
    this.qtdRecebimentosVencidos = 0,
    this.qtdPagamentosVencidos = 0,
  });

  @override
  List<Object?> get props => [
        aReceberHoje,
        aPagarHoje,
        recebimentosVencidos,
        pagamentosVencidos,
        qtdAReceberHoje,
        qtdAPagarHoje,
        qtdRecebimentosVencidos,
        qtdPagamentosVencidos,
      ];
}

class LinhaResumoPeriodo extends Equatable {
  final double previsto;
  final double naoPago;
  final double realizado;

  const LinhaResumoPeriodo({
    this.previsto = 0.0,
    this.naoPago = 0.0,
    this.realizado = 0.0,
  });

  @override
  List<Object?> get props => [previsto, naoPago, realizado];
}

class ResumoPeriodo extends Equatable {
  final LinhaResumoPeriodo receber;
  final LinhaResumoPeriodo pagar;

  const ResumoPeriodo({
    this.receber = const LinhaResumoPeriodo(),
    this.pagar = const LinhaResumoPeriodo(),
  });

  LinhaResumoPeriodo get saldo => LinhaResumoPeriodo(
        previsto: receber.previsto - pagar.previsto,
        naoPago: receber.naoPago - pagar.naoPago,
        realizado: receber.realizado - pagar.realizado,
      );

  @override
  List<Object?> get props => [receber, pagar];
}

class AniversarianteItem extends Equatable {
  final String id;
  final String nome;
  final String telefone;
  final DateTime dataNascimento;
  final String diaMesFormatado;
  final int? idadeACompletar;
  final bool isHoje;

  const AniversarianteItem({
    required this.id,
    required this.nome,
    required this.telefone,
    required this.dataNascimento,
    required this.diaMesFormatado,
    this.idadeACompletar,
    this.isHoje = false,
  });

  @override
  List<Object?> get props => [
        id,
        nome,
        telefone,
        dataNascimento,
        diaMesFormatado,
        idadeACompletar,
        isHoje,
      ];
}

class AgendamentoMiniItem extends Equatable {
  final String id;
  final String clienteNome;
  final String servicoNome;
  final DateTime dataHoraInicio;
  final String status;

  const AgendamentoMiniItem({
    required this.id,
    required this.clienteNome,
    required this.servicoNome,
    required this.dataHoraInicio,
    required this.status,
  });

  @override
  List<Object?> get props => [id, clienteNome, servicoNome, dataHoraInicio, status];
}

class CockpitData extends Equatable {
  final SaudeFinanceiraDia saudeFinanceira;
  final ResumoPeriodo resumoPeriodo;
  final List<AniversarianteItem> aniversariantesSemana;
  final Map<DateTime, int> diasComAgendamento; // data (sem hora) -> qtd
  final List<AgendamentoMiniItem> agendamentosDoDia;
  final DateTime dataSelecionada;

  const CockpitData({
    this.saudeFinanceira = const SaudeFinanceiraDia(),
    this.resumoPeriodo = const ResumoPeriodo(),
    this.aniversariantesSemana = const [],
    this.diasComAgendamento = const {},
    this.agendamentosDoDia = const [],
    required this.dataSelecionada,
  });

  CockpitData copyWith({
    SaudeFinanceiraDia? saudeFinanceira,
    ResumoPeriodo? resumoPeriodo,
    List<AniversarianteItem>? aniversariantesSemana,
    Map<DateTime, int>? diasComAgendamento,
    List<AgendamentoMiniItem>? agendamentosDoDia,
    DateTime? dataSelecionada,
  }) {
    return CockpitData(
      saudeFinanceira: saudeFinanceira ?? this.saudeFinanceira,
      resumoPeriodo: resumoPeriodo ?? this.resumoPeriodo,
      aniversariantesSemana: aniversariantesSemana ?? this.aniversariantesSemana,
      diasComAgendamento: diasComAgendamento ?? this.diasComAgendamento,
      agendamentosDoDia: agendamentosDoDia ?? this.agendamentosDoDia,
      dataSelecionada: dataSelecionada ?? this.dataSelecionada,
    );
  }

  @override
  List<Object?> get props => [
        saudeFinanceira,
        resumoPeriodo,
        aniversariantesSemana,
        diasComAgendamento,
        agendamentosDoDia,
        dataSelecionada,
      ];
}
