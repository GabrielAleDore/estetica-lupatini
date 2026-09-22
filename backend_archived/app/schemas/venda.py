from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import List, Optional, Literal
from pydantic import BaseModel, Field, model_validator, ConfigDict


class ItemVendaCreate(BaseModel):
    tipo_item: Literal["PRODUTO", "SERVICO"]
    produto_id: Optional[UUID] = None
    servico_id: Optional[UUID] = None
    quantidade: Decimal = Field(gt=0, default=Decimal("1.000"))
    preco_unitario: Optional[Decimal] = Field(ge=0, default=None)

    @model_validator(mode="after")
    def check_item_references(self):
        if self.tipo_item == "PRODUTO":
            if not self.produto_id:
                raise ValueError("produto_id é obrigatório quando tipo_item é 'PRODUTO'")
            if self.servico_id is not None:
                raise ValueError("servico_id não deve ser fornecido para itens do tipo 'PRODUTO'")
        elif self.tipo_item == "SERVICO":
            if not self.servico_id:
                raise ValueError("servico_id é obrigatório quando tipo_item é 'SERVICO'")
            if self.produto_id is not None:
                raise ValueError("produto_id não deve ser fornecido para itens do tipo 'SERVICO'")
        return self


class VendaCreate(BaseModel):
    cliente_id: Optional[UUID] = None
    desconto: Decimal = Field(ge=0, default=Decimal("0.00"))
    forma_pagamento: Literal["DINHEIRO", "PIX", "CARTAO_CREDITO", "CARTAO_DEBITO", "BOLETO", "TRANSFERENCIA"] = "PIX"
    cartao_id: Optional[UUID] = None
    parcelas: int = Field(ge=1, default=1)
    observacoes: Optional[str] = None
    itens: List[ItemVendaCreate] = Field(min_length=1)

    @model_validator(mode="after")
    def check_cartao_se_credito(self):
        if self.forma_pagamento == "CARTAO_CREDITO" and self.parcelas > 1 and not self.cartao_id:
            # Opcional se for maquininha genérica, mas se especificado valida coerência
            pass
        return self


class ItemVendaResponse(BaseModel):
    id: UUID
    tipo_item: str
    produto_id: Optional[UUID] = None
    servico_id: Optional[UUID] = None
    nome_item: Optional[str] = None
    quantidade: Decimal
    preco_unitario: Decimal
    subtotal: Decimal

    model_config = ConfigDict(from_attributes=True)


class VendaResponse(BaseModel):
    id: UUID
    cliente_id: Optional[UUID] = None
    cliente_nome: Optional[str] = None
    data_hora: datetime
    valor_bruto: Decimal
    desconto: Decimal
    valor_liquido: Decimal
    forma_pagamento: str
    status: str
    observacoes: Optional[str] = None
    itens: List[ItemVendaResponse]
    movimentacoes_geradas: int = 0
    transacao_id: Optional[UUID] = None

    model_config = ConfigDict(from_attributes=True)
