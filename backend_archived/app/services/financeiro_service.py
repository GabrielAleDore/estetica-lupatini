from uuid import UUID
from datetime import date, datetime
from decimal import Decimal
from typing import List, Optional
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, text
from sqlalchemy.orm import selectinload

from app.models.entities import (
    ContaCartao, TransacaoFinanceira, ParcelaFinanceira, Venda, ItemVenda,
    MovimentacaoEstoque, Produto
)
from app.schemas.financeiro import (
    DespesaCartaoCreate, TransacaoResponse, ParcelaResponse,
    FaturaCartaoResponse, ConciliacaoFinanceiraResponse
)
from app.schemas.produto import AlertaEstoqueResponse
from app.schemas.relatorios import DREResumidoResponse, DashboardResumoResponse
from app.services.cartao_service import CartaoEngineService


class FinanceiroService:
    @staticmethod
    async def registrar_despesa_cartao(
        db: AsyncSession,
        dados: DespesaCartaoCreate
    ) -> TransacaoResponse:
        """
        Registra uma despesa em cartão de crédito (PF ou PJ), projeta as N parcelas
        com base no fechamento/vencimento e persiste tudo no banco de dados.
        """
        # 1. Obter e validar o cartão informado
        res_cartao = await db.execute(
            select(ContaCartao).where(ContaCartao.id == dados.cartao_id)
        )
        cartao = res_cartao.scalar_one_or_none()
        if not cartao:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Cartão de crédito {dados.cartao_id} não encontrado."
            )
        
        # Validação cruzada de escopo se o cartão tiver escopo pré-definido
        if cartao.escopo != dados.escopo:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"Incompatibilidade de escopo: O cartão '{cartao.nome}' é de uso estrito "
                    f"'{cartao.escopo}', mas a despesa foi informada como '{dados.escopo}'."
                )
            )

        # 2. Criar Transação Mestre
        transacao = TransacaoFinanceira(
            descricao=dados.descricao,
            escopo=dados.escopo,
            tipo="SAIDA",
            categoria_id=dados.categoria_id,
            cartao_id=cartao.id,
            valor_total=dados.valor_total,
            parcelas=dados.parcelas,
            data_competencia=dados.data_compra
        )
        db.add(transacao)
        await db.flush()

        # 3. Projetar Parcelas pelo Motor Financeiro
        parcelas_calculadas = CartaoEngineService.projetar_parcelas(
            valor_total=dados.valor_total,
            numero_parcelas=dados.parcelas,
            data_compra=dados.data_compra,
            dia_fechamento=cartao.dia_fechamento,
            dia_vencimento=cartao.dia_vencimento,
            cartao_id=cartao.id
        )

        # 4. Persistir Parcelas no Banco
        parcelas_db: List[ParcelaFinanceira] = []
        for p in parcelas_calculadas:
            parcela_entity = ParcelaFinanceira(
                transacao_id=transacao.id,
                cartao_id=cartao.id,
                numero_parcela=p.numero_parcela,
                valor_parcela=p.valor_parcela,
                data_vencimento=p.data_vencimento,
                status="PENDENTE",
                mes_fatura_referencia=p.mes_fatura_referencia
            )
            db.add(parcela_entity)
            parcelas_db.append(parcela_entity)

        await db.commit()

        # Monta resposta
        parcelas_resp = [
            ParcelaResponse(
                id=p.id,
                transacao_id=transacao.id,
                cartao_id=cartao.id,
                numero_parcela=p.numero_parcela,
                valor_parcela=p.valor_parcela,
                data_vencimento=p.data_vencimento,
                status=p.status,
                mes_fatura_referencia=p.mes_fatura_referencia
            ) for p in parcelas_db
        ]

        return TransacaoResponse(
            id=transacao.id,
            descricao=transacao.descricao,
            escopo=transacao.escopo,
            tipo=transacao.tipo,
            categoria_id=transacao.categoria_id,
            cartao_id=transacao.cartao_id,
            valor_total=transacao.valor_total,
            parcelas=transacao.parcelas,
            data_competencia=transacao.data_competencia,
            parcelas_rel=parcelas_resp
        )

    @staticmethod
    async def consultar_fatura_cartao(
        db: AsyncSession,
        cartao_id: UUID,
        mes_referencia: str
    ) -> FaturaCartaoResponse:
        """
        Retorna o agrupamento da fatura de um cartão para o mês YYYY-MM solicitado.
        """
        res_cartao = await db.execute(
            select(ContaCartao).where(ContaCartao.id == cartao_id)
        )
        cartao = res_cartao.scalar_one_or_none()
        if not cartao:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Cartão não encontrado."
            )

        stmt = (
            select(ParcelaFinanceira)
            .where(
                and_(
                    ParcelaFinanceira.cartao_id == cartao_id,
                    ParcelaFinanceira.mes_fatura_referencia == mes_referencia
                )
            )
            .order_by(ParcelaFinanceira.data_vencimento.asc())
        )
        res_parcelas = await db.execute(stmt)
        parcelas = res_parcelas.scalars().all()

        total = sum((p.valor_parcela for p in parcelas), Decimal("0.00"))

        # Determina datas estimadas da fatura
        ano, mes = map(int, mes_referencia.split("-"))
        data_vencimento = date(ano, mes, min(cartao.dia_vencimento, 28))
        data_fechamento = date(ano, mes, min(cartao.dia_fechamento, 28))

        status_fatura = "ABERTA"
        if date.today() > data_fechamento:
            status_fatura = "FECHADA"
        if parcelas and all(p.status == "PAGA" for p in parcelas):
            status_fatura = "PAGA"

        parcelas_dto = [
            ParcelaResponse(
                id=p.id,
                transacao_id=p.transacao_id,
                cartao_id=p.cartao_id,
                numero_parcela=p.numero_parcela,
                valor_parcela=p.valor_parcela,
                data_vencimento=p.data_vencimento,
                status=p.status,
                mes_fatura_referencia=p.mes_fatura_referencia,
                data_pagamento=p.data_pagamento
            ) for p in parcelas
        ]

        # Calcula limites do cartão
        stmt_utilizado = (
            select(func.coalesce(func.sum(ParcelaFinanceira.valor_parcela), Decimal("0.00")))
            .where(
                and_(
                    ParcelaFinanceira.cartao_id == cartao_id,
                    ParcelaFinanceira.status == "PENDENTE"
                )
            )
        )
        res_utilizado = await db.execute(stmt_utilizado)
        limite_utilizado = Decimal(str(res_utilizado.scalar_one()))
        limite_total = Decimal(str(cartao.limite))
        limite_disponivel = max(Decimal("0.00"), limite_total - limite_utilizado)

        return FaturaCartaoResponse(
            cartao_id=cartao.id,
            cartao_nome=cartao.nome,
            escopo=cartao.escopo,
            mes_referencia=mes_referencia,
            valor_total=total,
            limite_total=limite_total,
            limite_utilizado=limite_utilizado,
            limite_disponivel=limite_disponivel,
            data_fechamento_estimada=data_fechamento,
            data_vencimento_real=data_vencimento,
            status_fatura=status_fatura,
            parcelas=parcelas_dto
        )

    @staticmethod
    async def calcular_dre_mensal(
        db: AsyncSession,
        mes_referencia: str  # 'YYYY-MM'
    ) -> DREResumidoResponse:
        """
        Calcula o DRE Gerencial do mês com segregação cirúrgica entre a clínica (PJ)
        e retiradas/gastos dos sócios (PF).
        """
        ano, mes = map(int, mes_referencia.split("-"))
        primeiro_dia = date(ano, mes, 1)
        if mes == 12:
            ultimo_dia = date(ano + 1, 1, 1)
        else:
            ultimo_dia = date(ano, mes + 1, 1)

        # 1. Faturamento Bruto e Descontos (Vendas no mês)
        stmt_vendas = (
            select(
                func.coalesce(func.sum(Venda.valor_bruto), Decimal("0.00")),
                func.coalesce(func.sum(Venda.desconto), Decimal("0.00")),
                func.coalesce(func.sum(Venda.valor_liquido), Decimal("0.00"))
            )
            .where(
                and_(
                    Venda.data_hora >= datetime.combine(primeiro_dia, datetime.min.time()),
                    Venda.data_hora < datetime.combine(ultimo_dia, datetime.min.time()),
                    Venda.status == "CONCLUIDA"
                )
            )
        )
        res_vendas = await db.execute(stmt_vendas)
        receita_bruta, descontos, receita_liquida = res_vendas.one()

        # 2. Custos Variáveis Técnicos (CPV e CIS via Movimentações de Estoque no mês)
        # 2.1 Produtos de revenda vendidos (tipo SAIDA associados a vendas)
        stmt_cpv = (
            select(func.coalesce(func.sum(MovimentacaoEstoque.quantidade * Produto.preco_custo), Decimal("0.00")))
            .join(Produto, MovimentacaoEstoque.produto_id == Produto.id)
            .where(
                and_(
                    MovimentacaoEstoque.tipo == "SAIDA",
                    MovimentacaoEstoque.created_at >= datetime.combine(primeiro_dia, datetime.min.time()),
                    MovimentacaoEstoque.created_at < datetime.combine(ultimo_dia, datetime.min.time())
                )
            )
        )
        res_cpv = await db.execute(stmt_cpv)
        custo_produtos = res_cpv.scalar_one()

        # 2.2 Insumos técnicos consumidos em procedimentos (tipo CONSUMO)
        stmt_cis = (
            select(func.coalesce(func.sum(MovimentacaoEstoque.quantidade * Produto.preco_custo), Decimal("0.00")))
            .join(Produto, MovimentacaoEstoque.produto_id == Produto.id)
            .where(
                and_(
                    MovimentacaoEstoque.tipo == "CONSUMO",
                    MovimentacaoEstoque.created_at >= datetime.combine(primeiro_dia, datetime.min.time()),
                    MovimentacaoEstoque.created_at < datetime.combine(ultimo_dia, datetime.min.time())
                )
            )
        )
        res_cis = await db.execute(stmt_cis)
        custo_insumos = res_cis.scalar_one()

        custo_total_var = custo_produtos + custo_insumos
        lucro_bruto_pj = receita_liquida - custo_total_var

        # 3. Despesas Fixas e Operacionais da Clínica (PJ)
        stmt_desp_pj = (
            select(func.coalesce(func.sum(TransacaoFinanceira.valor_total), Decimal("0.00")))
            .where(
                and_(
                    TransacaoFinanceira.escopo == "PJ",
                    TransacaoFinanceira.tipo == "SAIDA",
                    TransacaoFinanceira.data_competencia >= primeiro_dia,
                    TransacaoFinanceira.data_competencia < ultimo_dia
                )
            )
        )
        res_desp_pj = await db.execute(stmt_desp_pj)
        despesas_pj = res_desp_pj.scalar_one()

        resultado_operacional_pj = lucro_bruto_pj - despesas_pj
        margem_pct = (float(resultado_operacional_pj / receita_liquida) * 100) if receita_liquida > 0 else 0.0

        # 4. Gastos Pessoais dos Sócios (PF) - Estritamente segregados
        stmt_gastos_pf = (
            select(func.coalesce(func.sum(TransacaoFinanceira.valor_total), Decimal("0.00")))
            .where(
                and_(
                    TransacaoFinanceira.escopo == "PF",
                    TransacaoFinanceira.tipo == "SAIDA",
                    TransacaoFinanceira.data_competencia >= primeiro_dia,
                    TransacaoFinanceira.data_competencia < ultimo_dia
                )
            )
        )
        res_pf = await db.execute(stmt_gastos_pf)
        gastos_pf = res_pf.scalar_one()

        # Saldo Final Líquido
        saldo_final = resultado_operacional_pj - gastos_pf

        return DREResumidoResponse(
            mes_referencia=mes_referencia,
            receita_bruta=receita_bruta,
            descontos_concedidos=descontos,
            receita_liquida=receita_liquida,
            custo_produtos_vendidos=custo_produtos,
            custo_insumos_procedimentos=custo_insumos,
            custo_total_variavel=custo_total_var,
            lucro_bruto_pj=lucro_bruto_pj,
            despesas_operacionais_pj=despesas_pj,
            resultado_operacional_pj=resultado_operacional_pj,
            margem_operacional_percentual=round(margem_pct, 2),
            gastos_pessoais_pf=gastos_pf,
            saldo_caixa_final=saldo_final
        )

    @staticmethod
    async def obter_dashboard_resumo(
        db: AsyncSession,
        mes_referencia: str
    ) -> DashboardResumoResponse:
        """
        Executa query agregada única em alta performance (eliminando N+1) para alimentar
        todo o dashboard executivo em um único roundtrip com o banco.
        """
        ano, mes = map(int, mes_referencia.split("-"))
        primeiro_dia = date(ano, mes, 1)
        if mes == 12:
            ultimo_dia = date(ano + 1, 1, 1)
        else:
            ultimo_dia = date(ano, mes + 1, 1)

        inicio_dt = datetime.combine(primeiro_dia, datetime.min.time())
        fim_dt = datetime.combine(ultimo_dia, datetime.min.time())

        stmt_agg = text('''
            SELECT
              (SELECT COALESCE(SUM(valor_liquido), 0) FROM vendas WHERE status = 'CONCLUIDA' AND data_hora >= :inicio_dt AND data_hora < :fim_dt) AS receita_liquida,
              (SELECT COALESCE(SUM(valor_bruto), 0) FROM vendas WHERE status = 'CONCLUIDA' AND data_hora >= :inicio_dt AND data_hora < :fim_dt) AS receita_bruta,
              (SELECT COALESCE(SUM(desconto), 0) FROM vendas WHERE status = 'CONCLUIDA' AND data_hora >= :inicio_dt AND data_hora < :fim_dt) AS descontos,
              (SELECT COALESCE(SUM(m.quantidade * p.preco_custo), 0) FROM movimentacoes_estoque m JOIN produtos p ON m.produto_id = p.id WHERE m.tipo = 'SAIDA' AND m.created_at >= :inicio_dt AND m.created_at < :fim_dt) AS custo_produtos,
              (SELECT COALESCE(SUM(m.quantidade * p.preco_custo), 0) FROM movimentacoes_estoque m JOIN produtos p ON m.produto_id = p.id WHERE m.tipo = 'CONSUMO' AND m.created_at >= :inicio_dt AND m.created_at < :fim_dt) AS custo_insumos,
              (SELECT COALESCE(SUM(valor_total), 0) FROM transacoes_financeiras WHERE escopo = 'PJ' AND tipo = 'SAIDA' AND data_competencia >= :inicio_d AND data_competencia < :fim_d) AS despesas_pj,
              (SELECT COALESCE(SUM(valor_total), 0) FROM transacoes_financeiras WHERE escopo = 'PF' AND tipo = 'SAIDA' AND data_competencia >= :inicio_d AND data_competencia < :fim_d) AS gastos_pf,
              (SELECT COUNT(*) FROM produtos WHERE quantidade_estoque <= estoque_minimo) AS total_alerta_estoque;
        ''')
        res_agg = await db.execute(stmt_agg, {
            'inicio_dt': inicio_dt,
            'fim_dt': fim_dt,
            'inicio_d': primeiro_dia,
            'fim_d': ultimo_dia
        })
        row = res_agg.mappings().one()

        receita_liquida = Decimal(str(row['receita_liquida']))
        receita_bruta = Decimal(str(row['receita_bruta']))
        descontos = Decimal(str(row['descontos']))
        custo_produtos = Decimal(str(row['custo_produtos']))
        custo_insumos = Decimal(str(row['custo_insumos']))
        despesas_pj = Decimal(str(row['despesas_pj']))
        gastos_pf = Decimal(str(row['gastos_pf']))
        total_alerta_estoque = int(row['total_alerta_estoque'])

        custo_total_var = custo_produtos + custo_insumos
        lucro_bruto_pj = receita_liquida - custo_total_var
        resultado_operacional_pj = lucro_bruto_pj - despesas_pj
        margem_pct = (float(resultado_operacional_pj / receita_liquida) * 100) if receita_liquida > 0 else 0.0
        saldo_final = resultado_operacional_pj - gastos_pf

        dre = DREResumidoResponse(
            mes_referencia=mes_referencia,
            receita_bruta=receita_bruta,
            descontos_concedidos=descontos,
            receita_liquida=receita_liquida,
            custo_produtos_vendidos=custo_produtos,
            custo_insumos_procedimentos=custo_insumos,
            custo_total_variavel=custo_total_var,
            lucro_bruto_pj=lucro_bruto_pj,
            despesas_operacionais_pj=despesas_pj,
            resultado_operacional_pj=resultado_operacional_pj,
            margem_operacional_percentual=round(margem_pct, 2),
            gastos_pessoais_pf=gastos_pf,
            saldo_caixa_final=saldo_final
        )

        # Busca os alertas de estoque com query indexada
        stmt_criticos = (
            select(Produto)
            .where(Produto.quantidade_estoque <= Produto.estoque_minimo)
            .order_by(Produto.quantidade_estoque.asc())
            .limit(10)
        )
        res_criticos = await db.execute(stmt_criticos)
        produtos_criticos = res_criticos.scalars().all()
        alertas_dto = []
        for prod in produtos_criticos:
            deficit = prod.estoque_minimo - prod.quantidade_estoque
            status_alerta = "CRITICO" if prod.quantidade_estoque <= 0 else "BAIXO"
            alertas_dto.append(
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

        return DashboardResumoResponse(
            mes_referencia=mes_referencia,
            dre=dre,
            total_itens_alerta_estoque=total_alerta_estoque,
            alertas_estoque=alertas_dto,
            total_faturado_pj=receita_liquida,
            total_despesas_pf=gastos_pf,
            balanco_liquido=saldo_final
        )
