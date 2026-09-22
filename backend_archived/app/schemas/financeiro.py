from uuid import UUID
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional, Literal
from pydantic import BaseModel, Field, ConfigDict


class ContaCartaoBase(BaseModel):
    nome: str = Field(min_length=2, max_length=100)
    escopo: Literal["PF", "PJ"]
    dia_fechamento: int = Field(ge=1, le=31)
    dia_vencimento: int = Field(ge=1, le=31)
    limite: Decimal = Field(ge=0, default=Decimal("0.00"))
    ativo: bool = True


class ContaCartaoCreate(ContaCartaoBase):
    pass


class ContaCartaoResponse(ContaCartaoBase):
    id: UUID
    limite_utilizado: Decimal = Decimal("0.00")
    limite_disponivel: Decimal = Decimal("0.00")
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DespesaCartaoCreate(BaseModel):
    descricao: str = Field(min_length=3, max_length=255)
    escopo: Literal["PF", "PJ"]
    cartao_id: UUID
    categoria_id: Optional[UUID] = None
    valor_total: Decimal = Field(gt=0)
    parcelas: int = Field(ge=1, le=48, default=1)
    data_compra: date = Field(default_factory=date.today)


class TransacaoAvulsaCreate(BaseModel):
    descricao: str = Field(min_length=2, max_length=255)
    escopo: Literal["PF", "PJ"]
    tipo: Literal["ENTRADA", "SAIDA"]
    valor_total: Decimal = Field(gt=0)
    data_competencia: date = Field(default_factory=date.today)
    categoria_id: Optional[UUID] = None


class ParcelaResponse(BaseModel):
    id: Optional[UUID] = None
    transacao_id: Optional[UUID] = None
    cartao_id: Optional[UUID] = None
    numero_parcela: int
    valor_parcela: Decimal
    data_vencimento: date
    status: str
    mes_fatura_referencia: str  # 'YYYY-MM'
    data_pagamento: Optional[date] = None

    model_config = ConfigDict(from_attributes=True)


class TransacaoResponse(BaseModel):
    id: UUID
    descricao: str
    escopo: str
    tipo: str
    categoria_id: Optional[UUID] = None
    cartao_id: Optional[UUID] = None
    valor_total: Decimal
    parcelas: int
    data_competencia: date
    parcelas_rel: List[ParcelaResponse] = []

    model_config = ConfigDict(from_attributes=True)


class FaturaCartaoResponse(BaseModel):
    cartao_id: UUID
    cartao_nome: str
    escopo: str
    mes_referencia: str  # 'YYYY-MM'
    valor_total: Decimal
    limite_total: Decimal = Decimal("0.00")
    limite_utilizado: Decimal = Decimal("0.00")
    limite_disponivel: Decimal = Decimal("0.00")
    data_fechamento_estimada: date
    data_vencimento_real: date
    status_fatura: Literal["ABERTA", "FECHADA", "PAGA"]
    parcelas: List[ParcelaResponse]


class ConciliacaoFinanceiraResponse(BaseModel):
    periodo_inicio: date
    periodo_fim: date
    total_entradas_pj: Decimal
    total_saidas_pj: Decimal
    saldo_operacional_pj: Decimal
    total_gastos_pf: Decimal
    quantidade_transacoes_pj: int
    quantidade_transacoes_pf: int
