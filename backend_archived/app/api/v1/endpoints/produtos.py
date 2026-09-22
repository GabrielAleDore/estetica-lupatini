from uuid import UUID
from decimal import Decimal
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, status, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, delete
from sqlalchemy.orm import selectinload

from app.api.deps import get_db, get_current_user
from app.models.entities import Produto, MovimentacaoEstoque, Categoria
from app.schemas.produto import (
    AlertaEstoqueResponse, ProdutoResponse, ProdutoCreate, ProdutoUpdate
)

router = APIRouter()


class EntradaEstoqueRequest(BaseModel):
    quantidade: Decimal = Field(gt=0, description="Quantidade comprada / adicionada ao estoque")
    custo_unitario: Optional[Decimal] = Field(ge=0, default=None, description="Novo custo unitário de compra (opcional)")
    motivo: str = Field(default="Compra de mercadoria / reposição de estoque")


@router.get(
    "/alerta-estoque",
    response_model=List[AlertaEstoqueResponse],
    summary="Listar alertas de estoque crítico ou abaixo do mínimo",
    description="Retorna produtos e insumos cujo saldo em estoque está menor ou igual ao estoque mínimo configurado."
)
async def listar_alertas_estoque(
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[AlertaEstoqueResponse]:
    stmt = (
        select(Produto)
        .where(Produto.quantidade_estoque <= Produto.estoque_minimo)
        .order_by(Produto.quantidade_estoque.asc())
    )
    res = await db.execute(stmt)
    produtos_criticos = res.scalars().all()

    alertas: List[AlertaEstoqueResponse] = []
    for prod in produtos_criticos:
        deficit = prod.estoque_minimo - prod.quantidade_estoque
        status_alerta = "CRITICO" if prod.quantidade_estoque <= 0 else "BAIXO"
        alertas.append(
            AlertaEstoqueResponse(
                id=prod.id,
                nome=prod.nome,
                codigo_barras=prod.codigo_barras,
                quantidade_estoque=prod.quantidade_estoque,
                estoque_minimo=prod.estoque_minimo,
                unidade_medida=prod.unidade_medida,
                deficit=deficit,
                status_alerta=status_alerta
            )
        )
    return alertas


@router.get(
    "",
    response_model=List[ProdutoResponse],
    summary="Listar catálogo de produtos com busca e filtros"
)
async def listar_produtos(
    busca: Optional[str] = Query(None, description="Busca por nome ou código de barras"),
    categoria_id: Optional[UUID] = Query(None, description="Filtro por categoria"),
    apenas_venda: Optional[bool] = Query(None, description="Filtrar por permite_venda"),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[ProdutoResponse]:
    stmt = select(Produto).options(selectinload(Produto.categoria))
    if apenas_venda is not None:
        stmt = stmt.where(Produto.permite_venda.is_(apenas_venda))
    if categoria_id:
        stmt = stmt.where(Produto.categoria_id == categoria_id)
    if busca:
        termo = f"%{busca.strip()}%"
        stmt = stmt.where(
            or_(
                Produto.nome.ilike(termo),
                Produto.codigo_barras.ilike(termo)
            )
        )
    stmt = stmt.order_by(Produto.nome.asc())
    res = await db.execute(stmt)
    produtos = res.scalars().all()

    resultados = []
    for p in produtos:
        resp = ProdutoResponse.model_validate(p)
        resp.categoria_nome = p.categoria.nome if p.categoria else None
        resultados.append(resp)
    return resultados


@router.get(
    "/catalogo-pdv",
    summary="Listar catálogo unificado de procedimentos e produtos para o PDV",
    description="Retorna procedimentos ativos e produtos de revenda para exibição no frente de caixa."
)
async def listar_catalogo_pdv(
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
):
    from app.models.entities import Servico

    # 1. Procedimentos / Serviços Clínicos
    res_servicos = await db.execute(select(Servico).where(Servico.ativo.is_(True)).order_by(Servico.nome.asc()))
    servicos = res_servicos.scalars().all()

    # 2. Produtos
    res_produtos = await db.execute(select(Produto).order_by(Produto.nome.asc()))
    produtos = res_produtos.scalars().all()

    itens = []
    for s in servicos:
        itens.append({
            "id": str(s.id),
            "nome": s.nome,
            "tipo": "servico",
            "preco": float(s.preco),
            "duracao_minutos": s.duracao_minutos,
            "permite_venda": True,
            "quantidade_estoque": 999.0,
            "estoque_minimo": 0.0,
            "unidade_medida": "SESSÃO"
        })

    for p in produtos:
        itens.append({
            "id": str(p.id),
            "nome": p.nome,
            "tipo": "produto",
            "preco": float(p.preco_venda),
            "duracao_minutos": 0,
            "permite_venda": p.permite_venda,
            "quantidade_estoque": float(p.quantidade_estoque),
            "estoque_minimo": float(p.estoque_minimo),
            "unidade_medida": p.unidade_medida
        })

    return itens


@router.get(
    "/{produto_id}",
    response_model=ProdutoResponse,
    summary="Obter detalhes de um produto"
)
async def obter_produto(
    produto_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ProdutoResponse:
    stmt = select(Produto).options(selectinload(Produto.categoria)).where(Produto.id == produto_id)
    res = await db.execute(stmt)
    produto = res.scalar_one_or_none()
    if not produto:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Produto não encontrado.")
    resp = ProdutoResponse.model_validate(produto)
    resp.categoria_nome = produto.categoria.nome if produto.categoria else None
    return resp


@router.post(
    "",
    response_model=ProdutoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastrar novo produto ou insumo"
)
async def cadastrar_produto(
    produto_in: ProdutoCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ProdutoResponse:
    # Verifica unicidade do código de barras se informado
    if produto_in.codigo_barras:
        stmt_check = select(Produto).where(Produto.codigo_barras == produto_in.codigo_barras.strip())
        res_check = await db.execute(stmt_check)
        if res_check.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Código de barras '{produto_in.codigo_barras}' já cadastrado."
            )

    novo_produto = Produto(
        nome=produto_in.nome.strip(),
        categoria_id=produto_in.categoria_id,
        codigo_barras=produto_in.codigo_barras.strip() if produto_in.codigo_barras else None,
        preco_custo=produto_in.preco_custo,
        preco_venda=produto_in.preco_venda,
        quantidade_estoque=produto_in.quantidade_estoque,
        estoque_minimo=produto_in.estoque_minimo,
        permite_venda=produto_in.permite_venda,
        unidade_medida=produto_in.unidade_medida.strip().upper()
    )
    db.add(novo_produto)
    await db.commit()
    await db.refresh(novo_produto)

    # Se teve estoque inicial > 0, cria movimentação de entrada inicial
    if produto_in.quantidade_estoque > 0:
        mov = MovimentacaoEstoque(
            produto_id=novo_produto.id,
            tipo="ENTRADA",
            quantidade=produto_in.quantidade_estoque,
            saldo_anterior=Decimal("0.000"),
            saldo_posterior=produto_in.quantidade_estoque,
            motivo="Saldo inicial de implantação de catálogo"
        )
        db.add(mov)
        await db.commit()

    return ProdutoResponse.model_validate(novo_produto)


@router.put(
    "/{produto_id}",
    response_model=ProdutoResponse,
    summary="Atualizar produto ou insumo"
)
async def atualizar_produto(
    produto_id: UUID,
    produto_in: ProdutoUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ProdutoResponse:
    stmt = select(Produto).where(Produto.id == produto_id)
    res = await db.execute(stmt)
    produto = res.scalar_one_or_none()
    if not produto:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Produto não encontrado.")

    if produto_in.codigo_barras is not None:
        cb = produto_in.codigo_barras.strip() if produto_in.codigo_barras else None
        if cb and cb != produto.codigo_barras:
            stmt_cb = select(Produto).where(Produto.codigo_barras == cb)
            res_cb = await db.execute(stmt_cb)
            if res_cb.scalar_one_or_none():
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Código de barras '{cb}' já cadastrado."
                )
        produto.codigo_barras = cb

    if produto_in.nome is not None:
        produto.nome = produto_in.nome.strip()
    if produto_in.categoria_id is not None:
        produto.categoria_id = produto_in.categoria_id
    if produto_in.preco_custo is not None:
        produto.preco_custo = produto_in.preco_custo
    if produto_in.preco_venda is not None:
        produto.preco_venda = produto_in.preco_venda
    if produto_in.quantidade_estoque is not None:
        produto.quantidade_estoque = produto_in.quantidade_estoque
    if produto_in.estoque_minimo is not None:
        produto.estoque_minimo = produto_in.estoque_minimo
    if produto_in.permite_venda is not None:
        produto.permite_venda = produto_in.permite_venda
    if produto_in.unidade_medida is not None:
        produto.unidade_medida = produto_in.unidade_medida.strip().upper()

    await db.commit()
    await db.refresh(produto)
    return ProdutoResponse.model_validate(produto)


@router.delete(
    "/{produto_id}",
    status_code=status.HTTP_200_OK,
    summary="Excluir ou desativar produto"
)
async def excluir_produto(
    produto_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    stmt = select(Produto).where(Produto.id == produto_id)
    res = await db.execute(stmt)
    produto = res.scalar_one_or_none()
    if not produto:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Produto não encontrado.")

    # Se já tiver movimentações de estoque, desativa para preservar integridade contábil
    stmt_mov = select(MovimentacaoEstoque).where(MovimentacaoEstoque.produto_id == produto_id).limit(1)
    res_mov = await db.execute(stmt_mov)
    if res_mov.scalar_one_or_none():
        produto.permite_venda = False
        await db.commit()
        return {"message": "Produto possui histórico financeiro/estoque e foi desativado para vendas.", "id": str(produto_id), "desativado": True}

    await db.delete(produto)
    await db.commit()
    return {"message": "Produto removido com sucesso.", "id": str(produto_id), "excluido": True}


@router.post(
    "/{produto_id}/entrada-estoque",
    response_model=ProdutoResponse,
    summary="Registrar entrada de mercadoria / compra para reposição de estoque"
)
async def registrar_entrada_estoque(
    produto_id: UUID,
    entrada_in: EntradaEstoqueRequest,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ProdutoResponse:
    stmt = select(Produto).where(Produto.id == produto_id).with_for_update()
    res = await db.execute(stmt)
    produto = res.scalar_one_or_none()
    if not produto:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Produto não encontrado.")
    
    saldo_antigo = produto.quantidade_estoque
    saldo_novo = saldo_antigo + entrada_in.quantidade
    produto.quantidade_estoque = saldo_novo
    
    if entrada_in.custo_unitario is not None and entrada_in.custo_unitario > 0:
        produto.preco_custo = entrada_in.custo_unitario
        
    mov = MovimentacaoEstoque(
        produto_id=produto.id,
        tipo="ENTRADA",
        quantidade=entrada_in.quantidade,
        saldo_anterior=saldo_antigo,
        saldo_posterior=saldo_novo,
        motivo=entrada_in.motivo
    )
    db.add(mov)
    await db.commit()
    await db.refresh(produto)
    return ProdutoResponse.model_validate(produto)
