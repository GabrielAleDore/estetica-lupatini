import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

class RelatorioDrePdfService {
  static final _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  /// Carrega os dados contábeis da Stored Procedure `obter_relatorio_dre`
  static Future<Map<String, dynamic>> carregarDadosDre({
    required int mes,
    required int ano,
    SupabaseClient? client,
  }) async {
    final supabase = client ?? SupabaseService.client;
    final res = await supabase.rpc(
      'obter_relatorio_dre',
      params: {'p_mes': mes, 'p_ano': ano},
    );

    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {};
  }

  /// Gera e abre a pré-visualização/impressão do PDF do DRE
  static Future<void> imprimirRelatorioDre({
    required int mes,
    required int ano,
    Map<String, dynamic>? dadosDre,
  }) async {
    final dados = dadosDre ?? await carregarDadosDre(mes: mes, ano: ano);
    final pdfBytes = await gerarPdfBytes(dados: dados, mes: mes, ano: ano);

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'DRE_Estetica_Lupatini_${mes.toString().padLeft(2, "0")}_$ano.pdf',
    );
  }

  /// Constrói o documento PDF com layout profissional contábil
  static Future<Uint8List> gerarPdfBytes({
    required Map<String, dynamic> dados,
    required int mes,
    required int ano,
  }) async {
    final doc = pw.Document();

    final mesesNomes = [
      '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ];
    final mesExtenso = (mes >= 1 && mes <= 12) ? mesesNomes[mes] : 'Mês $mes';

    final recServicos = (dados['receita_bruta_servicos'] as num?)?.toDouble() ?? 0.0;
    final recProdutos = (dados['receita_bruta_produtos'] as num?)?.toDouble() ?? 0.0;
    final recBrutaTotal = (dados['receita_bruta_total'] as num?)?.toDouble() ?? (recServicos + recProdutos);
    final descontos = (dados['descontos_total'] as num?)?.toDouble() ?? 0.0;
    final recLiquida = (dados['receita_liquida'] as num?)?.toDouble() ?? (recBrutaTotal - descontos);
    final custoInsumos = (dados['custo_insumos'] as num?)?.toDouble() ?? 0.0;
    final despFixasPj = (dados['despesas_fixas_pj'] as num?)?.toDouble() ?? 0.0;
    final despVariaveisPj = (dados['despesas_variaveis_pj'] as num?)?.toDouble() ?? 0.0;
    final totalDespesasPj = (dados['despesas_pj_total'] as num?)?.toDouble() ?? (despFixasPj + despVariaveisPj);
    final lucroOperacional = (dados['lucro_operacional_liquido'] as num?)?.toDouble() ?? (recLiquida - custoInsumos - totalDespesasPj);
    final detalheDespesas = (dados['detalhe_despesas'] as List?) ?? [];

    // Cores temáticas para PDF
    final primaryColor = PdfColor.fromHex('#588157');
    final darkColor = PdfColor.fromHex('#344E41');
    final lightColor = PdfColor.fromHex('#F4F7F4');
    final errorColor = PdfColor.fromHex('#C53030');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Cabeçalho da Clínica
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: primaryColor,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'ESTÉTICA LUPATINI',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Demonstração do Resultado do Exercício (DRE Operacional)',
                        style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Competência: $mesExtenso / $ano',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Emissão: ${_dateFormat.format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Tabela Principal de DRE Estruturado
            pw.Text(
              '1. ESTRUTURA CONTÁBIL E OPERACIONAL',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: darkColor),
            ),
            pw.SizedBox(height: 8),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                _buildDreRow(
                  codigo: '(+)',
                  descricao: 'Receita Bruta de Serviços e Procedimentos',
                  valor: recServicos,
                  isHeader: false,
                  primaryColor: primaryColor,
                ),
                _buildDreRow(
                  codigo: '(+)',
                  descricao: 'Receita Bruta de Venda de Produtos / Cosméticos',
                  valor: recProdutos,
                  isHeader: false,
                  primaryColor: primaryColor,
                ),
                _buildDreRow(
                  codigo: '(=)',
                  descricao: 'Subtotal Receita Bruta Consolidada',
                  valor: recBrutaTotal,
                  isBold: true,
                  bgColor: lightColor,
                  primaryColor: primaryColor,
                ),
                _buildDreRow(
                  codigo: '(-)',
                  descricao: 'Descontos Concedidos e Promoções Concedidas',
                  valor: -descontos,
                  isNegative: true,
                  primaryColor: primaryColor,
                ),
                _buildDreRow(
                  codigo: '(=)',
                  descricao: 'RECEITA LÍQUIDA OPERACIONAL',
                  valor: recLiquida,
                  isBold: true,
                  bgColor: lightColor,
                  primaryColor: primaryColor,
                ),
                _buildDreRow(
                  codigo: '(-)',
                  descricao: 'Custo dos Insumos Consumidos (Ficha Técnica & Custo de Produtos)',
                  valor: -custoInsumos,
                  isNegative: true,
                  primaryColor: primaryColor,
                ),
                _buildDreRow(
                  codigo: '(-)',
                  descricao: 'Despesas Operacionais Fixas (Aluguel, Energia, Água, Salários)',
                  valor: -despFixasPj,
                  isNegative: true,
                  primaryColor: primaryColor,
                ),
                _buildDreRow(
                  codigo: '(-)',
                  descricao: 'Despesas Variáveis (Taxas de Cartão, Reposição, Insumos Avulsos)',
                  valor: -despVariaveisPj,
                  isNegative: true,
                  primaryColor: primaryColor,
                ),
                _buildDreRow(
                  codigo: '(=)',
                  descricao: 'LUCRO / PREJUÍZO OPERACIONAL LÍQUIDO',
                  valor: lucroOperacional,
                  isBold: true,
                  bgColor: lucroOperacional >= 0 ? PdfColor.fromHex('#E8F5E9') : PdfColor.fromHex('#FFEBEE'),
                  highlightColor: lucroOperacional >= 0 ? primaryColor : errorColor,
                  primaryColor: primaryColor,
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Detalhamento de Despesas Operacionais Pagas no Mês
            if (detalheDespesas.isNotEmpty) ...[
              pw.Text(
                '2. DISCRIMINAÇÃO DAS DESPESAS OPERACIONAIS PAGAS',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkColor),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: darkColor),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                headers: ['Descrição da Despesa', 'Tipo de Recorrência', 'Valor (R\$)'],
                data: detalheDespesas.map((d) {
                  final valor = (d['valor'] as num?)?.toDouble() ?? 0.0;
                  return [
                    d['descricao'] ?? '',
                    d['tipo_recorrencia'] ?? 'AVULSA',
                    _currencyFormat.format(valor),
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 24),
            ],

            // Rodapé e Assinaturas
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Estética Lupatini - Sistema Integrado de Gestão Clínica', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                    pw.Text('Relatório Contábil Oficial para Fins Gerenciais e Fiscais', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(width: 180, height: 0.5, color: PdfColors.grey600),
                    pw.SizedBox(height: 4),
                    pw.Text('Dra. Amanda Lupatini', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Responsável Técnica / Gestão', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  static pw.TableRow _buildDreRow({
    required String codigo,
    required String descricao,
    required double valor,
    bool isHeader = false,
    bool isBold = false,
    bool isNegative = false,
    PdfColor? bgColor,
    PdfColor? highlightColor,
    required PdfColor primaryColor,
  }) {
    final style = pw.TextStyle(
      fontSize: isBold ? 10 : 9,
      fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: highlightColor ?? (isNegative ? PdfColors.red800 : PdfColors.black),
    );

    return pw.TableRow(
      decoration: bgColor != null ? pw.BoxDecoration(color: bgColor) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(codigo, style: style),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(descricao, style: style),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(_currencyFormat.format(valor), style: style),
          ),
        ),
      ],
    );
  }
}
