import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';
import '../domain/models/cockpit_data.dart';

class OperacoesRepository {
  final SupabaseClient _supabase;

  OperacoesRepository({SupabaseClient? client})
      : _supabase = client ?? SupabaseService.client;

  Future<CockpitData> carregarCockpitData({
    DateTime? dataReferencia,
  }) async {
    final hoje = dataReferencia ?? DateTime.now();
    final hojeStr = DateFormat('yyyy-MM-dd').format(hoje);
    final mesInicio = DateTime(hoje.year, hoje.month, 1);
    final mesFim = DateTime(hoje.year, hoje.month + 1, 0, 23, 59, 59);
    final mesInicioStr = DateFormat('yyyy-MM-dd').format(mesInicio);
    final mesFimStr = DateFormat('yyyy-MM-dd').format(mesFim);

    // 1. Executa consultas em paralelo com Future.wait
    final resultados = await Future.wait([
      _carregarTransacoesPagar(hojeStr, mesInicioStr, mesFimStr),
      _carregarRecebimentosVendas(hojeStr, mesInicioStr, mesFimStr),
      _carregarAgendamentosMes(mesInicio, mesFim, hoje),
      _carregarAniversariantesSemana(hoje),
    ]);

    final dadosPagar = resultados[0] as _PagarResumoInternal;
    final dadosReceber = resultados[1] as _ReceberResumoInternal;
    final dadosAgendamentos = resultados[2] as _AgendamentosMesInternal;
    final aniversariantes = resultados[3] as List<AniversarianteItem>;

    final saudeFinanceira = SaudeFinanceiraDia(
      aReceberHoje: dadosReceber.aReceberHoje,
      aPagarHoje: dadosPagar.aPagarHoje,
      recebimentosVencidos: dadosReceber.recebimentosVencidos,
      pagamentosVencidos: dadosPagar.pagamentosVencidos,
      qtdAReceberHoje: dadosReceber.qtdAReceberHoje,
      qtdAPagarHoje: dadosPagar.qtdAPagarHoje,
      qtdRecebimentosVencidos: dadosReceber.qtdRecebimentosVencidos,
      qtdPagamentosVencidos: dadosPagar.qtdPagamentosVencidos,
    );

    final resumoPeriodo = ResumoPeriodo(
      receber: LinhaResumoPeriodo(
        previsto: dadosReceber.periodoPrevisto,
        naoPago: dadosReceber.periodoNaoPago,
        realizado: dadosReceber.periodoRealizado,
      ),
      pagar: LinhaResumoPeriodo(
        previsto: dadosPagar.periodoPrevisto,
        naoPago: dadosPagar.periodoNaoPago,
        realizado: dadosPagar.periodoRealizado,
      ),
    );

    return CockpitData(
      saudeFinanceira: saudeFinanceira,
      resumoPeriodo: resumoPeriodo,
      aniversariantesSemana: aniversariantes,
      diasComAgendamento: dadosAgendamentos.diasComAgendamento,
      agendamentosDoDia: dadosAgendamentos.agendamentosDoDia,
      dataSelecionada: hoje,
    );
  }

  /// Consulta contas a pagar (tipo = 'SAIDA')
  Future<_PagarResumoInternal> _carregarTransacoesPagar(
    String hojeStr,
    String mesInicioStr,
    String mesFimStr,
  ) async {
    try {
      final res = await _supabase
          .from('transacoes_financeiras')
          .select('id, valor, valor_total, data_vencimento, data_pagamento, status')
          .eq('tipo', 'SAIDA')
          .or('status.eq.PENDENTE,data_vencimento.gte.$mesInicioStr');

      final lista = List<Map<String, dynamic>>.from(res as List);

      double aPagarHoje = 0.0;
      int qtdAPagarHoje = 0;
      double pagamentosVencidos = 0.0;
      int qtdPagamentosVencidos = 0;

      double periodoPrevisto = 0.0;
      double periodoNaoPago = 0.0;
      double periodoRealizado = 0.0;

      for (final item in lista) {
        final valor = (item['valor_total'] as num?)?.toDouble() ??
            (item['valor'] as num?)?.toDouble() ??
            0.0;
        final status = (item['status'] as String? ?? '').toUpperCase();
        final vencimento = item['data_vencimento']?.toString().substring(0, 10) ?? '';
        final isPago = status == 'PAGO' || status == 'EFETIVADO';

        // 1. Saúde do Dia
        if (!isPago) {
          if (vencimento == hojeStr) {
            aPagarHoje += valor;
            qtdAPagarHoje++;
          } else if (vencimento.isNotEmpty && vencimento.compareTo(hojeStr) < 0) {
            pagamentosVencidos += valor;
            qtdPagamentosVencidos++;
          }
        }

        // 2. Resumo do Período (Mês)
        if (vencimento.isNotEmpty &&
            vencimento.compareTo(mesInicioStr) >= 0 &&
            vencimento.compareTo(mesFimStr) <= 0) {
          periodoPrevisto += valor;
          if (isPago) {
            periodoRealizado += valor;
          } else {
            periodoNaoPago += valor;
          }
        }
      }

      return _PagarResumoInternal(
        aPagarHoje: aPagarHoje,
        qtdAPagarHoje: qtdAPagarHoje,
        pagamentosVencidos: pagamentosVencidos,
        qtdPagamentosVencidos: qtdPagamentosVencidos,
        periodoPrevisto: periodoPrevisto,
        periodoNaoPago: periodoNaoPago,
        periodoRealizado: periodoRealizado,
      );
    } catch (_) {
      return const _PagarResumoInternal();
    }
  }

  /// Consulta vendas e recebimentos (vendas + receitas avulsas)
  Future<_ReceberResumoInternal> _carregarRecebimentosVendas(
    String hojeStr,
    String mesInicioStr,
    String mesFimStr,
  ) async {
    try {
      final res = await _supabase
          .from('vendas')
          .select('id, valor_total, valor_final, data_hora, status_pagamento')
          .or('status_pagamento.eq.PENDENTE,data_hora.gte.$mesInicioStr');

      final lista = List<Map<String, dynamic>>.from(res as List);

      double aReceberHoje = 0.0;
      int qtdAReceberHoje = 0;
      double recebimentosVencidos = 0.0;
      int qtdRecebimentosVencidos = 0;

      double periodoPrevisto = 0.0;
      double periodoNaoPago = 0.0;
      double periodoRealizado = 0.0;

      for (final item in lista) {
        final valor = (item['valor_final'] as num?)?.toDouble() ??
            (item['valor_total'] as num?)?.toDouble() ??
            0.0;
        final status = (item['status_pagamento'] as String? ?? '').toUpperCase();
        final dataVendaStr = item['data_hora']?.toString().substring(0, 10) ?? '';
        final isPago = status == 'PAGO' || status == 'EFETIVADO';

        // Saúde do Dia (Fiados / pendentes)
        if (!isPago) {
          if (dataVendaStr == hojeStr) {
            aReceberHoje += valor;
            qtdAReceberHoje++;
          } else if (dataVendaStr.isNotEmpty && dataVendaStr.compareTo(hojeStr) < 0) {
            recebimentosVencidos += valor;
            qtdRecebimentosVencidos++;
          }
        }

        // Resumo do Período (Mês)
        if (dataVendaStr.isNotEmpty &&
            dataVendaStr.compareTo(mesInicioStr) >= 0 &&
            dataVendaStr.compareTo(mesFimStr) <= 0) {
          periodoPrevisto += valor;
          if (isPago) {
            periodoRealizado += valor;
          } else {
            periodoNaoPago += valor;
          }
        }
      }

      // 2. Inclui receitas avulsas (tabela transacoes_financeiras tipo ENTRADA/RECEITA sem venda_id)
      try {
        final resAvulsas = await _supabase
            .from('transacoes_financeiras')
            .select('id, valor, valor_total, data_transacao, status')
            .inFilter('tipo', ['ENTRADA', 'RECEITA'])
            .filter('venda_id', 'is', null)
            .or('status.eq.PENDENTE,data_transacao.gte.$mesInicioStr');

        for (final item in resAvulsas) {
          final valor = (item['valor'] as num?)?.toDouble() ?? (item['valor_total'] as num?)?.toDouble() ?? 0.0;
          final status = (item['status'] as String? ?? '').toUpperCase();
          final dataStr = (item['data_transacao'] ?? '').toString();
          final isPago = status == 'PAGO' || status == 'EFETIVADO';

          if (dataStr.isNotEmpty && dataStr.compareTo(mesInicioStr) >= 0 && dataStr.compareTo(mesFimStr) <= 0) {
            periodoPrevisto += valor;
            if (isPago) {
              periodoRealizado += valor;
            } else {
              periodoNaoPago += valor;
            }
          }
        }
      } catch (_) {}

      return _ReceberResumoInternal(
        aReceberHoje: aReceberHoje,
        qtdAReceberHoje: qtdAReceberHoje,
        recebimentosVencidos: recebimentosVencidos,
        qtdRecebimentosVencidos: qtdRecebimentosVencidos,
        periodoPrevisto: periodoPrevisto,
        periodoNaoPago: periodoNaoPago,
        periodoRealizado: periodoRealizado,
      );
    } catch (_) {
      return const _ReceberResumoInternal();
    }
  }

  /// Consulta agendamentos do mês e agrupa dias com agendamento
  Future<_AgendamentosMesInternal> _carregarAgendamentosMes(
    DateTime inicio,
    DateTime fim,
    DateTime diaSelecionado,
  ) async {
    try {
      final res = await _supabase
          .from('agendamentos')
          .select('id, data_hora_inicio, status, clientes(nome), servicos(nome)')
          .gte('data_hora_inicio', inicio.toUtc().toIso8601String())
          .lte('data_hora_inicio', fim.toUtc().toIso8601String())
          .neq('status', 'CANCELADO');

      final lista = List<Map<String, dynamic>>.from(res as List);
      final Map<DateTime, int> mapaDias = {};
      final List<AgendamentoMiniItem> agendamentosDoDia = [];

      final diaSelStr = DateFormat('yyyy-MM-dd').format(diaSelecionado);

      for (final item in lista) {
        final dataHoraRaw = item['data_hora_inicio']?.toString();
        if (dataHoraRaw == null) continue;
        final dataHora = DateTime.tryParse(dataHoraRaw)?.toLocal();
        if (dataHora == null) continue;

        final chaveDia = DateTime(dataHora.year, dataHora.month, dataHora.day);
        mapaDias[chaveDia] = (mapaDias[chaveDia] ?? 0) + 1;

        final itemDiaStr = DateFormat('yyyy-MM-dd').format(dataHora);
        if (itemDiaStr == diaSelStr) {
          final cliente = item['clientes'] as Map<String, dynamic>?;
          final servico = item['servicos'] as Map<String, dynamic>?;

          agendamentosDoDia.add(
            AgendamentoMiniItem(
              id: item['id']?.toString() ?? '',
              clienteNome: cliente?['nome']?.toString() ?? 'Cliente',
              servicoNome: servico?['nome']?.toString() ?? 'Atendimento',
              dataHoraInicio: dataHora,
              status: item['status']?.toString() ?? 'AGENDADO',
            ),
          );
        }
      }

      agendamentosDoDia.sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));

      return _AgendamentosMesInternal(
        diasComAgendamento: mapaDias,
        agendamentosDoDia: agendamentosDoDia,
      );
    } catch (_) {
      return const _AgendamentosMesInternal();
    }
  }

  /// Consulta clientes ativos e filtra os aniversariantes da semana corrente
  Future<List<AniversarianteItem>> _carregarAniversariantesSemana(DateTime hoje) async {
    try {
      final res = await _supabase
          .from('clientes')
          .select('id, nome, telefone, data_nascimento')
          .eq('status', 'ATIVO')
          .not('data_nascimento', 'is', null);

      final lista = List<Map<String, dynamic>>.from(res as List);
      final List<AniversarianteItem> resultado = [];

      // Define o intervalo da semana: segunda-feira até domingo da semana atual
      final diasDesdeSegunda = (hoje.weekday - 1);
      final inicioSemana = DateTime(hoje.year, hoje.month, hoje.day).subtract(Duration(days: diasDesdeSegunda));
      final fimSemana = inicioSemana.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      for (final item in lista) {
        final dataNascRaw = item['data_nascimento']?.toString();
        if (dataNascRaw == null || dataNascRaw.isEmpty) continue;
        final dataNasc = DateTime.tryParse(dataNascRaw);
        if (dataNasc == null) continue;

        // Projeta o aniversário para o ano atual
        final aniversarioEsteAno = DateTime(hoje.year, dataNasc.month, dataNasc.day);

        // Verifica se cai na semana corrente (ou nos próximos 7 dias)
        if (aniversarioEsteAno.isAfter(inicioSemana.subtract(const Duration(seconds: 1))) &&
            aniversarioEsteAno.isBefore(fimSemana.add(const Duration(seconds: 1)))) {
          final idade = hoje.year - dataNasc.year;
          final isHoje = (aniversarioEsteAno.month == hoje.month && aniversarioEsteAno.day == hoje.day);

          resultado.add(
            AniversarianteItem(
              id: item['id']?.toString() ?? '',
              nome: item['nome']?.toString() ?? 'Sem nome',
              telefone: item['telefone']?.toString() ?? '',
              dataNascimento: dataNasc,
              diaMesFormatado: DateFormat('dd/MM').format(dataNasc),
              idadeACompletar: idade > 0 ? idade : null,
              isHoje: isHoje,
            ),
          );
        }
      }

      // Ordena: aniversariantes de hoje primeiro, depois por dia do mês crescente
      resultado.sort((a, b) {
        if (a.isHoje && !b.isHoje) return -1;
        if (!a.isHoje && b.isHoje) return 1;
        return a.dataNascimento.day.compareTo(b.dataNascimento.day);
      });

      return resultado;
    } catch (_) {
      return [];
    }
  }
}

class _PagarResumoInternal {
  final double aPagarHoje;
  final int qtdAPagarHoje;
  final double pagamentosVencidos;
  final int qtdPagamentosVencidos;
  final double periodoPrevisto;
  final double periodoNaoPago;
  final double periodoRealizado;

  const _PagarResumoInternal({
    this.aPagarHoje = 0.0,
    this.qtdAPagarHoje = 0,
    this.pagamentosVencidos = 0.0,
    this.qtdPagamentosVencidos = 0,
    this.periodoPrevisto = 0.0,
    this.periodoNaoPago = 0.0,
    this.periodoRealizado = 0.0,
  });
}

class _ReceberResumoInternal {
  final double aReceberHoje;
  final int qtdAReceberHoje;
  final double recebimentosVencidos;
  final int qtdRecebimentosVencidos;
  final double periodoPrevisto;
  final double periodoNaoPago;
  final double periodoRealizado;

  const _ReceberResumoInternal({
    this.aReceberHoje = 0.0,
    this.qtdAReceberHoje = 0,
    this.recebimentosVencidos = 0.0,
    this.qtdRecebimentosVencidos = 0,
    this.periodoPrevisto = 0.0,
    this.periodoNaoPago = 0.0,
    this.periodoRealizado = 0.0,
  });
}

class _AgendamentosMesInternal {
  final Map<DateTime, int> diasComAgendamento;
  final List<AgendamentoMiniItem> agendamentosDoDia;

  const _AgendamentosMesInternal({
    this.diasComAgendamento = const {},
    this.agendamentosDoDia = const [],
  });
}
