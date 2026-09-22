import pytest
import uuid
from decimal import Decimal
from pydantic import ValidationError

from app.schemas.venda import VendaCreate, ItemVendaCreate
from app.schemas.financeiro import DespesaCartaoCreate


def test_validacao_item_produto_sem_servico():
    prod_id = uuid.uuid4()
    item = ItemVendaCreate(
        tipo_item="PRODUTO",
        produto_id=prod_id,
        quantidade=Decimal("2.0"),
        preco_unitario=Decimal("50.00")
    )
    assert item.tipo_item == "PRODUTO"
    assert item.produto_id == prod_id
    assert item.servico_id is None


def test_falha_item_produto_sem_id():
    with pytest.raises(ValidationError):
        ItemVendaCreate(
            tipo_item="PRODUTO",
            quantidade=Decimal("1.0")
        )


def test_falha_item_com_ambos_ids():
    with pytest.raises(ValidationError):
        ItemVendaCreate(
            tipo_item="PRODUTO",
            produto_id=uuid.uuid4(),
            servico_id=uuid.uuid4(),
            quantidade=Decimal("1.0")
        )


def test_venda_create_schema_completo():
    venda = VendaCreate(
        cliente_id=uuid.uuid4(),
        desconto=Decimal("20.00"),
        forma_pagamento="PIX",
        itens=[
            ItemVendaCreate(
                tipo_item="PRODUTO",
                produto_id=uuid.uuid4(),
                quantidade=Decimal("1.0"),
                preco_unitario=Decimal("100.00")
            )
        ]
    )
    assert venda.forma_pagamento == "PIX"
    assert len(venda.itens) == 1
    assert venda.desconto == Decimal("20.00")


def test_despesa_cartao_escopo_obrigatorio():
    with pytest.raises(ValidationError):
        DespesaCartaoCreate(
            descricao="Compra de insumos",
            escopo="INVALIDO",  # Deve ser PF ou PJ
            cartao_id=uuid.uuid4(),
            valor_total=Decimal("500.00")
        )
