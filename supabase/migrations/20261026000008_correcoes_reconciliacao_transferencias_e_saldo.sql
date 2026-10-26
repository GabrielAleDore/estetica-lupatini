-- ==============================================================================
-- Migration: 20261026000008_correcoes_reconciliacao_transferencias_e_saldo.sql
-- Correção de Procedures, Reconciliação Bancária, Transferências, Saldo e PDV
-- ==============================================================================

-- 1. STORED PROCEDURE: RECONCILIAR SALDO DE CONTA BANCÁRIA
CREATE OR REPLACE FUNCTION public.reconciliar_saldo_conta_bancaria(
    p_conta_id UUID
)
RETURNS NUMERIC(12, 2)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_saldo_inicial NUMERIC(12, 2) := 0.00;
    v_total_entradas NUMERIC(12, 2) := 0.00;
    v_total_saidas NUMERIC(12, 2) := 0.00;
    v_saldo_recalculado NUMERIC(12, 2) := 0.00;
BEGIN
    -- 1. Busca saldo inicial da conta
    SELECT saldo_inicial INTO v_saldo_inicial
    FROM public.contas_bancarias
    WHERE id = p_conta_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conta bancária com ID % não encontrada.', p_conta_id;
    END IF;

    -- 2. Total de Entradas Efetivadas / Pagas vinculadas à conta
    SELECT COALESCE(SUM(COALESCE(valor, valor_total, 0.00)), 0.00)
    INTO v_total_entradas
    FROM public.transacoes_financeiras
    WHERE conta_bancaria_id = p_conta_id
      AND tipo IN ('RECEITA', 'ENTRADA')
      AND status IN ('EFETIVADO', 'PAGO');

    -- 3. Total de Saídas Efetivadas / Pagas vinculadas à conta
    SELECT COALESCE(SUM(COALESCE(valor, valor_total, 0.00)), 0.00)
    INTO v_total_saidas
    FROM public.transacoes_financeiras
    WHERE conta_bancaria_id = p_conta_id
      AND tipo IN ('DESPESA', 'SAIDA')
      AND status IN ('EFETIVADO', 'PAGO');

    -- 4. Cálculo do novo saldo matematicamente conciliado
    v_saldo_recalculado := v_saldo_inicial + v_total_entradas - v_total_saidas;

    -- 5. Atualiza o saldo atual da conta
    UPDATE public.contas_bancarias
    SET saldo_atual = v_saldo_recalculado,
        updated_at = NOW()
    WHERE id = p_conta_id;

    RETURN v_saldo_recalculado;
END;
$$;

GRANT EXECUTE ON FUNCTION public.reconciliar_saldo_conta_bancaria(UUID) TO anon, authenticated, service_role;

-- 2. STORED PROCEDURE: REALIZAR TRANSFERÊNCIA ENTRE CONTAS BANCÁRIAS
CREATE OR REPLACE FUNCTION public.realizar_transferencia_bancaria(
    p_conta_origem_id UUID,
    p_conta_destino_id UUID,
    p_valor NUMERIC(12, 2),
    p_data DATE,
    p_descricao TEXT,
    p_escopo VARCHAR(10) DEFAULT 'PJ',
    p_observacoes TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_origem_record RECORD;
    v_destino_record RECORD;
    v_transacao_saida_id UUID := gen_random_uuid();
    v_transacao_entrada_id UUID := gen_random_uuid();
BEGIN
    IF p_valor <= 0.00 THEN
        RAISE EXCEPTION 'O valor da transferência deve ser maior que zero.';
    END IF;

    IF p_conta_origem_id = p_conta_destino_id THEN
        RAISE EXCEPTION 'A conta de origem e destino não podem ser as mesmas.';
    END IF;

    SELECT * INTO v_origem_record FROM public.contas_bancarias WHERE id = p_conta_origem_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conta de origem não encontrada.';
    END IF;

    SELECT * INTO v_destino_record FROM public.contas_bancarias WHERE id = p_conta_destino_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Conta de destino não encontrada.';
    END IF;

    -- Registra a transação de SAÍDA na conta de origem
    INSERT INTO public.transacoes_financeiras (
        id, descricao, escopo, tipo, valor, valor_total, status,
        conta_bancaria_id, data_transacao, data_competencia, data_vencimento, data_pagamento,
        forma_pagamento, origem, observacoes
    ) VALUES (
        v_transacao_saida_id,
        p_descricao || ' (Débito: ' || v_origem_record.nome_conta || ' -> ' || v_destino_record.nome_conta || ')',
        p_escopo,
        'SAIDA',
        p_valor,
        p_valor,
        'PAGO',
        p_conta_origem_id,
        COALESCE(p_data, CURRENT_DATE),
        COALESCE(p_data, CURRENT_DATE),
        COALESCE(p_data, CURRENT_DATE),
        COALESCE(p_data, CURRENT_DATE),
        'TRANSFERENCIA',
        'TRANSFERENCIA',
        p_observacoes
    );

    -- Registra a transação de ENTRADA na conta de destino
    INSERT INTO public.transacoes_financeiras (
        id, descricao, escopo, tipo, valor, valor_total, status,
        conta_bancaria_id, data_transacao, data_competencia, data_vencimento, data_pagamento,
        forma_pagamento, origem, observacoes
    ) VALUES (
        v_transacao_entrada_id,
        p_descricao || ' (Crédito: ' || v_origem_record.nome_conta || ' -> ' || v_destino_record.nome_conta || ')',
        p_escopo,
        'ENTRADA',
        p_valor,
        p_valor,
        'PAGO',
        p_conta_destino_id,
        COALESCE(p_data, CURRENT_DATE),
        COALESCE(p_data, CURRENT_DATE),
        COALESCE(p_data, CURRENT_DATE),
        COALESCE(p_data, CURRENT_DATE),
        'TRANSFERENCIA',
        'TRANSFERENCIA',
        p_observacoes
    );

    RETURN jsonb_build_object(
        'success', true,
        'valor', p_valor,
        'conta_origem_id', p_conta_origem_id,
        'conta_destino_id', p_conta_destino_id,
        'transacao_saida_id', v_transacao_saida_id,
        'transacao_entrada_id', v_transacao_entrada_id,
        'data', COALESCE(p_data, CURRENT_DATE)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.realizar_transferencia_bancaria(UUID, UUID, NUMERIC, DATE, TEXT, VARCHAR, TEXT) TO anon, authenticated, service_role;

-- 3. STORED PROCEDURE: ATUALIZADA DAR BAIXA VENDA PENDENTE (Com Conta Bancária)
CREATE OR REPLACE FUNCTION public.dar_baixa_venda_pendente(
    p_venda_id UUID,
    p_forma_pagamento TEXT,
    p_conta_bancaria_id UUID DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_venda RECORD;
    v_forma_enum forma_pagamento_tipo;
BEGIN
    v_forma_enum := COALESCE(p_forma_pagamento::forma_pagamento_tipo, 'PIX'::forma_pagamento_tipo);

    SELECT * INTO v_venda 
    FROM public.vendas 
    WHERE id = p_venda_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venda com ID % não encontrada.', p_venda_id;
    END IF;

    IF v_venda.status_pagamento = 'EFETIVADO' THEN
        RAISE EXCEPTION 'Esta venda já está liquidada/efetivada.';
    END IF;

    -- Atualiza venda
    UPDATE public.vendas
    SET status_pagamento = 'EFETIVADO',
        forma_pagamento = v_forma_enum
    WHERE id = p_venda_id;

    -- Atualiza transação financeira vinculada
    UPDATE public.transacoes_financeiras
    SET status = 'PAGO',
        data_pagamento = CURRENT_DATE,
        conta_bancaria_id = COALESCE(p_conta_bancaria_id, conta_bancaria_id),
        forma_pagamento = p_forma_pagamento,
        descricao = 'Receita Venda Liquidada #' || UPPER(SUBSTRING(p_venda_id::TEXT FROM 1 FOR 8))
    WHERE venda_id = p_venda_id;

    RETURN jsonb_build_object(
        'success', true,
        'venda_id', p_venda_id,
        'forma_pagamento', p_forma_pagamento,
        'conta_bancaria_id', p_conta_bancaria_id,
        'status', 'EFETIVADO'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dar_baixa_venda_pendente(UUID, TEXT, UUID) TO anon, authenticated, service_role;

-- 4. STORED PROCEDURE ATUALIZADA: REALIZAR_VENDA (Com suporte a conta_bancaria_id)
CREATE OR REPLACE FUNCTION public.realizar_venda(p_venda jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_venda_id UUID := gen_random_uuid();
    v_cliente_id UUID := NULL;
    v_forma_pagamento forma_pagamento_tipo;
    v_desconto NUMERIC(12, 2) := 0.00;
    v_tipo_desconto VARCHAR(30) := 'NENHUM';
    v_observacoes TEXT;
    v_status_pagamento VARCHAR(20) := 'EFETIVADO';
    v_data_prevista DATE := NULL;
    v_cartao_id UUID := NULL;
    v_conta_bancaria_id UUID := NULL;
    v_parcelas INT := 1;
    v_itens jsonb;
    v_item jsonb;
    
    v_tipo_item VARCHAR(20);
    v_prod_id UUID;
    v_serv_id UUID;
    v_qtd NUMERIC(12, 3);
    v_preco_unit NUMERIC(12, 2);
    v_preco_orig NUMERIC(12, 2);
    v_subtotal NUMERIC(12, 2);
    v_item_desconto NUMERIC(12, 2);
    v_item_final NUMERIC(12, 2);
    v_valor_bruto NUMERIC(12, 2) := 0.00;
    v_valor_liquido NUMERIC(12, 2) := 0.00;
    
    v_prod_record RECORD;
    v_serv_record RECORD;
    v_insumo_record RECORD;
    v_qtd_insumo_total NUMERIC(12, 3);
    v_transacao_id UUID;
BEGIN
    IF p_venda IS NULL THEN
        RAISE EXCEPTION 'Dados da venda não fornecidos.';
    END IF;

    IF p_venda->>'cliente_id' IS NOT NULL AND p_venda->>'cliente_id' <> '' THEN
        v_cliente_id := (p_venda->>'cliente_id')::UUID;
    END IF;

    v_forma_pagamento := COALESCE((p_venda->>'forma_pagamento')::forma_pagamento_tipo, 'PIX'::forma_pagamento_tipo);
    v_desconto := COALESCE((p_venda->>'desconto')::NUMERIC, 0.00);
    v_tipo_desconto := COALESCE(p_venda->>'tipo_desconto', 'NENHUM');
    v_observacoes := p_venda->>'observacoes';
    
    IF p_venda->>'status_pagamento' IS NOT NULL THEN
        v_status_pagamento := UPPER(p_venda->>'status_pagamento');
    END IF;

    IF p_venda->>'data_prevista_pagamento' IS NOT NULL AND p_venda->>'data_prevista_pagamento' <> '' THEN
        v_data_prevista := (p_venda->>'data_prevista_pagamento')::DATE;
    END IF;
    
    IF p_venda->>'cartao_id' IS NOT NULL AND p_venda->>'cartao_id' <> '' THEN
        v_cartao_id := (p_venda->>'cartao_id')::UUID;
    END IF;

    IF p_venda->>'conta_bancaria_id' IS NOT NULL AND p_venda->>'conta_bancaria_id' <> '' THEN
        v_conta_bancaria_id := (p_venda->>'conta_bancaria_id')::UUID;
    END IF;

    v_parcelas := COALESCE((p_venda->>'parcelas')::INT, 1);
    
    v_itens := p_venda->'itens';
    IF v_itens IS NULL OR jsonb_array_length(v_itens) = 0 THEN
        RAISE EXCEPTION 'A venda deve conter pelo menos um item.';
    END IF;

    -- 1. Cria a venda inicial
    INSERT INTO public.vendas (
        id, cliente_id, data_hora, valor_bruto, desconto, valor_liquido, 
        valor_original, valor_desconto, tipo_desconto, valor_final,
        forma_pagamento, status, status_pagamento, data_prevista_pagamento, observacoes
    ) VALUES (
        v_venda_id, v_cliente_id, NOW(), 0.00, v_desconto, 0.00,
        0.00, v_desconto, v_tipo_desconto, 0.00,
        v_forma_pagamento, 'CONCLUIDA', v_status_pagamento, v_data_prevista, v_observacoes
    );

    -- 2. Processa itens com baixa atômica de estoque
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_itens)
    LOOP
        v_tipo_item := UPPER(v_item->>'tipo_item');
        v_qtd := COALESCE((v_item->>'quantidade')::NUMERIC, 1.000);
        
        IF v_tipo_item = 'PRODUTO' THEN
            v_prod_id := (v_item->>'produto_id')::UUID;
            
            SELECT * INTO v_prod_record 
            FROM public.produtos 
            WHERE id = v_prod_id 
            FOR UPDATE;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Produto com ID % não encontrado.', v_prod_id;
            END IF;
            
            IF NOT v_prod_record.permite_venda THEN
                RAISE EXCEPTION 'O item "%" é insumo técnico de uso interno e não permite venda direta.', v_prod_record.nome;
            END IF;
            
            IF v_prod_record.quantidade_estoque < v_qtd THEN
                RAISE EXCEPTION 'Estoque insuficiente para o produto "%". Saldo atual: %, Solicitado: %', 
                    v_prod_record.nome, v_prod_record.quantidade_estoque, v_qtd;
            END IF;
            
            v_preco_orig := COALESCE((v_item->>'preco_original')::NUMERIC, v_prod_record.preco_venda);
            v_preco_unit := COALESCE((v_item->>'preco_unitario')::NUMERIC, 
                                     CASE WHEN v_prod_record.em_promocao AND v_prod_record.preco_promocional IS NOT NULL 
                                          THEN v_prod_record.preco_promocional 
                                          ELSE v_prod_record.preco_venda END);
            v_subtotal := ROUND(v_preco_orig * v_qtd, 2);
            v_item_final := ROUND(v_preco_unit * v_qtd, 2);
            v_item_desconto := GREATEST(v_subtotal - v_item_final, 0.00);
            
            v_valor_bruto := v_valor_bruto + v_subtotal;
            
            UPDATE public.produtos 
            SET quantidade_estoque = quantidade_estoque - v_qtd 
            WHERE id = v_prod_id;
            
            INSERT INTO public.movimentacoes_estoque (produto_id, tipo, quantidade, saldo_anterior, saldo_posterior, venda_id, motivo)
            VALUES (
                v_prod_id, 
                'SAIDA', 
                v_qtd, 
                v_prod_record.quantidade_estoque, 
                v_prod_record.quantidade_estoque - v_qtd, 
                v_venda_id, 
                'Venda PDV - ' || v_prod_record.nome
            );
            
            INSERT INTO public.itens_venda (
                venda_id, tipo_item, produto_id, quantidade, preco_unitario, subtotal,
                valor_original, valor_desconto, tipo_desconto, valor_final
            ) VALUES (
                v_venda_id, 'PRODUTO', v_prod_id, v_qtd, v_preco_unit, v_subtotal,
                v_subtotal, v_item_desconto, COALESCE(v_item->>'tipo_desconto', 'NENHUM'), v_item_final
            );
            
        ELSIF v_tipo_item = 'SERVICO' THEN
            v_serv_id := (v_item->>'servico_id')::UUID;
            
            SELECT * INTO v_serv_record 
            FROM public.servicos 
            WHERE id = v_serv_id;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Serviço com ID % não encontrado.', v_serv_id;
            END IF;
            
            IF NOT v_serv_record.ativo THEN
                RAISE EXCEPTION 'O serviço "%" está desativado.', v_serv_record.nome;
            END IF;
            
            v_preco_orig := COALESCE((v_item->>'preco_original')::NUMERIC, v_serv_record.preco);
            v_preco_unit := COALESCE((v_item->>'preco_unitario')::NUMERIC, 
                                     CASE WHEN v_serv_record.em_promocao AND v_serv_record.preco_promocional IS NOT NULL 
                                          THEN v_serv_record.preco_promocional 
                                          ELSE v_serv_record.preco END);
            v_subtotal := ROUND(v_preco_orig * v_qtd, 2);
            v_item_final := ROUND(v_preco_unit * v_qtd, 2);
            v_item_desconto := GREATEST(v_subtotal - v_item_final, 0.00);
            
            v_valor_bruto := v_valor_bruto + v_subtotal;
            
            INSERT INTO public.itens_venda (
                venda_id, tipo_item, servico_id, quantidade, preco_unitario, subtotal,
                valor_original, valor_desconto, tipo_desconto, valor_final
            ) VALUES (
                v_venda_id, 'SERVICO', v_serv_id, v_qtd, v_preco_unit, v_subtotal,
                v_subtotal, v_item_desconto, COALESCE(v_item->>'tipo_desconto', 'NENHUM'), v_item_final
            );
            
            -- Baixa técnica dos insumos consumidos pelo procedimento
            FOR v_insumo_record IN 
                SELECT si.produto_id, si.quantidade_consumo, p.nome, p.quantidade_estoque, p.unidade_medida
                FROM public.servico_insumos si
                JOIN public.produtos p ON p.id = si.produto_id
                WHERE si.servico_id = v_serv_id
                FOR UPDATE OF p
            LOOP
                v_qtd_insumo_total := v_insumo_record.quantidade_consumo * v_qtd;
                
                IF v_insumo_record.quantidade_estoque < v_qtd_insumo_total THEN
                    RAISE EXCEPTION 'Estoque insuficiente do insumo técnico "%" para o procedimento "%". Saldo atual: % %, Necessário: % %',
                        v_insumo_record.nome, v_serv_record.nome, v_insumo_record.quantidade_estoque, v_insumo_record.unidade_medida,
                        v_qtd_insumo_total, v_insumo_record.unidade_medida;
                END IF;
                
                UPDATE public.produtos 
                SET quantidade_estoque = quantidade_estoque - v_qtd_insumo_total 
                WHERE id = v_insumo_record.produto_id;
                
                INSERT INTO public.movimentacoes_estoque (produto_id, tipo, quantidade, saldo_anterior, saldo_posterior, venda_id, motivo)
                VALUES (
                    v_insumo_record.produto_id,
                    'CONSUMO',
                    v_qtd_insumo_total,
                    v_insumo_record.quantidade_estoque,
                    v_insumo_record.quantidade_estoque - v_qtd_insumo_total,
                    v_venda_id,
                    'Consumo técnico: ' || v_serv_record.nome
                );
            END LOOP;
        ELSE
            RAISE EXCEPTION 'Tipo de item desconhecido: %', v_tipo_item;
        END IF;
    END LOOP;

    v_valor_liquido := GREATEST(v_valor_bruto - v_desconto, 0.00);

    UPDATE public.vendas 
    SET valor_bruto = v_valor_bruto,
        valor_liquido = v_valor_liquido,
        valor_original = v_valor_bruto,
        valor_desconto = v_desconto,
        tipo_desconto = v_tipo_desconto,
        valor_final = v_valor_liquido
    WHERE id = v_venda_id;

    -- 3. Registro na Transação Financeira (com conta_bancaria_id e status)
    v_transacao_id := gen_random_uuid();
    INSERT INTO public.transacoes_financeiras (
        id, descricao, escopo, tipo, cartao_id, conta_bancaria_id, venda_id, valor, valor_total, 
        parcelas, data_competencia, data_transacao, data_vencimento, data_pagamento, forma_pagamento, status
    ) VALUES (
        v_transacao_id,
        CASE WHEN v_status_pagamento = 'PENDENTE' 
             THEN 'Venda a Receber (Fiado) #' || UPPER(SUBSTRING(v_venda_id::TEXT FROM 1 FOR 8))
             ELSE 'Receita Venda PDV #' || UPPER(SUBSTRING(v_venda_id::TEXT FROM 1 FOR 8))
        END,
        'PJ',
        'ENTRADA',
        v_cartao_id,
        v_conta_bancaria_id,
        v_venda_id,
        v_valor_liquido,
        v_valor_liquido,
        v_parcelas,
        CURRENT_DATE,
        CURRENT_DATE,
        COALESCE(v_data_prevista, CURRENT_DATE),
        CASE WHEN v_status_pagamento = 'EFETIVADO' THEN CURRENT_DATE ELSE NULL END,
        v_forma_pagamento::text,
        CASE WHEN v_status_pagamento = 'EFETIVADO' THEN 'PAGO' ELSE 'PENDENTE' END
    );

    RETURN jsonb_build_object(
        'success', true,
        'venda_id', v_venda_id,
        'valor_bruto', v_valor_bruto,
        'desconto', v_desconto,
        'valor_liquido', v_valor_liquido,
        'valor_original', v_valor_bruto,
        'valor_desconto', v_desconto,
        'tipo_desconto', v_tipo_desconto,
        'valor_final', v_valor_liquido,
        'forma_pagamento', v_forma_pagamento,
        'status_pagamento', v_status_pagamento,
        'conta_bancaria_id', v_conta_bancaria_id,
        'data_prevista_pagamento', v_data_prevista,
        'transacao_id', v_transacao_id,
        'status', 'CONCLUIDA'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.realizar_venda(jsonb) TO anon, authenticated, service_role;

-- 5. STORED PROCEDURE ATUALIZADA: OBTER_DASHBOARD_RESUMO (Com filtro dinâmico de mês)
CREATE OR REPLACE FUNCTION public.obter_dashboard_resumo(
    p_mes_referencia TEXT DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_faturamento_pj NUMERIC(12, 2) := 0.00;
    v_despesas_pf NUMERIC(12, 2) := 0.00;
    v_despesas_pj NUMERIC(12, 2) := 0.00;
    v_balanco_liquido NUMERIC(12, 2) := 0.00;
    v_vendas_efetivadas NUMERIC(12, 2) := 0.00;
    v_vendas_a_receber NUMERIC(12, 2) := 0.00;
    v_total_vendas_mes INT := 0;
    v_alertas jsonb := '[]'::jsonb;
    v_primeiro_dia_mes DATE;
    v_ultimo_dia_mes DATE;
BEGIN
    -- Se fornecido YYYY-MM, filtra pelo mês especificado; caso contrário usa o mês corrente
    IF p_mes_referencia IS NOT NULL AND p_mes_referencia ~ '^\d{4}-\d{2}$' THEN
        v_primeiro_dia_mes := TO_DATE(p_mes_referencia || '-01', 'YYYY-MM-DD');
        v_ultimo_dia_mes := (DATE_TRUNC('month', v_primeiro_dia_mes) + INTERVAL '1 month - 1 day')::DATE;
    ELSE
        v_primeiro_dia_mes := DATE_TRUNC('month', CURRENT_DATE)::DATE;
        v_ultimo_dia_mes := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    END IF;

    -- 1. Vendas Efetivadas vs Vendas a Receber (Fiado) no período
    SELECT 
        COALESCE(SUM(CASE WHEN status_pagamento = 'EFETIVADO' THEN valor_liquido ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN status_pagamento = 'PENDENTE' THEN valor_liquido ELSE 0 END), 0.00),
        COUNT(*)
    INTO 
        v_vendas_efetivadas,
        v_vendas_a_receber,
        v_total_vendas_mes
    FROM public.vendas
    WHERE status = 'CONCLUIDA'
      AND data_hora::DATE BETWEEN v_primeiro_dia_mes AND v_ultimo_dia_mes;

    -- 2. Métricas de Caixa Real (Apenas transações efetivamente pagas)
    SELECT 
        COALESCE(SUM(CASE WHEN escopo = 'PJ' AND tipo IN ('ENTRADA', 'RECEITA') AND status IN ('PAGO', 'EFETIVADO') THEN COALESCE(valor, valor_total) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN escopo = 'PF' AND tipo IN ('SAIDA', 'DESPESA') AND status IN ('PAGO', 'EFETIVADO') THEN COALESCE(valor, valor_total) ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN escopo = 'PJ' AND tipo IN ('SAIDA', 'DESPESA') AND status IN ('PAGO', 'EFETIVADO') THEN COALESCE(valor, valor_total) ELSE 0 END), 0.00)
    INTO 
        v_faturamento_pj,
        v_despesas_pf,
        v_despesas_pj
    FROM public.transacoes_financeiras
    WHERE COALESCE(data_pagamento, data_transacao, data_competencia, created_at::DATE) BETWEEN v_primeiro_dia_mes AND v_ultimo_dia_mes;

    -- Se não houver transações de entrada lançadas mas houver vendas PDV efetivadas, usa o faturamento de vendas
    IF v_faturamento_pj = 0.00 AND v_vendas_efetivadas > 0.00 THEN
        v_faturamento_pj := v_vendas_efetivadas;
    END IF;

    v_balanco_liquido := v_faturamento_pj - v_despesas_pj;

    -- 3. Alertas de Estoque Crítico
    SELECT COALESCE(jsonb_agg(alerta_row), '[]'::jsonb)
    INTO v_alertas
    FROM (
        SELECT 
            id, nome, codigo_barras, quantidade_estoque, estoque_minimo, unidade_medida,
            GREATEST(estoque_minimo - quantidade_estoque, 0.000) AS deficit,
            CASE WHEN quantidade_estoque <= 0 THEN 'CRITICO' ELSE 'BAIXO' END AS status_alerta
        FROM public.produtos
        WHERE quantidade_estoque <= estoque_minimo
        ORDER BY quantidade_estoque ASC
        LIMIT 10
    ) alerta_row;

    RETURN jsonb_build_object(
        'mes_referencia', COALESCE(p_mes_referencia, TO_CHAR(v_primeiro_dia_mes, 'YYYY-MM')),
        'faturamento_pj', v_faturamento_pj,
        'despesas_pf', v_despesas_pf,
        'despesas_pj', v_despesas_pj,
        'balanco_liquido', v_balanco_liquido,
        'vendas_efetivadas', v_vendas_efetivadas,
        'vendas_a_receber', v_vendas_a_receber,
        'total_vendas_mes', v_total_vendas_mes,
        'total_alertas_estoque', jsonb_array_length(v_alertas),
        'alertas_estoque', v_alertas
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.obter_dashboard_resumo(TEXT) TO anon, authenticated, service_role;

-- 6. TRIGGER ROBUSTO: ATUALIZAÇÃO AUTOMÁTICA DE SALDO EM CONTAS BANCÁRIAS (INSERT, UPDATE, DELETE)
CREATE OR REPLACE FUNCTION public.fn_atualizar_saldo_conta_bancaria()
RETURNS TRIGGER AS $$
DECLARE
    v_valor_novo NUMERIC(12, 2);
    v_valor_antigo NUMERIC(12, 2);
BEGIN
    -- Ao inserir nova transação efetivada
    IF TG_OP = 'INSERT' THEN
        v_valor_novo := COALESCE(NEW.valor, NEW.valor_total, 0.00);
        IF NEW.conta_bancaria_id IS NOT NULL AND NEW.status IN ('EFETIVADO', 'PAGO') THEN
            IF NEW.tipo IN ('RECEITA', 'ENTRADA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual + v_valor_novo, updated_at = NOW()
                WHERE id = NEW.conta_bancaria_id;
            ELSIF NEW.tipo IN ('DESPESA', 'SAIDA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual - v_valor_novo, updated_at = NOW()
                WHERE id = NEW.conta_bancaria_id;
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    -- Ao atualizar transação (reversão do antigo + aplicação do novo)
    IF TG_OP = 'UPDATE' THEN
        v_valor_antigo := COALESCE(OLD.valor, OLD.valor_total, 0.00);
        v_valor_novo := COALESCE(NEW.valor, NEW.valor_total, 0.00);

        -- 1. Reverter saldo antigo se estava pago
        IF OLD.conta_bancaria_id IS NOT NULL AND OLD.status IN ('EFETIVADO', 'PAGO') THEN
            IF OLD.tipo IN ('RECEITA', 'ENTRADA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual - v_valor_antigo, updated_at = NOW()
                WHERE id = OLD.conta_bancaria_id;
            ELSIF OLD.tipo IN ('DESPESA', 'SAIDA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual + v_valor_antigo, updated_at = NOW()
                WHERE id = OLD.conta_bancaria_id;
            END IF;
        END IF;

        -- 2. Aplicar saldo novo se está pago
        IF NEW.conta_bancaria_id IS NOT NULL AND NEW.status IN ('EFETIVADO', 'PAGO') THEN
            IF NEW.tipo IN ('RECEITA', 'ENTRADA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual + v_valor_novo, updated_at = NOW()
                WHERE id = NEW.conta_bancaria_id;
            ELSIF NEW.tipo IN ('DESPESA', 'SAIDA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual - v_valor_novo, updated_at = NOW()
                WHERE id = NEW.conta_bancaria_id;
            END IF;
        END IF;
        RETURN NEW;
    END IF;

    -- Ao deletar transação efetivada (reverter saldo)
    IF TG_OP = 'DELETE' THEN
        v_valor_antigo := COALESCE(OLD.valor, OLD.valor_total, 0.00);
        IF OLD.conta_bancaria_id IS NOT NULL AND OLD.status IN ('EFETIVADO', 'PAGO') THEN
            IF OLD.tipo IN ('RECEITA', 'ENTRADA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual - v_valor_antigo, updated_at = NOW()
                WHERE id = OLD.conta_bancaria_id;
            ELSIF OLD.tipo IN ('DESPESA', 'SAIDA') THEN
                UPDATE public.contas_bancarias
                SET saldo_atual = saldo_atual + v_valor_antigo, updated_at = NOW()
                WHERE id = OLD.conta_bancaria_id;
            END IF;
        END IF;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_atualizar_saldo_conta_bancaria ON public.transacoes_financeiras;
CREATE TRIGGER trg_atualizar_saldo_conta_bancaria
    AFTER INSERT OR UPDATE OR DELETE ON public.transacoes_financeiras
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_atualizar_saldo_conta_bancaria();

-- 7. STORED PROCEDURE: ADMIN EXCLUIR USUÁRIO COM SEGURANÇA
CREATE OR REPLACE FUNCTION public.admin_excluir_usuario(
    p_user_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Remove da tabela pública e autenticação do Supabase
    DELETE FROM public.perfis_usuarios WHERE id = p_user_id;
    DELETE FROM auth.users WHERE id = p_user_id;

    RETURN jsonb_build_object(
        'success', true,
        'user_id', p_user_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_excluir_usuario(UUID) TO anon, authenticated, service_role;

-- 8. RECARREGAR O CACHE DO SCHEMA POSTGREST
NOTIFY pgrst, 'reload schema';
