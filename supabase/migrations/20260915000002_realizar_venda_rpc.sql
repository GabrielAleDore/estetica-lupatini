-- ==============================================================================
-- Migration: 20260915000002_realizar_venda_rpc.sql
-- Stored Procedures para Operação 100% Flutter + Supabase
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. FUNÇÃO ATÔMICA: REALIZAR VENDA (RPC Supabase)
-- Executa com bloqueio pessimista, baixa de estoque e lançamento contábil.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION realizar_venda(p_venda jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_venda_id UUID := gen_random_uuid();
    v_cliente_id UUID;
    v_forma_pagamento forma_pagamento_tipo;
    v_desconto NUMERIC(12, 2) := 0.00;
    v_observacoes TEXT;
    v_cartao_id UUID;
    v_parcelas INT := 1;
    v_itens jsonb;
    v_item jsonb;
    
    v_tipo_item VARCHAR(20);
    v_prod_id UUID;
    v_serv_id UUID;
    v_qtd NUMERIC(12, 3);
    v_preco_unit NUMERIC(12, 2);
    v_subtotal NUMERIC(12, 2);
    v_valor_bruto NUMERIC(12, 2) := 0.00;
    v_valor_liquido NUMERIC(12, 2) := 0.00;
    
    -- Insumos e Estoque
    v_prod_record RECORD;
    v_serv_record RECORD;
    v_insumo_record RECORD;
    v_qtd_insumo_total NUMERIC(12, 3);
    v_transacao_id UUID;
BEGIN
    -- Validação do payload
    IF p_venda IS NULL THEN
        RAISE EXCEPTION 'Dados da venda não fornecidos.';
    END IF;

    IF p_venda->>'cliente_id' IS NOT NULL AND p_venda->>'cliente_id' <> '' THEN
        v_cliente_id := (p_venda->>'cliente_id')::UUID;
    END IF;

    v_forma_pagamento := COALESCE((p_venda->>'forma_pagamento')::forma_pagamento_tipo, 'PIX'::forma_pagamento_tipo);
    v_desconto := COALESCE((p_venda->>'desconto')::NUMERIC, 0.00);
    v_observacoes := p_venda->>'observacoes';
    
    IF p_venda->>'cartao_id' IS NOT NULL AND p_venda->>'cartao_id' <> '' THEN
        v_cartao_id := (p_venda->>'cartao_id')::UUID;
    END IF;
    v_parcelas := COALESCE((p_venda->>'parcelas')::INT, 1);
    
    v_itens := p_venda->'itens';
    IF v_itens IS NULL OR jsonb_array_length(v_itens) = 0 THEN
        RAISE EXCEPTION 'A venda deve conter pelo menos um item.';
    END IF;

    -- 1. Cria a venda inicial
    INSERT INTO vendas (id, cliente_id, data_hora, valor_bruto, desconto, valor_liquido, forma_pagamento, status, observacoes)
    VALUES (v_venda_id, v_cliente_id, NOW(), 0.00, v_desconto, 0.00, v_forma_pagamento, 'CONCLUIDA', v_observacoes);

    -- 2. Processa os itens
    FOR v_item IN SELECT * FROM jsonb_array_elements(v_itens)
    LOOP
        v_tipo_item := UPPER(v_item->>'tipo_item');
        v_qtd := COALESCE((v_item->>'quantidade')::NUMERIC, 1.000);
        
        IF v_tipo_item = 'PRODUTO' THEN
            v_prod_id := (v_item->>'produto_id')::UUID;
            
            -- Bloqueio pessimista para evitar concorrência de estoque
            SELECT * INTO v_prod_record 
            FROM produtos 
            WHERE id = v_prod_id 
            FOR UPDATE;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Produto com ID % não encontrado.', v_prod_id;
            END IF;
            
            IF NOT v_prod_record.permite_venda THEN
                RAISE EXCEPTION 'O item "%" é insumo de uso interno e não permite venda direta.', v_prod_record.nome;
            END IF;
            
            IF v_prod_record.quantidade_estoque < v_qtd THEN
                RAISE EXCEPTION 'Estoque insuficiente para o produto "%". Saldo atual: %, Solicitado: %', 
                    v_prod_record.nome, v_prod_record.quantidade_estoque, v_qtd;
            END IF;
            
            v_preco_unit := COALESCE((v_item->>'preco_unitario')::NUMERIC, v_prod_record.preco_venda);
            v_subtotal := ROUND(v_preco_unit * v_qtd, 2);
            v_valor_bruto := v_valor_bruto + v_subtotal;
            
            -- Baixa de Estoque
            UPDATE produtos 
            SET quantidade_estoque = quantidade_estoque - v_qtd 
            WHERE id = v_prod_id;
            
            -- Rastreabilidade de movimentação
            INSERT INTO movimentacoes_estoque (produto_id, tipo, quantidade, saldo_anterior, saldo_posterior, venda_id, motivo)
            VALUES (
                v_prod_id, 
                'SAIDA', 
                v_qtd, 
                v_prod_record.quantidade_estoque, 
                v_prod_record.quantidade_estoque - v_qtd, 
                v_venda_id, 
                'Venda PDV - ' || v_prod_record.nome
            );
            
            -- Item da Venda
            INSERT INTO itens_venda (venda_id, tipo_item, produto_id, quantidade, preco_unitario, subtotal)
            VALUES (v_venda_id, 'PRODUTO', v_prod_id, v_qtd, v_preco_unit, v_subtotal);
            
        ELSIF v_tipo_item = 'SERVICO' THEN
            v_serv_id := (v_item->>'servico_id')::UUID;
            
            SELECT * INTO v_serv_record 
            FROM servicos 
            WHERE id = v_serv_id;
            
            IF NOT FOUND THEN
                RAISE EXCEPTION 'Serviço com ID % não encontrado.', v_serv_id;
            END IF;
            
            IF NOT v_serv_record.ativo THEN
                RAISE EXCEPTION 'O serviço "%" está desativado.', v_serv_record.nome;
            END IF;
            
            v_preco_unit := COALESCE((v_item->>'preco_unitario')::NUMERIC, v_serv_record.preco);
            v_subtotal := ROUND(v_preco_unit * v_qtd, 2);
            v_valor_bruto := v_valor_bruto + v_subtotal;
            
            -- Item da Venda
            INSERT INTO itens_venda (venda_id, tipo_item, servico_id, quantidade, preco_unitario, subtotal)
            VALUES (v_venda_id, 'SERVICO', v_serv_id, v_qtd, v_preco_unit, v_subtotal);
            
            -- Baixa técnica de insumos vinculados ao serviço
            FOR v_insumo_record IN 
                SELECT si.produto_id, si.quantidade_consumo, p.nome, p.quantidade_estoque, p.unidade_medida
                FROM servico_insumos si
                JOIN produtos p ON p.id = si.produto_id
                WHERE si.servico_id = v_serv_id
                FOR UPDATE OF p
            LOOP
                v_qtd_insumo_total := v_insumo_record.quantidade_consumo * v_qtd;
                
                IF v_insumo_record.quantidade_estoque < v_qtd_insumo_total THEN
                    RAISE EXCEPTION 'Estoque insuficiente do insumo técnico "%" para o procedimento "%". Saldo atual: % %, Necessário: % %',
                        v_insumo_record.nome, v_serv_record.nome, v_insumo_record.quantidade_estoque, v_insumo_record.unidade_medida,
                        v_qtd_insumo_total, v_insumo_record.unidade_medida;
                END IF;
                
                UPDATE produtos 
                SET quantidade_estoque = quantidade_estoque - v_qtd_insumo_total 
                WHERE id = v_insumo_record.produto_id;
                
                INSERT INTO movimentacoes_estoque (produto_id, tipo, quantidade, saldo_anterior, saldo_posterior, venda_id, motivo)
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

    -- Atualiza totais na venda
    UPDATE vendas 
    SET valor_bruto = v_valor_bruto,
        valor_liquido = v_valor_liquido
    WHERE id = v_venda_id;

    -- 3. Registro contábil da receita (Escopo PJ)
    v_transacao_id := gen_random_uuid();
    INSERT INTO transacoes_financeiras (
        id, descricao, escopo, tipo, cartao_id, venda_id, valor_total, parcelas, data_competencia
    ) VALUES (
        v_transacao_id,
        'Receita de Venda PDV #' || UPPER(SUBSTRING(v_venda_id::TEXT FROM 1 FOR 8)),
        'PJ',
        'ENTRADA',
        v_cartao_id,
        v_venda_id,
        v_valor_liquido,
        v_parcelas,
        CURRENT_DATE
    );

    -- Retorna o resumo da venda em jsonb
    RETURN jsonb_build_object(
        'success', true,
        'venda_id', v_venda_id,
        'valor_bruto', v_valor_bruto,
        'desconto', v_desconto,
        'valor_liquido', v_valor_liquido,
        'forma_pagamento', v_forma_pagamento,
        'transacao_id', v_transacao_id,
        'status', 'CONCLUIDA'
    );
END;
$$;


-- ------------------------------------------------------------------------------
-- 2. FUNÇÃO: DASHBOARD RESUMO (RPC Supabase)
-- Agregação otimizada em uma única consulta PostgreSQL.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION obter_dashboard_resumo()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_faturamento_pj NUMERIC(12, 2) := 0.00;
    v_despesas_pf NUMERIC(12, 2) := 0.00;
    v_despesas_pj NUMERIC(12, 2) := 0.00;
    v_balanco_liquido NUMERIC(12, 2) := 0.00;
    v_total_vendas_mes INT := 0;
    v_alertas jsonb := '[]'::jsonb;
    v_transacoes jsonb := '[]'::jsonb;
    v_primeiro_dia_mes DATE := DATE_TRUNC('month', CURRENT_DATE)::DATE;
    v_ultimo_dia_mes DATE := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
BEGIN
    -- 1. Métricas financeiras agregadas do mês corrente
    SELECT 
        COALESCE(SUM(CASE WHEN escopo = 'PJ' AND tipo = 'ENTRADA' THEN valor_total ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN escopo = 'PF' AND tipo = 'SAIDA' THEN valor_total ELSE 0 END), 0.00),
        COALESCE(SUM(CASE WHEN escopo = 'PJ' AND tipo = 'SAIDA' THEN valor_total ELSE 0 END), 0.00)
    INTO 
        v_faturamento_pj,
        v_despesas_pf,
        v_despesas_pj
    FROM transacoes_financeiras
    WHERE data_competencia BETWEEN v_primeiro_dia_mes AND v_ultimo_dia_mes;

    v_balanco_liquido := v_faturamento_pj - v_despesas_pj;

    -- 2. Total de vendas concluídas no mês
    SELECT COUNT(*)
    INTO v_total_vendas_mes
    FROM vendas
    WHERE status = 'CONCLUIDA'
      AND data_hora >= v_primeiro_dia_mes::TIMESTAMPTZ;

    -- 3. Alertas de estoque crítico
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'nome', p.nome,
            'codigo_barras', p.codigo_barras,
            'quantidade_estoque', p.quantidade_estoque,
            'estoque_minimo', p.estoque_minimo,
            'unidade_medida', p.unidade_medida,
            'deficit', GREATEST(p.estoque_minimo - p.quantidade_estoque, 0.000),
            'status_alerta', CASE WHEN p.quantidade_estoque <= 0 THEN 'CRITICO' ELSE 'BAIXO' END
        )
    ), '[]'::jsonb)
    INTO v_alertas
    FROM produtos p
    WHERE p.quantidade_estoque <= p.estoque_minimo;

    -- 4. Últimas 10 transações
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', t.id,
            'descricao', t.descricao,
            'escopo', t.escopo,
            'tipo', t.tipo,
            'valor_total', t.valor_total,
            'data_competencia', t.data_competencia,
            'created_at', t.created_at
        ) ORDER BY t.created_at DESC
    ), '[]'::jsonb)
    INTO v_transacoes
    FROM (
        SELECT * FROM transacoes_financeiras
        ORDER BY created_at DESC
        LIMIT 10
    ) t;

    RETURN jsonb_build_object(
        'faturamento_pj', v_faturamento_pj,
        'despesas_pf', v_despesas_pf,
        'despesas_pj', v_despesas_pj,
        'balanco_liquido', v_balanco_liquido,
        'total_vendas_mes', v_total_vendas_mes,
        'alertas_estoque', v_alertas,
        'total_alertas_estoque', jsonb_array_length(v_alertas),
        'transacoes_recentes', v_transacoes
    );
END;
$$;
