from uuid import UUID
from decimal import Decimal
from typing import List, Optional, Literal, Dict, Any
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.api.deps import get_db, get_current_user
from app.models.entities import ContaCartao
from app.schemas.financeiro import (
    DespesaCartaoCreate, TransacaoResponse, FaturaCartaoResponse,
    ContaCartaoCreate, ContaCartaoResponse, TransacaoAvulsaCreate
)
from app.services.financeiro_service import FinanceiroService

router = APIRouter()


@router.post(
    "/despesas-cartao",
    response_model=TransacaoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar despesa em cartão de crédito (PF ou PJ) com projeção de faturas",
    description="""
    Registra uma despesa com cálculo automático de parcelas:
    - Segregação mandatória de escopo ('PF' ou 'PJ').
    - Determina faturas de referência ('YYYY-MM') e vencimentos a partir do dia de fechamento e dia de vencimento.
    - Distribuição exata dos centavos de arredondamento.
    """
)
async def registrar_despesa_cartao(
    despesa_in: DespesaCartaoCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> TransacaoResponse:
    return await FinanceiroService.registrar_despesa_cartao(db=db, dados=despesa_in)


@router.get(
    "/faturas/{cartao_id}",
    response_model=FaturaCartaoResponse,
    summary="Consultar fatura do cartão por mês de referência",
    description="Consulta as parcelas e valor total consolidado da fatura de um cartão no formato 'YYYY-MM'."
)
async def consultar_fatura_cartao(
    cartao_id: UUID,
    mes: str = Query(..., pattern=r"^\d{4}-\d{2}$", description="Mês de referência no formato YYYY-MM (ex: 2026-09)"),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> FaturaCartaoResponse:
    return await FinanceiroService.consultar_fatura_cartao(db=db, cartao_id=cartao_id, mes_referencia=mes)


@router.get(
    "/cartoes",
    response_model=List[ContaCartaoResponse],
    summary="Listar cartões de crédito/contas cadastradas",
    description="Permite filtrar cartões por escopo ('PF', 'PJ' ou todos)."
)
async def listar_cartoes(
    escopo: Optional[Literal["PF", "PJ"]] = Query(None, description="Filtro por escopo"),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[ContaCartaoResponse]:
    from sqlalchemy import func
    from app.models.entities import ParcelaFinanceira

    stmt = select(ContaCartao).where(ContaCartao.ativo.is_(True))
    if escopo:
        stmt = stmt.where(ContaCartao.escopo == escopo)
    stmt = stmt.order_by(ContaCartao.nome.asc())
    res = await db.execute(stmt)
    cartoes = res.scalars().all()

    # Agregação única e otimizada de parcelas pendentes por cartão
    stmt_pendentes = (
        select(ParcelaFinanceira.cartao_id, func.coalesce(func.sum(ParcelaFinanceira.valor_parcela), Decimal("0.00")))
        .where(ParcelaFinanceira.status == "PENDENTE")
        .group_by(ParcelaFinanceira.cartao_id)
    )
    res_pendentes = await db.execute(stmt_pendentes)
    utilizados_map = {row[0]: row[1] for row in res_pendentes.all()}

    resultados = []
    for c in cartoes:
        utilizado = Decimal(str(utilizados_map.get(c.id, Decimal("0.00"))))
        limite_total = Decimal(str(c.limite))
        disponivel = max(Decimal("0.00"), limite_total - utilizado)
        resultados.append(
            ContaCartaoResponse(
                id=c.id,
                nome=c.nome,
                escopo=c.escopo,
                dia_fechamento=c.dia_fechamento,
                dia_vencimento=c.dia_vencimento,
                limite=limite_total,
                limite_utilizado=utilizado,
                limite_disponivel=disponivel,
                ativo=c.ativo,
                created_at=c.created_at
            )
        )
    return resultados


@router.post(
    "/cartoes",
    response_model=ContaCartaoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Cadastrar nova conta/cartão com parâmetros de fechamento e vencimento"
)
async def cadastrar_cartao(
    cartao_in: ContaCartaoCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> ContaCartaoResponse:
    cartao = ContaCartao(
        nome=cartao_in.nome,
        escopo=cartao_in.escopo,
        dia_fechamento=cartao_in.dia_fechamento,
        dia_vencimento=cartao_in.dia_vencimento,
        limite=cartao_in.limite,
        ativo=cartao_in.ativo
    )
    db.add(cartao)
    await db.commit()
    await db.refresh(cartao)
    return ContaCartaoResponse.model_validate(cartao)


@router.post(
    "/transacoes",
    response_model=TransacaoResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar lançamento financeiro avulso (Despesa ou Receita PJ/PF)",
    description="Permite registrar despesas operacionais da clínica (aluguel, luz, salários) ou despesas pessoais dos sócios sem cartão."
)
async def registrar_transacao_avulsa(
    transacao_in: TransacaoAvulsaCreate,
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> TransacaoResponse:
    from app.models.entities import TransacaoFinanceira
    transacao = TransacaoFinanceira(
        descricao=transacao_in.descricao,
        escopo=transacao_in.escopo,
        tipo=transacao_in.tipo,
        categoria_id=transacao_in.categoria_id,
        valor_total=transacao_in.valor_total,
        parcelas=1,
        data_competencia=transacao_in.data_competencia
    )
    db.add(transacao)
    await db.commit()
    await db.refresh(transacao)
    return TransacaoResponse(
        id=transacao.id,
        descricao=transacao.descricao,
        escopo=transacao.escopo,
        tipo=transacao.tipo,
        categoria_id=transacao.categoria_id,
        cartao_id=None,
        valor_total=transacao.valor_total,
        parcelas=1,
        data_competencia=transacao.data_competencia,
        parcelas_rel=[]
    )


@router.get(
    "/transacoes",
    response_model=List[TransacaoResponse],
    summary="Listar transações financeiras recentes"
)
async def listar_transacoes(
    escopo: Optional[Literal["PF", "PJ"]] = Query(None),
    limite: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    current_user: Dict[str, Any] = Depends(get_current_user)
) -> List[TransacaoResponse]:
    from app.models.entities import TransacaoFinanceira
    stmt = select(TransacaoFinanceira)
    if escopo:
        stmt = stmt.where(TransacaoFinanceira.escopo == escopo)
    stmt = stmt.order_by(TransacaoFinanceira.data_competencia.desc(), TransacaoFinanceira.created_at.desc()).limit(limite)
    res = await db.execute(stmt)
    transacoes = res.scalars().all()
    return [
        TransacaoResponse(
            id=t.id,
            descricao=t.descricao,
            escopo=t.escopo,
            tipo=t.tipo,
            categoria_id=t.categoria_id,
            cartao_id=t.cartao_id,
            valor_total=t.valor_total,
            parcelas=t.parcelas,
            data_competencia=t.data_competencia,
            parcelas_rel=[]
        ) for t in transacoes
    ]
