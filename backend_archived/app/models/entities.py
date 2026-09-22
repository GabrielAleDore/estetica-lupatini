import uuid
from datetime import datetime, date
from decimal import Decimal
from typing import List, Optional
from sqlalchemy import (
    Column, String, Boolean, Integer, Numeric, Date, DateTime,
    ForeignKey, Text, CheckConstraint, Index
)
from sqlalchemy.dialects.postgresql import UUID, JSONB, ENUM
from sqlalchemy.orm import relationship
from app.core.database import Base

# Enums mapeados diretamente com os tipos ENUM nativos do PostgreSQL (Supabase)
categoria_tipo_enum = ENUM(
    'SERVICO', 'PRODUTO', 'DESPESA', 'RECEITA',
    name='categoria_tipo',
    create_type=False
)

escopo_tipo_enum = ENUM(
    'PF', 'PJ',
    name='escopo_tipo',
    create_type=False
)

transacao_tipo_enum = ENUM(
    'ENTRADA', 'SAIDA',
    name='transacao_tipo',
    create_type=False
)

movimentacao_tipo_enum = ENUM(
    'ENTRADA', 'SAIDA', 'CONSUMO',
    name='movimentacao_tipo',
    create_type=False
)

status_venda_enum = ENUM(
    'PENDENTE', 'CONCLUIDA', 'CANCELADA',
    name='status_venda',
    create_type=False
)

status_parcela_enum = ENUM(
    'PENDENTE', 'PAGA', 'ATRASADA', 'CANCELADA',
    name='status_parcela',
    create_type=False
)

item_tipo_enum = ENUM(
    'PRODUTO', 'SERVICO',
    name='item_tipo',
    create_type=False
)

forma_pagamento_tipo_enum = ENUM(
    'DINHEIRO', 'PIX', 'CARTAO_CREDITO', 'CARTAO_DEBITO', 'BOLETO', 'TRANSFERENCIA',
    name='forma_pagamento_tipo',
    create_type=False
)


class Cliente(Base):
    __tablename__ = "clientes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nome = Column(String(255), nullable=False, index=True)
    telefone = Column(String(20), nullable=False)
    email = Column(String(255), nullable=True)
    cpf = Column(String(14), unique=True, nullable=True, index=True)
    data_nascimento = Column(Date, nullable=True)
    anamnese = Column(JSONB, nullable=False, default=dict)
    status = Column(String(20), nullable=False, default="ATIVO")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    vendas = relationship("Venda", back_populates="cliente")


class Categoria(Base):
    __tablename__ = "categorias"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nome = Column(String(100), nullable=False)
    tipo = Column(categoria_tipo_enum, nullable=False)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)

    produtos = relationship("Produto", back_populates="categoria")
    servicos = relationship("Servico", back_populates="categoria")
    transacoes = relationship("TransacaoFinanceira", back_populates="categoria")


class Produto(Base):
    __tablename__ = "produtos"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    categoria_id = Column(UUID(as_uuid=True), ForeignKey("categorias.id", ondelete="SET NULL"), nullable=True)
    nome = Column(String(255), nullable=False)
    codigo_barras = Column(String(50), unique=True, nullable=True, index=True)
    preco_custo = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    preco_venda = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    quantidade_estoque = Column(Numeric(12, 3), nullable=False, default=Decimal("0.000"))
    estoque_minimo = Column(Numeric(12, 3), nullable=False, default=Decimal("5.000"))
    permite_venda = Column(Boolean, nullable=False, default=True)
    unidade_medida = Column(String(20), nullable=False, default="UN")
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    categoria = relationship("Categoria", back_populates="produtos")
    movimentacoes = relationship("MovimentacaoEstoque", back_populates="produto")
    insumos_servicos = relationship("ServicoInsumo", back_populates="produto")


class Servico(Base):
    __tablename__ = "servicos"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    categoria_id = Column(UUID(as_uuid=True), ForeignKey("categorias.id", ondelete="SET NULL"), nullable=True)
    nome = Column(String(255), nullable=False)
    duracao_minutos = Column(Integer, nullable=False, default=60)
    preco = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    ativo = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    categoria = relationship("Categoria", back_populates="servicos")
    insumos = relationship("ServicoInsumo", back_populates="servico", cascade="all, delete-orphan")


class ServicoInsumo(Base):
    __tablename__ = "servico_insumos"

    servico_id = Column(UUID(as_uuid=True), ForeignKey("servicos.id", ondelete="CASCADE"), primary_key=True)
    produto_id = Column(UUID(as_uuid=True), ForeignKey("produtos.id", ondelete="RESTRICT"), primary_key=True)
    quantidade_consumo = Column(Numeric(12, 3), nullable=False)

    servico = relationship("Servico", back_populates="insumos")
    produto = relationship("Produto", back_populates="insumos_servicos")


class Venda(Base):
    __tablename__ = "vendas"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    cliente_id = Column(UUID(as_uuid=True), ForeignKey("clientes.id", ondelete="SET NULL"), nullable=True)
    data_hora = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False, index=True)
    valor_bruto = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    desconto = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    valor_liquido = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    forma_pagamento = Column(forma_pagamento_tipo_enum, nullable=False, default="PIX")
    status = Column(status_venda_enum, nullable=False, default="CONCLUIDA")
    observacoes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)

    cliente = relationship("Cliente", back_populates="vendas")
    itens = relationship("ItemVenda", back_populates="venda", cascade="all, delete-orphan")
    movimentacoes = relationship("MovimentacaoEstoque", back_populates="venda")
    transacoes = relationship("TransacaoFinanceira", back_populates="venda")


class ItemVenda(Base):
    __tablename__ = "itens_venda"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    venda_id = Column(UUID(as_uuid=True), ForeignKey("vendas.id", ondelete="CASCADE"), nullable=False, index=True)
    tipo_item = Column(item_tipo_enum, nullable=False)  # PRODUTO ou SERVICO
    produto_id = Column(UUID(as_uuid=True), ForeignKey("produtos.id", ondelete="RESTRICT"), nullable=True)
    servico_id = Column(UUID(as_uuid=True), ForeignKey("servicos.id", ondelete="RESTRICT"), nullable=True)
    quantidade = Column(Numeric(12, 3), nullable=False, default=Decimal("1.000"))
    preco_unitario = Column(Numeric(12, 2), nullable=False)
    subtotal = Column(Numeric(12, 2), nullable=False)

    venda = relationship("Venda", back_populates="itens")
    produto = relationship("Produto")
    servico = relationship("Servico")


class MovimentacaoEstoque(Base):
    __tablename__ = "movimentacoes_estoque"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    produto_id = Column(UUID(as_uuid=True), ForeignKey("produtos.id", ondelete="CASCADE"), nullable=False, index=True)
    tipo = Column(movimentacao_tipo_enum, nullable=False)  # ENTRADA, SAIDA, CONSUMO
    quantidade = Column(Numeric(12, 3), nullable=False)
    saldo_anterior = Column(Numeric(12, 3), nullable=False)
    saldo_posterior = Column(Numeric(12, 3), nullable=False)
    venda_id = Column(UUID(as_uuid=True), ForeignKey("vendas.id", ondelete="SET NULL"), nullable=True)
    motivo = Column(String(255), nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)

    produto = relationship("Produto", back_populates="movimentacoes")
    venda = relationship("Venda", back_populates="movimentacoes")


class ContaCartao(Base):
    __tablename__ = "contas_cartoes"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    nome = Column(String(100), nullable=False)
    escopo = Column(escopo_tipo_enum, nullable=False)  # 'PF' ou 'PJ'
    dia_fechamento = Column(Integer, nullable=False)
    dia_vencimento = Column(Integer, nullable=False)
    limite = Column(Numeric(12, 2), nullable=False, default=Decimal("0.00"))
    ativo = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)

    transacoes = relationship("TransacaoFinanceira", back_populates="cartao")
    parcelas = relationship("ParcelaFinanceira", back_populates="cartao")


class TransacaoFinanceira(Base):
    __tablename__ = "transacoes_financeiras"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    descricao = Column(String(255), nullable=False)
    escopo = Column(escopo_tipo_enum, nullable=False, index=True)  # 'PF' ou 'PJ'
    tipo = Column(transacao_tipo_enum, nullable=False)  # 'ENTRADA' ou 'SAIDA'
    categoria_id = Column(UUID(as_uuid=True), ForeignKey("categorias.id", ondelete="SET NULL"), nullable=True)
    cartao_id = Column(UUID(as_uuid=True), ForeignKey("contas_cartoes.id", ondelete="SET NULL"), nullable=True)
    venda_id = Column(UUID(as_uuid=True), ForeignKey("vendas.id", ondelete="SET NULL"), nullable=True)
    valor_total = Column(Numeric(12, 2), nullable=False)
    parcelas = Column(Integer, nullable=False, default=1)
    data_competencia = Column(Date, nullable=False, default=date.today, index=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)

    categoria = relationship("Categoria", back_populates="transacoes")
    cartao = relationship("ContaCartao", back_populates="transacoes")
    venda = relationship("Venda", back_populates="transacoes")
    parcelas_rel = relationship("ParcelaFinanceira", back_populates="transacao", cascade="all, delete-orphan")


class ParcelaFinanceira(Base):
    __tablename__ = "parcelas_financeiras"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    transacao_id = Column(UUID(as_uuid=True), ForeignKey("transacoes_financeiras.id", ondelete="CASCADE"), nullable=False)
    cartao_id = Column(UUID(as_uuid=True), ForeignKey("contas_cartoes.id", ondelete="SET NULL"), nullable=True, index=True)
    numero_parcela = Column(Integer, nullable=False)
    valor_parcela = Column(Numeric(12, 2), nullable=False)
    data_vencimento = Column(Date, nullable=False, index=True)
    status = Column(status_parcela_enum, nullable=False, default="PENDENTE", index=True)
    mes_fatura_referencia = Column(String(7), nullable=False, index=True)  # 'YYYY-MM'
    data_pagamento = Column(Date, nullable=True)
    created_at = Column(DateTime(timezone=True), default=datetime.utcnow, nullable=False)

    transacao = relationship("TransacaoFinanceira", back_populates="parcelas_rel")
    cartao = relationship("ContaCartao", back_populates="parcelas")
