from typing import List, Dict, Any, Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.deps import get_db, get_current_user
from app.models.entities import Categoria
from app.schemas.produto import CategoriaResponse, CategoriaCreate

router = APIRouter()


@router.get(
    "",
    response_model=List[CategoriaResponse],
    summary="Listar categorias da clínica"
)
async def listar_categorias(
    tipo: Optional[str] = Query(None, description="Filtrar por tipo: SERVICO, PRODUTO, DESPESA, RECEITA"),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[CategoriaResponse]:
    stmt = select(Categoria)
    if tipo:
        stmt = stmt.where(Categoria.tipo == tipo)
    stmt = stmt.order_by(Categoria.nome.asc())
    res = await db.execute(stmt)
    categorias = res.scalars().all()
    return [CategoriaResponse.model_validate(c) for c in categorias]


@router.post(
    "",
    response_model=CategoriaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Criar nova categoria"
)
async def criar_categoria(
    cat_in: CategoriaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> CategoriaResponse:
    cat = Categoria(nome=cat_in.nome.strip(), tipo=cat_in.tipo)
    db.add(cat)
    await db.commit()
    await db.refresh(cat)
    return CategoriaResponse.model_validate(cat)
