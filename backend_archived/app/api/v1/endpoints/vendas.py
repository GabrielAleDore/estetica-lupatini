from typing import Any, Dict
from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, get_current_user
from app.schemas.venda import VendaCreate, VendaResponse
from app.services.vendas_service import VendasService

router = APIRouter()


@router.post(
    "",
    response_model=VendaResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar venda transacional no PDV",
    description="""
    Realiza o fechamento de uma venda com múltiplos itens (produtos e serviços):
    - Executa bloqueio pessimista de estoque para evitar concorrência desleal.
    - Executa baixa atômica de produtos comercializados.
    - Executa baixa atômica dos insumos técnicos consumidos em cada serviço realizado.
    - Registra a movimentação de estoque para rastreabilidade/auditoria.
    - Registra a receita clínica PJ no fluxo financeiro.
    """
)
async def criar_venda_pdv(
    venda_in: VendaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> VendaResponse:
    return await VendasService.registrar_venda_transacional(
        db=db,
        dados_venda=venda_in,
        operador=current_user
    )
