from typing import Dict, Any
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_db, get_current_user
from app.schemas.relatorios import DREResumidoResponse, DashboardResumoResponse
from app.services.financeiro_service import FinanceiroService

router = APIRouter()


@router.get(
    "/dashboard-resumo",
    response_model=DashboardResumoResponse,
    summary="Resumo Consolidado do Dashboard em Consulta Agregada Única",
    description="""
    Retorna todo o sumário executivo em alta performance (single query agregada):
    - DRE completo (faturamento PJ, custos CPV/CIS, despesas PJ e gastos PF).
    - Métricas diretas de resumo (faturado PJ, despesas PF, balanço líquido).
    - Contagem e listagem dos alertas de estoque crítico.
    """
)
async def obter_dashboard_resumo(
    mes: str = Query(..., pattern=r"^\d{4}-\d{2}$", description="Mês de competência no formato YYYY-MM (ex: 2026-09)"),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> DashboardResumoResponse:
    return await FinanceiroService.obter_dashboard_resumo(db=db, mes_referencia=mes)


@router.get(
    "/dre-mensal",
    response_model=DREResumidoResponse,
    summary="Demonstrativo de Resultado do Exercício (DRE) Mensal",
    description="""
    Gera o DRE gerencial do mês segregando:
    - Receita Bruta e Líquida de vendas e procedimentos.
    - Custos de produtos vendidos (CPV) e custos de insumos técnicos consumidos (CIS).
    - Despesas Operacionais da Clínica (PJ).
    - Gastos Pessoais dos Sócios (PF) isolados com precisão.
    - Saldo final consolidado.
    """
)
async def obter_dre_mensal(
    mes: str = Query(..., pattern=r"^\d{4}-\d{2}$", description="Mês de competência no formato YYYY-MM (ex: 2026-09)"),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> DREResumidoResponse:
    return await FinanceiroService.calcular_dre_mensal(db=db, mes_referencia=mes)
