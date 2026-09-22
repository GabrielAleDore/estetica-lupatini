from uuid import UUID
from datetime import datetime
from decimal import Decimal
from typing import Optional, List
from pydantic import BaseModel, Field, ConfigDict


class CategoriaBase(BaseModel):
    nome: str = Field(min_length=2, max_length=100)
    tipo: str  # SERVICO, PRODUTO, DESPESA, RECEITA


class CategoriaCreate(CategoriaBase):
    pass


class CategoriaResponse(CategoriaBase):
    id: UUID
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


# =====================================================================
# SCHEMAS DE PRODUTOS & INSUMOS
# =====================================================================

class ProdutoBase(BaseModel):
    nome: str = Field(min_length=2, max_length=255)
    categoria_id: Optional[UUID] = None
    codigo_barras: Optional[str] = None
    preco_custo: Decimal = Field(ge=0, default=Decimal("0.00"))
    preco_venda: Decimal = Field(ge=0, default=Decimal("0.00"))
    quantidade_estoque: Decimal = Field(default=Decimal("0.000"))
    estoque_minimo: Decimal = Field(ge=0, default=Decimal("5.000"))
    permite_venda: bool = True
    unidade_medida: str = "UN"


class ProdutoCreate(ProdutoBase):
    pass


class ProdutoUpdate(BaseModel):
    nome: Optional[str] = None
    categoria_id: Optional[UUID] = None
    codigo_barras: Optional[str] = None
    preco_custo: Optional[Decimal] = None
    preco_venda: Optional[Decimal] = None
    quantidade_estoque: Optional[Decimal] = None
    estoque_minimo: Optional[Decimal] = None
    permite_venda: Optional[bool] = None
    unidade_medida: Optional[str] = None


class ProdutoResponse(ProdutoBase):
    id: UUID
    categoria_nome: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AlertaEstoqueResponse(BaseModel):
    id: UUID
    nome: str
    codigo_barras: Optional[str] = None
    quantidade_estoque: Decimal
    estoque_minimo: Decimal
    unidade_medida: str
    deficit: Decimal
    status_alerta: str  # CRITICO, BAIXO

    model_config = ConfigDict(from_attributes=True)


# =====================================================================
# SCHEMAS DE SERVIÇOS & BOM (INSUMOS VINCULADOS)
# =====================================================================

class ServicoInsumoCreate(BaseModel):
    produto_id: UUID
    quantidade_consumo: Decimal = Field(gt=0, description="Quantidade de insumo gasta por procedimento")


class ServicoInsumoResponse(BaseModel):
    produto_id: UUID
    produto_nome: Optional[str] = None
    quantidade_consumo: Decimal
    unidade_medida: Optional[str] = "UN"

    model_config = ConfigDict(from_attributes=True)


class ServicoBase(BaseModel):
    nome: str = Field(min_length=2, max_length=255)
    categoria_id: Optional[UUID] = None
    duracao_minutos: int = Field(ge=5, le=480, default=60)
    preco: Decimal = Field(ge=0, default=Decimal("0.00"))
    ativo: bool = True


class ServicoCreate(ServicoBase):
    insumos: List[ServicoInsumoCreate] = Field(default_factory=list)


class ServicoUpdate(BaseModel):
    nome: Optional[str] = None
    categoria_id: Optional[UUID] = None
    duracao_minutos: Optional[int] = None
    preco: Optional[Decimal] = None
    ativo: Optional[bool] = None
    insumos: Optional[List[ServicoInsumoCreate]] = None


class ServicoResponse(ServicoBase):
    id: UUID
    categoria_nome: Optional[str] = None
    insumos: List[ServicoInsumoResponse] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
