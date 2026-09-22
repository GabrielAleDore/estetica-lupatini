from uuid import UUID
from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, status, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_, delete
from sqlalchemy.orm import selectinload

from app.api.deps import get_db, get_current_user
from app.models.entities import Servico, ServicoInsumo, Categoria, Produto
from app.schemas.produto import (
    ServicoCreate, ServicoUpdate, ServicoResponse, ServicoInsumoResponse
)

router = APIRouter()


def _formatar_servico_response(s: Servico) -> ServicoResponse:
    insumos_resp = []
    if s.insumos:
        for ins in s.insumos:
            insumos_resp.append(
                ServicoInsumoResponse(
                    produto_id=ins.produto_id,
                    produto_nome=ins.produto.nome if ins.produto else None,
                    quantidade_consumo=ins.quantidade_consumo,
                    unidade_medida=ins.produto.unidade_medida if ins.produto else "UN"
                )
            )
    return ServicoResponse(
        id=s.id,
        nome=s.nome,
        categoria_id=s.categoria_id,
        categoria_nome=s.categoria.nome if s.categoria else None,
        duracao_minutos=s.duracao_minutos,
        preco=s.preco,
        ativo=s.ativo,
        insumos=insumos_resp,
        created_at=s.created_at,
        updated_at=s.updated_at
    )


@router.get(
    "",
    response_model=List[ServicoResponse],
    summary="Listar serviços e procedimentos estéticos"
)
async def listar_servicos(
    busca: Optional[str] = Query(None, description="Busca por nome"),
    categoria_id: Optional[UUID] = Query(None, description="Filtro por categoria"),
    apenas_ativos: Optional[bool] = Query(None, description="Filtrar por status ativo"),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[ServicoResponse]:
    stmt = (
        select(Servico)
        .options(
            selectinload(Servico.categoria),
            selectinload(Servico.insumos).selectinload(ServicoInsumo.produto)
        )
    )
    if apenas_ativos is not None:
        stmt = stmt.where(Servico.ativo.is_(apenas_ativos))
    if categoria_id:
        stmt = stmt.where(Servico.categoria_id == categoria_id)
    if busca:
        stmt = stmt.where(Servico.nome.ilike(f"%{busca.strip()}%"))
    stmt = stmt.order_by(Servico.nome.asc())

    res = await db.execute(stmt)
    servicos = res.scalars().all()
    return [_formatar_servico_response(s) for s in servicos]


@router.get(
    "/{servico_id}",
    response_model=ServicoResponse,
    summary="Obter detalhes de um procedimento"
)
async def obter_servico(
    servico_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ServicoResponse:
    stmt = (
        select(Servico)
        .options(
            selectinload(Servico.categoria),
            selectinload(Servico.insumos).selectinload(ServicoInsumo.produto)
        )
        .where(Servico.id == servico_id)
    )
    res = await db.execute(stmt)
    servico = res.scalar_one_or_none()
    if not servico:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Serviço não encontrado.")
    return _formatar_servico_response(servico)


@router.post(
    "",
    response_model=ServicoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastrar novo procedimento estético com lista técnica de insumos (BOM)"
)
async def cadastrar_servico(
    servico_in: ServicoCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ServicoResponse:
    novo_servico = Servico(
        nome=servico_in.nome.strip(),
        categoria_id=servico_in.categoria_id,
        duracao_minutos=servico_in.duracao_minutos,
        preco=servico_in.preco,
        ativo=servico_in.ativo
    )
    db.add(novo_servico)
    await db.flush()

    # Vínculo de insumos técnicos
    if servico_in.insumos:
        for ins in servico_in.insumos:
            # Verifica se produto existe
            prod = await db.get(Produto, ins.produto_id)
            if prod:
                item_insumo = ServicoInsumo(
                    servico_id=novo_servico.id,
                    produto_id=ins.produto_id,
                    quantidade_consumo=ins.quantidade_consumo
                )
                db.add(item_insumo)

    await db.commit()
    return await obter_servico(novo_servico.id, db, current_user)


@router.put(
    "/{servico_id}",
    response_model=ServicoResponse,
    summary="Atualizar procedimento estético e seus insumos"
)
async def atualizar_servico(
    servico_id: UUID,
    servico_in: ServicoUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ServicoResponse:
    stmt = select(Servico).where(Servico.id == servico_id)
    res = await db.execute(stmt)
    servico = res.scalar_one_or_none()
    if not servico:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Serviço não encontrado.")

    if servico_in.nome is not None:
        servico.nome = servico_in.nome.strip()
    if servico_in.categoria_id is not None:
        servico.categoria_id = servico_in.categoria_id
    if servico_in.duracao_minutos is not None:
        servico.duracao_minutos = servico_in.duracao_minutos
    if servico_in.preco is not None:
        servico.preco = servico_in.preco
    if servico_in.ativo is not None:
        servico.ativo = servico_in.ativo

    # Atualiza lista técnica de insumos se informada
    if servico_in.insumos is not None:
        await db.execute(delete(ServicoInsumo).where(ServicoInsumo.servico_id == servico_id))
        for ins in servico_in.insumos:
            prod = await db.get(Produto, ins.produto_id)
            if prod:
                item_insumo = ServicoInsumo(
                    servico_id=servico.id,
                    produto_id=ins.produto_id,
                    quantidade_consumo=ins.quantidade_consumo
                )
                db.add(item_insumo)

    await db.commit()
    return await obter_servico(servico_id, db, current_user)


@router.delete(
    "/{servico_id}",
    status_code=status.HTTP_200_OK,
    summary="Excluir ou inativar procedimento estético"
)
async def excluir_servico(
    servico_id: UUID,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    stmt = select(Servico).where(Servico.id == servico_id)
    res = await db.execute(stmt)
    servico = res.scalar_one_or_none()
    if not servico:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Serviço não encontrado.")

    # Soft delete seguro (desativação)
    servico.ativo = False
    await db.commit()
    return {"message": "Procedimento desativado com sucesso.", "id": str(servico_id), "ativo": False}
