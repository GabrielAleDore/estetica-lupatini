from decimal import Decimal
from typing import List, Dict, Any
from uuid import UUID
from datetime import datetime, date
from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models.entities import (
    Venda, ItemVenda, Produto, Servico, ServicoInsumo,
    MovimentacaoEstoque, TransacaoFinanceira, ParcelaFinanceira, ContaCartao, Cliente
)
from app.schemas.venda import VendaCreate, VendaResponse, ItemVendaResponse
from app.services.cartao_service import CartaoEngineService


class VendasService:
    @staticmethod
    async def registrar_venda_transacional(
        db: AsyncSession,
        dados_venda: VendaCreate,
        operador: Dict[str, Any] = None
    ) -> VendaResponse:
        """
        Executa a venda atômica no PDV com:
        1. Validação de cliente.
        2. Bloqueio pessimista de estoque (SELECT ... FOR UPDATE) para evitar race condition.
        3. Baixa atômica de produtos comercializados (tipo 'SAIDA').
        4. Baixa atômica dos insumos técnicos consumidos por serviços (tipo 'CONSUMO').
        5. Persistência de Venda e Itens da Venda.
        6. Registro contábil da receita em Transações Financeiras (Escopo 'PJ').
        """
        # 1. Validar Cliente se fornecido
        cliente_nome = None
        if dados_venda.cliente_id:
            res_cliente = await db.execute(
                select(Cliente).where(Cliente.id == dados_venda.cliente_id)
            )
            cliente = res_cliente.scalar_one_or_none()
            if not cliente:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Cliente {dados_venda.cliente_id} não encontrado."
                )
            cliente_nome = cliente.nome

        # Inicializa lista de itens, movimentações e cálculo de valor bruto
        itens_para_persistir: List[ItemVenda] = []
        movimentacoes_para_persistir: List[MovimentacaoEstoque] = []
        valor_bruto_acumulado = Decimal("0.00")

        # 2. Processar cada item da venda
        for item_in in dados_venda.itens:
            if item_in.tipo_item == "PRODUTO":
                # Bloqueio com FOR UPDATE para concorrência segura
                stmt = select(Produto).where(Produto.id == item_in.produto_id).with_for_update()
                res_prod = await db.execute(stmt)
                produto = res_prod.scalar_one_or_none()

                if not produto:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"Produto com ID {item_in.produto_id} não encontrado."
                    )
                if not produto.permite_venda:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"O item '{produto.nome}' é um insumo técnico de uso interno e não permite venda direta."
                    )
                
                # Validação de estoque disponível
                if produto.quantidade_estoque < item_in.quantidade:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=(
                            f"Estoque insuficiente para o produto '{produto.nome}'. "
                            f"Saldo disponível: {produto.quantidade_estoque} {produto.unidade_medida}, "
                            f"solicitado: {item_in.quantidade} {produto.unidade_medida}."
                        )
                    )

                preco_unit = item_in.preco_unitario if item_in.preco_unitario is not None else produto.preco_venda
                subtotal = (preco_unit * item_in.quantidade).quantize(Decimal("0.01"))
                valor_bruto_acumulado += subtotal

                # Baixa do estoque
                saldo_ant = produto.quantidade_estoque
                saldo_pos = saldo_ant - item_in.quantidade
                produto.quantidade_estoque = saldo_pos

                movimentacoes_para_persistir.append(
                    MovimentacaoEstoque(
                        produto_id=produto.id,
                        tipo="SAIDA",
                        quantidade=item_in.quantidade,
                        saldo_anterior=saldo_ant,
                        saldo_posterior=saldo_pos,
                        motivo=f"Venda direta PDV - {produto.nome}"
                    )
                )

                itens_para_persistir.append(
                    ItemVenda(
                        tipo_item="PRODUTO",
                        produto_id=produto.id,
                        quantidade=item_in.quantidade,
                        preco_unitario=preco_unit,
                        subtotal=subtotal
                    )
                )

            elif item_in.tipo_item == "SERVICO":
                # Consulta serviço com seus insumos associados
                stmt_servico = (
                    select(Servico)
                    .options(selectinload(Servico.insumos))
                    .where(Servico.id == item_in.servico_id)
                )
                res_serv = await db.execute(stmt_servico)
                servico = res_serv.scalar_one_or_none()

                if not servico:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=f"Serviço com ID {item_in.servico_id} não encontrado."
                    )
                if not servico.ativo:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=f"O serviço '{servico.nome}' está inativo no catálogo."
                    )

                preco_unit = item_in.preco_unitario if item_in.preco_unitario is not None else servico.preco
                subtotal = (preco_unit * item_in.quantidade).quantize(Decimal("0.01"))
                valor_bruto_acumulado += subtotal

                # Baixa automática dos insumos técnicos exigidos por este procedimento
                for insumo in servico.insumos:
                    qtd_necessaria_total = insumo.quantidade_consumo * item_in.quantidade
                    
                    # Bloqueio pessimista do produto insumo
                    stmt_insumo = select(Produto).where(Produto.id == insumo.produto_id).with_for_update()
                    res_insumo = await db.execute(stmt_insumo)
                    prod_insumo = res_insumo.scalar_one_or_none()

                    if not prod_insumo:
                        raise HTTPException(
                            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                            detail=f"Insumo técnico ID {insumo.produto_id} não cadastrado no estoque."
                        )
                    
                    if prod_insumo.quantidade_estoque < qtd_necessaria_total:
                        raise HTTPException(
                            status_code=status.HTTP_400_BAD_REQUEST,
                            detail=(
                                f"Estoque insuficiente de insumo técnico: '{prod_insumo.nome}' "
                                f"para realizar '{servico.nome}'. "
                                f"Disponível: {prod_insumo.quantidade_estoque} {prod_insumo.unidade_medida}, "
                                f"necessário: {qtd_necessaria_total} {prod_insumo.unidade_medida}."
                            )
                        )

                    saldo_ant = prod_insumo.quantidade_estoque
                    saldo_pos = saldo_ant - qtd_necessaria_total
                    prod_insumo.quantidade_estoque = saldo_pos

                    movimentacoes_para_persistir.append(
                        MovimentacaoEstoque(
                            produto_id=prod_insumo.id,
                            tipo="CONSUMO",
                            quantidade=qtd_necessaria_total,
                            saldo_anterior=saldo_ant,
                            saldo_posterior=saldo_pos,
                            motivo=f"Consumo técnico no serviço '{servico.nome}'"
                        )
                    )

                itens_para_persistir.append(
                    ItemVenda(
                        tipo_item="SERVICO",
                        servico_id=servico.id,
                        quantidade=item_in.quantidade,
                        preco_unitario=preco_unit,
                        subtotal=subtotal
                    )
                )

        # 3. Fechamento dos Valores com validação de teto de desconto
        valor_desconto = dados_venda.desconto
        if valor_desconto > valor_bruto_acumulado:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Desconto (R$ {valor_desconto}) não pode ser maior que o valor bruto da venda (R$ {valor_bruto_acumulado})."
            )
        if valor_bruto_acumulado > 0 and (valor_desconto / valor_bruto_acumulado) > Decimal("0.50"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Desconto concedido ({(valor_desconto / valor_bruto_acumulado * 100):.1f}%) excede o teto operacional permitido (50%). Solicite aprovação gerencial."
            )

        valor_liquido = valor_bruto_acumulado - valor_desconto

        # 4. Criar Venda
        nova_venda = Venda(
            cliente_id=dados_venda.cliente_id,
            data_hora=datetime.utcnow(),
            valor_bruto=valor_bruto_acumulado,
            desconto=valor_desconto,
            valor_liquido=valor_liquido,
            forma_pagamento=dados_venda.forma_pagamento,
            status="CONCLUIDA",
            observacoes=dados_venda.observacoes
        )
        db.add(nova_venda)
        await db.flush()  # Gera o UUID da venda

        # Vincular itens e movimentações à venda recém-criada
        for item in itens_para_persistir:
            item.venda_id = nova_venda.id
            db.add(item)

        for mov in movimentacoes_para_persistir:
            mov.venda_id = nova_venda.id
            db.add(mov)

        # 5. Gerar Lançamento Financeiro de Receita Clínica (PJ)
        transacao_receita = TransacaoFinanceira(
            descricao=f"Receita Venda PDV #{str(nova_venda.id)[:8]}",
            escopo="PJ",  # Toda venda da clínica é estritamente PJ
            tipo="ENTRADA",
            venda_id=nova_venda.id,
            cartao_id=dados_venda.cartao_id,
            valor_total=valor_liquido,
            parcelas=dados_venda.parcelas,
            data_competencia=date.today()
        )
        db.add(transacao_receita)
        await db.flush()

        # Se houver parcelamento no cartão de crédito na venda
        if dados_venda.forma_pagamento == "CARTAO_CREDITO" and dados_venda.cartao_id and dados_venda.parcelas > 0:
            res_cartao = await db.execute(
                select(ContaCartao).where(ContaCartao.id == dados_venda.cartao_id)
            )
            cartao = res_cartao.scalar_one_or_none()
            if not cartao:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f"Cartão de crédito com ID '{dados_venda.cartao_id}' não foi encontrado no sistema."
                )
            
            projecao = CartaoEngineService.projetar_parcelas(
                valor_total=valor_liquido,
                numero_parcelas=dados_venda.parcelas,
                data_compra=date.today(),
                dia_fechamento=cartao.dia_fechamento,
                dia_vencimento=cartao.dia_vencimento,
                cartao_id=cartao.id
            )
            for p in projecao:
                parcela_db = ParcelaFinanceira(
                    transacao_id=transacao_receita.id,
                    cartao_id=cartao.id,
                    numero_parcela=p.numero_parcela,
                    valor_parcela=p.valor_parcela,
                    data_vencimento=p.data_vencimento,
                    status="PENDENTE",
                    mes_fatura_referencia=p.mes_fatura_referencia
                )
                db.add(parcela_db)

        await db.commit()

        # Monta resposta tipada
        itens_resp: List[ItemVendaResponse] = []
        for it in itens_para_persistir:
            itens_resp.append(
                ItemVendaResponse(
                    id=it.id,
                    tipo_item=it.tipo_item,
                    produto_id=it.produto_id,
                    servico_id=it.servico_id,
                    quantidade=it.quantidade,
                    preco_unitario=it.preco_unitario,
                    subtotal=it.subtotal
                )
            )

        return VendaResponse(
            id=nova_venda.id,
            cliente_id=nova_venda.cliente_id,
            cliente_nome=cliente_nome,
            data_hora=nova_venda.data_hora,
            valor_bruto=nova_venda.valor_bruto,
            desconto=nova_venda.desconto,
            valor_liquido=nova_venda.valor_liquido,
            forma_pagamento=nova_venda.forma_pagamento,
            status=nova_venda.status,
            observacoes=nova_venda.observacoes,
            itens=itens_resp,
            movimentacoes_geradas=len(movimentacoes_para_persistir),
            transacao_id=transacao_receita.id
        )
