import calendar
from datetime import date, timedelta
from decimal import Decimal, ROUND_HALF_UP
from typing import List, Tuple
from dateutil.relativedelta import relativedelta

from app.schemas.financeiro import ParcelaResponse


class CartaoEngineService:
    """
    Motor financeiro para projeção de faturas e parcelamento em cartão de crédito.
    Suporta segregação estrita PF vs. PJ e ajuste preciso de ciclos de faturamento.
    """

    @staticmethod
    def calcular_primeira_fatura_e_vencimento(
        data_compra: date,
        dia_fechamento: int,
        dia_vencimento: int
    ) -> Tuple[str, date]:
        """
        Determina o mês da fatura de referência (YYYY-MM) e a data do primeiro vencimento
        com base na data de compra, dia de melhor compra (fechamento) e dia de vencimento.
        
        Regras:
        - Se dia_compra < dia_fechamento:
            A compra entra na fatura do ciclo corrente.
        - Se dia_compra >= dia_fechamento:
            A fatura já fechou ("melhor dia"). A compra entra na fatura do ciclo seguinte (+1 mês).
        """
        # Se a compra foi feita no dia do fechamento ou depois, joga para o próximo ciclo
        if data_compra.day >= dia_fechamento:
            ciclo_base = data_compra + relativedelta(months=1)
        else:
            ciclo_base = data_compra

        # Se dia de vencimento < dia de fechamento (ex: fecha dia 25 e vence dia 05),
        # o vencimento ocorre no mês seguinte ao fechamento do ciclo.
        if dia_vencimento < dia_fechamento:
            data_vencimento_base = ciclo_base + relativedelta(months=1)
        else:
            data_vencimento_base = ciclo_base

        # Ajusta dia de vencimento para o limite do mês (ex: dia 31 em fevereiro vira 28/29)
        _, ultimo_dia = calendar.monthrange(data_vencimento_base.year, data_vencimento_base.month)
        dia_efetivo = min(dia_vencimento, ultimo_dia)
        
        primeiro_vencimento = date(data_vencimento_base.year, data_vencimento_base.month, dia_efetivo)
        mes_fatura_referencia = primeiro_vencimento.strftime("%Y-%m")
        
        return mes_fatura_referencia, primeiro_vencimento

    @staticmethod
    def ajustar_para_dia_util(data_ref: date) -> date:
        """
        Ajusta data de vencimento caso caia em fim de semana (Regra Febraban):
        - Sábado -> Prorroga para Segunda (+2 dias)
        - Domingo -> Prorroga para Segunda (+1 dia)
        """
        if data_ref.weekday() == 5:  # Sábado
            return data_ref + timedelta(days=2)
        elif data_ref.weekday() == 6:  # Domingo
            return data_ref + timedelta(days=1)
        return data_ref

    @classmethod
    def projetar_parcelas(
        cls,
        valor_total: Decimal,
        numero_parcelas: int,
        data_compra: date,
        dia_fechamento: int,
        dia_vencimento: int,
        cartao_id=None
    ) -> List[ParcelaResponse]:
        """
        Gera as N parcelas com:
        - Divisão exata em centavos (diferença de arredondamento alocada na 1ª parcela).
        - Cálculo individual de cada mês de fatura e vencimento subsequente.
        - Ajuste automático para dias úteis bancários.
        """
        if numero_parcelas < 1:
            raise ValueError("Número de parcelas deve ser no mínimo 1.")
        
        # Cálculo do valor base da parcela com 2 casas decimais
        valor_base = (valor_total / Decimal(numero_parcelas)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        diferenca_arredondamento = valor_total - (valor_base * numero_parcelas)

        # Determina a data e fatura da 1ª parcela
        _, primeiro_vencimento = cls.calcular_primeira_fatura_e_vencimento(
            data_compra=data_compra,
            dia_fechamento=dia_fechamento,
            dia_vencimento=dia_vencimento
        )

        parcelas: List[ParcelaResponse] = []

        for i in range(numero_parcelas):
            numero_parcela = i + 1
            # Na 1ª parcela, soma o eventual centavo residual da divisão
            valor_parcela = valor_base + (diferenca_arredondamento if i == 0 else Decimal("0.00"))
            
            # Vencimento do mês i
            vencimento_mes = primeiro_vencimento + relativedelta(months=i)
            _, ultimo_dia_mes = calendar.monthrange(vencimento_mes.year, vencimento_mes.month)
            dia_efetivo = min(dia_vencimento, ultimo_dia_mes)
            data_vencimento_nominal = date(vencimento_mes.year, vencimento_mes.month, dia_efetivo)
            
            # Mês de referência da fatura mantém o ciclo nominal YYYY-MM
            mes_fatura = data_vencimento_nominal.strftime("%Y-%m")
            
            # Data real de vencimento bancário ajustada para dia útil
            data_vencimento_util = cls.ajustar_para_dia_util(data_vencimento_nominal)

            parcelas.append(
                ParcelaResponse(
                    cartao_id=cartao_id,
                    numero_parcela=numero_parcela,
                    valor_parcela=valor_parcela,
                    data_vencimento=data_vencimento_util,
                    status="PENDENTE",
                    mes_fatura_referencia=mes_fatura
                )
            )

        return parcelas
