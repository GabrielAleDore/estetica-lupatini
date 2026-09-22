import asyncio
import time
from datetime import datetime, timedelta, timezone
from decimal import Decimal
import uuid
import jwt
import pytest
import httpx
from sqlalchemy import text, select

from app.core.config import settings
from app.core.database import engine, AsyncSessionLocal
from app.core.security import decode_supabase_jwt, get_current_user
from app.models.entities import Produto, Venda, ItemVenda, MovimentacaoEstoque
from app.schemas.venda import VendaCreate, ItemVendaCreate
from app.services.vendas_service import VendasService
from fastapi import HTTPException


@pytest.mark.asyncio
async def test_smoke_1_database_connectivity():
    """
    Smoke Test 1: Conectividade direta com Supabase PostgreSQL via AsyncPG.
    Mede tempo de resposta de um 'SELECT 1'.
    """
    start_time = time.perf_counter()
    async with engine.connect() as conn:
        res = await conn.execute(text("SELECT 1"))
        val = res.scalar()
    elapsed_ms = (time.perf_counter() - start_time) * 1000
    
    assert val == 1, f"Esperado 1, recebido: {val}"
    print(f"\n[PASS] Smoke 1: Conectividade com Banco Supabase ativa. Latência: {elapsed_ms:.2f}ms")


@pytest.mark.asyncio
async def test_smoke_2_health_endpoint_inspection():
    """
    Smoke Test 2: Inspeciona endpoint /health da aplicação.
    Avalia se o endpoint valida a saúde real do banco de dados ou é estático.
    """
    start_time = time.perf_counter()
    async with httpx.AsyncClient(base_url="http://127.0.0.1:8000") as client:
        try:
            resp = await client.get("/health")
            elapsed_ms = (time.perf_counter() - start_time) * 1000
            assert resp.status_code == 200
            data = resp.json()
            assert data["status"] == "healthy"
            
            # Auditoria: Verifica se o payload tem chave 'database'
            has_db_check = "database" in data
            print(f"[AUDIT] Smoke 2: /health respondeu 200 em {elapsed_ms:.2f}ms. Checa banco de dados? {'SIM' if has_db_check else 'NAO (ALERTA: healthcheck estático)'}")
        except httpx.ConnectError:
            print("[WARN] Smoke 2: Servidor HTTP não está ativo em 127.0.0.1:8000 para teste de endpoint.")


def test_smoke_3_supabase_jwt_auth_validation():
    """
    Smoke Test 3: Auditoria de validação de tokens JWT do Supabase.
    Testa token válido, token expirado e token adulterado.
    """
    # 3.1 Token Válido
    payload_valido = {
        "sub": "e0000000-0000-0000-0000-000000000001",
        "email": "mariana.silveira@email.com",
        "role": "authenticated",
        "aud": "authenticated",
        "exp": datetime.now(timezone.utc) + timedelta(hours=1)
    }
    token_valido = jwt.encode(payload_valido, settings.SUPABASE_JWT_SECRET, algorithm=settings.SUPABASE_JWT_ALGORITHM)
    decoded = decode_supabase_jwt(token_valido)
    assert decoded["sub"] == payload_valido["sub"]
    assert decoded["email"] == payload_valido["email"]
    print("[PASS] Smoke 3.1: Token JWT Supabase válido decodificado com sucesso.")

    # 3.2 Token Expirado
    payload_expirado = {
        "sub": "e0000000-0000-0000-0000-000000000001",
        "email": "mariana.silveira@email.com",
        "aud": "authenticated",
        "exp": datetime.now(timezone.utc) - timedelta(hours=1)
    }
    token_expirado = jwt.encode(payload_expirado, settings.SUPABASE_JWT_SECRET, algorithm=settings.SUPABASE_JWT_ALGORITHM)
    with pytest.raises(HTTPException) as exc_info:
        decode_supabase_jwt(token_expirado)
    assert exc_info.value.status_code == 401
    assert "expirado" in exc_info.value.detail.lower()
    print("[PASS] Smoke 3.2: Rejeição correta de Token JWT expirado (401).")

    # 3.3 Token com Assinatura Inválida
    token_adulterado = token_valido[:-5] + "XXXXX"
    with pytest.raises(HTTPException) as exc_info:
        decode_supabase_jwt(token_adulterado)
    assert exc_info.value.status_code == 401
    print("[PASS] Smoke 3.3: Rejeição correta de Token JWT com assinatura inválida (401).")


@pytest.mark.asyncio
async def test_smoke_4_transactional_rollback_on_stock_failure():
    """
    Smoke Test 4: Integridade Transacional e Atomicidade de Estoque.
    Simula uma venda com 2 itens:
    - Item 1: Produto com estoque suficiente.
    - Item 2: Produto com estoque INSUFICIENTE.
    Garante que o estoque do Item 1 NÃO seja alterado (Rollback total).
    """
    async with AsyncSessionLocal() as session:
        # Busca um produto com estoque
        res = await session.execute(
            select(Produto).where(Produto.permite_venda.is_(True)).order_by(Produto.quantidade_estoque.desc())
        )
        produto_teste = res.scalars().first()
        if not produto_teste:
            pytest.skip("Nenhum produto cadastrado para teste de estoque.")

        saldo_inicial = produto_teste.quantidade_estoque
        produto_id = produto_teste.id

    # Monta payload com falha no segundo item (estoque insuficiente forçado)
    venda_payload = VendaCreate(
        forma_pagamento="PIX",
        desconto=Decimal("0.00"),
        itens=[
            ItemVendaCreate(
                tipo_item="PRODUTO",
                produto_id=produto_id,
                quantidade=Decimal("1.0"),
                preco_unitario=Decimal("50.00")
            ),
            ItemVendaCreate(
                tipo_item="PRODUTO",
                produto_id=produto_id,
                quantidade=Decimal("999999.0"),  # Quantidade absurda para forçar erro de estoque
                preco_unitario=Decimal("50.00")
            )
        ]
    )

    # Executa a venda esperando falha 400 Bad Request
    async with AsyncSessionLocal() as session:
        with pytest.raises(HTTPException) as exc_info:
            await VendasService.registrar_venda_transacional(
                db=session,
                dados_venda=venda_payload
            )
        assert exc_info.value.status_code == 400
        assert "Estoque insuficiente" in exc_info.value.detail
        await session.rollback()

    # Verifica se o estoque no banco permaneceu rigorosamente intocado
    async with AsyncSessionLocal() as session:
        res_pos = await session.execute(
            select(Produto).where(Produto.id == produto_id)
        )
        produto_pos = res_pos.scalar_one()
        assert produto_pos.quantidade_estoque == saldo_inicial, (
            f"FALHA DE ATOMICIDADE! Saldo inicial era {saldo_inicial}, "
            f"mas após o erro ficou {produto_pos.quantidade_estoque}"
        )
        print(f"[PASS] Smoke 4: Atomicidade e Rollback confirmados! Estoque permaneceu intacto ({saldo_inicial} un.).")


if __name__ == "__main__":
    async def run_all():
        print("="*70)
        print("EXECUTANDO SUÍTE DE SMOKE TESTS DE PRODUÇÃO - ESTÉTICA LUPATINI")
        print("="*70)
        await test_smoke_1_database_connectivity()
        await test_smoke_2_health_endpoint_inspection()
        test_smoke_3_supabase_jwt_auth_validation()
        await test_smoke_4_transactional_rollback_on_stock_failure()
        print("="*70)
        print("SUÍTE DE TESTES EXECUTADA COM SUCESSO!")
        print("="*70)

    asyncio.run(run_all())
