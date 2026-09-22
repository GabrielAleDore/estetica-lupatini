import calendar
from datetime import date
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Tuple

# Simple standalone dateutil relativedelta equivalent for verification if package not installed
def add_months(sourcedate: date, months: int) -> date:
    month = sourcedate.month - 1 + months
    year = sourcedate.year + month // 12
    month = month % 12 + 1
    day = min(sourcedate.day, calendar.monthrange(year, month)[1])
    return date(year, month, day)

def calcular_primeira_fatura_e_vencimento(
    data_compra: date,
    dia_fechamento: int,
    dia_vencimento: int
) -> Tuple[str, date]:
    if data_compra.day >= dia_fechamento:
        ciclo_base = add_months(data_compra, 1)
    else:
        ciclo_base = data_compra

    if dia_vencimento < dia_fechamento:
        data_vencimento_base = add_months(ciclo_base, 1)
    else:
        data_vencimento_base = ciclo_base

    _, ultimo_dia = calendar.monthrange(data_vencimento_base.year, data_vencimento_base.month)
    dia_efetivo = min(dia_vencimento, ultimo_dia)
    
    primeiro_vencimento = date(data_vencimento_base.year, data_vencimento_base.month, dia_efetivo)
    mes_fatura_referencia = primeiro_vencimento.strftime("%Y-%m")
    
    return mes_fatura_referencia, primeiro_vencimento

def projetar_parcelas(
    valor_total: Decimal,
    numero_parcelas: int,
    data_compra: date,
    dia_fechamento: int,
    dia_vencimento: int
):
    valor_base = (valor_total / Decimal(numero_parcelas)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    diferenca_arredondamento = valor_total - (valor_base * numero_parcelas)

    _, primeiro_vencimento = calcular_primeira_fatura_e_vencimento(
        data_compra=data_compra,
        dia_fechamento=dia_fechamento,
        dia_vencimento=dia_vencimento
    )

    parcelas = []
    for i in range(numero_parcelas):
        numero_parcela = i + 1
        valor_parcela = valor_base + (diferenca_arredondamento if i == 0 else Decimal("0.00"))
        
        vencimento_mes = add_months(primeiro_vencimento, i)
        _, ultimo_dia_mes = calendar.monthrange(vencimento_mes.year, vencimento_mes.month)
        dia_efetivo = min(dia_vencimento, ultimo_dia_mes)
        data_vencimento_final = date(vencimento_mes.year, vencimento_mes.month, dia_efetivo)
        mes_fatura = data_vencimento_final.strftime("%Y-%m")

        parcelas.append({
            "numero": numero_parcela,
            "valor": valor_parcela,
            "vencimento": data_vencimento_final,
            "fatura": mes_fatura
        })
    return parcelas

if __name__ == "__main__":
    # Test 1: Compra antes do fechamento
    fatura, venc = calcular_primeira_fatura_e_vencimento(date(2026, 9, 10), 18, 25)
    assert fatura == "2026-09" and venc == date(2026, 9, 25), f"Falha T1: {fatura}, {venc}"

    # Test 2: Compra no dia do fechamento (melhor dia)
    fatura, venc = calcular_primeira_fatura_e_vencimento(date(2026, 9, 18), 18, 25)
    assert fatura == "2026-10" and venc == date(2026, 10, 25), f"Falha T2: {fatura}, {venc}"

    # Test 3: Divisão com centavos exatos
    p = projetar_parcelas(Decimal("100.00"), 3, date(2026, 9, 5), 18, 25)
    assert len(p) == 3
    assert p[0]["valor"] == Decimal("33.34")
    assert p[1]["valor"] == Decimal("33.33")
    assert p[2]["valor"] == Decimal("33.33")
    assert sum(x["valor"] for x in p) == Decimal("100.00")

    # Test 4: Ajuste para mês de fevereiro (dia 31 em ano não-bissexto)
    p_fev = projetar_parcelas(Decimal("500.00"), 3, date(2026, 1, 15), 20, 31)
    assert p_fev[0]["vencimento"] == date(2026, 1, 31)
    assert p_fev[1]["vencimento"] == date(2026, 2, 28)
    assert p_fev[2]["vencimento"] == date(2026, 3, 31)

    print("TODOS OS TESTES DO MOTOR FINANCEIRO PASSARAM COM SUCESSO!")
