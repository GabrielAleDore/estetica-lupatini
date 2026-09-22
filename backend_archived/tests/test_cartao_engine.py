import pytest
from datetime import date
from decimal import Decimal
from app.services.cartao_service import CartaoEngineService


def test_compra_antes_do_fechamento():
    """
    Compra antes do fechamento:
    Fechamento: dia 18.
    Vencimento: dia 25.
    Data da compra: 10/09/2026.
    Esperado: Primeiro vencimento em 25/09/2026, fatura '2026-09'.
    """
    data_compra = date(2026, 9, 10)
    dia_fechamento = 18
    dia_vencimento = 25

    mes_fatura, vencimento = CartaoEngineService.calcular_primeira_fatura_e_vencimento(
        data_compra=data_compra,
        dia_fechamento=dia_fechamento,
        dia_vencimento=dia_vencimento
    )

    assert mes_fatura == "2026-09"
    assert vencimento == date(2026, 9, 25)


def test_compra_no_fechamento_melhor_dia():
    """
    Compra no dia do fechamento (melhor dia de compra):
    Fechamento: dia 18.
    Vencimento: dia 25.
    Data da compra: 18/09/2026.
    Esperado: Próximo ciclo! Primeiro vencimento em 25/10/2026, fatura '2026-10'.
    """
    data_compra = date(2026, 9, 18)
    dia_fechamento = 18
    dia_vencimento = 25

    mes_fatura, vencimento = CartaoEngineService.calcular_primeira_fatura_e_vencimento(
        data_compra=data_compra,
        dia_fechamento=dia_fechamento,
        dia_vencimento=dia_vencimento
    )

    assert mes_fatura == "2026-10"
    assert vencimento == date(2026, 10, 25)


def test_vencimento_menor_que_fechamento():
    """
    Cartão com fechamento dia 25 e vencimento dia 05 do mês seguinte:
    Data da compra: 10/09/2026 (antes do fechamento de 25/09).
    Esperado: Vencimento no mês seguinte (05/10/2026), fatura '2026-10'.
    """
    data_compra = date(2026, 9, 10)
    dia_fechamento = 25
    dia_vencimento = 5

    mes_fatura, vencimento = CartaoEngineService.calcular_primeira_fatura_e_vencimento(
        data_compra=data_compra,
        dia_fechamento=dia_fechamento,
        dia_vencimento=dia_vencimento
    )

    assert mes_fatura == "2026-10"
    assert vencimento == date(2026, 10, 5)


def test_projecao_parcelas_divisao_exata_centavos():
    """
    Valida divisão de R$ 100,00 em 3 parcelas:
    33,34 + 33,33 + 33,33 = 100,00 exatamente.
    """
    valor_total = Decimal("100.00")
    parcelas = CartaoEngineService.projetar_parcelas(
        valor_total=valor_total,
        numero_parcelas=3,
        data_compra=date(2026, 9, 5),
        dia_fechamento=18,
        dia_vencimento=25
    )

    assert len(parcelas) == 3
    assert parcelas[0].valor_parcela == Decimal("33.34")
    assert parcelas[1].valor_parcela == Decimal("33.33")
    assert parcelas[2].valor_parcela == Decimal("33.33")
    assert sum(p.valor_parcela for p in parcelas) == valor_total

    # Sequência cronológica das faturas
    assert parcelas[0].mes_fatura_referencia == "2026-09"
    assert parcelas[1].mes_fatura_referencia == "2026-10"
    assert parcelas[2].mes_fatura_referencia == "2026-11"


def test_ajuste_dias_meses_curtos():
    """
    Vencimento configurado no dia 31 em meses que têm 28 ou 30 dias.
    Compra em 10/01/2026, vencimento dia 31.
    Parcela 2 cai em Fevereiro (máximo dia 28 em ano não bissexto).
    Ajuste Febraban: se cair em fim de semana, prorroga para o próximo dia útil.
    31/01/2026 (Sábado) -> 02/02/2026 (Segunda)
    28/02/2026 (Sábado) -> 02/03/2026 (Segunda)
    """
    parcelas = CartaoEngineService.projetar_parcelas(
        valor_total=Decimal("600.00"),
        numero_parcelas=4,
        data_compra=date(2026, 1, 10),
        dia_fechamento=20,
        dia_vencimento=31
    )

    assert parcelas[0].data_vencimento == date(2026, 2, 2)
    assert parcelas[0].mes_fatura_referencia == "2026-01"
    assert parcelas[1].data_vencimento == date(2026, 3, 2)
    assert parcelas[1].mes_fatura_referencia == "2026-02"
    assert parcelas[2].data_vencimento == date(2026, 3, 31)
    assert parcelas[2].mes_fatura_referencia == "2026-03"
    assert parcelas[3].data_vencimento == date(2026, 4, 30)
    assert parcelas[3].mes_fatura_referencia == "2026-04"
